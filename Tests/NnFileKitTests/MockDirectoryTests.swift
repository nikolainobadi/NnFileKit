//
//  MockDirectoryTests.swift
//  NnFileKitTests
//
//  Created by Nikolai Nobadi on 2/12/26.
//

import Testing
import NnFileKit
@testable import NnFileTesting

struct MockDirectoryTests {
    @Test
    func `Path and name are derived from initialization path`() {
        let sut = makeSUT(path: "/Users/Home/Projects")

        #expect(sut.path == "/Users/Home/Projects")
        #expect(sut.name == "Projects")
    }
}

// MARK: - File Operations
extension MockDirectoryTests {
    @Test
    func `Configured file is detected as present`() {
        let sut = makeSUT(containedFiles: ["readme.md"])

        #expect(sut.containsFile(named: "readme.md"))
    }

    @Test
    func `Unconfigured file is detected as absent`() {
        let sut = makeSUT()

        #expect(!sut.containsFile(named: "missing.txt"))
    }

    @Test
    func `Created file is added to contained files`() throws {
        let sut = makeSUT()

        try sut.createFile(named: "new.txt", contents: "hello")

        #expect(sut.containsFile(named: "new.txt"))
    }

    @Test
    func `Created file contents are readable`() throws {
        let sut = makeSUT()

        try sut.createFile(named: "new.txt", contents: "hello")
        let contents = try sut.readFile(named: "new.txt")

        #expect(contents == "hello")
    }

    @Test
    func `Created file returns full path`() throws {
        let sut = makeSUT(path: "/tmp/test")

        let path = try sut.createFile(named: "file.txt", contents: "")

        #expect(path == "/tmp/test/file.txt")
    }

    @Test
    func `Reading unconfigured file throws an error`() {
        let sut = makeSUT()

        #expect(throws: (any Error).self) {
            try sut.readFile(named: "nonexistent.txt")
        }
    }

    @Test
    func `Deleted file is removed from contained files`() throws {
        let sut = makeSUT(containedFiles: ["target.txt"])

        try sut.deleteFile(named: "target.txt")

        #expect(!sut.containsFile(named: "target.txt"))
    }
}

// MARK: - Subdirectories
extension MockDirectoryTests {
    @Test
    func `Configured subdirectory is returned by name`() throws {
        let child = MockDirectory(path: "/parent/child")
        let sut = makeSUT(subdirectories: [child])

        let result = try sut.subdirectory(named: "child")

        #expect(result.path == "/parent/child")
    }

    @Test
    func `Unconfigured subdirectory throws an error`() {
        let sut = makeSUT()

        #expect(throws: (any Error).self) {
            try sut.subdirectory(named: "nonexistent")
        }
    }

    @Test
    func `New subdirectory is created and added`() throws {
        let sut = makeSUT(path: "/parent")

        let sub = try sut.createSubdirectory(named: "child")

        #expect(sub.name == "child")
        #expect(sut.subdirectories.contains(where: { $0.name == "child" }))
    }

    @Test
    func `Creating a subdirectory that already exists throws an error`() throws {
        let sut = makeSUT()
        _ = try sut.createSubdirectory(named: "child")

        #expect(throws: (any Error).self) {
            try sut.createSubdirectory(named: "child")
        }
    }

    @Test
    func `Existing subfolder is returned without duplication`() throws {
        let child = MockDirectory(path: "/parent/child")
        let sut = makeSUT(subdirectories: [child])

        let result = try sut.createSubfolderIfNeeded(named: "child")

        #expect(result.path == child.path)
        #expect(sut.subdirectories.count == 1)
    }

    @Test
    func `Missing subfolder is created and added`() throws {
        let sut = makeSUT(path: "/parent")

        _ = try sut.createSubfolderIfNeeded(named: "new")

        #expect(sut.subdirectories.count == 1)
    }
}

// MARK: - Name Validation
extension MockDirectoryTests {
    @Test
    func `Subdirectory lookup rejects a name containing a slash`() throws {
        let sut = makeSUT()
        let name = "parent/child"
        try sut.createSubdirectory(atRelativePath: name)

        let error = try #require(throws: FileSystemError.self) {
            try sut.subdirectory(named: name)
        }

        #expect(error.isInvalidName(name))
    }

    @Test
    func `Creating a subdirectory rejects a name containing a slash`() throws {
        let sut = makeSUT()
        let name = "parent/child"
        _ = try sut.createSubdirectory(named: "parent")

        let error = try #require(throws: FileSystemError.self) {
            try sut.createSubdirectory(named: name)
        }

        #expect(error.isInvalidName(name))
    }

    @Test
    func `Ensuring a subfolder exists rejects a name containing a slash`() throws {
        let sut = makeSUT()
        let name = "parent/child"

        let error = try #require(throws: FileSystemError.self) {
            try sut.createSubfolderIfNeeded(named: name)
        }

        #expect(error.isInvalidName(name))
    }

    @Test
    func `File presence is false for a name containing a slash`() {
        let name = "parent/note.txt"
        let sut = makeSUT(containedFiles: [name])

        #expect(!sut.containsFile(named: name))
    }

    @Test
    func `Creating a file rejects a name containing a slash`() throws {
        let sut = makeSUT()
        let name = "parent/note.txt"

        let error = try #require(throws: FileSystemError.self) {
            try sut.createFile(named: name, contents: "")
        }

        #expect(error.isInvalidName(name))
    }

    @Test
    func `Reading a file rejects a name containing a slash`() throws {
        let name = "parent/note.txt"
        let sut = makeSUT(containedFiles: [name])

        let error = try #require(throws: FileSystemError.self) {
            try sut.readFile(named: name)
        }

        #expect(error.isInvalidName(name))
    }

    @Test
    func `Deleting a file rejects a name containing a slash`() throws {
        let name = "parent/note.txt"
        let sut = makeSUT(containedFiles: [name])

        let error = try #require(throws: FileSystemError.self) {
            try sut.deleteFile(named: name)
        }

        #expect(error.isInvalidName(name))
    }

    @Test
    func `Copying a file rejects a name containing a slash`() throws {
        let name = "parent/note.txt"
        let sut = makeSUT(containedFiles: [name])
        let destination = MockDirectory(path: "/other")

        let error = try #require(throws: FileSystemError.self) {
            try sut.copyFile(named: name, to: destination, overwrite: false)
        }

        #expect(error.isInvalidName(name))
    }

    @Test
    func `Comparing a file rejects a name containing a slash`() throws {
        let name = "parent/note.txt"
        let sut = makeSUT(containedFiles: [name])
        let other = MockDirectory(path: "/other", containedFiles: [name])

        let error = try #require(throws: FileSystemError.self) {
            try sut.fileContentsEqual(named: name, in: other)
        }

        #expect(error.isInvalidName(name))
    }
}

// MARK: - Relative Paths
extension MockDirectoryTests {
    @Test
    func `Creating a relative path creates every missing intermediate`() throws {
        let sut = makeSUT()

        try sut.createSubdirectory(atRelativePath: "a/b/c")

        #expect(try sut.subdirectory(named: "a").containsSubdirectory(named: "b"))
    }

    @Test
    func `Creating a relative path returns the deepest directory`() throws {
        let sut = makeSUT()
        let relativePath = "a/b/c"

        let created = try sut.createSubdirectory(atRelativePath: relativePath)

        #expect(created.path == sut.path.appendingPathComponent(relativePath))
    }

    @Test
    func `Creating an existing relative path returns it without throwing`() throws {
        let sut = makeSUT()
        let first = try sut.createSubdirectory(atRelativePath: "a/b")

        let second = try sut.createSubdirectory(atRelativePath: "a/b")

        #expect(second.path == first.path)
    }

    @Test
    func `A directory created by relative path is found by relative path`() throws {
        let sut = makeSUT()
        let created = try sut.createSubdirectory(atRelativePath: "a/b/c")

        let found = try sut.subdirectory(atRelativePath: "a/b/c")

        #expect(found.path == created.path)
    }

    @Test
    func `Intermediates created by relative path are each named by one component`() throws {
        let sut = makeSUT()

        try sut.createSubdirectory(atRelativePath: "a/b")

        #expect(sut.subdirectories.map(\.name) == ["a"])
    }

    @Test
    func `Relative path lookup throws when a component is missing`() throws {
        let sut = makeSUT()
        _ = try sut.createSubdirectory(named: "a")

        #expect(throws: (any Error).self) {
            try sut.subdirectory(atRelativePath: "a/missing")
        }
    }

    @Test
    func `An empty relative path resolves to the directory itself`() throws {
        let sut = makeSUT()

        let found = try sut.subdirectory(atRelativePath: "")

        #expect(found.path == sut.path)
    }

    @Test
    func `Creating an empty relative path returns the directory itself`() throws {
        let sut = makeSUT()

        let created = try sut.createSubdirectory(atRelativePath: "")

        #expect(created.path == sut.path)
    }

    @Test
    func `Relative path lookup rejects a leading slash`() throws {
        let sut = makeSUT()
        let path = "/a"
        _ = try sut.createSubdirectory(named: "a")

        let error = try #require(throws: FileSystemError.self) {
            try sut.subdirectory(atRelativePath: path)
        }

        #expect(error.isInvalidName(path))
    }

    @Test
    func `Creating a relative path rejects a leading slash`() throws {
        let sut = makeSUT()
        let path = "/a/b"

        let error = try #require(throws: FileSystemError.self) {
            try sut.createSubdirectory(atRelativePath: path)
        }

        #expect(error.isInvalidName(path))
    }

    @Test
    func `Repeated separators in a relative path are collapsed`() throws {
        let sut = makeSUT()

        let created = try sut.createSubdirectory(atRelativePath: "a//b")

        #expect(created.path == sut.path.appendingPathComponent("a/b"))
    }
}

// MARK: - Recorded Calls
extension MockDirectoryTests {
    @Test
    func `Delete increments the recorded call count`() throws {
        let sut = makeSUT()

        try sut.delete()

        #expect(sut.deleteCallCount == 1)
    }

    @Test
    func `Move records parent path`() throws {
        let sut = makeSUT()
        let parent = MockDirectory(path: "/new/parent")

        try sut.move(to: parent)

        #expect(sut.movedToParents == ["/new/parent"])
    }
}

// MARK: - File Search
extension MockDirectoryTests {
    @Test
    func `Files are filtered by extension`() throws {
        let sut = makeSUT(path: "/dir", containedFiles: ["a.txt", "b.swift"])

        let found = try sut.findFiles(withExtension: "txt", recursive: false)

        #expect(found == [sut.path.appendingPathComponent("a.txt")])
    }

    @Test
    func `All files returned when no extension filter applied`() throws {
        let sut = makeSUT(path: "/dir", containedFiles: ["a.txt", "b.swift"])

        let found = try sut.findFiles(withExtension: nil as String?, recursive: false)

        #expect(found.count == 2)
    }

    @Test
    func `Recursive search includes subdirectory files`() throws {
        let child = MockDirectory(path: "/dir/sub", containedFiles: ["nested.txt"])
        let sut = makeSUT(path: "/dir", containedFiles: ["top.txt"], subdirectories: [child])

        let found = try sut.findFiles(withExtension: "txt", recursive: true)

        #expect(found.count == 2)
    }
}

// MARK: - File Comparison
extension MockDirectoryTests {
    @Test
    func `Files with identical contents compare as equal`() throws {
        let sut = makeSUT()
        let other = MockDirectory(path: "/other")
        try sut.createFile(named: "note.txt", contents: "same")
        try other.createFile(named: "note.txt", contents: "same")

        #expect(try sut.fileContentsEqual(named: "note.txt", in: other))
    }

    @Test
    func `Files with different contents compare as unequal`() throws {
        let sut = makeSUT()
        let other = MockDirectory(path: "/other")
        try sut.createFile(named: "note.txt", contents: "original")
        try other.createFile(named: "note.txt", contents: "changed")

        #expect(!(try sut.fileContentsEqual(named: "note.txt", in: other)))
    }

    @Test
    func `A file missing from the other directory compares as unequal`() throws {
        let sut = makeSUT()
        let other = MockDirectory(path: "/other")
        try sut.createFile(named: "note.txt", contents: "")

        #expect(!(try sut.fileContentsEqual(named: "note.txt", in: other)))
    }

    @Test
    func `A folder with the same name in the other directory compares as unequal`() throws {
        let sut = makeSUT()
        let other = MockDirectory(path: "/other")
        try sut.createFile(named: "note.txt", contents: "")
        _ = try other.createSubdirectory(named: "note.txt")

        #expect(!(try sut.fileContentsEqual(named: "note.txt", in: other)))
    }

    @Test
    func `Comparing a file this directory does not contain throws an error`() throws {
        let sut = makeSUT()
        let other = MockDirectory(path: "/other")
        try other.createFile(named: "note.txt", contents: "")

        #expect(throws: FileSystemError.self) {
            try sut.fileContentsEqual(named: "note.txt", in: other)
        }
    }
}

// MARK: - Error Flag
extension MockDirectoryTests {
    @Test(arguments: ThrowingOperation.allCases)
    func `Error flag makes every throwing operation fail`(operation: ThrowingOperation) {
        let sut = makeSUT(containedFiles: ["note.txt"], throwError: true)

        #expect(throws: (any Error).self) {
            try perform(operation, on: sut)
        }
    }
}

// MARK: - Copy
extension MockDirectoryTests {
    @Test
    func `Copy records the destination parent and the overwrite value`() throws {
        let sut = makeSUT()
        let parent = MockDirectory(path: "/new/parent")

        try sut.copy(to: parent, overwrite: true)

        #expect(sut.copiedToParents == [CopiedDirectory(parentPath: "/new/parent", overwrite: true)])
    }

    @Test
    func `Copy places the copy in the destination's subdirectories`() throws {
        let sut = makeSUT(path: "/source/skill", containedFiles: ["SKILL.md"])
        let parent = MockDirectory(path: "/new/parent")

        try sut.copy(to: parent, overwrite: false)

        #expect(parent.containsSubdirectory(named: "skill"))
        let placed = try parent.subdirectory(named: "skill")
        #expect(placed.containsFile(named: "SKILL.md"))
    }

    @Test
    func `Copying a file records its name, destination, and overwrite value`() throws {
        let sut = makeSUT(containedFiles: ["note.txt"])
        let destination = MockDirectory(path: "/other")

        try sut.copyFile(named: "note.txt", to: destination, overwrite: false)

        let expected = CopiedFile(name: "note.txt", destinationPath: "/other/note.txt", overwrite: false)
        #expect(sut.copiedFiles == [expected])
    }

    @Test
    func `Copying a file places its name and contents in the destination`() throws {
        let sut = makeSUT()
        let destination = MockDirectory(path: "/other")
        try sut.createFile(named: "note.txt", contents: "hello")

        try sut.copyFile(named: "note.txt", to: destination, overwrite: false)

        #expect(destination.containsFile(named: "note.txt"))
        #expect(try destination.readFile(named: "note.txt") == "hello")
    }
}

// MARK: - Error Flag Helpers
extension MockDirectoryTests {
    enum ThrowingOperation: CaseIterable {
        case subdirectory, createSubdirectory, createSubfolderIfNeeded, createFile, readFile, deleteFile, copyFile, fileContentsEqual, findFiles, copy, move, delete
    }

    func perform(_ operation: ThrowingOperation, on directory: MockDirectory) throws {
        let destination = MockDirectory(path: "/other")

        switch operation {
        case .subdirectory:
            _ = try directory.subdirectory(named: "child")
        case .createSubdirectory:
            _ = try directory.createSubdirectory(named: "child")
        case .createSubfolderIfNeeded:
            _ = try directory.createSubfolderIfNeeded(named: "child")
        case .createFile:
            try directory.createFile(named: "new.txt", contents: "")
        case .readFile:
            _ = try directory.readFile(named: "note.txt")
        case .deleteFile:
            try directory.deleteFile(named: "note.txt")
        case .copyFile:
            try directory.copyFile(named: "note.txt", to: destination, overwrite: false)
        case .fileContentsEqual:
            _ = try directory.fileContentsEqual(named: "note.txt", in: destination)
        case .findFiles:
            _ = try directory.findFiles(withExtension: nil, recursive: false)
        case .copy:
            try directory.copy(to: destination, overwrite: false)
        case .move:
            try directory.move(to: destination)
        case .delete:
            try directory.delete()
        }
    }
}

// MARK: - SUT
private extension MockDirectoryTests {
    func makeSUT(
        path: String = "/test/mock",
        containedFiles: Set<String> = [],
        subdirectories: [any Directory] = [],
        throwError: Bool = false
    ) -> MockDirectory {
        return MockDirectory(
            path: path,
            subdirectories: subdirectories,
            containedFiles: containedFiles,
            throwError: throwError
        )
    }
}
