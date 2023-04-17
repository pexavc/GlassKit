//
//  File.swift
//  
//
//  Created by PEXAVC on 3/23/21.
//

import Foundation
import AVFoundation
import AudioToolbox

protocol AudioConvertable {
    var engineAudioFormat: AVAudioFormat {get}
    
    init(withRemoteUrl url: AudioURL, toEngineAudioFormat: AVAudioFormat, label: String) throws
    func pullBuffer(withSize size: AVAudioFrameCount) throws -> AVAudioPCMBuffer
    func pollPredictedDuration() -> Duration?
    func pollNetworkAudioAvailabilityRange() -> (Needle, Duration)
    func seek(_ needle: Needle)
    func invalidate()
}

extension AudioConvertable {
    init(withRemoteUrl url: AudioURL, toEngineAudioFormat: AVAudioFormat) throws {
        try self.init(withRemoteUrl: url, toEngineAudioFormat: toEngineAudioFormat, label: "main")
    }
}

extension LeVerre {
    
    /**
     Creates PCM Buffers for the audio engine
     
     Main Responsibilities:
     
     CREATE CONVERTER. Waits for parser to give back audio format then creates a
     converter.
     
     USE CONVERTER. The converter takes parsed audio packets and 1. transforms them
     into a format that the engine can take. 2. Fills a buffer of a certain size.
     Note that we might not need a converted if the format that the engine takes in
     is the same as what the parser outputs.
     
     KEEP AUDIO INDEX: The engine keeps trying to pull a buffer from converter. The
     converter will keep pulling from parser. The converter calculates the exact
     index that it wants to convert and keeps pulling at that index until the parser
     passes up a value.
     */
    public class Converter: AudioConvertable {
        let queue = DispatchQueue(label: "glass.leverre.converter")
        
        //From Init
        var parser: AudioParsable!
        
        //From protocol
        public var engineAudioFormat: AVAudioFormat
        
        //Field
        var converter: AudioConverterRef? //set by AudioConverterNew
        var currentAudioPacketIndex: AVAudioPacketCount = 0
        var label: String
        required init(withRemoteUrl url: AudioURL, toEngineAudioFormat: AVAudioFormat, label: String) throws {
            self.label = label
            self.engineAudioFormat = toEngineAudioFormat
            do {
                parser = try AudioParser(withRemoteUrl: url, parsedFileAudioFormatCallback: {
                    [weak self] (fileAudioFormat: AVAudioFormat) in
                    guard let strongSelf = self else { return }
                    
                    let sourceFormat = fileAudioFormat.streamDescription
                    let destinationFormat = strongSelf.engineAudioFormat.streamDescription
                    let result = AudioConverterNew(sourceFormat, destinationFormat, &strongSelf.converter)
                    
                    guard result == noErr else {
                        Log.monitor(ConverterError.unableToCreateConverter(result).errorDescription as Any)
                        return
                    }
                })
            } catch {
                throw ConverterError.failedToCreateParser
            }
        }
        
        deinit {
            guard let converter = converter else {
                Log.error("No converter n deinit!")
                return
            }
            
            guard AudioConverterDispose(converter) == noErr else {
                Log.monitor("failed to dispose audio converter")
                return
            }
        }
        
        func pullBuffer(withSize size: AVAudioFrameCount) throws -> AVAudioPCMBuffer {
            guard let converter = converter else {
                Log.monitor("reader_error trying to read before converter has been created")
                throw ConverterError.cannotCreatePCMBufferWithoutConverter
            }
            
            guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: engineAudioFormat, frameCapacity: size) else {
                Log.monitor(ConverterError.failedToCreatePCMBuffer.errorDescription as Any)
                throw ConverterError.failedToCreatePCMBuffer
            }
            pcmBuffer.frameLength = size
            
            /**
             The whole thing is wrapped in queue.sync() because the converter listener
             needs to eventually increment the audioPatcketIndex. We don't want threads
             to mess this up
             */
            return try queue.sync { () -> AVAudioPCMBuffer in
                let framesPerPacket = engineAudioFormat.streamDescription.pointee.mFramesPerPacket
                var numberOfPacketsWeWantTheBufferToFill = size / framesPerPacket
                
                let context = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
                let status = AudioConverterFillComplexBuffer(converter, ConverterListener, context, &numberOfPacketsWeWantTheBufferToFill, pcmBuffer.mutableAudioBufferList, nil)
                
                guard status == noErr else {
                    switch status {
                    case ReaderMissingSourceFormatError:
                        throw ConverterError.parserMissingDataFormat
                    case ReaderReachedEndOfDataError:
                        throw ConverterError.reachedEndOfFile
                    case ReaderNotEnoughDataError:
                        throw ConverterError.notEnoughData
                    case ReaderShouldNotHappenError:
                        throw ConverterError.superConcerningShouldNeverHappen
                    default:
                        throw ConverterError.converterFailed(status)
                    }
                }
                return pcmBuffer
            }
        }
        
        func seek(_ needle: Needle) {
            guard let audioPacketIndex = getPacketIndex(forNeedle: needle) else {
                return
            }
            Log.info("didSeek to packet index: \(audioPacketIndex)")
            queue.sync {
                currentAudioPacketIndex = audioPacketIndex
                parser.tellSeek(toIndex: audioPacketIndex)
            }
        }
        
        func pollPredictedDuration() -> Duration? {
            return parser.predictedDuration
        }
        
        func pollNetworkAudioAvailabilityRange() -> (Needle, Duration) {
            return parser.pollRangeOfSecondsAvailableFromNetwork()
        }
        
        func invalidate() {
            parser.invalidate()
        }
        
        private func getPacketIndex(forNeedle needle: Needle) -> AVAudioPacketCount? {
            guard needle >= 0 else {
                Log.error("needle should never be a negative number! needle received: \(needle)")
                return nil
            }
            guard let frame = frameOffset(forTime: TimeInterval(needle)) else { return nil }
            guard let framesPerPacket = parser.fileAudioFormat?.streamDescription.pointee.mFramesPerPacket else { return nil }
            return AVAudioPacketCount(frame) / AVAudioPacketCount(framesPerPacket)
        }
        
        private func frameOffset(forTime time: TimeInterval) -> AVAudioFramePosition? {
            guard let _ = parser.fileAudioFormat?.streamDescription.pointee, let frameCount = parser.totalPredictedAudioFrameCount, let duration = parser.predictedDuration else { return nil }
            let ratio = time / duration
            return AVAudioFramePosition(Double(frameCount) * ratio)
        }
    }
}

//MARK: -- Errors
let ReaderReachedEndOfDataError: OSStatus = 932332581
let ReaderNotEnoughDataError: OSStatus = 932332582
let ReaderMissingSourceFormatError: OSStatus = 932332583
let ReaderMissingParserError: OSStatus = 932332584
let ReaderShouldNotHappenError: OSStatus = 932332585

public enum ConverterError: LocalizedError {
    case cannotLockQueue
    case converterFailed(OSStatus)
    case cannotCreatePCMBufferWithoutConverter
    case failedToCreateDestinationFormat
    case failedToCreatePCMBuffer
    case notEnoughData
    case parserMissingDataFormat
    case reachedEndOfFile
    case unableToCreateConverter(OSStatus)
    case superConcerningShouldNeverHappen
    case throttleParsingBuffersForEngine
    case failedToCreateParser
    
    public var errorDescription: String? {
        switch self {
        case .cannotLockQueue:
            Log.warn("Failed to lock queue")
            return "Failed to lock queue"
        case .converterFailed(let status):
            Log.warn(localizedDescriptionFromConverterError(status))
            return localizedDescriptionFromConverterError(status)
        case .failedToCreateDestinationFormat:
            Log.warn("Failed to create a destination (processing) format")
            return "Failed to create a destination (processing) format"
        case .failedToCreatePCMBuffer:
            Log.warn("Failed to create PCM buffer for reading data")
            return "Failed to create PCM buffer for reading data"
        case .notEnoughData:
            Log.warn("Not enough data for read-conversion operation")
            return "Not enough data for read-conversion operation"
        case .parserMissingDataFormat:
            Log.warn("Parser is missing a valid data format")
            return "Parser is missing a valid data format"
        case .reachedEndOfFile:
            Log.warn("Reached the end of the file")
            return "Reached the end of the file"
        case .unableToCreateConverter(let status):
            return localizedDescriptionFromConverterError(status)
        case .superConcerningShouldNeverHappen:
            Log.warn("Weird unexpected reader error. Should not have happened")
            return "Weird unexpected reader error. Should not have happened"
        case .cannotCreatePCMBufferWithoutConverter:
            Log.debug("Could not create a PCM Buffer because reader does not have a converter yet")
            return "Could not create a PCM Buffer because reader does not have a converter yet"
        case .throttleParsingBuffersForEngine:
            Log.warn("Preventing the reader from creating more PCM buffers since the player has more than 60 seconds of audio already to play")
            return "Preventing the reader from creating more PCM buffers since the player has more than 60 seconds of audio already to play"
        case .failedToCreateParser:
            Log.warn("Could not create a parser")
            return "Could not create a parser"
        }
    }
    
    func localizedDescriptionFromConverterError(_ status: OSStatus) -> String {
        switch status {
        case kAudioConverterErr_FormatNotSupported:
            return "Format not supported"
        case kAudioConverterErr_OperationNotSupported:
            return "Operation not supported"
        case kAudioConverterErr_PropertyNotSupported:
            return "Property not supported"
        case kAudioConverterErr_InvalidInputSize:
            return "Invalid input size"
        case kAudioConverterErr_InvalidOutputSize:
            return "Invalid output size"
        case kAudioConverterErr_BadPropertySizeError:
            return "Bad property size error"
        case kAudioConverterErr_RequiresPacketDescriptionsError:
            return "Requires packet descriptions"
        case kAudioConverterErr_InputSampleRateOutOfRange:
            return "Input sample rate out of range"
        case kAudioConverterErr_OutputSampleRateOutOfRange:
            return "Output sample rate out of range"
        #if os(iOS)
        case kAudioConverterErr_HardwareInUse:
            return "Hardware is in use"
        case kAudioConverterErr_NoHardwarePermission:
            return "No hardware permission"
        #endif
        default:
            return "Unspecified error"
        }
    }
}

//MARK: -- Listener

func ConverterListener(_ converter: AudioConverterRef, _ packetCount: UnsafeMutablePointer<UInt32>, _ ioData: UnsafeMutablePointer<AudioBufferList>, _ outPacketDescriptions: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?, _ context: UnsafeMutableRawPointer?) -> OSStatus {
    let selfAudioConverter = Unmanaged<LeVerre.Converter>.fromOpaque(context!).takeUnretainedValue()
    
    guard let parser = selfAudioConverter.parser else {
        Log.monitor("ReaderMissingParserError")
        return ReaderMissingParserError
    }
    
    guard let fileAudioFormat = parser.fileAudioFormat else {
        Log.monitor("ReaderMissingSourceFormatError")
        return ReaderMissingSourceFormatError
    }
    
    var audioPacketFromParser:(AudioStreamPacketDescription?, Data)?
    do {
        audioPacketFromParser = try parser.pullPacket(atIndex: selfAudioConverter.currentAudioPacketIndex)
        Log.debug("received packet from parser at index: \(selfAudioConverter.currentAudioPacketIndex)")
    } catch ParserError.notEnoughDataForReader {
        return ReaderNotEnoughDataError
    } catch ParserError.readerAskingBeyondEndOfFile {
        //On output, the number of packets of audio data provided for conversion,
        //or 0 if there is no more data to convert.
        packetCount.pointee = 0
        return ReaderReachedEndOfDataError
    } catch {
        return ReaderShouldNotHappenError
    }
    
    guard let audioPacket = audioPacketFromParser else {
        return ReaderShouldNotHappenError
    }
    
    // Copy data over (note we've only processing a single packet of data at a time)
    var packet = audioPacket.1
    let packetByteCount = packet.count //this is not the count of an array
    ioData.pointee.mNumberBuffers = 1
    ioData.pointee.mBuffers.mData = UnsafeMutableRawPointer.allocate(byteCount: packetByteCount, alignment: 0)
    _ = packet.accessMutableBytes({ (bytes: UnsafeMutablePointer<UInt8>) in
        memcpy((ioData.pointee.mBuffers.mData?.assumingMemoryBound(to: UInt8.self))!, bytes, packetByteCount)
    })
    ioData.pointee.mBuffers.mDataByteSize = UInt32(packetByteCount)
    
    // Handle packet descriptions for compressed formats (MP3, AAC, etc)
    let fileFormatDescription = fileAudioFormat.streamDescription.pointee
    if fileFormatDescription.mFormatID != kAudioFormatLinearPCM {
        if outPacketDescriptions?.pointee == nil {
            outPacketDescriptions?.pointee = UnsafeMutablePointer<AudioStreamPacketDescription>.allocate(capacity: 1)
        }
        outPacketDescriptions?.pointee?.pointee.mDataByteSize = UInt32(packetByteCount)
        outPacketDescriptions?.pointee?.pointee.mStartOffset = 0
        outPacketDescriptions?.pointee?.pointee.mVariableFramesInPacket = 0
    }
    
    packetCount.pointee = 1
    
    //we've successfully given a packet to the LPCM buffer now we can process the next audio packet
    selfAudioConverter.currentAudioPacketIndex = selfAudioConverter.currentAudioPacketIndex + 1
    
    return noErr
}
