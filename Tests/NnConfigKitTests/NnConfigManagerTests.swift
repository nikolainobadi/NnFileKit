//
//  NnConfigManagerTests.swift
//
//
//  Created by Nikolai Nobadi on 6/19/24.
//

import XCTest
import NnFileKit
import NnFileTesting
@testable import NnConfigKit

final class NnConfigManagerTests: XCTestCase {
    let sampleTextLines = ["first", "second", "third"]

    override func setUpWithError() throws {
        try super.setUpWithError()
        try cleanConfigFolders()
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        try cleanConfigFolders()
    }
}


// MARK: - Default Config Folder Tests
extension NnConfigManagerTests {
    func test_throws_error_when_config_does_not_exist_when_loading() throws {
        try saveConfig(makeConfig(), configType: .customConfig)

        XCTAssertThrowsError(try makeSUT(type: .defaultConfig).loadConfig())
    }

    func test_saves_config_in_default_folder_and_overwrites_config_when_updating() throws {
        let customConfig = makeConfig()
        let updatedConfig = makeConfig(secondSetting: "newSetting")

        try runSaveLoadUpdateTest(for: customConfig, updatedConfig: updatedConfig, configType: .defaultConfig)
    }

    func test_saves_and_deletes_nested_file_in_default_config_folder() throws {
        let nestedFilePath = "NestedFolder/NestedFile"
        let sut = makeSUT(type: .defaultConfig)
        let configFolderPath = sut.configFolderPath
        let completeFilePath = "\(configFolderPath)/\(nestedFilePath)"
        let contents = makeNestedContent()

        XCTAssertFalse(FileManager.default.fileExists(atPath: completeFilePath))

        try sut.saveNestedConfigFile(contents: contents, nestedFilePath: nestedFilePath)

        XCTAssertTrue(FileManager.default.fileExists(atPath: completeFilePath))

        try sut.deletedNestedConfigFile(nestedFilePath: nestedFilePath)

        XCTAssertFalse(FileManager.default.fileExists(atPath: completeFilePath))
    }

    func test_performs_all_operations_on_nested_file_in_default_config_folder() throws {
        let newLine = "new line"
        let contents = makeNestedContent()
        let existingLine = sampleTextLines[0]
        let nestedFilePath = "NestedFolder/NestedFile"
        let sut = makeSUT(type: .defaultConfig)
        let configFolderPath = sut.configFolderPath
        let completeFilePath = "\(configFolderPath)/\(nestedFilePath)"

        XCTAssertFalse(FileManager.default.fileExists(atPath: completeFilePath))

        try sut.saveNestedConfigFile(contents: contents, nestedFilePath: nestedFilePath)
        try sut.appendTextToNestedConfigFileIfNeeded(text: existingLine, nestedFilePath: nestedFilePath, asNewLine: true)

        let initialContents = try String(contentsOfFile: completeFilePath, encoding: .utf8)

        XCTAssertEqual(initialContents, contents)

        try sut.appendTextToNestedConfigFileIfNeeded(text: newLine, nestedFilePath: nestedFilePath, asNewLine: true)

        let newContents = try String(contentsOfFile: completeFilePath, encoding: .utf8)

        XCTAssert(newContents.contains(newLine))

        try sut.removeTextFromNestedConfigFile(text: existingLine, nestedFilePath: nestedFilePath)

        let finalContents = try String(contentsOfFile: completeFilePath, encoding: .utf8)

        XCTAssert(finalContents.contains(newLine))
        XCTAssertFalse(finalContents.contains(existingLine))
    }
}


// MARK: - Custom Folder Tests
extension NnConfigManagerTests {
    func test_throws_error_when_config_does_not_exist_in_custom_folder_when_loading() throws {
        try saveConfig(makeConfig(), configType: .defaultConfig)

        XCTAssertThrowsError(try makeSUT(type: .customConfig).loadConfig())
    }

    func test_saves_and_updates_config_in_custom_folder() throws {
        let customConfig = makeConfig()
        let updatedConfig = makeConfig(secondSetting: "newSetting")

        try runSaveLoadUpdateTest(for: customConfig, updatedConfig: updatedConfig, configType: .customConfig)
    }
}


// MARK: - Unit Tests (Mock FileSystem)
extension NnConfigManagerTests {
    func test_loadConfig_with_mock_returns_decoded_config() throws {
        let config = makeConfig()
        let data = try JSONEncoder.prettyOutput().encode(config)
        let jsonString = String(data: data, encoding: .utf8)!

        let mockDir = MockDirectory(path: "/mock/config", containedFiles: ["TestProject.json"])
        mockDir.fileContents["TestProject.json"] = jsonString

        let mockFS = MockFileSystem(directoryToLoad: mockDir)
        let sut = NnConfigManager<MockConfig>(
            projectName: "TestProject",
            configFolderPath: "/mock/config",
            fileSystem: mockFS
        )

        let loaded = try sut.loadConfig()

        XCTAssertEqual(loaded, config)
    }

    func test_loadConfig_with_mock_throws_when_directory_missing() {
        let mockFS = MockFileSystem()
        let sut = NnConfigManager<MockConfig>(
            projectName: "TestProject",
            configFolderPath: "/mock/config",
            fileSystem: mockFS
        )

        XCTAssertThrowsError(try sut.loadConfig())
    }

    func test_saveConfig_with_mock_writes_json_to_directory() throws {
        let config = makeConfig()
        let homeMock = MockDirectory(path: "/Users/Home")
        let mockFS = MockFileSystem(homeDirectory: homeMock)

        let sut = NnConfigManager<MockConfig>(
            projectName: "TestProject",
            configFolderPath: "/Users/Home/configs/TestProject",
            fileSystem: mockFS
        )

        try sut.saveConfig(config)

        // Walk the created directory chain
        let configsDir = homeMock.subdirectories.first { $0.name == "configs" }
        XCTAssertNotNil(configsDir)

        let projectDir = configsDir?.subdirectories.first { $0.name == "TestProject" }
        XCTAssertNotNil(projectDir)

        if let mockProjectDir = projectDir as? MockDirectory {
            XCTAssertTrue(mockProjectDir.containedFiles.contains("TestProject.json"))

            let savedJSON = mockProjectDir.fileContents["TestProject.json"] ?? ""
            let decoded = try JSONDecoder().decode(MockConfig.self, from: Data(savedJSON.utf8))
            XCTAssertEqual(decoded, config)
        } else {
            XCTFail("Expected MockDirectory")
        }
    }
}


// MARK: - SUT
extension NnConfigManagerTests {
    func makeSUT(type: ConfigType) -> NnConfigManager<MockConfig> {
        return .init(
            projectName: type.projectName,
            configFolderPath: type.configFolderPath,
            configFileName: type.configFileName
        )
    }

    func makeConfig(firstSetting: Int = 0, secondSetting: String = "something to remember") -> MockConfig {
        return .init(firstSetting: firstSetting, secondSetting: secondSetting)
    }
}


// MARK: - Helpers
extension NnConfigManagerTests {
    class MockConfig: Codable, Equatable {
        static func == (lhs: NnConfigManagerTests.MockConfig, rhs: NnConfigManagerTests.MockConfig) -> Bool {
            return lhs.firstSetting == rhs.firstSetting && lhs.secondSetting == rhs.secondSetting
        }

        var firstSetting: Int
        var secondSetting: String

        init(firstSetting: Int = 0, secondSetting: String = "something to remember") {
            self.firstSetting = firstSetting
            self.secondSetting = secondSetting
        }
    }

    enum ConfigType: CaseIterable {
        case defaultConfig, customConfig

        var projectName: String {
            return "\(self == .defaultConfig ? "Default" : "Custom")NnConfigKitTestProject"
        }

        var configFolderPath: String? {
            return self == .defaultConfig ? nil : "\(DefaultDirectory.temporary.path).testConfig/NnConfigList/\(projectName)"
        }

        var configFileName: String? {
            return self == .defaultConfig ? nil : "\(projectName)-custom.json"
        }
    }
}


// MARK: - Assertion Helpers
extension NnConfigManagerTests {
    func runSaveLoadUpdateTest(for config: MockConfig, updatedConfig: MockConfig, configType: ConfigType) throws {
        let sut = makeSUT(type: configType)

        try sut.saveConfig(config)

        let loadedConfig = try sut.loadConfig()

        XCTAssertEqual(config, loadedConfig)
        XCTAssertNotEqual(config, updatedConfig)

        try sut.saveConfig(updatedConfig)

        let loadedUpdatedConfig = try sut.loadConfig()
        XCTAssertEqual(updatedConfig, loadedUpdatedConfig)
        XCTAssertNotEqual(loadedConfig, loadedUpdatedConfig)
    }
}


// MARK: - Helper Methods
private extension NnConfigManagerTests {
    func makeNestedContent() -> String {
        return sampleTextLines.joined(separator: "\n")
    }

    func saveConfig(_ config: MockConfig, configType: ConfigType, file: StaticString = #filePath, line: UInt = #line) throws {
        try makeSUT(type: configType).saveConfig(config)
    }

    func cleanConfigFolders() throws {
        try deleteExistingFolder(path: ConfigType.customConfig.configFolderPath!)
        try deleteExistingFolder(path: "\(DEFAULT_CONFIGLIST_FOLDER_PATH)/\(ConfigType.defaultConfig.projectName)")
    }

    func deleteExistingFolder(path: String) throws {
        let fileSystem = DefaultFileSystem()
        if let folder = try? fileSystem.directory(at: path) {
            try folder.delete()
        }
    }
}
