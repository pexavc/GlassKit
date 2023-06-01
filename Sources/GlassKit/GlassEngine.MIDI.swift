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
    
    var teacher: PianoTeacher?
    public func test() -> [ModelNote] {
        guard let filepath = Bundle.module.url(forResource: "test3", withExtension: "mid") else {
            return []
        }
//        teacher = PianoTeacher()
//        teacher?.playMidi()
//        teacher?.play(scale: .blues, inKey: .Eflat, inOctaves: [2,3,4], withTempo: 150, useStaticTime: true)
        let midi = MidiData()
        
        do {
            let data: Data = try Data(contentsOf: filepath)
            midi.load(data: data)
            
            var notes: [ModelNote] = []
            
            midi.noteTracks.forEach { track in
                track.notes.forEach {
                    let length = $0.duration.inSeconds
                    let start = ($0.timeStamp.inSeconds)
                    let pitch = $0.note
                    
                    notes.append(.init(start: start, length: length, pitch: Int(pitch)))
                }
            }
            
            return notes
        }
        catch let error as NSError {
            print("\(error.localizedDescription)")
            return []
        }
        
        return []
    }
    
//    public func loadMIDI() {
//        guard let filepath = Bundle.module.url(forResource: "test", withExtension: "mid") else {
//            return
//        }
//        do {
//            let data: Data = try Data(contentsOf: filepath)
//            self.sequencer = AVAudioSequencer(audioEngine: engine)
//
//            try self.sequencer?.load(from: data, options: [])
//            self.sequencer?.prepareToPlay()
//        }
//        catch let error as NSError {
//            print("\(error.localizedDescription)")
//            return
//        }
//    }
}

public struct ModelNote: Codable, Identifiable, Hashable, Equatable {
    public var id: String {
        String(start + length + Double(pitch))
    }
    
    public let start: Double
    public let length: Double
    public let pitch: Int
}
