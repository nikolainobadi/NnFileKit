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
    @Test("Trailing slash is added to paths that lack one")
    func trailingSlashAdded() throws {
        let sut = try makeSUT(path: "/tmp/test")

        #expect(sut.path == "/tmp/test/")
    }

    @Test("Existing trailing slash in path is preserved")
    func trailingSlashPreserved() throws {
        let sut = try makeSUT(path: "/tmp/test/")

        #expect(sut.path == "/tmp/test/")
    }

    @Test("Name is derived from last path component")
    func nameDerived() throws {
        let sut = try makeSUT(path: "/tmp/myFolder")

        #expect(sut.name == "myFolder")
    }

    @Test("File extension is extracted when present in path")
    func extensionExtracted() throws {
        let sut = try makeSUT(path: "/tmp/archive.zip")

        #expect(sut.extension == "zip")
    }

    @Test("No extension is reported for extensionless paths")
    func noExtension() throws {
        let sut = try makeSUT(path: "/tmp/folder")

        #expect(sut.extension == nil)
    }
}


extension DefaultDirectoryTests {
    @Test("New file is created with specified contents")
    func createFile() throws {
        let sut = try makeSUT()

        try sut.createFile(named: "test.txt", contents: "hello")
        let contents = try sut.readFile(named: "test.txt")

        #expect(contents == "hello")
    }

    @Test("Reading nonexistent file throws an error")
    func readNonexistentFile() throws {
        let sut = try makeSUT()

        #expect(throws: FileSystemError.self) {
            try sut.readFile(named: "nonexistent.txt")
        }
    }

    @Test("Existing file is detected as present")
    func containsExistingFile() throws {
        let sut = try makeSUT()
        try sut.createFile(named: "test.txt", contents: "")

        #expect(sut.containsFile(named: "test.txt"))
    }

    @Test("Missing file is detected as absent")
    func missingFileAbsent() throws {
        let sut = try makeSUT()

        #expect(!sut.containsFile(named: "nonexistent.txt"))
    }

    @Test("Deleted file is no longer present")
    func deleteFile() throws {
        let sut = try makeSUT()
        try sut.createFile(named: "test.txt", contents: "")

        try sut.deleteFile(named: "test.txt")

        #expect(!sut.containsFile(named: "test.txt"))
    }

    @Test("Subdirectory is not detected as a file")
    func subdirectoryNotDetectedAsFile() throws {
        let sut = try makeSUT()
        _ = try sut.createSubdirectory(named: "child")

        #expect(!sut.containsFile(named: "child"))
    }
}


extension DefaultDirectoryTests {
    @Test("New subdirectory is created at expected location")
    func createSubdirectory() throws {
        let sut = try makeSUT()

        let sub = try sut.createSubdirectory(named: "child")

        #expect(sub.name == "child")
    }

    @Test("Existing subdirectory is returned by name")
    func getExistingSubdirectory() throws {
        let sut = try makeSUT()
        _ = try sut.createSubdirectory(named: "child")

        let sub = try sut.subdirectory(named: "child")

        #expect(sub.name == "child")
    }

    @Test("Requesting nonexistent subdirectory throws an error")
    func getNonexistentSubdirectory() throws {
        let sut = try makeSUT()

        #expect(throws: FileSystemError.self) {
            try sut.subdirectory(named: "nonexistent")
        }
    }

    @Test("Subdirectory is created when it does not already exist")
    func createSubfolderIfNeededCreates() throws {
        let sut = try makeSUT()

        let sub = try sut.createSubfolderIfNeeded(named: "child")

        #expect(sub.name == "child")
    }

    @Test("Existing subdirectory is returned without duplication")
    func createSubfolderIfNeededReturnsExisting() throws {
        let sut = try makeSUT()
        let original = try sut.createSubdirectory(named: "child")

        let returned = try sut.createSubfolderIfNeeded(named: "child")

        #expect(returned.path == original.path)
    }

    @Test("All subdirectories are listed")
    func listSubdirectories() throws {
        let sut = try makeSUT()
        _ = try sut.createSubdirectory(named: "alpha")
        _ = try sut.createSubdirectory(named: "beta")

        let names = sut.subdirectories.map(\.name).sorted()

        #expect(names == ["alpha", "beta"])
    }

    @Test("Subdirectory presence is correctly detected")
    func containsSubdirectory() throws {
        let sut = try makeSUT()
        _ = try sut.createSubdirectory(named: "child")

        #expect(sut.containsSubdirectory(named: "child"))
    }

    @Test("Missing subdirectory absence is correctly detected")
    func missingSubdirectoryAbsent() throws {
        let sut = try makeSUT()

        #expect(!sut.containsSubdirectory(named: "nonexistent"))
    }

    @Test("Directory is removed from filesystem on delete")
    func deleteDirectory() throws {
        let sut = try makeSUT()

        try sut.delete()

        #expect(!FileManager.default.fileExists(atPath: sut.path))
    }

    @Test("Directory is moved to new parent location")
    func moveDirectory() throws {
        let sut = try makeSUT()
        let parent = try makeSUT()
        let originalName = sut.name

        try sut.move(to: parent)

        let expectedPath = parent.path.appendingPathComponent(originalName)
        #expect(FileManager.default.fileExists(atPath: expectedPath))
    }
}


extension DefaultDirectoryTests {
    @Test("Files are filtered by extension")
    func findFilesByExtension() throws {
        let sut = try makeSUT()
        try sut.createFile(named: "a.txt", contents: "")
        try sut.createFile(named: "b.swift", contents: "")

        let found = try sut.findFiles(withExtension: "txt", recursive: false)

        #expect(found.count == 1)
    }

    @Test("All files returned when no extension filter applied")
    func findAllFiles() throws {
        let sut = try makeSUT()
        try sut.createFile(named: "a.txt", contents: "")
        try sut.createFile(named: "b.swift", contents: "")

        let found = try sut.findFiles(withExtension: nil, recursive: false)

        #expect(found.count == 2)
    }

    @Test("Recursive search includes files in subdirectories")
    func findFilesRecursively() throws {
        let sut = try makeSUT()
        try sut.createFile(named: "top.txt", contents: "")
        let sub = try sut.createSubdirectory(named: "sub")
        try sub.createFile(named: "nested.txt", contents: "")

        let found = try sut.findFiles(withExtension: "txt", recursive: true)

        #expect(found.count == 2)
    }

    @Test("Non-recursive search excludes files in subdirectories")
    func findFilesNonRecursively() throws {
        let sut = try makeSUT()
        try sut.createFile(named: "top.txt", contents: "")
        let sub = try sut.createSubdirectory(named: "sub")
        try sub.createFile(named: "nested.txt", contents: "")

        let found = try sut.findFiles(withExtension: "txt", recursive: false)

        #expect(found.count == 1)
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
