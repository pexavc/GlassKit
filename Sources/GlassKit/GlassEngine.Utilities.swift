//
//  File.swift
//  
//
//  Created by PEXAVC on 3/23/21.
//

import Foundation
import AVFoundation

extension GlassEngine {
    public struct Utilities {
        public static func getAudioSamples(asset: AVAsset, _ sampleRate: Int, sampleCount: Int) -> [Float]? {
            
            guard
                let reader = try? AVAssetReader(asset: asset),
                let track = asset.tracks.first else {
                    return nil
            }
            
            let outputSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVNumberOfChannelsKey: 1,
                AVLinearPCMIsBigEndianKey: 0,
                AVLinearPCMIsFloatKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsNonInterleaved: 1,
                AVSampleRateKey: sampleRate as NSNumber//This rate key should be used for conversion (8k for headphones)
            ]
            
            let output = AVAssetReaderTrackOutput(track: track,
                                                  outputSettings: outputSettings)
            
            reader.add(output)
            reader.startReading()
            
            var samples = [Float]()
            
            while reader.status == .reading {
                if
                    let sampleBuffer = output.copyNextSampleBuffer(),
                    let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                    
                    let bufferLength = CMBlockBufferGetDataLength(dataBuffer)
                    
                    var data = [Float](repeating: 0,
                                       count: bufferLength / 4)
                    CMBlockBufferCopyDataBytes(dataBuffer,
                                               atOffset: 0,
                                               dataLength: bufferLength,
                                               destination: &data)
                    
                    
                    samples.append(contentsOf: data)
                }
            }
            
            let preferredIOBufferDuration: Double = Double(sampleCount)/Double(sampleRate)
            
            #if os(iOS) || os(tvOS)
            do {
               try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(preferredIOBufferDuration)
            } catch let error {
            }
            #endif
            
            return samples
        }
        
        public static func getAudioSamplesInt32(asset: AVAsset, _ sampleRate: Int, sampleCount: Int) -> [UInt32]? {
            
            guard
                let reader = try? AVAssetReader(asset: asset),
                let track = asset.tracks.first else {
                    return nil
            }
            
            let outputSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVNumberOfChannelsKey: 1,
                AVLinearPCMIsBigEndianKey: 0,
                AVLinearPCMIsFloatKey: 0,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsNonInterleaved: 1,
                AVSampleRateKey: sampleRate as NSNumber//This rate key should be used for conversion (8k for headphones)
            ]
            
            let output = AVAssetReaderTrackOutput(track: track,
                                                  outputSettings: outputSettings)
            
            reader.add(output)
            reader.startReading()
            
            var samples = [UInt32]()
            
            while reader.status == .reading {
                if
                    let sampleBuffer = output.copyNextSampleBuffer(),
                    let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                    
                    let bufferLength = CMBlockBufferGetDataLength(dataBuffer)
                    
                    var data = [UInt32](repeating: 0,
                                       count: bufferLength / 4)
                    CMBlockBufferCopyDataBytes(dataBuffer,
                                               atOffset: 0,
                                               dataLength: bufferLength,
                                               destination: &data)
                    
                    
                    samples.append(contentsOf: data)
                }
            }
            
            let preferredIOBufferDuration: Double = Double(sampleCount)/Double(sampleRate)
            
            #if os(iOS) || os(tvOS)
            do {
               try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(preferredIOBufferDuration)
            } catch let error {
            }
            #endif
            
            return samples
        }
        
        
        
        public static func bluetoothAudioConnected() -> Bool {
            #if os(iOS) || os(tvOS)
                  let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
                  for output in outputs{
                    if output.portType == AVAudioSession.Port.bluetoothA2DP || output.portType == AVAudioSession.Port.bluetoothHFP || output.portType == AVAudioSession.Port.bluetoothLE{
                      return true
                    }
                  }
                  return false
            #else
                return false
            #endif
        }
        
        public static func trimAsset(_ asset: AVAsset, filePath: String, startTime: Double, endTime: Double, completion: @escaping ((Bool) -> Void)) {
            
            let trimmedSoundFileURL = URL(fileURLWithPath: filePath)
            
            
            if let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) {
                exporter.outputFileType = .m4a//getFileType(fromURL: trimmedSoundFileURL)
                exporter.outputURL = trimmedSoundFileURL
                
                
                let startTimeCM = CMTimeMake(value: Int64(startTime*1000), timescale: 1000)
                let stopTimeCM = CMTimeMake(value: Int64(endTime*1000), timescale: 1000)
                exporter.timeRange = CMTimeRangeFromTimeToTime(start: startTimeCM, end: stopTimeCM)
                
                exporter.exportAsynchronously(completionHandler: {
                    switch exporter.status {
                    case  AVAssetExportSession.Status.failed:
                        
                        if let e = exporter.error {
                        }
                        
                        completion(false)
                    case AVAssetExportSession.Status.cancelled:
                        completion(false)
                    default:
                        completion(true)
                    }
                })
            } else {
                completion(false)
            }
        }
        
        
        
        public static func getFileType(fromURL url: URL) -> AVFileType {
            switch url.pathExtension{
                case "m4a":
                    return .m4a
                case "mp3":
                    return .mp3
                case "aiff":
                    return .aiff
                default:
                    return .m4a
            }
        }
    }
}
