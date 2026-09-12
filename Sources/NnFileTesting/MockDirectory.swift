//
//  MockDirectory.swift
//  NnFileTesting
//
//  Created by Nikolai Nobadi on 2/12/26.
//

import NnFileKit
import Foundation

/// A test double for ``Directory`` that records calls and returns preconfigured values.
public final class MockDirectory: Directory {
    private let throwError: Bool
    private let shouldThrowOnSubdirectory: Bool
    private let autoCreateSubdirectories: Bool

    public let path: String
    public let name: String
    public let `extension`: String?
    public var subdirectories: [any Directory]
    public var containedFiles: Set<String>
    public var fileContents: [String: String] = [:]
    public private(set) var movedToParents: [String] = []
    public private(set) var copiedToParents: [CopiedDirectory] = []
    public private(set) var copiedFiles: [CopiedFile] = []
    public private(set) var deleteCallCount: Int = 0

    /// Creates a mock directory.
    /// - Parameters:
    ///   - path: The directory path, stored verbatim.
    ///   - subdirectories: The subdirectories this directory reports.
    ///   - containedFiles: The file names this directory reports as present.
    ///   - throwError: Pass `true` to make every throwing operation fail, for exercising error paths.
    ///   - shouldThrowOnSubdirectory: Pass `true` to fail only ``subdirectory(named:)``.
    ///   - autoCreateSubdirectories: Pass `true` to make ``subdirectory(named:)`` synthesize a directory for unknown names instead of failing.
    ///   - ext: The value reported by ``extension``.
    public init(path: String, subdirectories: [any Directory] = [], containedFiles: Set<String> = [], throwError: Bool = false, shouldThrowOnSubdirectory: Bool = false, autoCreateSubdirectories: Bool = false, ext: String? = nil) {
        self.path = path
        self.name = (path as NSString).lastPathComponent
        self.subdirectories = subdirectories
        self.containedFiles = containedFiles
        self.throwError = throwError
        self.shouldThrowOnSubdirectory = shouldThrowOnSubdirectory
        self.autoCreateSubdirectories = autoCreateSubdirectories
        self.extension = ext
    }

    public func containsFile(named name: String) -> Bool {
        return containedFiles.contains(name)
    }

    public func subdirectory(named name: String) throws -> any Directory {
        try throwIfNeeded()

        if shouldThrowOnSubdirectory {
            throw NSError(domain: "MockDirectory", code: 1)
        }

        if let match = subdirectories.first(where: { $0.name == name }) {
            return match
        }

        if autoCreateSubdirectories {
            return MockDirectory(path: path.appendingPathComponent(name))
        }

        throw NSError(domain: "MockDirectory", code: 2)
    }

    public func createSubdirectory(named name: String) throws -> any Directory {
        try throwIfNeeded()

        return try createSubfolderIfNeeded(named: name)
    }

    public func move(to parent: any Directory) throws {
        try throwIfNeeded()

        movedToParents.append(parent.path)
    }

    @discardableResult
    public func copy(to parent: any Directory, overwrite: Bool) throws -> any Directory {
        try throwIfNeeded()

        copiedToParents.append(CopiedDirectory(parentPath: parent.path, overwrite: overwrite))

        let copy = deepCopy(toPath: parent.path.appendingPathComponent(name))

        if let mockParent = parent as? MockDirectory {
            mockParent.subdirectories.append(copy)
        }

        return copy
    }

    public func delete() throws {
        try throwIfNeeded()

        deleteCallCount += 1
    }

    public func createSubfolderIfNeeded(named name: String) throws -> any Directory {
        try throwIfNeeded()

        if let existing = subdirectories.first(where: { $0.name == name }) {
            return existing
        }
        let newSubdirectory = MockDirectory(path: path.appendingPathComponent(name))
        subdirectories.append(newSubdirectory)
        return newSubdirectory
    }

    public func deleteFile(named name: String) throws {
        try throwIfNeeded()

        containedFiles.remove(name)
    }

    @discardableResult
    public func createFile(named name: String, contents: String) throws -> String {
        try throwIfNeeded()

        containedFiles.insert(name)
        fileContents[name] = contents
        return path.appendingPathComponent(name)
    }

    @discardableResult
    public func copyFile(named name: String, to destination: any Directory, overwrite: Bool) throws -> String {
        try throwIfNeeded()

        guard containedFiles.contains(name) else {
            throw NSError(domain: "MockDirectory", code: 5, userInfo: [NSLocalizedDescriptionKey: "File not found: \(name)"])
        }

        let destinationPath = destination.path.appendingPathComponent(name)
        copiedFiles.append(CopiedFile(name: name, destinationPath: destinationPath, overwrite: overwrite))

        if let mockDestination = destination as? MockDirectory {
            mockDestination.containedFiles.insert(name)
            mockDestination.fileContents[name] = fileContents[name]
        }

        return destinationPath
    }

    public func readFile(named name: String) throws -> String {
        try throwIfNeeded()

        guard containedFiles.contains(name) else {
            throw NSError(domain: "MockDirectory", code: 3, userInfo: [NSLocalizedDescriptionKey: "File not found: \(name)"])
        }
        return fileContents[name] ?? ""
    }

    public func findFiles(withExtension extension: String?, recursive: Bool) throws -> [String] {
        try throwIfNeeded()

        var filePaths: [String] = []

        for fileName in containedFiles {
            if let ext = `extension` {
                let fileExt = (fileName as NSString).pathExtension
                if fileExt == ext {
                    filePaths.append(path.appendingPathComponent(fileName))
                }
            } else {
                filePaths.append(path.appendingPathComponent(fileName))
            }
        }

        if recursive {
            for subdirectory in subdirectories {
                let subFiles = try subdirectory.findFiles(withExtension: `extension`, recursive: true)
                filePaths.append(contentsOf: subFiles)
            }
        }

        return filePaths
    }
}


// MARK: - Private Methods
private extension MockDirectory {
    /// Returns a deep copy rooted at `path`, so the copy shares no mutable children with the original.
    func deepCopy(toPath path: String) -> MockDirectory {
        let copy = MockDirectory(
            path: path,
            subdirectories: [],
            containedFiles: containedFiles,
            throwError: false,
            shouldThrowOnSubdirectory: false,
            autoCreateSubdirectories: false,
            ext: `extension`
        )

        copy.fileContents = fileContents
        copy.subdirectories = subdirectories.map { child -> any Directory in
            guard let mockChild = child as? MockDirectory else {
                return child
            }

            return mockChild.deepCopy(toPath: path.appendingPathComponent(mockChild.name))
        }

        return copy
    }

    func throwIfNeeded() throws {
        if throwError {
            throw NSError(domain: "MockDirectory", code: 4)
        }
    }
}


// MARK: - Dependencies
/// A directory copy recorded by ``MockDirectory/copy(to:overwrite:)``.
public struct CopiedDirectory: Equatable {
    public let parentPath: String
    public let overwrite: Bool

    /// - Parameters:
    ///   - parentPath: The path of the parent the directory was copied into.
    ///   - overwrite: The value passed for `overwrite`.
    public init(parentPath: String, overwrite: Bool) {
        self.parentPath = parentPath
        self.overwrite = overwrite
    }
}

/// A file copy recorded by ``MockDirectory/copyFile(named:to:overwrite:)``.
public struct CopiedFile: Equatable {
    public let name: String
    public let destinationPath: String
    public let overwrite: Bool

    /// - Parameters:
    ///   - name: The name of the copied file.
    ///   - destinationPath: The full path the file was copied to.
    ///   - overwrite: The value passed for `overwrite`.
    public init(name: String, destinationPath: String, overwrite: Bool) {
        self.name = name
        self.destinationPath = destinationPath
        self.overwrite = overwrite
    }
}
