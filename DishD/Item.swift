//
//  Item.swift
//  DishD
//
//  Created by Luca Ragazzini on 23/06/2026.
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
