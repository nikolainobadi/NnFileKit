//
//  FileSystem.swift
//  NnFileKit
//
//  Created by Nikolai Nobadi on 2/12/26.
//

import Foundation

/// Provides top-level file system operations for navigating directories and managing files.
public protocol FileSystem {
    /// The current user's home directory.
    var homeDirectory: any Directory { get }

    /// The process's current working directory.
    var currentDirectory: any Directory { get }

    /// Moves the item at the specified path to the trash.
    /// - Parameter path: The absolute path of the item to trash.
    func moveToTrash(at path: String) throws

    /// Returns the directory at the specified path.
    /// - Parameter path: The absolute path of the directory.
    /// - Returns: The directory at `path`.
    /// - Throws: ``FileSystemError/directoryNotFound(_:)`` if no directory exists at `path`.
    func directory(at path: String) throws -> any Directory

    /// Returns the current user's desktop directory.
    /// - Returns: The desktop directory.
    func desktopDirectory() throws -> any Directory

    /// Reads the contents of a file as a UTF-8 string.
    /// - Parameter path: The absolute path of the file to read.
    /// - Returns: The file's contents.
    func readFile(at path: String) throws -> String

    /// Writes a string to a file, creating or overwriting as needed.
    /// - Parameters:
    ///   - path: The absolute path of the file to write.
    ///   - contents: The string to write.
    func writeFile(at path: String, contents: String) throws
}


// MARK: - Helpers
public extension FileSystem {
    /// Returns the directory at the given path, falling back to ``currentDirectory`` when `path` is `nil`.
    /// - Parameter path: An optional absolute path. Pass `nil` to use the current directory.
    /// - Returns: The resolved directory.
    func getDirectoryAtPathOrCurrent(path: String?) throws -> any Directory {
        guard let path else {
            return currentDirectory
        }

        return try directory(at: path)
    }
}
