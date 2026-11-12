//
//  FileSystemError.swift
//  NnFileKit
//
//  Created by Nikolai Nobadi on 2/12/26.
//

/// Errors thrown by ``FileSystem`` and ``Directory`` operations.
public enum FileSystemError: Error {
    /// The directory at the associated path does not exist.
    case directoryNotFound(String)

    /// The file at the associated path does not exist.
    case fileNotFound(String)

    /// The associated name is not a single path component, or the associated relative path is absolute.
    case invalidName(String)

    /// The lock file at the associated path could not be opened or locked.
    case lockFailed(path: String, reason: String)
}
