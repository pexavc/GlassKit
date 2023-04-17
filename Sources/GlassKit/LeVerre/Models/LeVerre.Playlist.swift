//
//  File.swift
//  
//
//  Created by 0xKala on 3/20/21.
//

import Foundation

public extension LeVerre {
    static var delim = "{@del=1216%im@}"
    
    class Playlist {
        public var songs: [Song]
        private var index: Int = 0
        
        var currentSong: Song {
            let song = songs[index]
            runningTotal += song.duration
            return song
        }
        
        var nextSong: Song {
            advance()
            return currentSong
        }
        
        var getIndex: Int {
            index
        }
        
        public var runningTotal: Float = 0.0
        
        private func advance() {
            let nextIndex: Int = index + 1
            if nextIndex >= songs.count {
                index = 0
            } else {
                index = nextIndex
            }
        }
        
        public init(songs: [Song] = []) {
            self.songs = songs
        }
        
        static func generate(from data: String) -> Playlist {
            let list: Playlist = .init(songs: [])
            let songMetadatas = data.components(separatedBy: LeVerre.delim)
        
            for (index, item) in songMetadatas.enumerated() {
                let metadata = item.components(separatedBy: LeVerre.SongPut.delim)
                guard !item.isEmpty &&
                      metadata.count - 1 <= LeVerre.SongPut.order.count else {
                    continue
                }
                
                var title: String = ""
                var artist: String = ""
                var durationString: String = ""
                var songExt: String = ""
                var artExt: String = ""
                
                for (i, attribute) in LeVerre.SongPut.order.enumerated() {
                    let index: Int = i + 1 //(index number is first) so we skip via a +1
                    switch attribute {
                    case .title:
                        title = metadata[index]
                    case .artist:
                        artist = metadata[index]
                    case .duration:
                        durationString = metadata[index]
                    case .songext:
                        songExt = metadata[index]
                    case .artext:
                        artExt = metadata[index]
                        
                    }
                }
                
                if let duration = Float(durationString) {
                    let song = LeVerre.Song.init(title: title,
                                                 artist: artist,
                                                 songPath: "music/\(title+artist).\(songExt)",
                                                 artworkPath: "artwork/\(title+artist).\(artExt)",
                                                 duration: duration,
                                                 durationString: durationString,
                                                 index: index)
                    
                    list.songs.append(song)
                }
            }
            
            //DEV: maybe shuffle is an option instead
            list.songs.shuffle()
            
            return list
        }
    }
    
    struct Song: Metadata, Equatable, Hashable {
        public var title: String
        public var artist: String
        public let songPath: String
        public let artworkPath: String
        public let duration: Float
        public let durationString: String
        public let index: Int
        
        var toString: String {
            """
            \(index)
            [ \(title) by \(artist) ]
            duration: \(duration)
            song: \(songPath)
            songURL: \(songURL)
            art: \(artworkPath)
            artURL: \(artworkURL)
            """
        }
        
        public var songURL: URL? {
            URL.init(string: LeVerre.rootPath + (songPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? songPath))
        }
        
        public var artworkURL: URL? {
            URL.init(string: LeVerre.rootPath + (artworkPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? artworkPath))
        }
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
        var seconds: Float64 = 0.0 {
            didSet {
                secondsString = "\(seconds)"
            }
        }
        var secondsString: String = ""
        
        public static var empty: SongPut {
            return .init(title: "", artist: "", songFilename: "", songPath: "", artworkFilename: "", artworkPath: "")
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
                return secondsString
            case .songext:
                return songExt
            case .artext:
                return artworkExt
            }
        }
    }
}

protocol Metadata {
    var title: String { get set }
    var artist: String { get set }
}
