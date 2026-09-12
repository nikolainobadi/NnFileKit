//
//  DefaultDirectoryTests.swift
//  NnFileKitTests
//
//  Created by Nikolai Nobadi on 2/12/26.
//

import Testing
import Foundation
@testable import NnFileKit

struct DefaultDirectoryTests {
    @Test
    func `Trailing slash is added to paths that lack one`() throws {
        let sut = try makeSUT(path: "/tmp/test")

        #expect(sut.path == "/tmp/test/")
    }

    @Test
    func `Existing trailing slash in path is preserved`() throws {
        let sut = try makeSUT(path: "/tmp/test/")

        #expect(sut.path == "/tmp/test/")
    }

    @Test
    func `Name is derived from last path component`() throws {
        let sut = try makeSUT(path: "/tmp/myFolder")

        #expect(sut.name == "myFolder")
    }

    @Test
    func `File extension is extracted when present in path`() throws {
        let sut = try makeSUT(path: "/tmp/archive.zip")

        #expect(sut.extension == "zip")
    }

    @Test
    func `No extension is reported for extensionless paths`() throws {
        let sut = try makeSUT(path: "/tmp/folder")

        #expect(sut.extension == nil)
    }
}

// MARK: - File Operations
extension DefaultDirectoryTests {
    @Test
    func `New file is created with specified contents`() throws {
        let sut = try makeSUT()

        try sut.createFile(named: "test.txt", contents: "hello")
        let contents = try sut.readFile(named: "test.txt")

        #expect(contents == "hello")
    }

    @Test
    func `Reading nonexistent file throws an error`() throws {
        let sut = try makeSUT()

        #expect(throws: FileSystemError.self) {
            try sut.readFile(named: "nonexistent.txt")
        }
    }

    @Test
    func `Existing file is detected as present`() throws {
        let sut = try makeSUT()
        try sut.createFile(named: "test.txt", contents: "")

        #expect(sut.containsFile(named: "test.txt"))
    }

    @Test
    func `Missing file is detected as absent`() throws {
        let sut = try makeSUT()

        #expect(!sut.containsFile(named: "nonexistent.txt"))
    }

    @Test
    func `Deleted file is no longer present`() throws {
        let sut = try makeSUT()
        try sut.createFile(named: "test.txt", contents: "")

        try sut.deleteFile(named: "test.txt")

        #expect(!sut.containsFile(named: "test.txt"))
    }

    @Test
    func `Subdirectory is not detected as a file`() throws {
        let sut = try makeSUT()
        _ = try sut.createSubdirectory(named: "child")

        #expect(!sut.containsFile(named: "child"))
    }
}

// MARK: - Subdirectories and Lifecycle
extension DefaultDirectoryTests {
    @Test
    func `New subdirectory is created at expected location`() throws {
        let sut = try makeSUT()
        let expectedPath = sut.path.appendingPathComponent("child")

        _ = try sut.createSubdirectory(named: "child")

        #expect(FileManager.default.fileExists(atPath: expectedPath))
    }

    @Test
    func `Existing subdirectory is returned by name`() throws {
        let sut = try makeSUT()
        _ = try sut.createSubdirectory(named: "child")

        let sub = try sut.subdirectory(named: "child")

        #expect(sub.name == "child")
    }

    @Test
    func `Requesting nonexistent subdirectory throws an error`() throws {
        let sut = try makeSUT()

        #expect(throws: FileSystemError.self) {
            try sut.subdirectory(named: "nonexistent")
        }
    }

    @Test
    func `Creating a subdirectory that already exists throws an error`() throws {
        let sut = try makeSUT()
        _ = try sut.createSubdirectory(named: "child")

        #expect(throws: (any Error).self) {
            try sut.createSubdirectory(named: "child")
        }
    }

    @Test
    func `Subdirectory is created when it does not already exist`() throws {
        let sut = try makeSUT()
        let expectedPath = sut.path.appendingPathComponent("child")

        _ = try sut.createSubfolderIfNeeded(named: "child")

        #expect(FileManager.default.fileExists(atPath: expectedPath))
    }

    @Test
    func `Existing subdirectory is returned without duplication`() throws {
        let sut = try makeSUT()
        let original = try sut.createSubdirectory(named: "child")

        let returned = try sut.createSubfolderIfNeeded(named: "child")

        #expect(returned.path == original.path)
    }

    @Test
    func `All subdirectories are listed`() throws {
        let sut = try makeSUT()
        _ = try sut.createSubdirectory(named: "alpha")
        _ = try sut.createSubdirectory(named: "beta")

        let names = sut.subdirectories.map(\.name).sorted()

        #expect(names == ["alpha", "beta"])
    }

    @Test
    func `Subdirectory presence is correctly detected`() throws {
        let sut = try makeSUT()
        _ = try sut.createSubdirectory(named: "child")

        #expect(sut.containsSubdirectory(named: "child"))
    }

    @Test
    func `Missing subdirectory absence is correctly detected`() throws {
        let sut = try makeSUT()

        #expect(!sut.containsSubdirectory(named: "nonexistent"))
    }

    @Test
    func `Directory is removed from filesystem on delete`() throws {
        let sut = try makeSUT()

        try sut.delete()

        #expect(!FileManager.default.fileExists(atPath: sut.path))
    }

    @Test
    func `Directory is moved to new parent location`() throws {
        let sut = try makeSUT()
        let parent = try makeSUT()
        let originalName = sut.name

        try sut.move(to: parent)

        let expectedPath = parent.path.appendingPathComponent(originalName)
        #expect(FileManager.default.fileExists(atPath: expectedPath))
    }
}

// MARK: - Name Validation
extension DefaultDirectoryTests {
    @Test
    func `Subdirectory lookup rejects a name containing a slash`() throws {
        let sut = try makeSUT()
        let name = "parent/child"
        try sut.createSubdirectory(atRelativePath: name)

        let error = try #require(throws: FileSystemError.self) {
            try sut.subdirectory(named: name)
        }

        #expect(error.isInvalidName(name))
    }

    @Test
    func `Creating a subdirectory rejects a name containing a slash`() throws {
        let sut = try makeSUT()
        let name = "parent/child"
        _ = try sut.createSubdirectory(named: "parent")

        let error = try #require(throws: FileSystemError.self) {
            try sut.createSubdirectory(named: name)
        }

        #expect(error.isInvalidName(name))
    }

    @Test
    func `Ensuring a subfolder exists rejects a name containing a slash`() throws {
        let sut = try makeSUT()
        let name = "parent/child"

        let error = try #require(throws: FileSystemError.self) {
            try sut.createSubfolderIfNeeded(named: name)
        }

        #expect(error.isInvalidName(name))
    }

    @Test
    func `Subdirectory presence is false for a name containing a slash`() throws {
        let sut = try makeSUT()
        let name = "parent/child"
        try sut.createSubdirectory(atRelativePath: name)

        #expect(!sut.containsSubdirectory(named: name))
    }

    @Test
    func `File presence is false for a name containing a slash`() throws {
        let sut = try makeSUT()
        let parent = try sut.createSubdirectory(named: "parent")
        try parent.createFile(named: "note.txt", contents: "")

        #expect(!sut.containsFile(named: "parent/note.txt"))
    }

    @Test
    func `Creating a file rejects a name containing a slash`() throws {
        let sut = try makeSUT()
        let name = "parent/note.txt"
        _ = try sut.createSubdirectory(named: "parent")

        let error = try #require(throws: FileSystemError.self) {
            try sut.createFile(named: name, contents: "")
        }

        #expect(error.isInvalidName(name))
    }

    @Test
    func `Reading a file rejects a name containing a slash`() throws {
        let sut = try makeSUT()
        let name = "parent/note.txt"
        let parent = try sut.createSubdirectory(named: "parent")
        try parent.createFile(named: "note.txt", contents: "")

        let error = try #require(throws: FileSystemError.self) {
            try sut.readFile(named: name)
        }

        #expect(error.isInvalidName(name))
    }

    @Test
    func `Deleting a file rejects a name containing a slash`() throws {
        let sut = try makeSUT()
        let name = "parent/note.txt"
        let parent = try sut.createSubdirectory(named: "parent")
        try parent.createFile(named: "note.txt", contents: "")

        let error = try #require(throws: FileSystemError.self) {
            try sut.deleteFile(named: name)
        }

        #expect(error.isInvalidName(name))
    }

    @Test
    func `Copying a file rejects a name containing a slash`() throws {
        let sut = try makeSUT()
        let destination = try makeSUT()
        let name = "parent/note.txt"
        let parent = try sut.createSubdirectory(named: "parent")
        try parent.createFile(named: "note.txt", contents: "")

        let error = try #require(throws: FileSystemError.self) {
            try sut.copyFile(named: name, to: destination, overwrite: false)
        }

        #expect(error.isInvalidName(name))
    }

    @Test
    func `Comparing a file rejects a name containing a slash`() throws {
        let sut = try makeSUT()
        let other = try makeSUT()
        let name = "parent/note.txt"
        let parent = try sut.createSubdirectory(named: "parent")
        try parent.createFile(named: "note.txt", contents: "")

        let error = try #require(throws: FileSystemError.self) {
            try sut.fileContentsEqual(named: name, in: other)
        }

        #expect(error.isInvalidName(name))
    }
}

// MARK: - Relative Paths
extension DefaultDirectoryTests {
    @Test
    func `Creating a relative path creates every missing intermediate`() throws {
        let sut = try makeSUT()

        try sut.createSubdirectory(atRelativePath: "a/b/c")

        #expect(try sut.subdirectory(named: "a").containsSubdirectory(named: "b"))
    }

    @Test
    func `Creating a relative path returns the deepest directory`() throws {
        let sut = try makeSUT()
        let relativePath = "a/b/c"

        let created = try sut.createSubdirectory(atRelativePath: relativePath)

        #expect(created.path == sut.path.appendingPathComponent(relativePath) + "/")
    }

    @Test
    func `Creating an existing relative path returns it without throwing`() throws {
        let sut = try makeSUT()
        let first = try sut.createSubdirectory(atRelativePath: "a/b")

        let second = try sut.createSubdirectory(atRelativePath: "a/b")

        #expect(second.path == first.path)
    }

    @Test
    func `A directory created by relative path is found by relative path`() throws {
        let sut = try makeSUT()
        let created = try sut.createSubdirectory(atRelativePath: "a/b/c")

        let found = try sut.subdirectory(atRelativePath: "a/b/c")

        #expect(found.path == created.path)
    }

    @Test
    func `Relative path lookup throws when a component is missing`() throws {
        let sut = try makeSUT()
        _ = try sut.createSubdirectory(named: "a")

        #expect(throws: FileSystemError.self) {
            try sut.subdirectory(atRelativePath: "a/missing")
        }
    }

    @Test
    func `An empty relative path resolves to the directory itself`() throws {
        let sut = try makeSUT()

        let found = try sut.subdirectory(atRelativePath: "")

        #expect(found.path == sut.path)
    }

    @Test
    func `Creating an empty relative path returns the directory itself`() throws {
        let sut = try makeSUT()

        let created = try sut.createSubdirectory(atRelativePath: "")

        #expect(created.path == sut.path)
    }

    @Test
    func `Relative path lookup rejects a leading slash`() throws {
        let sut = try makeSUT()
        let path = "/a"
        _ = try sut.createSubdirectory(named: "a")

        let error = try #require(throws: FileSystemError.self) {
            try sut.subdirectory(atRelativePath: path)
        }

        #expect(error.isInvalidName(path))
    }

    @Test
    func `Creating a relative path rejects a leading slash`() throws {
        let sut = try makeSUT()
        let path = "/a/b"

        let error = try #require(throws: FileSystemError.self) {
            try sut.createSubdirectory(atRelativePath: path)
        }

        #expect(error.isInvalidName(path))
    }

    @Test
    func `Repeated separators in a relative path are collapsed`() throws {
        let sut = try makeSUT()

        let created = try sut.createSubdirectory(atRelativePath: "a//b")

        #expect(created.path == sut.path.appendingPathComponent("a/b") + "/")
    }
}

// MARK: - File Search
extension DefaultDirectoryTests {
    @Test
    func `Files are filtered by extension`() throws {
        let sut = try makeSUT()
        try sut.createFile(named: "a.txt", contents: "")
        try sut.createFile(named: "b.swift", contents: "")

        let found = try sut.findFiles(withExtension: "txt", recursive: false)

        #expect(found == [sut.path.appendingPathComponent("a.txt")])
    }

    @Test
    func `All files returned when no extension filter applied`() throws {
        let sut = try makeSUT()
        try sut.createFile(named: "a.txt", contents: "")
        try sut.createFile(named: "b.swift", contents: "")

        let found = try sut.findFiles(withExtension: nil, recursive: false)

        #expect(found.count == 2)
    }

    @Test
    func `Recursive search includes files in subdirectories`() throws {
        let sut = try makeSUT()
        try sut.createFile(named: "top.txt", contents: "")
        let sub = try sut.createSubdirectory(named: "sub")
        try sub.createFile(named: "nested.txt", contents: "")

        let found = try sut.findFiles(withExtension: "txt", recursive: true)

        #expect(found.count == 2)
    }

    @Test
    func `Non-recursive search excludes files in subdirectories`() throws {
        let sut = try makeSUT()
        try sut.createFile(named: "top.txt", contents: "")
        let sub = try sut.createSubdirectory(named: "sub")
        try sub.createFile(named: "nested.txt", contents: "")

        let found = try sut.findFiles(withExtension: "txt", recursive: false)

        #expect(found.count == 1)
    }
}

// MARK: - Copy
extension DefaultDirectoryTests {
    @Test
    func `Single file is copied into another directory`() throws {
        let sut = try makeSUT()
        let destination = try makeSUT()
        try sut.createFile(named: "note.txt", contents: "hello")

        try sut.copyFile(named: "note.txt", to: destination, overwrite: false)

        #expect(try destination.readFile(named: "note.txt") == "hello")
    }

    @Test
    func `Copied tree preserves its nested structure`() throws {
        let sut = try makeSUT()
        let destination = try makeSUT()
        let sub = try sut.createSubdirectory(named: "sub")
        try sub.createFile(named: "nested.txt", contents: "deep")

        let copy = try sut.copy(to: destination, overwrite: false)

        let nestedPath = copy.path.appendingPathComponent("sub/nested.txt")
        #expect(FileManager.default.fileExists(atPath: nestedPath))
    }

    @Test
    func `Copied file keeps bytes that are not valid UTF-8`() throws {
        let sut = try makeSUT()
        let destination = try makeSUT()
        let bytes = Data([0xFF, 0xFE, 0x00, 0x80, 0xC0, 0x01])
        try bytes.write(to: URL(fileURLWithPath: sut.path.appendingPathComponent("image.bin")))

        let copy = try sut.copy(to: destination, overwrite: false)

        let copiedBytes = try Data(contentsOf: URL(fileURLWithPath: copy.path.appendingPathComponent("image.bin")))
        #expect(copiedBytes == bytes)
    }

    @Test
    func `Copy returns the new directory rather than the source`() throws {
        let sut = try makeSUT()
        let destination = try makeSUT()

        let copy = try sut.copy(to: destination, overwrite: false)

        #expect(copy.path == destination.path.appendingPathComponent(sut.name) + "/")
    }

    @Test
    func `Copying a file returns its destination path`() throws {
        let sut = try makeSUT()
        let destination = try makeSUT()
        try sut.createFile(named: "note.txt", contents: "")

        let returnedPath = try sut.copyFile(named: "note.txt", to: destination, overwrite: false)

        #expect(returnedPath == destination.path.appendingPathComponent("note.txt"))
    }
}

// MARK: - Copy Overwrite
extension DefaultDirectoryTests {
    @Test
    func `Copying without overwrite fails when the destination already exists`() throws {
        let sut = try makeSUT()
        let destination = try makeSUT()
        try sut.copy(to: destination, overwrite: false)

        #expect(throws: (any Error).self) {
            try sut.copy(to: destination, overwrite: false)
        }
    }

    @Test
    func `Copying with overwrite replaces an existing destination`() throws {
        let sut = try makeSUT()
        let destination = try makeSUT()
        let copy = try sut.copy(to: destination, overwrite: false)
        try copy.createFile(named: "stale.txt", contents: "")

        try sut.copy(to: destination, overwrite: true)

        #expect(!FileManager.default.fileExists(atPath: copy.path.appendingPathComponent("stale.txt")))
    }

    @Test
    func `Copying with overwrite succeeds when the destination does not exist`() throws {
        let sut = try makeSUT()
        let destination = try makeSUT()

        let copy = try sut.copy(to: destination, overwrite: true)

        #expect(FileManager.default.fileExists(atPath: copy.path))
    }

    @Test
    func `Copying a file without overwrite fails when the name is taken`() throws {
        let sut = try makeSUT()
        let destination = try makeSUT()
        try sut.createFile(named: "note.txt", contents: "source")
        try destination.createFile(named: "note.txt", contents: "existing")

        #expect(throws: (any Error).self) {
            try sut.copyFile(named: "note.txt", to: destination, overwrite: false)
        }
    }

    @Test
    func `Copying a file with overwrite replaces the existing file`() throws {
        let sut = try makeSUT()
        let destination = try makeSUT()
        try sut.createFile(named: "note.txt", contents: "source")
        try destination.createFile(named: "note.txt", contents: "existing")

        try sut.copyFile(named: "note.txt", to: destination, overwrite: true)

        #expect(try destination.readFile(named: "note.txt") == "source")
    }
}

// MARK: - Copy Errors
extension DefaultDirectoryTests {
    @Test
    func `Copying a file that is not present fails`() throws {
        let sut = try makeSUT()
        let destination = try makeSUT()

        #expect(throws: (any Error).self) {
            try sut.copyFile(named: "missing.txt", to: destination, overwrite: false)
        }
    }

    @Test
    func `Copying into a destination that does not exist fails`() throws {
        let sut = try makeSUT()
        let destination = try makeSUT(path: NSTemporaryDirectory().appendingPathComponent(UUID().uuidString))

        #expect(throws: (any Error).self) {
            try sut.copy(to: destination, overwrite: false)
        }
    }
}

// MARK: - File Comparison
extension DefaultDirectoryTests {
    @Test
    func `Files with identical contents compare as equal`() throws {
        let sut = try makeSUT()
        let other = try makeSUT()
        try sut.createFile(named: "note.txt", contents: "same")
        try other.createFile(named: "note.txt", contents: "same")

        #expect(try sut.fileContentsEqual(named: "note.txt", in: other))
    }

    @Test
    func `Files with different contents compare as unequal`() throws {
        let sut = try makeSUT()
        let other = try makeSUT()
        try sut.createFile(named: "note.txt", contents: "original")
        try other.createFile(named: "note.txt", contents: "changed")

        #expect(!(try sut.fileContentsEqual(named: "note.txt", in: other)))
    }

    @Test
    func `Binary files with identical bytes compare as equal`() throws {
        let sut = try makeSUT()
        let other = try makeSUT()
        let bytes = Data([0xFF, 0xFE, 0x00, 0x80, 0xC0, 0x01])
        try bytes.write(to: URL(fileURLWithPath: sut.path.appendingPathComponent("image.bin")))
        try bytes.write(to: URL(fileURLWithPath: other.path.appendingPathComponent("image.bin")))

        #expect(try sut.fileContentsEqual(named: "image.bin", in: other))
    }

    @Test
    func `A file missing from the other directory compares as unequal`() throws {
        let sut = try makeSUT()
        let other = try makeSUT()
        try sut.createFile(named: "note.txt", contents: "")

        #expect(!(try sut.fileContentsEqual(named: "note.txt", in: other)))
    }

    @Test
    func `A folder with the same name in the other directory compares as unequal`() throws {
        let sut = try makeSUT()
        let other = try makeSUT()
        try sut.createFile(named: "note.txt", contents: "")
        _ = try other.createSubdirectory(named: "note.txt")

        #expect(!(try sut.fileContentsEqual(named: "note.txt", in: other)))
    }

    @Test
    func `Comparing a file this directory does not contain throws an error`() throws {
        let sut = try makeSUT()
        let other = try makeSUT()
        try other.createFile(named: "note.txt", contents: "")

        #expect(throws: FileSystemError.self) {
            try sut.fileContentsEqual(named: "note.txt", in: other)
        }
    }

    @Test
    func `Comparing a folder rather than a file throws an error`() throws {
        let sut = try makeSUT()
        let other = try makeSUT()
        _ = try sut.createSubdirectory(named: "folder")
        _ = try other.createSubdirectory(named: "folder")

        #expect(throws: FileSystemError.self) {
            try sut.fileContentsEqual(named: "folder", in: other)
        }
    }
}

// MARK: - SUT
private extension DefaultDirectoryTests {
    func makeSUT(path: String? = nil) throws -> DefaultDirectory {
        if let path {
            return DefaultDirectory(path: path)
        }
        let tempPath = NSTemporaryDirectory().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(atPath: tempPath, withIntermediateDirectories: true)
        return DefaultDirectory(path: tempPath)
    }
}
