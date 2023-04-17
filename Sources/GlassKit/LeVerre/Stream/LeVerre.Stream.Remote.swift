//
//  File.swift
//  
//
//  Created by 0xKala on 3/23/21.
//

import Foundation
import AVFoundation

extension LeVerre {
    public class Remote: Engine {
        //Constants
        private let MAX_POLL_BUFFER_COUNT = 300 //Having one buffer in engine at a time is choppy.
        private let MIN_BUFFERS_TO_BE_PLAYABLE = 1
        private let PCM_BUFFER_SIZE: AVAudioFrameCount = 8192
        
        private let queue = DispatchQueue(label: "SwiftAudioPlayer.StreamEngine\(UUID().uuidString)", qos: .userInitiated)
        
        //From init
        var converter: AudioConvertable!
        
        //Fields
        private var currentTimeOffset: TimeInterval = 0
        
        init(withRemoteUrl url: AudioURL, delegate: AudioEngineDelegate?) {
            Log.info(url)
            super.init(url: url, delegate: delegate, engineAudioFormat: Engine.defaultEngineAudioFormat)
            do {
                converter = try Converter(withRemoteUrl: url, toEngineAudioFormat: Engine.defaultEngineAudioFormat)
            } catch {
                delegate?.didError()
            }
            
            //let timeInterval = 1 / (converter.engineAudioFormat.sampleRate / Double(PCM_BUFFER_SIZE))
        }
    
        override func invalidate() {
            super.invalidate()
            converter.invalidate()
        }
        
        public func poll(_ frames: AVAudioFrameCount) throws -> AVAudioPCMBuffer! {
            try converter.pullBuffer(withSize: frames)
        }
    }
}
