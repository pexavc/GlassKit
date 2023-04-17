//
//  MainState.swift
//  Base
//
//  Created by 0xKala on 3/20/21.
//  Copyright (c) 2021 Stoic Collective, LLC.. All rights reserved.
//

import GraniteUI
import SwiftUI
import Combine
import SotoS3

public class MainState: GraniteState {
    let bucket = "la-marque-radio"

    let client = AWSClient(
        credentialProvider: .static(accessKeyId: "AKIAUEKJ57IWM3QZYKWF", secretAccessKey: "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"),
        httpClientProvider: .createNew
    )
    
    var existingIndex: String = ""
    
    var playlist: LeVerre.Playlist = .init(songs: [])
    var metadataPut: LeVerre.SongPut = .empty
    var isMultiSelect: Bool = true
    var songs: [LeVerre.SongPut] = []
    var multiPutResults: Int = 0
    var putResults: Int = 0
    var currentIndex: Int = 0
}

public class MainCenter: GraniteCenter<MainState> {
    public override var expeditions: [GraniteBaseExpedition] {
        [
            S3GetExpedition.Discovery(),
            S3GetResultExpedition.Discovery(),
            S3PutExpedition.Discovery(),
            S3PutAllExpedition.Discovery(),
            S3PutResultExpedition.Discovery(),
            S3PutCompleteExpedition.Discovery(),
            S3DeleteAllExpedition.Discovery(),
            S3PutAllExpedition.Discovery()
        ]
    }
    
    public override var links: [GraniteLink] {
        [
            .onAppear(MainEvents.S3.Get())
        ]
    }
}

//

public struct LeVerre {
    
}

public extension LeVerre {
    static var delim = "{@del=1216%im@}"
    
    struct Playlist {
        var songs: [Song]
    }
    
    struct Song: Metadata, Equatable {
        var title: String
        var artist: String
        var songPath: String
        var artworkPath: String
        var duration: Float
        var durationString: String
        var index: Int
    }
    
    struct SongPut: Metadata, Equatable {
        static var delim: String = ":-:"
        
        var title: String
        var artist: String
        var songFilename: String
        var songPath: String
        var songExt: String = ""
        var artworkFilename: String
        var artworkPath: String
        var artworkExt: String = ""
        var duration: Float = 0.0 {
            didSet {
                durationString = "\(duration)"
            }
        }
        var durationString: String = ""
        var index: Int
        
        public static var empty: SongPut {
            return .init(title: "", artist: "", songFilename: "", songPath: "", artworkFilename: "", artworkPath: "", index: 0)
        }
        
        public static var order: [Indexing] {
            [ .title, .artist, .duration, .songext, .artext ]
        }
        
        var compiled: String {
            SongPut.delim + (SongPut.order.map { self.propertyFor($0) }.joined(separator: SongPut.delim)) + LeVerre.delim
        }
        
        public enum Indexing: Int {
            case title
            case artist
            case duration
            case songext
            case artext
        }
        
        public func propertyFor(_ index: Indexing) -> String {
            switch index {
            case .title:
                return title
            case .artist:
                return artist
            case .duration:
                return durationString
            case .songext:
                return songExt
            case .artext:
                return artworkExt
            }
        }
    }
}

protocol Metadata: Hashable {
    var title: String { get set }
    var artist: String { get set }
    var songPath: String { get set }
    var artworkPath: String { get set }
    var duration: Float { get set }
    var durationString: String { get set }
    var index: Int { get set }

}

extension Metadata {
    var toString: String {
        """
        \(index)
        [ \(title) by \(artist) ]
        duration: \(duration)
        song: \(songPath)
        art: \(artworkPath)
        """
    }
}
