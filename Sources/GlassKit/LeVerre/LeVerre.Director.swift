//
//  File.swift
//  
//
//  Created by PEXAVC on 3/23/21.
//

import Foundation
import AudioToolbox
import AVFoundation

public extension LeVerre {
    func request(engine: EngineType) -> Engine? {
        if let song = playlist.currentSong.songURL {
            engines.remote = Remote.init(withRemoteUrl: song, delegate: nil)
        }
        return engines.remote
    }
    
    func poll(_ frames: AUAudioFrameCount) throws -> [Float] {
        //should store the engine type requested above and then
        //a switch to poll depending on type
        //
        
        let transition = self.properties.transition
        
        if transition.queueing {
            return []
        }
        
        var buffer: AVAudioPCMBuffer! = try engines.remote?.poll(frames)
        
        let floatArray: [Float]
        
        guard buffer != nil else { return [] }
        
        if transition.isActive { // Fade out the track when ready
            floatArray = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))).map{ $0*(transition.factor) }

        } else {
            floatArray = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
        }
        
        //interestingly, we add a ! to AVAudioPCMBuffer in order to allow
        //a `nil` settable for freeing purposes
        buffer = nil
        
        return floatArray
    }
    
    func updateNeedle(_ time: Double) {
        let fTime = Float(time)
        let timeLeft = playlist.runningTotal - fTime
        let transition = self.properties.transition
        
        if timeLeft > 0 && timeLeft <= transition.time,
           !transition.isActive {
            properties.transition.isActive = true
        } else {
            //In theory we need a number to define the ratio from the
            //target time to normalize into [1, 0]
            //where `0` will indicate end of song.
            let norm = timeLeft/transition.time
            
            let normSquared: Float = norm * norm
            
            let easeOut = normSquared / (2.0 * (normSquared - norm) + 1.0);
            
            properties.transition.factor = easeOut
            
            if easeOut.magnitude <= 0.01 && !transition.queueing {
                properties.transition.isActive = false
                nextSong()
            }
        }
    }
    
    func nextSong() {
        properties.transition.queueing = true
        
        DispatchQueue.init(label: "leVerre.queueing.song").async { [weak self] in
            self?.engines.remote?.invalidate()
            self?.engines.remote = nil
            
            if let song = self?.playlist.nextSong.songURL {
                self?.engines.remote = Remote.init(withRemoteUrl: song, delegate: nil)
                self?.properties.transition.queueing = false
            }
        }
    }
}
