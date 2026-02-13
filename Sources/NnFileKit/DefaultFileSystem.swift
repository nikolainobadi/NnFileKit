//
//  DefaultFileSystem.swift
//  NnFileKit
//
//  Created by Nikolai Nobadi on 2/12/26.
//

import Foundation

/// A `FileManager`-backed ``FileSystem`` implementation that performs real file system operations.
public struct DefaultFileSystem: FileSystem, Sendable {
    private nonisolated(unsafe) let fileManager: FileManager

    /// Creates a file system backed by the given file manager.
    /// - Parameter fileManager: The `FileManager` to use. Defaults to `.default`.
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
}


// MARK: - FileSystem
extension DefaultFileSystem {
    public var homeDirectory: any Directory {
        return DefaultDirectory(path: NSHomeDirectory())
    }

    public var currentDirectory: any Directory {
        return DefaultDirectory(path: fileManager.currentDirectoryPath)
    }

    public func directory(at path: String) throws -> any Directory {
        var isDir: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            throw FileSystemError.directoryNotFound(path)
        }

        return DefaultDirectory(path: path)
    }

    public func desktopDirectory() throws -> any Directory {
        let desktopPath = (fileManager.homeDirectoryForCurrentUser.path as NSString).appendingPathComponent("Desktop")
        
        return try directory(at: desktopPath)
    }

    public func readFile(at path: String) throws -> String {
        return try String(contentsOfFile: path, encoding: .utf8)
    }

    public func writeFile(at path: String, contents: String) throws {
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
    }

    public func moveToTrash(at path: String) throws {
        try fileManager.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
    }
}
