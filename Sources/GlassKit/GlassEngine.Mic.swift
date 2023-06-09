//
//  AudioRecorder.swift
//  Wonder
//
//  Created by PEXAVC on 9/19/19.
//  Copyright © 2019 PEXAVC. All rights reserved.
//

//#if os(iOS) || os(tvOS)
import Foundation
import AVFoundation
import AudioUnit
import AudioToolbox

// call setupAudioSessionForRecording() during controlling view load
// call startRecording() to start recording in a later UI call

public protocol GlassMicEngineDelegate: class {
    func getSignal(fromMicrophone samples: [Float], sum: Float)
    func audioFileDisposed()
}


// call setupAudioSessionForRecording() during controlling view load
// call startRecording() to start recording in a later UI call

open class GlassMicEngine: NSObject {
    public weak var delegate: GlassMicEngineDelegate?
    var audioUnit:   AudioUnit?     = nil

    var micPermission   =  false
    var sessionActive   =  false
    var isRecording     =  false
    
    var sampleRate : Double = 44100.0    // default audio sample rate

    let circBuffSize = 32768        // lock-free circular fifo/buffer size
    var circBuffer   = [Float](repeating: 0, count: 32768)  // for incoming samples
    var circInIdx  : Int =  0
    var audioLevel : Float  = 0.0
    
    private var hwSRate = 48000.0   // guess of device hardware sample rate
    private var micPermissionDispatchToken = 0
    private var interrupted = false     // for restart from audio interruption notification

    
    private var gTmp0 = -1
    
    public override init() {
        //TODO: mic check for macOS needs to be moved to _v2 variant
//        #if os(macOS)
//        micPermission = true
//        #endif
        super.init()
    }
    
    public func startRecording() {
        if isRecording { return }

        startAudioSession()
        if sessionActive {
            startAudioUnit()
        }
    }
    
    var numberOfChannels: Int       =  2
    
    private let outputBus: UInt32   =  0
    private let inputBus: UInt32    =  1
    
    func startAudioUnit() {
        var err: OSStatus = noErr
        
        if self.audioUnit == nil {
            setupAudioUnit()         // setup once
        }
        guard let au = self.audioUnit
            else { return }
        
        err = AudioUnitInitialize(au)
        gTmp0 = Int(err)
        if err != noErr { return }
        err = AudioOutputUnitStart(au)  // start
        
        gTmp0 = Int(err)
        if err == noErr {
            isRecording = true
        }
    }

    func startAudioSession() {
        if (sessionActive == false) {
            // set and activate Audio Session
            do {
                
                #if(iOS)
                let audioSession = AVAudioSession.sharedInstance()

                if (micPermission == false) {
                    if (micPermissionDispatchToken == 0) {
                        micPermissionDispatchToken = 1
                        audioSession.requestRecordPermission({(granted: Bool)-> Void in
                            if granted {
                                self.micPermission = true
                                return
                                // check for this flag and call from UI loop if needed
                            } else {
                                self.gTmp0 += 1
                                // dispatch in main/UI thread an alert
                                //   informing that mic permission is not switched on
                            }
                        })
                    }
                }
                if micPermission == false { return }
                
                try audioSession.setCategory(AVAudioSession.Category.record)
                hwSRate = audioSession.sampleRate
                #else
                hwSRate = 48000
                #endif
                // choose 44100 or 48000 based on hardware rate
                // sampleRate = 44100.0
                var preferredIOBufferDuration = 0.0058      // 5.8 milliseconds = 256 samples
                           // get native hardware rate
                if hwSRate == 48000.0 { sampleRate = 48000.0 }  // set session to hardware rate
                if hwSRate == 48000.0 { preferredIOBufferDuration = 0.0053 }
                let desiredSampleRate = sampleRate
                
                #if(iOS)
                try audioSession.setPreferredSampleRate(desiredSampleRate)
                try audioSession.setPreferredIOBufferDuration(preferredIOBufferDuration)
                
                NotificationCenter.default.addObserver(
                    forName: AVAudioSession.interruptionNotification,
                    object: nil,
                    queue: nil,
                    using: myAudioSessionInterruptionHandler )
                
                try audioSession.setActive(true)
                #endif
                
                sessionActive = true
                
            } catch /* let error as NSError */ {
                // handle error here
            }
        }
    }
    
    private func setupAudioUnit() {
        var componentDesc: AudioComponentDescription
            
        #if (iOS)
        componentDesc = AudioComponentDescription(
            componentType:          OSType(kAudioUnitType_Output),
            componentSubType:       OSType(kAudioUnitSubType_RemoteIO),
            componentManufacturer:  OSType(kAudioUnitManufacturer_Apple),
            componentFlags:         UInt32(0),
            componentFlagsMask:     UInt32(0) )
        #else
        componentDesc = AudioComponentDescription(
            componentType:          OSType(kAudioUnitType_Output),
            componentSubType:       OSType(kAudioUnitSubType_VoiceProcessingIO),
            componentManufacturer:  OSType(kAudioUnitManufacturer_Apple),
            componentFlags:         UInt32(0),
            componentFlagsMask:     UInt32(0) )
        #endif
        
        var osErr: OSStatus = noErr
        
        let component: AudioComponent! = AudioComponentFindNext(nil, &componentDesc)
        
        var tempAudioUnit: AudioUnit?
        osErr = AudioComponentInstanceNew(component, &tempAudioUnit)
        self.audioUnit = tempAudioUnit
        
        guard let au = self.audioUnit
            else { return }
        
        // Enable I/O for input.
        
        var one_ui32: UInt32 = 1
        
        osErr = AudioUnitSetProperty(au,
                                     kAudioOutputUnitProperty_EnableIO,
                                     kAudioUnitScope_Input,
                                     inputBus,
                                     &one_ui32,
                                     UInt32(MemoryLayout<UInt32>.size))
        
        // Set format to 32-bit Floats, linear PCM
        let nc = 2  // 2 channel stereo
        var streamFormatDesc:AudioStreamBasicDescription = AudioStreamBasicDescription(
            mSampleRate:        Double(sampleRate),
            mFormatID:          kAudioFormatLinearPCM,
            mFormatFlags:       ( kAudioFormatFlagsNativeFloatPacked ),
            mBytesPerPacket:    UInt32(nc * MemoryLayout<UInt32>.size),
            mFramesPerPacket:   1,
            mBytesPerFrame:     UInt32(nc * MemoryLayout<UInt32>.size),
            mChannelsPerFrame:  UInt32(nc),
            mBitsPerChannel:    UInt32(8 * (MemoryLayout<UInt32>.size)),
            mReserved:          UInt32(0)
        )
        
        osErr = AudioUnitSetProperty(au,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Input, outputBus,
                                     &streamFormatDesc,
                                     UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        osErr = AudioUnitSetProperty(au,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     inputBus,
                                     &streamFormatDesc,
                                     UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        var inputCallbackStruct
            = AURenderCallbackStruct(inputProc: recordingCallback,
                                     inputProcRefCon:
                UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        
        osErr = AudioUnitSetProperty(au,
                                     AudioUnitPropertyID(kAudioOutputUnitProperty_SetInputCallback),
                                     AudioUnitScope(kAudioUnitScope_Global),
                                     inputBus,
                                     &inputCallbackStruct,
                                     UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        
        // Ask CoreAudio to allocate buffers for us on render.
        //   Is this true by default?
        osErr = AudioUnitSetProperty(au,
                                     AudioUnitPropertyID(kAudioUnitProperty_ShouldAllocateBuffer),
                                     AudioUnitScope(kAudioUnitScope_Output),
                                     inputBus,
                                     &one_ui32,
                                     UInt32(MemoryLayout<UInt32>.size))
        gTmp0 = Int(osErr)
    }
    
    let recordingCallback: AURenderCallback = { (
        inRefCon,
        ioActionFlags,
        inTimeStamp,
        inBusNumber,
        frameCount,
        ioData ) -> OSStatus in
        
        let audioObject = unsafeBitCast(inRefCon, to: GlassMicEngine.self)
        var err: OSStatus = noErr
        
        // set mData to nil, AudioUnitRender() should be allocating buffers
        var bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: UInt32(2),
                mDataByteSize: 16,
                mData: nil))
        
        if let au = audioObject.audioUnit {
            err = AudioUnitRender(au,
                                  ioActionFlags,
                                  inTimeStamp,
                                  inBusNumber,
                                  frameCount,
                                  &bufferList)
        }
        
        audioObject.processMicrophoneBuffer( inputDataList: &bufferList,
                                             frameCount: UInt32(frameCount) )
        
        return 0
    }
    
    func processMicrophoneBuffer(   // process RemoteIO Buffer from mic input
        inputDataList : UnsafeMutablePointer<AudioBufferList>,
        frameCount : UInt32 )
    {
        let inputDataPtr = UnsafeMutableAudioBufferListPointer(inputDataList)
        let mBuffers : AudioBuffer = inputDataPtr[0]
        let count = Int(frameCount)
        
        // Microphone Input Analysis
        // let data      = UnsafePointer<Int16>(mBuffers.mData)
        let bufferPointer = UnsafeMutableRawPointer(mBuffers.mData)
        if let bptr = bufferPointer {
            let dataArray = bptr.assumingMemoryBound(to: Float.self)
            var sum : Float = 0.0
            var j = self.circInIdx
            let m = self.circBuffSize
            for i in 0..<(count/2) {
                let x = Float(dataArray[i+i  ])   // copy left  channel sample
                let y = Float(dataArray[i+i+1])   // copy right channel sample
                self.circBuffer[j    ] = x
                self.circBuffer[j + 1] = y
                j += 2 ; if j >= m { j = 0 }                // into circular buffer
                sum += x * x + y * y
            }
            self.circInIdx = j              // circular index will always be less than size
            // measuredMicVol_1 = sqrt( Float(sum) / Float(count) ) // scaled volume
            
            delegate?.getSignal(fromMicrophone: self.circBuffer, sum: sum)
            
            if sum > 0.0 && count > 0 {
                let tmp = 5.0 * (logf(sum / Float(count)) + 20.0)
                let r : Float = 0.2
                audioLevel = r * tmp + (1.0 - r) * audioLevel
                
            }
        }
    }
    
    public func stopRecording() {
        guard self.audioUnit != nil else { return }
        AudioUnitUninitialize(self.audioUnit!)
        isRecording = false
    }
    
    func myAudioSessionInterruptionHandler(notification: Notification) -> Void {
        #if(iOS)
        let interuptionDict = notification.userInfo
        if let interuptionType = interuptionDict?[AVAudioSessionInterruptionTypeKey] {
            let interuptionVal = AVAudioSession.InterruptionType(
                rawValue: (interuptionType as AnyObject).uintValue )
            if (interuptionVal == AVAudioSession.InterruptionType.began) {
                if (isRecording) {
                    stopRecording()
                    isRecording = false
                    let audioSession = AVAudioSession.sharedInstance()
                    do {
                        try audioSession.setActive(false)
                        sessionActive = false
                    } catch {
                    }
                    interrupted = true
                }
            } else if (interuptionVal == AVAudioSession.InterruptionType.ended) {
                if (interrupted) {
                    // potentially restart here
                }
            }
        }
        #endif
    }
    
    
}

// end of class RecordAudio

open class GlassMicEngine_v2: NSObject {
    
    var auAudioUnit: AUAudioUnit! = nil
    
    var enableRecording     = true
    var audioSessionActive  = false
    var audioSetupComplete  = false
    var isRecording         = false
    
    var sampleRate : Double =  48000.0      // desired audio sample rate
    
    let circBuffSize        =  32768        // lock-free circular fifo/buffer size
    var circBuffer          = [Float](repeating: 0, count: 32768)
    var circInIdx  : Int    =  0            // sample input  index
    var circOutIdx : Int    =  0            // sample output index
    
    var audioLevel : Float  = 0.0

    private var micPermissionRequested  = false
    private var micPermissionGranted    = true
    
    // for restart from audio interruption notification
    private var audioInterrupted        = false
    
    private var renderBlock : AURenderBlock? = nil
    
    public func startRecording() {
        
        if isRecording { return }
        
        if audioSessionActive == false {
            // configure and activate Audio Session, this might change the sampleRate
            setupAudioSessionForRecording()
        }
        
        guard micPermissionGranted && audioSessionActive else { return }
        
        let audioFormat = AVAudioFormat(
            commonFormat: AVAudioCommonFormat.pcmFormatInt16,   // pcmFormatInt16, pcmFormatFloat32,
            sampleRate: Double(sampleRate),                     // 44100.0 48000.0
            channels:AVAudioChannelCount(2),                    // 1 or 2
            interleaved: true )                                 // true for interleaved stereo
        
        if (auAudioUnit == nil) {
            setupRemoteIOAudioUnitForRecord(audioFormat: audioFormat!)
        }
        
        renderBlock = auAudioUnit.renderBlock  //  returns AURenderBlock()
        
        if (   enableRecording
            && micPermissionGranted
            && audioSetupComplete
            && audioSessionActive
            && isRecording == false ) {
            
            auAudioUnit.isInputEnabled  = true
            
            auAudioUnit.outputProvider = { // AURenderPullInputBlock()
                
                (actionFlags, timestamp, frameCount, inputBusNumber, inputData) -> AUAudioUnitStatus in
                
                if let block = self.renderBlock {       // AURenderBlock?
                    let err : OSStatus = block(actionFlags,
                                               timestamp,
                                               frameCount,
                                               1,
                                               inputData,
                                               .none)
                    if err == noErr {
                        // save samples from current input buffer to circular buffer
                        self.recordMicrophoneInputSamples(
                            inputDataList:  inputData,
                            frameCount: UInt32(frameCount) )
                    }
                }
                let err2 : AUAudioUnitStatus = noErr
                return err2
            }
            
            do {
                circInIdx   =   0                       // initialize circular buffer pointers
                circOutIdx  =   0
                try auAudioUnit.allocateRenderResources()
                try auAudioUnit.startHardware()         // equivalent to AudioOutputUnitStart ???
                isRecording = true
                
            } catch {
                // placeholder for error handling
            }
        }
    }
    
    public func stopRecording() {
        
        if (isRecording) {
            auAudioUnit.stopHardware()
            isRecording = false
        }
        if (audioSessionActive) {
            #if(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setActive(false)
            } catch /* let error as NSError */ {
            }
            #endif
            audioSessionActive = false
        }
    }
    
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
                let x = Float(bptr[i+i  ])
                let y = Float(bptr[i+i+1])
                self.circBuffer[j    ] = x // Stereo Left
                self.circBuffer[j + 1] = y // Stereo Right
                j += 2 ; if j >= n { j = 0 }                // Circular buffer looping
                // Microphone Input Analysis
                audioLevelSum += x * x + y * y

            }
        }
        OSMemoryBarrier();              // from libkern/OSAtomic.h
        self.circInIdx = j              // circular index will always be less than size
        if audioLevelSum > 0.0 && count > 0 {
            audioLevel = logf(audioLevelSum / Float(count))
        }
    }
    
    // set up and activate Audio Session
    func setupAudioSessionForRecording() {
        do {
            #if(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            
            if (micPermissionGranted == false) {
                if (micPermissionRequested == false) {
                    micPermissionRequested = true
                    audioSession.requestRecordPermission({(granted: Bool)-> Void in
                        if granted {
                            self.micPermissionGranted = true
                            self.startRecording()
                            return
                        } else {
                            self.enableRecording = false
                            // dispatch in main/UI thread an alert
                            //   informing that mic permission is not switched on
                        }
                    })
                }
                return
            }
            
            if enableRecording {
                try audioSession.setCategory(AVAudioSession.Category.record)
            }
            let preferredIOBufferDuration = 0.0053  // 5.3 milliseconds = 256 samples
            try audioSession.setPreferredSampleRate(sampleRate) // at 48000.0
            try audioSession.setPreferredIOBufferDuration(preferredIOBufferDuration)
            
            NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: nil,
                using: myAudioSessionInterruptionHandler )
            
            try audioSession.setActive(true)
            #endif
            audioSessionActive = true
        } catch /* let error as NSError */ {
            // placeholder for error handling
        }
    }
    
    // find and set up the sample format for the RemoteIO Audio Unit
    private func setupRemoteIOAudioUnitForRecord(audioFormat : AVAudioFormat) {
        
        do {
            let audioComponentDescription: AudioComponentDescription
            #if(iOS)
            audioComponentDescription = AudioComponentDescription(
                componentType: kAudioUnitType_Output,
                componentSubType: kAudioUnitSubType_RemoteIO,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0 )
            #else
            audioComponentDescription = AudioComponentDescription(
                componentType: kAudioUnitType_Output,
                componentSubType: kAudioUnitSubType_VoiceProcessingIO,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0 )
            #endif
            
            
            try auAudioUnit = AUAudioUnit(componentDescription: audioComponentDescription)
            
            // bus 1 is for data that the microphone exports out to the handler block
            let bus1 = auAudioUnit.outputBusses[1]
            
            
            try bus1.setFormat(audioFormat)  //      for microphone bus
            audioSetupComplete = true
        } catch /* let error as NSError */ {
            // placeholder for error handling
        }
    }
    
    private func myAudioSessionInterruptionHandler(notification: Notification) -> Void {
        #if(iOS)
        let interuptionDict = notification.userInfo
        if let interuptionType = interuptionDict?[AVAudioSessionInterruptionTypeKey] {
            let interuptionVal = AVAudioSession.InterruptionType(
                rawValue: (interuptionType as AnyObject).uintValue )
            if (interuptionVal == AVAudioSession.InterruptionType.began) {
                // [self beginInterruption];
                if (isRecording) {
                    auAudioUnit.stopHardware()
                    isRecording = false
                    let audioSession = AVAudioSession.sharedInstance()
                    do {
                        try audioSession.setActive(false)
                        audioSessionActive = false
                    } catch {
                        // placeholder for error handling
                    }
                    audioInterrupted = true
                }
            } else if (interuptionVal == AVAudioSession.InterruptionType.ended) {
                // [self endInterruption];
                if (audioInterrupted) {
                    let audioSession = AVAudioSession.sharedInstance()
                    do {
                        try audioSession.setActive(true)
                        audioSessionActive = true
                        if (auAudioUnit.renderResourcesAllocated == false) {
                            try auAudioUnit.allocateRenderResources()
                        }
                        try auAudioUnit.startHardware()
                        isRecording = true
                    } catch {
                        // placeholder for error handling
                    }
                }
            }
        }
        #endif
    }
} // end of RecordAudio class

// eof
//#endif
