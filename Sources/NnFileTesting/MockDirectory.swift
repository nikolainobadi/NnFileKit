//
//  MockDirectory.swift
//  NnFileTesting
//
//  Created by Nikolai Nobadi on 2/12/26.
//

import NnFileKit
import Foundation
import Synchronization

/// A test double for ``Directory`` that records calls and returns preconfigured values.
///
/// Copies share one lock-guarded storage, so state recorded through any copy is visible from all of them.
public struct MockDirectory: Directory {
    private let throwError: Bool
    private let shouldThrowOnSubdirectory: Bool
    private let autoCreateSubdirectories: Bool
    private let storage: Storage

    public let path: String
    public let name: String
    public let `extension`: String?

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
        self.init(
            path: path,
            throwError: throwError,
            shouldThrowOnSubdirectory: shouldThrowOnSubdirectory,
            autoCreateSubdirectories: autoCreateSubdirectories,
            ext: ext,
            state: State(subdirectories: subdirectories, containedFiles: containedFiles, fileContents: [:], movedToParents: [], copiedToParents: [], copiedFiles: [], deleteCallCount: 0)
        )
    }

    private init(path: String, throwError: Bool, shouldThrowOnSubdirectory: Bool, autoCreateSubdirectories: Bool, ext: String?, state: State) {
        self.path = path
        self.name = (path as NSString).lastPathComponent
        self.throwError = throwError
        self.shouldThrowOnSubdirectory = shouldThrowOnSubdirectory
        self.autoCreateSubdirectories = autoCreateSubdirectories
        self.extension = ext
        self.storage = Storage(state: state)
    }
}

// MARK: - Recorded State
public extension MockDirectory {
    var subdirectories: [any Directory] {
        get { storage.state.withLock { $0.subdirectories } }
        nonmutating set { storage.state.withLock { $0.subdirectories = newValue } }
    }

    var containedFiles: Set<String> {
        get { storage.state.withLock { $0.containedFiles } }
        nonmutating set { storage.state.withLock { $0.containedFiles = newValue } }
    }

    var fileContents: [String: String] {
        get { storage.state.withLock { $0.fileContents } }
        nonmutating set { storage.state.withLock { $0.fileContents = newValue } }
    }

    var movedToParents: [String] {
        return storage.state.withLock { $0.movedToParents }
    }

    var copiedToParents: [CopiedDirectory] {
        return storage.state.withLock { $0.copiedToParents }
    }

    var copiedFiles: [CopiedFile] {
        return storage.state.withLock { $0.copiedFiles }
    }

    var deleteCallCount: Int {
        return storage.state.withLock { $0.deleteCallCount }
    }
}

// MARK: - Directory
extension MockDirectory {
    public func containsFile(named name: String) -> Bool {
        guard isSingleComponent(name) else {
            return false
        }

        return storage.state.withLock { $0.containedFiles.contains(name) }
    }

    public func subdirectory(named name: String) throws -> any Directory {
        try throwIfNeeded()
        try validateName(name)

        if shouldThrowOnSubdirectory {
            throw NSError(domain: "MockDirectory", code: 1)
        }

        if let match = storage.state.withLock({ state in state.subdirectories.first(where: { $0.name == name }) }) {
            return match
        }

        if autoCreateSubdirectories {
            return MockDirectory(path: path.appendingPathComponent(name))
        }

        throw NSError(domain: "MockDirectory", code: 2)
    }

    public func createSubdirectory(named name: String) throws -> any Directory {
        try throwIfNeeded()
        try validateName(name)

        let created: MockDirectory? = storage.state.withLock { state in
            guard !state.subdirectories.contains(where: { $0.name == name }) else {
                return nil
            }

            let child = makeChild(named: name)
            state.subdirectories.append(child)

            return child
        }

        guard let created else {
            throw NSError(domain: "MockDirectory", code: 6, userInfo: [NSLocalizedDescriptionKey: "Directory already exists: \(name)"])
        }

        return created
    }

    public func move(to parent: any Directory) throws {
        try throwIfNeeded()

        let parentPath = parent.path

        storage.state.withLock { $0.movedToParents.append(parentPath) }
    }

    @discardableResult
    public func copy(to parent: any Directory, overwrite: Bool) throws -> any Directory {
        try throwIfNeeded()

        let parentPath = parent.path

        storage.state.withLock { $0.copiedToParents.append(CopiedDirectory(parentPath: parentPath, overwrite: overwrite)) }

        let copy = deepCopy(toPath: parentPath.appendingPathComponent(name))

        if let mockParent = parent as? MockDirectory {
            mockParent.receiveSubdirectory(copy)
        }

        return copy
    }

    public func delete() throws {
        try throwIfNeeded()

        storage.state.withLock { $0.deleteCallCount += 1 }
    }

    public func createSubfolderIfNeeded(named name: String) throws -> any Directory {
        try throwIfNeeded()
        try validateName(name)

        return storage.state.withLock { state -> any Directory in
            if let existing = state.subdirectories.first(where: { $0.name == name }) {
                return existing
            }

            let child = makeChild(named: name)
            state.subdirectories.append(child)

            return child
        }
    }

    public func deleteFile(named name: String) throws {
        try throwIfNeeded()
        try validateName(name)

        storage.state.withLock { _ = $0.containedFiles.remove(name) }
    }

    @discardableResult
    public func createFile(named name: String, contents: String) throws -> String {
        try throwIfNeeded()
        try validateName(name)

        receiveFile(named: name, contents: contents)

        return path.appendingPathComponent(name)
    }

    @discardableResult
    public func copyFile(named name: String, to destination: any Directory, overwrite: Bool) throws -> String {
        try throwIfNeeded()
        try validateName(name)

        let destinationPath = destination.path.appendingPathComponent(name)
        let source: (found: Bool, contents: String?) = storage.state.withLock { state in
            guard state.containedFiles.contains(name) else {
                return (false, nil)
            }

            state.copiedFiles.append(CopiedFile(name: name, destinationPath: destinationPath, overwrite: overwrite))

            return (true, state.fileContents[name])
        }

        guard source.found else {
            throw NSError(domain: "MockDirectory", code: 5, userInfo: [NSLocalizedDescriptionKey: "File not found: \(name)"])
        }

        if let mockDestination = destination as? MockDirectory {
            mockDestination.receiveFile(named: name, contents: source.contents)
        }

        return destinationPath
    }

    /// Compares the stored contents of `name` here against the contents `other` reports for the same name.
    public func fileContentsEqual(named name: String, in other: any Directory) throws -> Bool {
        try throwIfNeeded()
        try validateName(name)

        let local: (found: Bool, contents: String) = storage.state.withLock { state in
            return (state.containedFiles.contains(name), state.fileContents[name] ?? "")
        }

        guard local.found else {
            throw FileSystemError.fileNotFound(path.appendingPathComponent(name))
        }

        guard other.containsFile(named: name) else {
            return false
        }

        return try local.contents == other.readFile(named: name)
    }

    public func readFile(named name: String) throws -> String {
        try throwIfNeeded()
        try validateName(name)

        let contents: String? = storage.state.withLock { state in
            guard state.containedFiles.contains(name) else {
                return nil
            }

            return state.fileContents[name] ?? ""
        }

        guard let contents else {
            throw NSError(domain: "MockDirectory", code: 3, userInfo: [NSLocalizedDescriptionKey: "File not found: \(name)"])
        }

        return contents
    }

    public func findFiles(withExtension extension: String?, recursive: Bool) throws -> [String] {
        try throwIfNeeded()

        let snapshot = storage.state.withLock { ($0.containedFiles, $0.subdirectories) }
        var filePaths: [String] = []

        for fileName in snapshot.0 {
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
            for subdirectory in snapshot.1 {
                let subFiles = try subdirectory.findFiles(withExtension: `extension`, recursive: true)
                filePaths.append(contentsOf: subFiles)
            }
        }

        return filePaths
    }
}

// MARK: - Internal Methods
extension MockDirectory {
    /// Adds `name` with `contents` in one critical section, so the file never appears without its contents.
    func receiveFile(named name: String, contents: String?) {
        storage.state.withLock { state in
            state.containedFiles.insert(name)
            state.fileContents[name] = contents
        }
    }
}

// MARK: - Private Methods
private extension MockDirectory {
    /// Appends `child` to this directory's subdirectories.
    func receiveSubdirectory(_ child: any Directory) {
        storage.state.withLock { $0.subdirectories.append(child) }
    }

    /// Returns a deep copy rooted at `path`, so the copy shares no mutable children with the original.
    /// Each child is copied after this directory's lock is released.
    func deepCopy(toPath path: String) -> MockDirectory {
        let snapshot = storage.state.withLock { $0 }
        let children = snapshot.subdirectories.map { child -> any Directory in
            guard let mockChild = child as? MockDirectory else {
                return child
            }

            return mockChild.deepCopy(toPath: path.appendingPathComponent(mockChild.name))
        }

        return MockDirectory(
            path: path,
            throwError: false,
            shouldThrowOnSubdirectory: false,
            autoCreateSubdirectories: false,
            ext: `extension`,
            state: State(subdirectories: children, containedFiles: snapshot.containedFiles, fileContents: snapshot.fileContents, movedToParents: [], copiedToParents: [], copiedFiles: [], deleteCallCount: 0)
        )
    }

    /// Returns a new, empty child one path component below this directory.
    func makeChild(named name: String) -> MockDirectory {
        return MockDirectory(
            path: path.appendingPathComponent(name),
            subdirectories: [],
            containedFiles: [],
            throwError: false,
            shouldThrowOnSubdirectory: false,
            autoCreateSubdirectories: false,
            ext: nil
        )
    }

    /// Returns whether `name` is a single path component.
    func isSingleComponent(_ name: String) -> Bool {
        return !name.contains("/")
    }

    /// Throws ``FileSystemError/invalidName(_:)`` when `name` is not a single path component.
    func validateName(_ name: String) throws {
        guard isSingleComponent(name) else {
            throw FileSystemError.invalidName(name)
        }
    }

    func throwIfNeeded() throws {
        if throwError {
            throw NSError(domain: "MockDirectory", code: 4)
        }
    }
}

// MARK: - Storage
private extension MockDirectory {
    final class Storage: Sendable {
        let state: Mutex<State>

        init(state: State) {
            self.state = Mutex(state)
        }
    }

    struct State {
        var subdirectories: [any Directory]
        var containedFiles: Set<String>
        var fileContents: [String: String]
        var movedToParents: [String]
        var copiedToParents: [CopiedDirectory]
        var copiedFiles: [CopiedFile]
        var deleteCallCount: Int
    }
}

// MARK: - Dependencies
/// A directory copy recorded by ``MockDirectory/copy(to:overwrite:)``.
public struct CopiedDirectory: Equatable, Sendable {
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
public struct CopiedFile: Equatable, Sendable {
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
