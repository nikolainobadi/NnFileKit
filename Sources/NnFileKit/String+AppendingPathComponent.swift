//
//  String+AppendingPathComponent.swift
//  NnFileKit
//
//  Created by Nikolai Nobadi on 2/12/26.
//

public extension String {
    /// Appends a path component to this string, inserting a separator if needed.
    /// - Parameter path: The path component to append.
    /// - Returns: The combined path string.
    func appendingPathComponent(_ path: String) -> String {
        if self.hasSuffix("/") {
            return self + path
        }

        return self + "/" + path
    }
}
