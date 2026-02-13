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
    @Test("Home directory matches configured value")
    func homeDirectory() {
        let home = MockDirectory(path: "/custom/home")
        let sut = makeSUT(homeDirectory: home)

        #expect(sut.homeDirectory.path == "/custom/home")
    }

    @Test("Current directory matches configured value")
    func currentDirectory() {
        let current = MockDirectory(path: "/custom/current")
        let sut = makeSUT(currentDirectory: current)

        #expect(sut.currentDirectory.path == "/custom/current")
    }

    @Test("Observable state starts at baseline")
    func startingValues() {
        let sut = makeSUT()

        #expect(sut.capturedPaths.isEmpty)
        #expect(sut.pathToMoveToTrash == nil)
        #expect(sut.writtenFilePath == nil)
        #expect(sut.writtenFileContents == nil)
    }
}


extension MockFileSystemTests {
    @Test("Directory map match is returned first")
    func directoryFromMap() throws {
        let expected = MockDirectory(path: "/mapped")
        let sut = makeSUT(directoryMap: ["/mapped": expected])

        let result = try sut.directory(at: "/mapped")

        #expect(result.path == "/mapped")
    }

    @Test("Fallback directory is returned when map has no match")
    func directoryFromFallback() throws {
        let fallback = MockDirectory(path: "/fallback")
        let sut = makeSUT(directoryToLoad: fallback)

        let result = try sut.directory(at: "/any/path")

        #expect(result.path == "/fallback")
    }

    @Test("Error is thrown when no map match and no fallback")
    func directoryThrowsWhenUnconfigured() {
        let sut = makeSUT()

        #expect(throws: (any Error).self) {
            try sut.directory(at: "/unknown")
        }
    }

    @Test("Looked-up paths are captured")
    func capturedPaths() throws {
        let fallback = MockDirectory(path: "/any")
        let sut = makeSUT(directoryToLoad: fallback)

        _ = try sut.directory(at: "/first")
        _ = try sut.directory(at: "/second")

        #expect(sut.capturedPaths == ["/first", "/second"])
    }

    @Test("Desktop directory returns configured value")
    func desktopDirectory() throws {
        let desktop = MockDirectory(path: "/custom/desktop")
        let sut = makeSUT(desktop: desktop)

        let result = try sut.desktopDirectory()

        #expect(result.path == "/custom/desktop")
    }
}


extension MockFileSystemTests {
    @Test("Configured file contents are returned by path")
    func readFileReturnsContents() throws {
        let sut = makeSUT(fileContentsToRead: ["/file.txt": "hello"])

        let contents = try sut.readFile(at: "/file.txt")

        #expect(contents == "hello")
    }

    @Test("Reading unconfigured path throws file not found")
    func readFileThrowsWhenMissing() {
        let sut = makeSUT()

        #expect(throws: FileSystemError.self) {
            try sut.readFile(at: "/missing.txt")
        }
    }

    @Test("Written file path and contents are recorded")
    func writeFileRecords() throws {
        let sut = makeSUT()

        try sut.writeFile(at: "/output.txt", contents: "data")

        #expect(sut.writtenFilePath == "/output.txt")
        #expect(sut.writtenFileContents == "data")
    }

    @Test("Trashed path is recorded")
    func moveToTrashRecords() throws {
        let sut = makeSUT()

        try sut.moveToTrash(at: "/trash/target")

        #expect(sut.pathToMoveToTrash == "/trash/target")
    }
}


extension MockFileSystemTests {
    @Test("Nil path returns current directory")
    func getDirectoryAtPathOrCurrentNil() throws {
        let current = MockDirectory(path: "/current")
        let sut = makeSUT(currentDirectory: current)

        let result = try sut.getDirectoryAtPathOrCurrent(path: nil)

        #expect(result.path == "/current")
    }

    @Test("Provided path returns directory at that path")
    func getDirectoryAtPathOrCurrentProvided() throws {
        let mapped = MockDirectory(path: "/specific")
        let sut = makeSUT(directoryMap: ["/specific": mapped])

        let result = try sut.getDirectoryAtPathOrCurrent(path: "/specific")

        #expect(result.path == "/specific")
    }
}


extension MockFileSystemTests {
    @Test("Error flag causes directory lookup to throw")
    func throwErrorOnDirectory() {
        let sut = makeSUT(throwError: true)

        #expect(throws: (any Error).self) {
            try sut.directory(at: "/any")
        }
    }

    @Test("Error flag causes read file to throw")
    func throwErrorOnReadFile() {
        let sut = makeSUT(
            fileContentsToRead: ["/exists.txt": "data"],
            throwError: true
        )

        #expect(throws: (any Error).self) {
            try sut.readFile(at: "/exists.txt")
        }
    }

    @Test("Error flag causes write file to throw")
    func throwErrorOnWriteFile() {
        let sut = makeSUT(throwError: true)

        #expect(throws: (any Error).self) {
            try sut.writeFile(at: "/file.txt", contents: "data")
        }
    }

    @Test("Error flag causes move to trash to throw")
    func throwErrorOnMoveToTrash() {
        let sut = makeSUT(throwError: true)

        #expect(throws: (any Error).self) {
            try sut.moveToTrash(at: "/target")
        }
    }

    @Test("Error flag causes desktop directory to throw")
    func throwErrorOnDesktopDirectory() {
        let sut = makeSUT(throwError: true)

        #expect(throws: (any Error).self) {
            try sut.desktopDirectory()
        }
    }

    @Test("Error flag prevents path capture on directory lookup")
    func throwErrorSkipsCapture() {
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
