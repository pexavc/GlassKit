//
//  GlassEngine._.swift
//  Marble
//
//  Created by 0xKala on 8/8/20.
//  Copyright © 2020 Linen & Sole. All rights reserved.
//

import AVFoundation
import Foundation


public class GlassEngine {
    public let player: GlassPlayerEngine = .init()
    public let mic: GlassMicEngine = .init()
    internal var leVerre: LeVerre = .init()
    
    public struct Info {
        public var pageNumber = 0
        
        public init() {}
    }
    
    public static func setupAudio() {
        #if os(iOS) || os(tvOS)
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playback, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
        } catch {
            
        }
        #endif
    }
    
    public struct Payload {
        public let sample: Float
        
        public init(_ sample: Float) {
            self.sample = sample
        }
    }
    
    public init() {
        player.directive = self
    }
    
    public func stop() {
        leVerre.stop()
        mic.stopRecording()
        player.stop()
    }
}
