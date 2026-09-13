//
//  MockFileSystem.swift
//  NnFileTesting
//
//  Created by Nikolai Nobadi on 2/12/26.
//

import NnFileKit
import Foundation

/// A test double for ``FileSystem`` that records calls and returns preconfigured values.
public final class MockFileSystem: FileSystem {
    private let desktop: any Directory
    private let throwError: Bool
    private let directoryToLoad: (any Directory)?
    private let directoryMap: [String: any Directory]?
    private let fileContentsToRead: [String: String]
    private let rootDirectory: any Directory

    public private(set) var capturedPaths: [String] = []
    public private(set) var pathToMoveToTrash: String?
    public private(set) var writtenFilePath: String?
    public private(set) var writtenFileContents: String?

    public let homeDirectory: any Directory
    public var currentDirectory: any Directory

    /// Creates a mock file system.
    /// - Parameters:
    ///   - homeDirectory: The value returned by ``homeDirectory``.
    ///   - currentDirectory: The value returned by ``currentDirectory``.
    ///   - directoryToLoad: A fallback directory returned by ``directory(at:)`` when `directoryMap` has no match.
    ///   - directoryMap: Directories keyed by the path ``directory(at:)`` should return them for.
    ///   - desktop: The value returned by ``desktopDirectory()``. Defaults to `Desktop` inside `homeDirectory`.
    ///   - fileContentsToRead: File contents keyed by the path ``readFile(at:)`` should return them for.
    ///   - throwError: Pass `true` to make every operation fail, for exercising error paths.
    public init(
        homeDirectory: any Directory = MockDirectory(path: "/Users/Home"),
        currentDirectory: any Directory = MockDirectory(path: "/Users/Home/CurrentTest"),
        directoryToLoad: (any Directory)? = nil,
        directoryMap: [String: any Directory]? = nil,
        desktop: (any Directory)? = nil,
        fileContentsToRead: [String: String] = [:],
        throwError: Bool = false
    ) {
        self.homeDirectory = homeDirectory
        self.currentDirectory = currentDirectory
        self.directoryToLoad = directoryToLoad
        self.directoryMap = directoryMap
        self.desktop = desktop ?? MockDirectory(path: homeDirectory.path.appendingPathComponent("Desktop"))
        self.fileContentsToRead = fileContentsToRead
        self.throwError = throwError
        self.rootDirectory = MockDirectory(
            path: "/",
            subdirectories: [],
            containedFiles: [],
            throwError: false,
            shouldThrowOnSubdirectory: false,
            autoCreateSubdirectories: false,
            ext: nil
        )
    }

    /// Resolves `directoryMap` first, then folders present in the home or root tree, then `directoryToLoad`.
    public func directory(at path: String) throws -> any Directory {
        try throwIfNeeded()

        capturedPaths.append(path)

        if let directory = existingDirectory(at: path) {
            return directory
        }

        throw NSError(domain: "MockFileSystem", code: 1)
    }

    /// Returns whatever ``directory(at:)`` would resolve; otherwise creates the chain in the home tree
    /// when `path` is under ``homeDirectory``, and in an in-memory root tree otherwise.
    @discardableResult
    public func createDirectory(at path: String) throws -> any Directory {
        try throwIfNeeded()

        capturedPaths.append(path)

        if let directory = existingDirectory(at: path) {
            return directory
        }

        let tree = treeRoot(for: path)

        return try tree.directory.createSubdirectory(atRelativePath: tree.relativePath)
    }

    public func desktopDirectory() throws -> any Directory {
        try throwIfNeeded()

        return desktop
    }

    /// Returns configured contents for `path`, falling back to the directory containing it.
    /// - Throws: ``FileSystemError/fileNotFound(_:)`` when neither source has the file.
    public func readFile(at path: String) throws -> String {
        try throwIfNeeded()

        if let contents = fileContentsToRead[path] {
            return contents
        }

        let directoryPath = (path as NSString).deletingLastPathComponent
        let fileName = (path as NSString).lastPathComponent

        guard let directory = try? self.directory(at: directoryPath), let contents = try? directory.readFile(named: fileName) else {
            throw FileSystemError.fileNotFound(path)
        }

        return contents
    }

    /// Records the write, and also applies it to the containing directory when one is configured.
    public func writeFile(at path: String, contents: String) throws {
        try throwIfNeeded()

        writtenFilePath = path
        writtenFileContents = contents

        let directoryPath = (path as NSString).deletingLastPathComponent
        let fileName = (path as NSString).lastPathComponent

        if let mockDir = try? self.directory(at: directoryPath) as? MockDirectory {
            mockDir.fileContents[fileName] = contents
            mockDir.containedFiles.insert(fileName)
        }
    }

    public func moveToTrash(at path: String) throws {
        try throwIfNeeded()

        pathToMoveToTrash = path
    }
}

// MARK: - Private Methods
private extension MockFileSystem {
    /// Resolves `path` through `directoryMap`, then the home or root tree, then `directoryToLoad`.
    func existingDirectory(at path: String) -> (any Directory)? {
        if let directoryMap, let directory = directoryMap[path] {
            return directory
        }

        let tree = treeRoot(for: path)

        if let directory = try? tree.directory.subdirectory(atRelativePath: tree.relativePath) {
            return directory
        }

        return directoryToLoad
    }

    /// Returns the tree `path` belongs to and `path` relative to that tree's root.
    /// The home check compares whole components, so `/Users/HomeOther` is not under `/Users/Home`.
    func treeRoot(for path: String) -> (directory: any Directory, relativePath: String) {
        let components = path.split(separator: "/").map(String.init)
        let homeComponents = homeDirectory.path.split(separator: "/").map(String.init)

        if components.starts(with: homeComponents) {
            return (homeDirectory, components.dropFirst(homeComponents.count).joined(separator: "/"))
        }

        return (rootDirectory, components.joined(separator: "/"))
    }

    func throwIfNeeded() throws {
        if throwError {
            throw NSError(domain: "MockFileSystem", code: 2)
        }
    }
}
