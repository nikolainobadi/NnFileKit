//
//  MockFileSystemTests.swift
//  NnFileKitTests
//
//  Created by Nikolai Nobadi on 2/12/26.
//

import Testing
import NnFileKit
@testable import NnFileTesting

struct MockFileSystemTests {
    @Test
    func `Home directory matches configured value`() {
        let home = MockDirectory(path: "/custom/home")
        let sut = makeSUT(homeDirectory: home)

        #expect(sut.homeDirectory.path == "/custom/home")
    }

    @Test
    func `Current directory matches configured value`() {
        let current = MockDirectory(path: "/custom/current")
        let sut = makeSUT(currentDirectory: current)

        #expect(sut.currentDirectory.path == "/custom/current")
    }

    @Test
    func `Observable state starts at baseline`() {
        let sut = makeSUT()

        #expect(sut.capturedPaths.isEmpty)
        #expect(sut.pathToMoveToTrash == nil)
        #expect(sut.writtenFilePath == nil)
        #expect(sut.writtenFileContents == nil)
    }
}

// MARK: - Directory Lookup
extension MockFileSystemTests {
    @Test
    func `Directory map match is returned first`() throws {
        let expected = MockDirectory(path: "/mapped")
        let sut = makeSUT(directoryMap: ["/mapped": expected])

        let result = try sut.directory(at: "/mapped")

        #expect(result.path == "/mapped")
    }

    @Test
    func `Fallback directory is returned when map has no match`() throws {
        let fallback = MockDirectory(path: "/fallback")
        let sut = makeSUT(directoryToLoad: fallback)

        let result = try sut.directory(at: "/any/path")

        #expect(result.path == "/fallback")
    }

    @Test
    func `Error is thrown when no map match and no fallback`() {
        let sut = makeSUT()

        #expect(throws: (any Error).self) {
            try sut.directory(at: "/unknown")
        }
    }

    @Test
    func `Looked-up paths are captured`() throws {
        let fallback = MockDirectory(path: "/any")
        let sut = makeSUT(directoryToLoad: fallback)

        _ = try sut.directory(at: "/first")
        _ = try sut.directory(at: "/second")

        #expect(sut.capturedPaths == ["/first", "/second"])
    }

    @Test
    func `Desktop directory returns configured value`() throws {
        let desktop = MockDirectory(path: "/custom/desktop")
        let sut = makeSUT(desktop: desktop)

        let result = try sut.desktopDirectory()

        #expect(result.path == "/custom/desktop")
    }
}

// MARK: - File Operations
extension MockFileSystemTests {
    @Test
    func `Configured file contents are returned by path`() throws {
        let sut = makeSUT(fileContentsToRead: ["/file.txt": "hello"])

        let contents = try sut.readFile(at: "/file.txt")

        #expect(contents == "hello")
    }

    @Test
    func `Reading unconfigured path throws file not found`() {
        let sut = makeSUT()

        #expect(throws: FileSystemError.self) {
            try sut.readFile(at: "/missing.txt")
        }
    }

    @Test
    func `Written file path and contents are recorded`() throws {
        let sut = makeSUT()

        try sut.writeFile(at: "/output.txt", contents: "data")

        #expect(sut.writtenFilePath == "/output.txt")
        #expect(sut.writtenFileContents == "data")
    }

    @Test
    func `Trashed path is recorded`() throws {
        let sut = makeSUT()

        try sut.moveToTrash(at: "/trash/target")

        #expect(sut.pathToMoveToTrash == "/trash/target")
    }
}

// MARK: - Directory Resolution
extension MockFileSystemTests {
    @Test
    func `Nil path returns current directory`() throws {
        let current = MockDirectory(path: "/current")
        let sut = makeSUT(currentDirectory: current)

        let result = try sut.getDirectoryAtPathOrCurrent(path: nil)

        #expect(result.path == "/current")
    }

    @Test
    func `Provided path returns directory at that path`() throws {
        let mapped = MockDirectory(path: "/specific")
        let sut = makeSUT(directoryMap: ["/specific": mapped])

        let result = try sut.getDirectoryAtPathOrCurrent(path: "/specific")

        #expect(result.path == "/specific")
    }
}

// MARK: - Error Flag
extension MockFileSystemTests {
    @Test
    func `Error flag causes directory lookup to throw`() {
        let sut = makeSUT(throwError: true)

        #expect(throws: (any Error).self) {
            try sut.directory(at: "/any")
        }
    }

    @Test
    func `Error flag causes read file to throw`() {
        let sut = makeSUT(
            fileContentsToRead: ["/exists.txt": "data"],
            throwError: true
        )

        #expect(throws: (any Error).self) {
            try sut.readFile(at: "/exists.txt")
        }
    }

    @Test
    func `Error flag causes write file to throw`() {
        let sut = makeSUT(throwError: true)

        #expect(throws: (any Error).self) {
            try sut.writeFile(at: "/file.txt", contents: "data")
        }
    }

    @Test
    func `Error flag causes move to trash to throw`() {
        let sut = makeSUT(throwError: true)

        #expect(throws: (any Error).self) {
            try sut.moveToTrash(at: "/target")
        }
    }

    @Test
    func `Error flag causes desktop directory to throw`() {
        let sut = makeSUT(throwError: true)

        #expect(throws: (any Error).self) {
            try sut.desktopDirectory()
        }
    }

    @Test
    func `Error flag prevents path capture on directory lookup`() {
        let sut = makeSUT(throwError: true)

        _ = try? sut.directory(at: "/should/not/capture")

        #expect(sut.capturedPaths.isEmpty)
    }
}

// MARK: - SUT
private extension MockFileSystemTests {
    func makeSUT(
        homeDirectory: any Directory = MockDirectory(path: "/Users/Home"),
        currentDirectory: any Directory = MockDirectory(path: "/Users/Home/Current"),
        directoryToLoad: (any Directory)? = nil,
        directoryMap: [String: any Directory] = [:],
        desktop: (any Directory)? = nil,
        fileContentsToRead: [String: String] = [:],
        throwError: Bool = false
    ) -> MockFileSystem {
        return MockFileSystem(
            homeDirectory: homeDirectory,
            currentDirectory: currentDirectory,
            directoryToLoad: directoryToLoad,
            directoryMap: directoryMap,
            desktop: desktop,
            fileContentsToRead: fileContentsToRead,
            throwError: throwError
        )
    }
}
