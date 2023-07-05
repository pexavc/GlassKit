//
//  GlassEngine.swift
//  Marble
//
//  Created by PEXAVC on 8/8/20.
//  Copyright © 2020 Linen & Sole. All rights reserved.
//


import Foundation
import AudioToolbox
import AVFoundation
import VideoToolbox
import Accelerate
import AudioToolbox

var _audio_utilities_sample_count = 8192//480//1024 for hardware audio

public protocol GlassPlayerEngineDelegate: class {
    func getSignal(fromPlayer samples: [Float], sum: Float)
}

public protocol GlassPlayerEngineDirectiveDelegate: class {
    func requestSignal(_ frames: AUAudioFrameCount) throws -> [Float]
    func getPlayerTime(_ time: Double)
}

open class GlassPlayerEngine: NSObject {
    public weak var delegate: GlassPlayerEngineDelegate?
    public weak var directive: GlassPlayerEngineDirectiveDelegate?
    
    public static let shared = GlassPlayerEngine()
    
#if os(iOS) || os(tvOS)
    let audioSession : AVAudioSession = AVAudioSession.sharedInstance()
#endif
    
    public var liveAudioUnit: AUAudioUnit?
    private var renderBlock : AURenderBlock? = nil
    
    var sampleRate : Double =  48000.0      // desired audio sample rate
    
    let circBuffSize        =  32768        // lock-free circular fifo/buffer size
    var circBuffer          = [Float](repeating: 0, count: 32768)
    var circInIdx  : Int    =  0            // sample input  index
    var circOutIdx : Int    =  0            // sample output index
    
    
    public override init(){}
    
    public func stop(){
        self.liveAudioUnit?.outputProvider = nil
        self.liveAudioUnit?.deallocateRenderResources()
        self.liveAudioUnit?.stopHardware()
        self.liveAudioUnit?.reset()
    }
    
    public func load(_ engine: LeVerre.Engine?) {
        guard engine != nil else { return }
        configureAudioUnit()
    }
    
    public func setup() {
        configureAudioUnit()
    }
    
    // Configures audio unit to request and play samples from `signalProvider`.
    func configureAudioUnit() {
#if os(iOS) || os(tvOS)
        let kOutputUnitSubType = kAudioUnitSubType_RemoteIO
#else
        let kOutputUnitSubType = kAudioUnitSubType_DefaultOutput
#endif
        
        let ioUnitDesc = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kOutputUnitSubType,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0)
        
        guard
            let ioUnit = try? AUAudioUnit(componentDescription: ioUnitDesc,
                                          options: AudioComponentInstantiationOptions()) else {
            
            return
        }
        
        let sampleRate: Double = 44100//Double = ioUnit.outputBusses[0].format.sampleRate
        
        ioUnit.isInputEnabled = true
        
        guard let outputRenderFormat = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1) else {
            return
        }
        self.liveAudioUnit = ioUnit
        
        do {
            try ioUnit.inputBusses[0].setFormat(outputRenderFormat)
        } catch {
            Log.debug("Error setting format on ioUnit")
            return
        }
        
        var startTime = 0.0
        var pollCount = 0
        
        ioUnit.outputProvider = { [weak self] (
            actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
            timestamp: UnsafePointer<AudioTimeStamp>,
            frameCount: AUAudioFrameCount,
            busIndex: Int,
            rawBufferList: UnsafeMutablePointer<AudioBufferList>) -> AUAudioUnitStatus in
            
            let bufferList = UnsafeMutableAudioBufferListPointer(rawBufferList)
            
            var signal: ([Float], Int) = ([], 0)
            
            if !bufferList.isEmpty {
                do {
                    signal = (try self?.directive?.requestSignal(frameCount) ?? [], pollCount)
                    
                    //Let's push the results up stream for Mods on UX Side
                    let sum = signal.0.reduce(0, +)
                    
                    self?.delegate?.getSignal(fromPlayer: signal.0, sum: sum)
                    //
                    
                    if signal.1 <= 1 {
                        startTime = (timestamp.pointee.mSampleTime/sampleRate)
                    } else {
                        self?.directive?.getPlayerTime((timestamp.pointee.mSampleTime/sampleRate) - startTime)
                    }
                    
                    pollCount += 1
                } catch ConverterError.reachedEndOfFile {
                    print("EOF")
                } catch ConverterError.notEnoughData {
                    print("no data")
                } catch ConverterError.superConcerningShouldNeverHappen {
                    print("huh")
                } catch let error {
                    print("uh oh: \(error)")
                }
            } else {
                print("empty buffer list")
            }
            
            if signal.0.isEmpty {
                signal.0 = [Float](repeating: 0.0, count: Int(frameCount))
            }
            
            //Let's output to the spearker
            bufferList[0].mData?.copyMemory(from: signal.0,
                                            byteCount: Int(frameCount) * MemoryLayout<Float>.size)
            
            return noErr
        }
        
        do {
            try ioUnit.allocateRenderResources()
        } catch {
            Log.debug("[GlassKit] Error allocating render resources")
            return
        }
        
        do {
            try ioUnit.startHardware()
        } catch {
            Log.debug("[GlassKit] Error starting hardware")
        }
    }
    
//    func configureAudioUnitInput() {
//        let audioCallback: AURenderCallback = { (
//            inRefCon,
//            ioActionFlags,
//            inTimeStamp,
//            inBusNumber,
//            inNumberFrames,
//            ioData) -> OSStatus in
//
//            let audioBuffer = UnsafeMutableAudioBufferListPointer(ioData)
//            // Process the audio buffer here
//            print("{TEST}")
//            return noErr
//        }
//
//        var captureAudioUnit: AudioUnit?
//        var captureComponentDescription = AudioComponentDescription(
//            componentType: kAudioUnitType_Output,
//            componentSubType: kAudioUnitSubType_DefaultOutput,
//            componentManufacturer: kAudioUnitManufacturer_Apple,
//            componentFlags: 0,
//            componentFlagsMask: 0)
//
//        guard let captureComponent = AudioComponentFindNext(nil, &captureComponentDescription) else {
//            return
//        }
//
//        AudioComponentInstanceNew(captureComponent, &captureAudioUnit)
//
//        var audioDeviceID: AudioDeviceID = AudioDeviceID(kAudioObjectSystemObject)
//        for audioDevice in AudioDeviceFinder.findDevices() {
//            if let name = audioDevice.name,
//               let uid = audioDevice.uid {
//                if name == "MacBook Pro Speakers" {
//                    audioDeviceID = audioDevice.audioDeviceID
//                    print("[GlassKit] Found device \"\(name)\", uid=\(uid)")
//                }
//            }
//        }
//
//        var defaultDeviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)
//
//        AudioUnitSetProperty(
//            captureAudioUnit!,
//            kAudioOutputUnitProperty_CurrentDevice,
//            kAudioUnitScope_Global,
//            0,
//            &audioDeviceID,
//            defaultDeviceIDSize)
//
//        var audioFormat = AudioStreamBasicDescription(
//            mSampleRate: 44100.0,
//            mFormatID: kAudioFormatLinearPCM,
//            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
//            mBytesPerPacket: 2,
//            mFramesPerPacket: 1,
//            mBytesPerFrame: 2,
//            mChannelsPerFrame: 1,
//            mBitsPerChannel: 16,
//            mReserved: 0)
//
//        AudioUnitSetProperty(
//            captureAudioUnit!,
//            kAudioUnitProperty_StreamFormat,
//            kAudioUnitScope_Input,
//            0,
//            &audioFormat,
//            UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
//
//        var renderCallback = AURenderCallbackStruct(
//            inputProc: audioCallback,
//            inputProcRefCon: nil)
//
//        AudioUnitSetProperty(
//            captureAudioUnit!,
//            kAudioOutputUnitProperty_SetInputCallback,
//            kAudioUnitScope_Global,
//            0,
//            &renderCallback,
//            UInt32(MemoryLayout<AURenderCallbackStruct>.size))
//
//        AudioUnitInitialize(captureAudioUnit!)
//        AudioOutputUnitStart(captureAudioUnit!)
//    }
    
    private func recordMicrophoneInputSamples(   // process RemoteIO Buffer from mic input
        inputDataList : UnsafeMutablePointer<AudioBufferList>,
        frameCount : UInt32 )
    {
        let inputDataPtr = UnsafeMutableAudioBufferListPointer(inputDataList)
        let mBuffers : AudioBuffer = inputDataPtr[0]
        let count = Int(frameCount)
        
        let bufferPointer = UnsafeMutableRawPointer(mBuffers.mData)
        
        var j = self.circInIdx          // current circular array input index
        let n = self.circBuffSize
        var audioLevelSum : Float = 0.0
        if let bptr = bufferPointer?.assumingMemoryBound(to: Int16.self) {
            for i in 0..<(count/2) {
                // Save samples in circular buffer for latter processing
                self.circBuffer[j    ] = Float(bptr[i+i  ]) // Stereo Left
                self.circBuffer[j + 1] = Float(bptr[i+i+1]) // Stereo Right
                j += 2 ; if j >= n { j = 0 }                // Circular buffer looping
                // Microphone Input Analysis
                let x = Float(bptr[i+i  ])
                let y = Float(bptr[i+i+1])
                audioLevelSum += x * x + y * y
                
            }
        }
        OSMemoryBarrier();              // from libkern/OSAtomic.h
        self.circInIdx = j              // circular index will always be less than size
        if audioLevelSum > 0.0 && count > 0 {
            let audioLevel = logf(audioLevelSum / Float(count))
            print("\(audioLevel)")
        } else {
            print("fsdf")
        }
    }
}

protocol SignalProvider {
    func getSignal() -> ([Float], Int)
}

//import Cocoa
//import AVFoundation
//
//class AudioDevice {
//    var audioDeviceID:AudioDeviceID
//
//    init(deviceID:AudioDeviceID) {
//        self.audioDeviceID = deviceID
//    }
//
//    var hasOutput: Bool {
//        get {
//            var address:AudioObjectPropertyAddress = AudioObjectPropertyAddress(
//                mSelector:AudioObjectPropertySelector(kAudioDevicePropertyStreamConfiguration),
//                mScope:AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
//                mElement:0)
//
//            var propsize:UInt32 = UInt32(MemoryLayout<CFString?>.size);
//            var result:OSStatus = AudioObjectGetPropertyDataSize(self.audioDeviceID, &address, 0, nil, &propsize);
//            if (result != 0) {
//                return false;
//            }
//
//            let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity:Int(propsize))
//            result = AudioObjectGetPropertyData(self.audioDeviceID, &address, 0, nil, &propsize, bufferList);
//            if (result != 0) {
//                return false
//            }
//
//            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
//            for bufferNum in 0..<buffers.count {
//                if buffers[bufferNum].mNumberChannels > 0 {
//                    return true
//                }
//            }
//
//            return false
//        }
//    }
//
//    var uid:String? {
//        get {
//            var address:AudioObjectPropertyAddress = AudioObjectPropertyAddress(
//                mSelector:AudioObjectPropertySelector(kAudioDevicePropertyDeviceUID),
//                mScope:AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
//                mElement:AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))
//
//            var name:CFString? = nil
//            var propsize:UInt32 = UInt32(MemoryLayout<CFString?>.size)
//            let result:OSStatus = AudioObjectGetPropertyData(self.audioDeviceID, &address, 0, nil, &propsize, &name)
//            if (result != 0) {
//                return nil
//            }
//
//            return name as String?
//        }
//    }
//
//    var name:String? {
//        get {
//            var address:AudioObjectPropertyAddress = AudioObjectPropertyAddress(
//                mSelector:AudioObjectPropertySelector(kAudioDevicePropertyDeviceNameCFString),
//                mScope:AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
//                mElement:AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))
//
//            var name:CFString? = nil
//            var propsize:UInt32 = UInt32(MemoryLayout<CFString?>.size)
//            let result:OSStatus = AudioObjectGetPropertyData(self.audioDeviceID, &address, 0, nil, &propsize, &name)
//            if (result != 0) {
//                return nil
//            }
//
//            return name as String?
//        }
//    }
//}
//
//
//class AudioDeviceFinder {
//    static func findDevices() -> [AudioDevice] {
//        var propsize:UInt32 = 0
//
//        var address:AudioObjectPropertyAddress = AudioObjectPropertyAddress(
//            mSelector:AudioObjectPropertySelector(kAudioHardwarePropertyDevices),
//            mScope:AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
//            mElement:AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))
//
//        var result:OSStatus = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, UInt32(MemoryLayout<AudioObjectPropertyAddress>.size), nil, &propsize)
//
//        if (result != 0) {
//            print("Error \(result) from AudioObjectGetPropertyDataSize")
//            return []
//        }
//
//        let numDevices = Int(propsize / UInt32(MemoryLayout<AudioDeviceID>.size))
//
//        var devids = [AudioDeviceID]()
//        for _ in 0..<numDevices {
//            devids.append(AudioDeviceID())
//        }
//
//        result = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize, &devids);
//        if (result != 0) {
//            print("Error \(result) from AudioObjectGetPropertyData")
//            return []
//        }
//
//        var devices: [AudioDevice] = []
//        for i in 0..<numDevices {
//            let audioDevice = AudioDevice(deviceID:devids[i])
//            if (audioDevice.hasOutput) {
//                devices.append(audioDevice)
//            }
//        }
//
//        return devices
//    }
//}
