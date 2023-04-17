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

open class GlassMIDIEngine: NSObject {
    public override init() {
        #if os(macOS)
        micPermission = true
        #endif
        super.init()
    }
    
    public func test() {
        if let filepath = Bundle.main.url(forResource: "test", withExtension: "midi")
        {
            do
            {
//                let contents = try String(contentsOfFile: filepath)
//                print(contents)
                print(filepath)
            }
            catch
            {
                print("Contents could not be loaded.")
            }
        }
    }
}
