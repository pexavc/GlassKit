//
//  GlassEngine.MIDI.swift
//  
//
//  Created by PEXAVC on 4/17/23.
//

import Foundation
import AVFoundation
import AudioUnit
import AudioToolbox
import CoreMIDI

open class GlassMIDIEngine: NSObject {
    
    var midiClient = MIDIClientRef()

    var outputPort = MIDIPortRef()

    var inputPort = MIDIPortRef()

    func MyMIDINotifyBlock(midiNotification: UnsafePointer<MIDINotification>) {
        print("\ngot a MIDINotification!")
    }
    
    
    var midiPlayerFromData: AVMIDIPlayer?
    
    public override init() {
        #if os(macOS)
        micPermission = true
        #endif
        super.init()
        
        var notifyBlock = MyMIDINotifyBlock


        var status = MIDIClientCreateWithBlock("com.rockhoppertech.MyMIDIClient" as CFString, &midiClient, notifyBlock)

        if status == noErr {
            print("created client \(midiClient)")
        } else {
            print("error creating client : \(status)")

        }
    }
    
    internal func createMusicPlayer(musicSequence:MusicSequence) -> MusicPlayer? {
        var musicPlayer: MusicPlayer?
        var status = noErr
        
        status = NewMusicPlayer(&musicPlayer)
        if status != noErr {
            print("bad status \(status) creating player")
        }
        
        if let player = musicPlayer {
            
            status = MusicPlayerSetSequence(player, musicSequence)
            if status != noErr {
                print("setting sequence \(status)")
            }
            
            status = MusicPlayerPreroll(player)
            if status != noErr {
                print("prerolling player \(status)")
            }
            
            return player
        } else {
            print("musicplayer is nil")
            return nil
        }
    }
    
    internal func playMusicPlayer(musicPlayer: MusicPlayer?) {
        var status = noErr
        var playing = DarwinBoolean(false)
        
        if let player = musicPlayer {
            status = MusicPlayerIsPlaying(player, &playing)
            if playing != false {
                print("music player is playing. stopping")
                status = MusicPlayerStop(player)
                if status != noErr {
                    print("Error stopping \(status)")
                    return
                }
            } else {
                print("music player is not playing.")
            }
            
            status = MusicPlayerSetTime(player, 0)
            if status != noErr {
                print("Error setting time \(status)")
                return
            }
            
            print("starting to play")
            status = MusicPlayerStart(player)
            if status != noErr {
                print("Error starting \(status)")
                return
            }
        }
    }
    
    var avEngine = AVAudioEngine()
    var midi: MyMIDIInstrument?
    var teacher: PianoTeacher?
    public func test() {
        teacher = PianoTeacher()
        teacher?.playMidi()
//        teacher?.play(scale: .blues, inKey: .Eflat, inOctaves: [2,3,4], withTempo: 150, useStaticTime: true)
    }
    
    func createAVMIDIPlayer(musicSequence: MusicSequence) {
            
            guard let bankURL = Bundle.module.url(forResource: "GeneralUser GS MuseScore v1.442", withExtension: "sf2") else {
                fatalError("\"GeneralUser GS MuseScore v1.442.sf2\" file not found.")
            }
            
            
            var status = noErr
            var data: Unmanaged<CFData>?
            status = MusicSequenceFileCreateData (musicSequence,
                                                  MusicSequenceFileTypeID.midiType,
                                                  MusicSequenceFileFlags.eraseFile,
                                                  480, &data)
            
            if status != noErr {
                print("bad status \(status)")
            }
            
            if let md = data {
                let midiData = md.takeUnretainedValue() as Data
                do {
                    try self.midiPlayerFromData = AVMIDIPlayer(data: midiData as Data, soundBankURL: bankURL)
                    print("created midi player with sound bank url \(bankURL)")
                } catch let error as NSError {
                    print("nil midi player")
                    print("Error \(error.localizedDescription)")
                }
                data?.release()
                
                self.midiPlayerFromData?.prepareToPlay()
            }
            
        }
}

class MyMIDIInstrument: AVAudioUnitMIDIInstrument {
    init(soundBankURL: URL) throws {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice, componentSubType: kAudioUnitSubType_MIDISynth, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0
        )
        super.init(audioComponentDescription: description)

        var bankURL = soundBankURL

        let status = AudioUnitSetProperty(
            self.audioUnit,
            AudioUnitPropertyID(kMusicDeviceProperty_SoundBankURL),
            AudioUnitScope(kAudioUnitScope_Global),
            0,
            &bankURL,
            UInt32(MemoryLayout<URL>.size))
        if (status != OSStatus(noErr)) {
            throw NSError(domain: "MyMIDIInstrument", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Could not set soundbank property"])
        }
    }
}
