//
//  Item.swift
//  Pour Rice
//
//  Created by Test-Plus on 10/2/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
