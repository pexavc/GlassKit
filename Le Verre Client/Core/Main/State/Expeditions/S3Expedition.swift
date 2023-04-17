//
//  S3Expedition.swift
//  Base
//
//  Created by 0xKala on 3/20/21.
//  Copyright (c) 2021 Stoic Collective, LLC.. All rights reserved.
//
import GraniteUI
import SwiftUI
import Combine
import Foundation
import SotoS3

struct S3GetExpedition: GraniteExpedition {
    typealias ExpeditionEvent = MainEvents.S3.Get
    typealias ExpeditionState = MainState
    
    func reduce(
        event: ExpeditionEvent,
        state: ExpeditionState,
        connection: GraniteConnection,
        publisher: inout AnyPublisher<GraniteEvent, Never>) {
        
        let s3 = S3(client: state.client, region: .uswest1)
        
        let getObjectRequest = S3.GetObjectRequest(bucket: state.bucket, key: "index.txt")
        s3.getObject(getObjectRequest)
            .whenComplete { result in
                switch result {
                case .success(let output):
                    if let data = output.body?.asString() {
                        connection.request(MainEvents.S3.Get.Result.init(data: data))
                    }
                case .failure(let error):
                    break
                }
            }
    }
}

struct S3GetResultExpedition: GraniteExpedition {
    typealias ExpeditionEvent = MainEvents.S3.Get.Result
    typealias ExpeditionState = MainState
    
    func reduce(
        event: ExpeditionEvent,
        state: ExpeditionState,
        connection: GraniteConnection,
        publisher: inout AnyPublisher<GraniteEvent, Never>) {
        
        guard !event.data.isEmpty else { return }
        
        state.playlist.songs.removeAll()
        
        state.existingIndex = event.data
        
        let songMetadatas = event.data.components(separatedBy: LeVerre.delim)
        
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
                
                state.playlist.songs.append(song)
            }
        }
        
        state.currentIndex = state.playlist.songs.count
    }
}

struct S3PutExpedition: GraniteExpedition {
    typealias ExpeditionEvent = MainEvents.S3.Put
    typealias ExpeditionState = MainState
    
    func reduce(
        event: ExpeditionEvent,
        state: ExpeditionState,
        connection: GraniteConnection,
        publisher: inout AnyPublisher<GraniteEvent, Never>) {
        
        /*
         
         index.txt
         delim NewLine = {@del=1216%im@} ?
         delim Metadata = :-:
         
         index:-:filename:-:title:-:artist:-:seconds{@del=1216%im@}
         
         
         */
        let s3 = S3(client: state.client, region: .uswest1)
        
        let meta = event.meta
        
        let songRequest = S3.CreateMultipartUploadRequest.init(acl: .publicRead,
                                                       bucket: state.bucket,
                                                       key: "music/"+meta.title+meta.artist+"."+meta.songExt)
        
        let artworkRequest = S3.CreateMultipartUploadRequest.init(acl: .publicRead,
                                                       bucket: state.bucket,
                                                       key: "artwork/"+meta.title+meta.artist+"."+meta.artworkExt)
        
        let newIndex = "\(state.currentIndex)"+meta.compiled
        guard let metadataIndex = (state.existingIndex+newIndex).data(using: .utf8) else {
            return
        }
        state.existingIndex += newIndex
        
        let indexRequest = S3.PutObjectRequest.init(acl: .publicRead,
                                                    body: .data(metadataIndex),
                                                    bucket: state.bucket,
                                                    key: "index.txt")
        
        s3.multipartUpload(songRequest,
                           filename: meta.songPath)
            .whenComplete { result in
                switch result {
                case .success(_):
                    connection.request(MainEvents.S3.Put.Result())
                case .failure(let error):
                    
                    print(error)
                    break
                }
            }
        
        s3.multipartUpload(artworkRequest,
                           filename: meta.artworkPath)
            .whenComplete { result in
                switch result {
                case .success(_):
                    connection.request(MainEvents.S3.Put.Result())
                case .failure(let error):
                    connection.request(MainEvents.S3.Put.Result())
                    break
                }
            }
        
        s3.putObject(indexRequest)
            .whenComplete { result in
                switch result {
                case .success(_):
                    connection.request(MainEvents.S3.Put.Result())
                case .failure(let error):
                    break
                }
            }
    }
}

struct S3PutResultExpedition: GraniteExpedition {
    typealias ExpeditionEvent = MainEvents.S3.Put.Result
    typealias ExpeditionState = MainState
    
    func reduce(
        event: ExpeditionEvent,
        state: ExpeditionState,
        connection: GraniteConnection,
        publisher: inout AnyPublisher<GraniteEvent, Never>) {
        
        state.putResults += 1
        if state.putResults >= 3 {
            connection.request(MainEvents.S3.Put.Complete())
        }
    }
}

struct S3PutAllExpedition: GraniteExpedition {
    typealias ExpeditionEvent = MainEvents.S3.Put.All
    typealias ExpeditionState = MainState
    
    func reduce(
        event: ExpeditionEvent,
        state: ExpeditionState,
        connection: GraniteConnection,
        publisher: inout AnyPublisher<GraniteEvent, Never>) {
        
        state.existingIndex = ""
        
        if state.playlist.songs.isEmpty {
            
            connection.request(MainEvents.S3.Delete.All(mp: true))
        } else {
            
            connection.request(MainEvents.S3.Put(meta: state.songs[state.multiPutResults]))
        }
        
    }
}

struct S3PutCompleteExpedition: GraniteExpedition {
    typealias ExpeditionEvent = MainEvents.S3.Put.Complete
    typealias ExpeditionState = MainState
    
    func reduce(
        event: ExpeditionEvent,
        state: ExpeditionState,
        connection: GraniteConnection,
        publisher: inout AnyPublisher<GraniteEvent, Never>) {
        
        state.multiPutResults += 1
        
        if state.multiPutResults >= state.songs.count - 1 {
            state.songs.removeAll()
            state.multiPutResults = 0
            state.putResults = 0
            connection.request(MainEvents.S3.Get())
        } else {
            state.putResults = 0
            print("{TEST} finished \(state.multiPutResults)")
            connection.request(MainEvents.S3.Put(meta: state.songs[state.multiPutResults]))
        }
        
        
        state.metadataPut = .empty
    }
}
