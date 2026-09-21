//
//  DefaultFileSystem.swift
//  NnFileKit
//
//  Created by Nikolai Nobadi on 2/12/26.
//

import Foundation

/// A `FileManager`-backed ``FileSystem`` implementation that performs real file system operations.
public struct DefaultFileSystem: FileSystem, Sendable {
    /// Creates a file system backed by `FileManager.default`.
    public init() { }
}

// MARK: - FileSystem
extension DefaultFileSystem {
    public var homeDirectory: any Directory {
        return DefaultDirectory(path: NSHomeDirectory())
    }

    public var currentDirectory: any Directory {
        return DefaultDirectory(path: FileManager.default.currentDirectoryPath)
    }

    public func directory(at path: String) throws -> any Directory {
        var isDir: ObjCBool = false

        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            throw FileSystemError.directoryNotFound(path)
        }

        return DefaultDirectory(path: path)
    }

    @discardableResult
    public func createDirectory(at path: String) throws -> any Directory {
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)

        return DefaultDirectory(path: path)
    }

    public func desktopDirectory() throws -> any Directory {
        let desktopPath = (FileManager.default.homeDirectoryForCurrentUser.path as NSString).appendingPathComponent("Desktop")
        
        return try directory(at: desktopPath)
    }

    public func readFile(at path: String) throws -> String {
        return try String(contentsOfFile: path, encoding: .utf8)
    }

    public func writeFile(at path: String, contents: String) throws {
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
    }

    public func moveToTrash(at path: String) throws {
        try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
    }
}
