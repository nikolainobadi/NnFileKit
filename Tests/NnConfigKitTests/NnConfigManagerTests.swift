//
//  NnConfigManagerTests.swift
//
//
//  Created by Nikolai Nobadi on 6/19/24.
//

import Testing
import NnFileKit
import NnFileTesting
@testable import NnConfigKit

struct NnConfigManagerTests {
    @Test
    func `Config folder defaults to a project folder inside the shared config list`() {
        let projectName = "TestProject"
        let sut = makeSUT(projectName: projectName, configFolderPath: nil, configFileName: nil).sut

        #expect(sut.configFolderPath == "\(DEFAULT_CONFIGLIST_FOLDER_PATH)/\(projectName)")
    }

    @Test
    func `Custom config folder is used when provided`() {
        let folderPath = "/Users/Home/custom/TestProject"
        let sut = makeSUT(projectName: "TestProject", configFolderPath: folderPath, configFileName: nil).sut

        #expect(sut.configFolderPath == folderPath)
    }

    @Test
    func `Config file name defaults to the project name`() {
        let projectName = "TestProject"
        let sut = makeSUT(projectName: projectName, configFolderPath: nil, configFileName: nil).sut

        #expect(sut.configFileName == projectName)
    }

    @Test
    func `Custom config file name is used when provided`() {
        let fileName = "Settings"
        let sut = makeSUT(projectName: "TestProject", configFolderPath: nil, configFileName: fileName).sut

        #expect(sut.configFileName == fileName)
    }
}

// MARK: - Load
extension NnConfigManagerTests {
    @Test
    func `Saved config is loaded back`() throws {
        let config = TestConfig(firstSetting: 1, secondSetting: "saved")
        let sut = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil).sut
        try sut.saveConfig(config)

        let loaded = try sut.loadConfig()

        #expect(loaded == config)
    }

    @Test
    func `Loading throws when the config folder does not exist`() {
        let sut = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil).sut

        #expect(throws: (any Error).self) {
            try sut.loadConfig()
        }
    }

    @Test
    func `Loading throws when the config file does not exist`() throws {
        let (sut, fileSystem) = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil)
        try fileSystem.createDirectory(at: sut.configFolderPath)

        #expect(throws: (any Error).self) {
            try sut.loadConfig()
        }
    }

    @Test
    func `Loading throws when the config file is not valid JSON`() throws {
        let (sut, fileSystem) = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil)
        let folder = try fileSystem.createDirectory(at: sut.configFolderPath)
        try folder.createFile(named: "\(sut.configFileName).json", contents: "not json")

        #expect(throws: (any Error).self) {
            try sut.loadConfig()
        }
    }
}

// MARK: - Save
extension NnConfigManagerTests {
    @Test
    func `Saving again replaces the previous config`() throws {
        let updated = TestConfig(firstSetting: 2, secondSetting: "updated")
        let sut = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil).sut
        try sut.saveConfig(TestConfig(firstSetting: 1, secondSetting: "original"))

        try sut.saveConfig(updated)

        #expect(try sut.loadConfig() == updated)
    }

    @Test
    func `Saved file name gains a json extension`() throws {
        let (sut, fileSystem) = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: "Settings")

        try sut.saveConfig(TestConfig(firstSetting: 1, secondSetting: "saved"))

        let folder = try fileSystem.directory(at: sut.configFolderPath)
        #expect(folder.containsFile(named: "Settings.json"))
    }

    @Test
    func `File name already ending in json is not given a second extension`() throws {
        let (sut, fileSystem) = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: "Settings.json")

        try sut.saveConfig(TestConfig(firstSetting: 1, secondSetting: "saved"))

        let folder = try fileSystem.directory(at: sut.configFolderPath)
        #expect(folder.containsFile(named: "Settings.json"))
    }
}

// MARK: - Nested Files
extension NnConfigManagerTests {
    @Test
    func `Nested file is written at its nested path`() throws {
        let contents = "nested contents"
        let (sut, fileSystem) = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil)

        try sut.saveNestedConfigFile(contents: contents, nestedFilePath: "Nested/File")

        #expect(try fileSystem.readFile(at: sut.configFolderPath.appendingPathComponent("Nested/File")) == contents)
    }

    @Test
    func `Nested file without folders is written into the config folder`() throws {
        let contents = "nested contents"
        let (sut, fileSystem) = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil)

        try sut.saveNestedConfigFile(contents: contents, nestedFilePath: "File")

        #expect(try fileSystem.readFile(at: sut.configFolderPath.appendingPathComponent("File")) == contents)
    }

    @Test
    func `Leading slash in a nested path stays relative to the config folder`() throws {
        let contents = "nested contents"
        let (sut, fileSystem) = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil)

        try sut.saveNestedConfigFile(contents: contents, nestedFilePath: "/Nested/File")

        #expect(try fileSystem.readFile(at: sut.configFolderPath.appendingPathComponent("Nested/File")) == contents)
    }

    @Test
    func `Deleted nested file is removed`() throws {
        let (sut, fileSystem) = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil)
        try sut.saveNestedConfigFile(contents: "nested contents", nestedFilePath: "Nested/File")

        try sut.deletedNestedConfigFile(nestedFilePath: "Nested/File")

        let nestedFolder = try fileSystem.directory(at: sut.configFolderPath.appendingPathComponent("Nested"))
        #expect(!nestedFolder.containsFile(named: "File"))
    }

    @Test
    func `Deleting a nested file does nothing when the config folder does not exist`() {
        let sut = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil).sut

        #expect(throws: Never.self) {
            try sut.deletedNestedConfigFile(nestedFilePath: "Nested/File")
        }
    }

    @Test
    func `Deleting a nested file does nothing when its folder does not exist`() throws {
        let (sut, fileSystem) = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil)
        try fileSystem.createDirectory(at: sut.configFolderPath)

        #expect(throws: Never.self) {
            try sut.deletedNestedConfigFile(nestedFilePath: "Nested/File")
        }
    }
}

// MARK: - Nested File Text
extension NnConfigManagerTests {
    @Test
    func `Absent text is appended on a new line`() throws {
        let (sut, fileSystem) = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil)
        try sut.saveNestedConfigFile(contents: "first", nestedFilePath: "Nested/File")

        try sut.appendTextToNestedConfigFileIfNeeded(text: "second", nestedFilePath: "Nested/File", asNewLine: true)

        #expect(try fileSystem.readFile(at: sut.configFolderPath.appendingPathComponent("Nested/File")) == "first\nsecond")
    }

    @Test
    func `Absent text is appended without a line break when requested`() throws {
        let (sut, fileSystem) = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil)
        try sut.saveNestedConfigFile(contents: "first", nestedFilePath: "Nested/File")

        try sut.appendTextToNestedConfigFileIfNeeded(text: "second", nestedFilePath: "Nested/File", asNewLine: false)

        #expect(try fileSystem.readFile(at: sut.configFolderPath.appendingPathComponent("Nested/File")) == "firstsecond")
    }

    @Test
    func `Text already present is not appended again`() throws {
        let contents = "first\nsecond"
        let (sut, fileSystem) = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil)
        try sut.saveNestedConfigFile(contents: contents, nestedFilePath: "Nested/File")

        try sut.appendTextToNestedConfigFileIfNeeded(text: "second", nestedFilePath: "Nested/File", asNewLine: true)

        #expect(try fileSystem.readFile(at: sut.configFolderPath.appendingPathComponent("Nested/File")) == contents)
    }

    @Test
    func `Appending to a missing nested file creates it with the text`() throws {
        let text = "first"
        let (sut, fileSystem) = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil)

        try sut.appendTextToNestedConfigFileIfNeeded(text: text, nestedFilePath: "Nested/File", asNewLine: false)

        #expect(try fileSystem.readFile(at: sut.configFolderPath.appendingPathComponent("Nested/File")) == text)
    }

    @Test
    func `Matching line is removed from a nested file`() throws {
        let (sut, fileSystem) = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil)
        try sut.saveNestedConfigFile(contents: "first\nsecond\nthird", nestedFilePath: "Nested/File")

        try sut.removeTextFromNestedConfigFile(text: "second", nestedFilePath: "Nested/File")

        #expect(try fileSystem.readFile(at: sut.configFolderPath.appendingPathComponent("Nested/File")) == "first\nthird")
    }

    @Test
    func `Surrounding whitespace in the text is ignored when removing a line`() throws {
        let (sut, fileSystem) = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil)
        try sut.saveNestedConfigFile(contents: "first\nsecond\nthird", nestedFilePath: "Nested/File")

        try sut.removeTextFromNestedConfigFile(text: "  second\n", nestedFilePath: "Nested/File")

        #expect(try fileSystem.readFile(at: sut.configFolderPath.appendingPathComponent("Nested/File")) == "first\nthird")
    }

    @Test
    func `Partially matching line is kept when removing text`() throws {
        let contents = "first\nsecond"
        let (sut, fileSystem) = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil)
        try sut.saveNestedConfigFile(contents: contents, nestedFilePath: "Nested/File")

        try sut.removeTextFromNestedConfigFile(text: "sec", nestedFilePath: "Nested/File")

        #expect(try fileSystem.readFile(at: sut.configFolderPath.appendingPathComponent("Nested/File")) == contents)
    }

    @Test
    func `Removing text does nothing when the config folder does not exist`() {
        let sut = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil).sut

        #expect(throws: Never.self) {
            try sut.removeTextFromNestedConfigFile(text: "first", nestedFilePath: "Nested/File")
        }
    }

    @Test
    func `Removing text does nothing when the nested folder does not exist`() throws {
        let (sut, fileSystem) = makeSUT(projectName: "TestProject", configFolderPath: "/Users/Home/.config/TestProject", configFileName: nil)
        try fileSystem.createDirectory(at: sut.configFolderPath)

        #expect(throws: Never.self) {
            try sut.removeTextFromNestedConfigFile(text: "first", nestedFilePath: "Nested/File")
        }
    }
}

// MARK: - SUT
private extension NnConfigManagerTests {
    func makeSUT(projectName: String, configFolderPath: String?, configFileName: String?) -> (sut: NnConfigManager<TestConfig>, fileSystem: MockFileSystem) {
        let homeDirectory = MockDirectory(
            path: "/Users/Home",
            subdirectories: [],
            containedFiles: [],
            throwError: false,
            shouldThrowOnSubdirectory: false,
            autoCreateSubdirectories: false,
            ext: nil
        )
        let currentDirectory = MockDirectory(
            path: "/Users/Home/Current",
            subdirectories: [],
            containedFiles: [],
            throwError: false,
            shouldThrowOnSubdirectory: false,
            autoCreateSubdirectories: false,
            ext: nil
        )
        let fileSystem = MockFileSystem(
            homeDirectory: homeDirectory,
            currentDirectory: currentDirectory,
            directoryToLoad: nil,
            directoryMap: nil,
            desktop: nil,
            fileContentsToRead: [:],
            throwError: false
        )
        let sut = NnConfigManager<TestConfig>(
            projectName: projectName,
            configFolderPath: configFolderPath,
            configFileName: configFileName,
            fileSystem: fileSystem
        )

        return (sut, fileSystem)
    }
}
