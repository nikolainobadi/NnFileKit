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
    @Test("Path and name are derived from initialization path")
    func pathAndName() {
        let sut = makeSUT(path: "/Users/Home/Projects")

        #expect(sut.path == "/Users/Home/Projects")
        #expect(sut.name == "Projects")
    }

    @Test("Extension is extracted when provided")
    func extensionProvided() {
        let sut = makeSUT(ext: "txt")

        #expect(sut.extension == "txt")
    }

    @Test("Extension is nil when not provided")
    func extensionNil() {
        let sut = makeSUT()

        #expect(sut.extension == nil)
    }

    @Test("Delete and move state starts at baseline")
    func startingValues() {
        let sut = makeSUT()

        #expect(sut.didDelete == false)
        #expect(sut.movedToParent == nil)
    }
}


extension MockDirectoryTests {
    @Test("Configured file is detected as present")
    func containsConfiguredFile() {
        let sut = makeSUT(containedFiles: ["readme.md"])

        #expect(sut.containsFile(named: "readme.md"))
    }

    @Test("Unconfigured file is detected as absent")
    func doesNotContainUnconfiguredFile() {
        let sut = makeSUT()

        #expect(!sut.containsFile(named: "missing.txt"))
    }

    @Test("Created file is added to contained files")
    func createFileAddsToContainedFiles() throws {
        let sut = makeSUT()

        try sut.createFile(named: "new.txt", contents: "hello")

        #expect(sut.containsFile(named: "new.txt"))
    }

    @Test("Created file contents are readable")
    func createFileStoresContents() throws {
        let sut = makeSUT()

        try sut.createFile(named: "new.txt", contents: "hello")
        let contents = try sut.readFile(named: "new.txt")

        #expect(contents == "hello")
    }

    @Test("Created file returns full path")
    func createFileReturnsPath() throws {
        let sut = makeSUT(path: "/tmp/test")

        let path = try sut.createFile(named: "file.txt", contents: "")

        #expect(path == "/tmp/test/file.txt")
    }

    @Test("Reading unconfigured file throws an error")
    func readMissingFileThrows() {
        let sut = makeSUT()

        #expect(throws: (any Error).self) {
            try sut.readFile(named: "nonexistent.txt")
        }
    }

    @Test("Deleted file is removed from contained files")
    func deleteFileRemoves() throws {
        let sut = makeSUT(containedFiles: ["target.txt"])

        try sut.deleteFile(named: "target.txt")

        #expect(!sut.containsFile(named: "target.txt"))
    }
}


extension MockDirectoryTests {
    @Test("Configured subdirectory is returned by name")
    func subdirectoryReturnsMatch() throws {
        let child = MockDirectory(path: "/parent/child")
        let sut = makeSUT(subdirectories: [child])

        let result = try sut.subdirectory(named: "child")

        #expect(result.path == "/parent/child")
    }

    @Test("Unconfigured subdirectory throws an error")
    func subdirectoryThrowsWhenMissing() {
        let sut = makeSUT()

        #expect(throws: (any Error).self) {
            try sut.subdirectory(named: "nonexistent")
        }
    }

    @Test("New subdirectory is created and added")
    func createSubdirectoryAdds() throws {
        let sut = makeSUT(path: "/parent")

        let sub = try sut.createSubdirectory(named: "child")

        #expect(sub.name == "child")
        #expect(sut.subdirectories.contains(where: { $0.name == "child" }))
    }

    @Test("Existing subfolder is returned without duplication")
    func createSubfolderIfNeededReturnsExisting() throws {
        let child = MockDirectory(path: "/parent/child")
        let sut = makeSUT(subdirectories: [child])

        let result = try sut.createSubfolderIfNeeded(named: "child")

        #expect(result.path == child.path)
        #expect(sut.subdirectories.count == 1)
    }

    @Test("Missing subfolder is created and added")
    func createSubfolderIfNeededCreatesNew() throws {
        let sut = makeSUT(path: "/parent")

        _ = try sut.createSubfolderIfNeeded(named: "new")

        #expect(sut.subdirectories.count == 1)
    }

    @Test("All subdirectories are listed")
    func subdirectoriesListed() {
        let children: [any Directory] = [
            MockDirectory(path: "/parent/a"),
            MockDirectory(path: "/parent/b")
        ]
        let sut = makeSUT(subdirectories: children)

        #expect(sut.subdirectories.count == 2)
    }
}


extension MockDirectoryTests {
    @Test("Delete sets didDelete to true")
    func deleteRecordsCall() throws {
        let sut = makeSUT()

        try sut.delete()

        #expect(sut.didDelete)
    }

    @Test("Move records parent path")
    func moveRecordsParent() throws {
        let sut = makeSUT()
        let parent = MockDirectory(path: "/new/parent")

        try sut.move(to: parent)

        #expect(sut.movedToParent == "/new/parent")
    }
}


extension MockDirectoryTests {
    @Test("Files are filtered by extension")
    func findFilesByExtension() throws {
        let sut = makeSUT(path: "/dir", containedFiles: ["a.txt", "b.swift"])

        let found = try sut.findFiles(withExtension: "txt", recursive: false)

        #expect(found.count == 1)
    }

    @Test("All files returned when no extension filter applied")
    func findAllFiles() throws {
        let sut = makeSUT(path: "/dir", containedFiles: ["a.txt", "b.swift"])

        let found = try sut.findFiles(withExtension: nil as String?, recursive: false)

        #expect(found.count == 2)
    }

    @Test("Recursive search includes subdirectory files")
    func findFilesRecursively() throws {
        let child = MockDirectory(path: "/dir/sub", containedFiles: ["nested.txt"])
        let sut = makeSUT(path: "/dir", containedFiles: ["top.txt"], subdirectories: [child])

        let found = try sut.findFiles(withExtension: "txt", recursive: true)

        #expect(found.count == 2)
    }
}


extension MockDirectoryTests {
    @Test("Error flag causes subdirectory lookup to throw")
    func throwErrorOnSubdirectory() {
        let sut = makeSUT(throwError: true)

        #expect(throws: (any Error).self) {
            try sut.subdirectory(named: "any")
        }
    }

    @Test("Error flag causes file creation to throw")
    func throwErrorOnCreateFile() {
        let sut = makeSUT(throwError: true)

        #expect(throws: (any Error).self) {
            try sut.createFile(named: "file.txt", contents: "")
        }
    }

    @Test("Error flag causes file read to throw")
    func throwErrorOnReadFile() {
        let sut = makeSUT(containedFiles: ["exists.txt"], throwError: true)

        #expect(throws: (any Error).self) {
            try sut.readFile(named: "exists.txt")
        }
    }

    @Test("Error flag causes delete to throw")
    func throwErrorOnDelete() {
        let sut = makeSUT(throwError: true)

        #expect(throws: (any Error).self) {
            try sut.delete()
        }
    }

    @Test("Error flag causes move to throw")
    func throwErrorOnMove() {
        let sut = makeSUT(throwError: true)

        #expect(throws: (any Error).self) {
            try sut.move(to: MockDirectory(path: "/other"))
        }
    }

    @Test("Error flag causes find files to throw")
    func throwErrorOnFindFiles() {
        let sut = makeSUT(throwError: true)

        #expect(throws: (any Error).self) {
            try sut.findFiles(withExtension: nil as String?, recursive: false)
        }
    }
}


// MARK: - SUT
private extension MockDirectoryTests {
    func makeSUT(
        path: String = "/test/mock",
        containedFiles: Set<String> = [],
        subdirectories: [any Directory] = [],
        throwError: Bool = false,
        ext: String? = nil
    ) -> MockDirectory {
        return MockDirectory(
            path: path,
            subdirectories: subdirectories,
            containedFiles: containedFiles,
            throwError: throwError,
            ext: ext
        )
    }
}
