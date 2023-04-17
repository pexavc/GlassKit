//
//  GlassEngine.swift
//  Marble
//
//  Created by 0xKala on 8/8/20.
//  Copyright © 2020 Linen & Sole. All rights reserved.
//


import Foundation
import AudioToolbox
import AVFoundation
import VideoToolbox
import Accelerate

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
    
    var liveAudioUnit: AUAudioUnit?
    
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
                } catch ConverterError.notEnoughData {
                } catch ConverterError.superConcerningShouldNeverHappen {
                } catch {
                }
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
            Log.debug("Error allocating render resources")
            return
        }
        
        do {
            try ioUnit.startHardware()
        } catch {
            Log.debug("Error starting hardware")
        }
    }
}

protocol SignalProvider {
    func getSignal() -> ([Float], Int)
}
