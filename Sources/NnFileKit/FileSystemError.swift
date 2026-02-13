//
//  FileSystemError.swift
//  NnFileKit
//
//  Created by Nikolai Nobadi on 2/12/26.
//

/// Errors thrown by ``DefaultFileSystem`` and ``DefaultDirectory`` operations.
public enum FileSystemError: Error {
    /// The directory at the associated path does not exist.
    case directoryNotFound(String)

    /// The file at the associated path does not exist.
    case fileNotFound(String)
}
