//
//  File.swift
//  
//
//  Created by PEXAVC on 3/23/21.
//

import Foundation
import AVFoundation

extension LeVerre {
    public class Disk: Engine {
        var audioFormat: AVAudioFormat?
        var audioSampleRate: Float = 0
        var audioLengthSamples: AVAudioFramePosition = 0
        var seekFrame: AVAudioFramePosition = 0
        var currentPosition: AVAudioFramePosition = 0
        
        var audioFile: AVAudioFile?
        
        var currentFrame: AVAudioFramePosition {
            guard let lastRenderTime = playerNode.lastRenderTime,
                let playerTime = playerNode.playerTime(forNodeTime: lastRenderTime) else {
                    return 0
            }
            
            return playerTime.sampleTime
        }
        
        var audioLengthSeconds: Float = 0
        
        init(withSavedUrl url: AudioURL, delegate: AudioEngineDelegate?) {
            Log.info(url.key)
            
            do {
                audioFile = try AVAudioFile(forReading: url)
            } catch {
                Log.monitor(error.localizedDescription)
            }
            
            super.init(url: url, delegate: delegate, engineAudioFormat: audioFile?.processingFormat ?? Engine.defaultEngineAudioFormat)
            
            if let file = audioFile {
                Log.debug("Audio file exists")
                audioLengthSamples = file.length
                audioFormat = file.processingFormat
                audioSampleRate = Float(audioFormat?.sampleRate ?? 44100)
                audioLengthSeconds = Float(audioLengthSamples) / audioSampleRate
                duration = Duration(audioLengthSeconds)
            } else {
                Log.monitor("Could not load downloaded file with url: \(url)")
            }
            
            scheduleAudioFile()
        }
        
        private func scheduleAudioFile() {
            guard let audioFile = audioFile else { return }
            
            playerNode.scheduleFile(audioFile, at: nil, completionHandler: nil)
        }
        
        override func invalidate() {
            super.invalidate()
            //Nothing to invalidate for disk
        }
    }
}
