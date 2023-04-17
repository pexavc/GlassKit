//
//  MainComponent.swift
//  Base
//
//  Created by 0xKala on 3/20/21.
//  Copyright (c) 2021 Stoic Collective, LLC.. All rights reserved.
//

import GraniteUI
import SwiftUI
import Combine
import AVFoundation

public struct MainComponent: GraniteComponent {
    @ObservedObject
    public var command: GraniteCommand<MainCenter, MainState> = .init()
    
    public init() {}
    
    public var body: some View {
        VStack {
            Button("delete all", action: sendEvent(MainEvents.S3.Delete.All()) )
            
            HStack {
                Spacer()
                
                Rectangle().frame(width: 25, height: 25, alignment: .center).foregroundColor(state.isMultiSelect ? Color.black : Color.gray)
                    .onTapGesture {
                        set(\.isMultiSelect, value: state.isMultiSelect ? false : true)
                    }
                
                Text("multi upload")
                
                Spacer()
            }
            
            Rectangle()
                .foregroundColor(Color.black)
                .frame(maxWidth: .infinity,
                       minHeight: 4,
                       idealHeight: 4,
                       maxHeight: 4)
            
            Spacer()
            
            if !state.isMultiSelect {
                VStack {
                    
                    TextField("title",
                              text: _state.metadataPut.title)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.black)
                        .padding(.leading, 4)
                        .padding(.trailing, 4)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                        .background(Color.gray)
                    
                    TextField("artist",
                              text: _state.metadataPut.artist)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.black)
                        .padding(.leading, 4)
                        .padding(.trailing, 4)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                        .background(Color.gray)
                    
                    HStack {
                        Spacer()
                        Button("\(state.metadataPut.songFilename.isEmpty ? "Upload Song" : state.metadataPut.songFilename)", action: { openPicker(song: true) } )
                        Button("\(state.metadataPut.artworkFilename.isEmpty ? "Upload Art" : state.metadataPut.artworkFilename)", action: { openPicker(song: false) } )
                            .padding(.top, 4)
                        Spacer()
                    }
                    .padding(.top, 4)
                    
                    
                    Button("Upload", action: sendEvent(MainEvents.S3.Put(meta: state.metadataPut)))
                }.padding([.top, .bottom], 24)
            } else {
                Button("Select", action: {openPicker(song: true)})
                if (state.songs.count >= 1) {
                    Button("Upload All", action: sendEvent(MainEvents.S3.Put.All()))
                }
            }
            
            Rectangle()
                .foregroundColor(Color.black)
                .frame(maxWidth: .infinity,
                       minHeight: 4,
                       idealHeight: 4,
                       maxHeight: 4)
            
            
            HStack {
                ScrollView {
                    LazyVGrid(columns: [GridItem.init(.flexible())]) {
                        ForEach(state.songs, id: \.self) { song in
                            Text(song.toString)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                if (state.playlist.songs.isEmpty == false) {
                    ScrollView {
                        LazyVGrid(columns: [GridItem.init(.flexible())]) {
                            ForEach(state.playlist.songs, id: \.self) { song in
                                Text(song.toString)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(Color.orange)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }.frame(width: 500, height: 600).padding(.top, 12)
    }
}

extension MainComponent {
    func openPicker(song: Bool) {
        let openPanel = NSOpenPanel()
        openPanel.prompt = "Select a \(song ? "Song" : "Artwork")"
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        
        
        openPanel.begin { (result) -> Void in
            if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
                if state.isMultiSelect {
                    for url in openPanel.urls {
                        state.songs.append(create(from: url, song: song))
                    }
                    
                    set(\.currentIndex, value: state.songs.count)
                } else {
                    guard let url = openPanel.url else {
                        return
                    }
                    
                    state.songs.append(create(from: url, song: song))
                }
            }
        }
    }
    
    func create(from url: URL, song: Bool) -> LeVerre.SongPut {
        let path = url.path
        
        var metadataPut: LeVerre.SongPut = .empty
        
        let ext = url.pathExtension
        if song {
            let filename = ((url.pathComponents.last ?? ""))
            let title = (filename.split(separator: "-").first ?? "").lowercased().trimmingTrailingSpaces
            
            let asset = AVURLAsset(url: url)
            let duration = asset.duration
            let seconds = CMTimeGetSeconds(duration)
            
            metadataPut.title = title+"_\(state.songs.count)"
            metadataPut.artist = "le_Verre"
            metadataPut.songPath = path
            metadataPut.duration = Float(seconds)
            metadataPut.songExt = ext
            //forces a redraw
            metadataPut.songFilename = filename
//                    set(\.metadataPut.songFilename, value: filename)
        } else {
            let filename = url.pathComponents.last ?? ""
            metadataPut.artworkPath = path
            metadataPut.artworkExt = ext
            
            metadataPut.artworkFilename = filename
//                    set(\.metadataPut.artworkFilename, value: filename)
        }
        
        metadataPut.index = state.songs.count
        
        return metadataPut
    }
}

extension String {
    var trimmingTrailingSpaces: String {
        if let range = rangeOfCharacter(from: .whitespacesAndNewlines, options: [.anchored, .backwards]) {
            return String(self[..<range.lowerBound]).trimmingTrailingSpaces
        }
        return self
    }
}

