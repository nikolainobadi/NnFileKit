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
    @Test(arguments: ThrowingOperation.allCases)
    func `Error flag makes every throwing operation fail`(operation: ThrowingOperation) {
        let sut = makeSUT(fileContentsToRead: ["/exists.txt": "data"], throwError: true)

        #expect(throws: (any Error).self) {
            try perform(operation, on: sut)
        }
    }
}

// MARK: - Error Flag Helpers
extension MockFileSystemTests {
    enum ThrowingOperation: CaseIterable {
        case directory, createDirectory, desktopDirectory, readFile, writeFile, moveToTrash
    }

    func perform(_ operation: ThrowingOperation, on fileSystem: MockFileSystem) throws {
        switch operation {
        case .directory:
            _ = try fileSystem.directory(at: "/any")
        case .createDirectory:
            try fileSystem.createDirectory(at: "/Users/Home/Projects")
        case .desktopDirectory:
            _ = try fileSystem.desktopDirectory()
        case .readFile:
            _ = try fileSystem.readFile(at: "/exists.txt")
        case .writeFile:
            try fileSystem.writeFile(at: "/file.txt", contents: "data")
        case .moveToTrash:
            try fileSystem.moveToTrash(at: "/target")
        }
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
