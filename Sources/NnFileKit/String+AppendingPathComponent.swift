//
//  String+AppendingPathComponent.swift
//  NnFileKit
//
//  Created by Nikolai Nobadi on 2/12/26.
//

public extension String {
    func appendingPathComponent(_ path: String) -> String {
        if self.hasSuffix("/") {
            return self + path
        }

        return self + "/" + path
    }
}
