//
//  File.swift
//  
//
//  Created by 0xKala on 3/20/21.
//

import Foundation
import AudioToolbox

extension GlassEngine {
    public func preparePlayer() {
        leVerre.prepare()
    }
    
    public func startLeVerre() {
        player.load(leVerre.request(engine: .remote))
    }
}

/**
 
 
 *in between each song we would want some sort of transition
 
 [ song is < 12 sec away from ending ]
 - queue up next song
 - increment index in playlist
 
 [ checks ]
 - playlist index vs songs remaining
 - loop to 0, by the end
 
 [ randomization ]
 - order of songs can be random each load
 -- if so, then the count should be a variable to manage looping
 --- or we just randomize the insertion of songs into a playlist.
 
 
 
 */
extension GlassEngine: GlassPlayerEngineDirectiveDelegate {
    public func requestSignal(_ frames: AUAudioFrameCount) throws -> [Float] {
        return try leVerre.poll(frames)
    }
    
    public func getPlayerTime(_ time: Double) {
        leVerre.updateNeedle(time)
    }
}
