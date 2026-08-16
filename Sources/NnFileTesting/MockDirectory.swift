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
    func throwIfNeeded() throws {
        if throwError {
            throw NSError(domain: "MockDirectory", code: 4)
        }
    }
}
