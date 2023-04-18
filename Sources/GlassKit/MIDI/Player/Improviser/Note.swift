//
//  Note.swift
//  Miles
//
//  Created by Lalo Martínez on 3/22/18.
//  Copyright © 2018 Lalo Martínez. All rights reserved.
//

import AudioToolbox

public struct Note {

  public var tone:Tone
  
  public var octave:Int
  
  public var midiValue: Int {
    return tone.rawValue + (12 * octave)
  }
  
  public init(tone: Tone, octave: Int) {
    self.tone = tone
    self.octave = octave
  }
  
  public func addToTrack(_ track: MusicTrack, onBeat beat: MusicTimeStamp, duration: NoteDuration, velocity: Int = Int.randomWith(floor: 40, ceil: 70)) {
    
    var mess = MIDINoteMessage(channel: 0,
                               note: midiValue.uint8,
                               velocity: velocity.uint8,
                               releaseVelocity: 10.uint8,
                               duration: duration.value)
    let status = MusicTrackNewMIDINoteEvent(track, beat, &mess)
    if status != noErr {
      print("Error creating new midi note event \(status)")
    }
  }
  
  public static func fromMidiValue(_ value: Int) -> Note {
    let octave = Int((Double(value) / 12).rounded(.down) - 2)
    let note = (value % 12) + 24
    return Note(tone: Tone(rawValue: note)!, octave: octave)
  }
}


  

