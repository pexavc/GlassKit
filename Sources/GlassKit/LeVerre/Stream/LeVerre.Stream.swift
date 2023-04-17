//
//  File.swift
//  
//
//  Created by PEXAVC on 3/23/21.
//

import Foundation
import AVFoundation


protocol AudioEngineProtocol {
    var key: Key { get }
    var engine: AVAudioEngine! { get }
    func invalidate()
}

protocol AudioEngineDelegate: AnyObject {
    func didError()
    func signal(samples: [Float])
}
extension LeVerre {
    public class Engine: AudioEngineProtocol {
        weak var delegate: AudioEngineDelegate?
        var key: Key
        
        var engine: AVAudioEngine!
        var playerNode: AVAudioPlayerNode!
        var duration: Duration = 0.0
        
        static let defaultEngineAudioFormat: AVAudioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: false)!
        
        init(url: AudioURL, delegate: AudioEngineDelegate?, engineAudioFormat: AVAudioFormat) {
            self.key = url.key
            self.delegate = delegate
            
            engine = AVAudioEngine()
            playerNode = AVAudioPlayerNode()
            
            initHelper(engineAudioFormat)
        }
        
        func initHelper(_ engineAudioFormat: AVAudioFormat) {
            engine.attach(playerNode)
            
            engine.connect(playerNode, to: engine.mainMixerNode, format: engineAudioFormat)
            
            engine.prepare()
        }
        
        deinit {
            engine.disconnectNodeInput(self.playerNode)
            engine.detach(self.playerNode)
            
            engine = nil
            playerNode = nil
        }
        
        func invalidate() {
            
        }
    }
}
