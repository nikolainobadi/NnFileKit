//
//  DefaultFileSystemTests.swift
//  NnFileKitTests
//
//  Created by Nikolai Nobadi on 2/12/26.
//

import Testing
import Foundation
@testable import NnFileKit

struct DefaultFileSystemTests {
    @Test
    func `Directory is returned for valid existing path`() throws {
        let sut = makeSUT()
        let tempPath = NSTemporaryDirectory()

        let dir = try sut.directory(at: tempPath)

        #expect(dir.path == tempPath)
    }

    @Test
    func `Error is thrown for nonexistent directory path`() {
        let sut = makeSUT()

        #expect(throws: FileSystemError.self) {
            try sut.directory(at: "/nonexistent/path/\(UUID().uuidString)")
        }
    }

    @Test
    func `File contents are written and readable`() throws {
        let sut = makeSUT()
        let path = NSTemporaryDirectory().appendingPathComponent(UUID().uuidString + ".txt")

        try sut.writeFile(at: path, contents: "test content")
        let contents = try sut.readFile(at: path)

        #expect(contents == "test content")
    }

    @Test
    func `Home directory matches system home path`() {
        let sut = makeSUT()

        #expect(sut.homeDirectory.path == NSHomeDirectory() + "/")
    }

    @Test
    func `Current directory matches system working directory path`() {
        let sut = makeSUT()

        #expect(sut.currentDirectory.path == FileManager.default.currentDirectoryPath + "/")
    }
}

// MARK: - Directory Resolution
extension DefaultFileSystemTests {
    @Test
    func `Nil path returns current directory`() throws {
        let sut = makeSUT()

        let dir = try sut.getDirectoryAtPathOrCurrent(path: nil)

        #expect(dir.path == sut.currentDirectory.path)
    }

    @Test
    func `Provided path returns directory at that path`() throws {
        let sut = makeSUT()
        let tempPath = NSTemporaryDirectory()

        let dir = try sut.getDirectoryAtPathOrCurrent(path: tempPath)

        #expect(dir.path == tempPath)
    }
}

// MARK: - Directory Creation
extension DefaultFileSystemTests {
    @Test
    func `Every missing intermediate along a path is created`() throws {
        let sut = makeSUT()
        let parentPath = NSTemporaryDirectory().appendingPathComponent(UUID().uuidString)

        try sut.createDirectory(at: parentPath.appendingPathComponent("child"))

        #expect(FileManager.default.fileExists(atPath: parentPath))
    }

    @Test
    func `Created directory is returned at the requested path`() throws {
        let sut = makeSUT()
        let path = NSTemporaryDirectory().appendingPathComponent(UUID().uuidString + "/child")

        let created = try sut.createDirectory(at: path)

        #expect(created.path == path + "/")
    }

    @Test
    func `Creating an existing directory returns it without throwing`() throws {
        let sut = makeSUT()
        let path = NSTemporaryDirectory().appendingPathComponent(UUID().uuidString)
        let first = try sut.createDirectory(at: path)

        let second = try sut.createDirectory(at: path)

        #expect(second.path == first.path)
    }

    @Test
    func `Created directory is found by path lookup`() throws {
        let sut = makeSUT()
        let path = NSTemporaryDirectory().appendingPathComponent(UUID().uuidString + "/child")
        let created = try sut.createDirectory(at: path)

        let found = try sut.directory(at: path)

        #expect(found.path == created.path)
    }

    @Test
    func `Directory under the home directory is created`() throws {
        let sut = makeSUT()
        let rootPath = sut.homeDirectory.path.appendingPathComponent(".nnfilekit-tests-\(UUID().uuidString)")
        let path = rootPath.appendingPathComponent("child")
        defer { try? FileManager.default.removeItem(atPath: rootPath) }

        try sut.createDirectory(at: path)

        #expect(FileManager.default.fileExists(atPath: path))
    }
}

// MARK: - SUT
private extension DefaultFileSystemTests {
    func makeSUT() -> DefaultFileSystem {
        return DefaultFileSystem()
    }
}
