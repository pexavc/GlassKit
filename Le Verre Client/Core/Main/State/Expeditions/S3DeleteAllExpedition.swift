//
//  S3DeleteAllExpedition.swift
//  Base
//
//  Created by 0xKala on 3/23/21.
//

import Foundation
import GraniteUI
import Combine
import SwiftUI
import SotoS3

struct S3DeleteAllExpedition: GraniteExpedition {
    typealias ExpeditionEvent = MainEvents.S3.Delete.All
    typealias ExpeditionState = MainState
    
    func reduce(
        event: ExpeditionEvent,
        state: ExpeditionState,
        connection: GraniteConnection,
        publisher: inout AnyPublisher<GraniteEvent, Never>) {
        
        let s3 = S3(client: state.client, region: .uswest1)
        
        let index = "index.txt"
        let songPaths = state.playlist.songs.map { $0.songPath }
        let artPaths = state.playlist.songs.map { $0.artworkPath }
        
        let ids = ([index] + songPaths + artPaths).map { S3.ObjectIdentifier.init(key: $0) }
        
        let delete = S3.Delete.init(objects: ids)
        let req = S3.DeleteObjectsRequest.init(bucket: state.bucket, delete: delete)
        s3.deleteObjects(req)
            .whenComplete { result in
                switch result {
                case .success(let output):
                    state.metadataPut = .empty
                    state.putResults = 0
                    
                    if event.multiupload {
                        connection.request(MainEvents.S3.Put(meta: state.songs[state.multiPutResults]))
                        
                    } else {
                        
                        connection.request(MainEvents.S3.Get())
                    }
                case .failure(let error):
                    print(error)
                    break
                }
            }
    }
}
