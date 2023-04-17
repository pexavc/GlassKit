//
//  File.swift
//  
//
//  Created by PEXAVC on 3/20/21.
//

import Foundation

public class LeVerre {
    struct Properties {
        public struct Transition {
            public var isActive: Bool = false
            public var commit: Bool = false
            let time: Float = 12
            var factor: Float = 0.0
            var queueing: Bool = false
        }
        
        var transition: Transition = .init()
    }
    struct Engines {
        var disk: Disk? = nil
        var remote: Remote? = nil
    }
    public enum EngineType {
        case remote
        case disk
    }
    
    static var rootPath: String = "https://la-marque-radio.s3-us-west-1.amazonaws.com/"
    static var indexPath: String = LeVerre.rootPath + "index.txt"
    
    //MARK: Properties
    var properties: Properties = .init()
    var engines: Engines = .init()
    
    //MARK: Stream Playlist
    var indexData: String = ""
    var playlist: Playlist = .init(songs: [])
    
    //MARK: Helpers
    var currentTime: Float = 0.0
    
    var playlistDuration: Song {
        playlist.songs[playlist.getIndex]
    }
    
    func prepare() {
        indexData = index ?? ""
        playlist = Playlist.generate(from: indexData)
    }
    
    public var index: String? {
    
        guard let url = URL(string: LeVerre.indexPath) else { return nil }
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil

        let session = URLSession.init(configuration: config)
        
        let result = session.synchronousDataTask(with: url)
        if let data = result.0 {
            if let string = String(data: data, encoding: .utf8) {
                return string
            }
        }
        return nil
    }
    
    public func stop() {
        self.engines.remote?.invalidate()
        self.engines.remote = nil
    }
}

extension URLSession {
    func synchronousDataTask(with url: URL) -> (Data?, URLResponse?, Error?) {
        var data: Data?
        var response: URLResponse?
        var error: Error?

        let semaphore = DispatchSemaphore(value: 0)
        
        let dataTask = self.dataTask(with: url) {
            data = $0
            response = $1
            error = $2

            semaphore.signal()
        }
        dataTask.resume()

        _ = semaphore.wait(timeout: .distantFuture)

        return (data, response, error)
    }
}
