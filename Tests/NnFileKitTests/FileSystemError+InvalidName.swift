//
//  FileSystemError+InvalidName.swift
//  NnFileKitTests
//
//  Created by Nikolai Nobadi on 9/12/26.
//

import NnFileKit

extension FileSystemError {
    /// Returns whether this error is ``FileSystemError/invalidName(_:)`` carrying `name`.
    func isInvalidName(_ name: String) -> Bool {
        guard case .invalidName(let rejectedName) = self else {
            return false
        }

        return rejectedName == name
    }
}
