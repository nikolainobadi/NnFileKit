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
    func `Directory present in the home tree is returned by path`() throws {
        let child = MockDirectory(path: "/Users/Home/Projects")
        let home = MockDirectory(path: "/Users/Home", subdirectories: [child])
        let sut = makeSUT(homeDirectory: home)

        let result = try sut.directory(at: child.path)

        #expect(result.path == child.path)
    }

    @Test
    func `Home path resolves to the home directory`() throws {
        let home = MockDirectory(path: "/Users/Home")
        let fallback = MockDirectory(path: "/fallback")
        let sut = makeSUT(homeDirectory: home, directoryToLoad: fallback)

        let result = try sut.directory(at: home.path)

        #expect(result.path == home.path)
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

// MARK: - Directory Creation
extension MockFileSystemTests {
    @Test
    func `Creating a directory under home adds the chain to the home tree`() throws {
        let home = MockDirectory(path: "/Users/Home")
        let sut = makeSUT(homeDirectory: home)

        try sut.createDirectory(at: "/Users/Home/Projects/App")

        #expect(try home.subdirectory(named: "Projects").containsSubdirectory(named: "App"))
    }

    @Test
    func `Directory created under home is returned at the requested path`() throws {
        let sut = makeSUT()
        let path = "/Users/Home/Projects/App"

        let created = try sut.createDirectory(at: path)

        #expect(created.path == path)
    }

    @Test
    func `Directory created outside home is returned at the requested path`() throws {
        let sut = makeSUT()
        let path = "/opt/tools/bin"

        let created = try sut.createDirectory(at: path)

        #expect(created.path == path)
    }

    @Test
    func `Directory created under home is found by path lookup`() throws {
        let sut = makeSUT()
        let path = "/Users/Home/Projects/App"
        let created = try sut.createDirectory(at: path)

        let found = try sut.directory(at: path)

        #expect(found.path == created.path)
    }

    @Test
    func `Directory created outside home is found by path lookup`() throws {
        let sut = makeSUT()
        let path = "/opt/tools/bin"
        let created = try sut.createDirectory(at: path)

        let found = try sut.directory(at: path)

        #expect(found.path == created.path)
    }

    @Test
    func `Creating an existing directory does not duplicate it`() throws {
        let home = MockDirectory(path: "/Users/Home")
        let sut = makeSUT(homeDirectory: home)
        try sut.createDirectory(at: "/Users/Home/Projects")

        try sut.createDirectory(at: "/Users/Home/Projects")

        #expect(home.subdirectories.count == 1)
    }

    @Test
    func `Mapped directory is returned instead of being created`() throws {
        let path = "/Users/Home/Projects"
        let mapped = MockDirectory(path: "/mapped")
        let sut = makeSUT(directoryMap: [path: mapped])

        let created = try sut.createDirectory(at: path)

        #expect(created.path == mapped.path)
    }

    @Test
    func `Fallback directory is returned instead of being created`() throws {
        let fallback = MockDirectory(path: "/fallback")
        let sut = makeSUT(directoryToLoad: fallback)

        let created = try sut.createDirectory(at: "/Users/Home/Projects")

        #expect(created.path == fallback.path)
    }

    @Test
    func `Sibling path sharing the home prefix is not created under home`() throws {
        let home = MockDirectory(path: "/Users/Home")
        let sut = makeSUT(homeDirectory: home)

        try sut.createDirectory(at: "/Users/HomeOther/App")

        #expect(home.subdirectories.isEmpty)
    }

    @Test
    func `Created paths are captured`() throws {
        let sut = makeSUT()
        let path = "/Users/Home/Projects"

        try sut.createDirectory(at: path)

        #expect(sut.capturedPaths == [path])
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
    func `Error flag causes directory creation to throw`() {
        let sut = makeSUT(throwError: true)

        #expect(throws: (any Error).self) {
            try sut.createDirectory(at: "/Users/Home/Projects")
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
