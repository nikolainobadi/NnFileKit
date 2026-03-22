//
//  JSONEncoder+Extensions.swift
//
//
//  Created by Nikolai Nobadi on 6/19/24.
//

import Foundation

public extension JSONEncoder {
    static func prettyOutput() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        return encoder
    }
}
