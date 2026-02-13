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
    @Test("Directory is returned for valid existing path")
    func directoryAtValidPath() throws {
        let sut = makeSUT()
        let tempPath = NSTemporaryDirectory()

        let dir = try sut.directory(at: tempPath)

        #expect(dir.path == tempPath)
    }

    @Test("Error is thrown for nonexistent directory path")
    func directoryAtInvalidPath() {
        let sut = makeSUT()

        #expect(throws: FileSystemError.self) {
            try sut.directory(at: "/nonexistent/path/\(UUID().uuidString)")
        }
    }

    @Test("File contents are written and readable")
    func writeAndReadFile() throws {
        let sut = makeSUT()
        let path = NSTemporaryDirectory().appendingPathComponent(UUID().uuidString + ".txt")

        try sut.writeFile(at: path, contents: "test content")
        let contents = try sut.readFile(at: path)

        #expect(contents == "test content")
    }

    @Test("Home directory matches system home path")
    func homeDirectory() {
        let sut = makeSUT()

        #expect(sut.homeDirectory.path == NSHomeDirectory() + "/")
    }

    @Test("Current directory matches system working directory path")
    func currentDirectory() {
        let sut = makeSUT()

        #expect(sut.currentDirectory.path == FileManager.default.currentDirectoryPath + "/")
    }
}


extension DefaultFileSystemTests {
    @Test("Nil path returns current directory")
    func nilPathReturnsCurrent() throws {
        let sut = makeSUT()

        let dir = try sut.getDirectoryAtPathOrCurrent(path: nil)

        #expect(dir.path == sut.currentDirectory.path)
    }

    @Test("Provided path returns directory at that path")
    func providedPathReturnsDirectory() throws {
        let sut = makeSUT()
        let tempPath = NSTemporaryDirectory()

        let dir = try sut.getDirectoryAtPathOrCurrent(path: tempPath)

        #expect(dir.path == tempPath)
    }
}


// MARK: - SUT
private extension DefaultFileSystemTests {
    func makeSUT() -> DefaultFileSystem {
        return DefaultFileSystem()
    }
}
