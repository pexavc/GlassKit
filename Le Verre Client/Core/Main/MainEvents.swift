//
//  MainEvents.swift
//  Base
//
//  Created by 0xKala on 3/20/21.
//  Copyright (c) 2021 Stoic Collective, LLC.. All rights reserved.
//

import GraniteUI
import SwiftUI
import Combine

struct MainEvents {
    public struct S3: GraniteEvent {
        public struct Get: GraniteEvent {
            public struct Result: GraniteEvent {
                let data: String
            }
            public var behavior: GraniteEventBehavior {
                .quiet
            }
        }
        public struct Put: GraniteEvent {
            let meta: LeVerre.SongPut
            public struct Result: GraniteEvent {
                public var behavior: GraniteEventBehavior {
                    .quiet
                }
            }
            public struct All: GraniteEvent {
                public var behavior: GraniteEventBehavior {
                    .quiet
                }
            }
            public struct Complete: GraniteEvent {
                public var behavior: GraniteEventBehavior {
                    .quiet
                }
            }
            public var behavior: GraniteEventBehavior {
                .quiet
            }
        }
        public struct Delete: GraniteEvent {
            public struct All: GraniteEvent {
                let multiupload: Bool
                
                public init(mp: Bool = false) {
                    multiupload = mp
                }
            }
            public var behavior: GraniteEventBehavior {
                .quiet
            }
        }
    }
}
