//
//  NnConfigManagerIntegrationTests.swift
//  NnConfigKitTests
//
//  Created by Nikolai Nobadi on 9/12/26.
//

import Testing
import NnFileKit
import Foundation
@testable import NnConfigKit

struct NnConfigManagerIntegrationTests {
    @Test
    func `Saved config is loaded back from disk`() throws {
        let config = TestConfig(firstSetting: 1, secondSetting: "saved")
        let sut = makeSUT()
        try sut.saveConfig(config)

        let loaded = try sut.loadConfig()

        #expect(loaded == config)
    }
}

// MARK: - Nested Files
extension NnConfigManagerIntegrationTests {
    @Test
    func `Nested file is written to disk at its nested path`() throws {
        let sut = makeSUT()

        try sut.saveNestedConfigFile(contents: "nested contents", nestedFilePath: "Nested/File")

        #expect(FileManager.default.fileExists(atPath: sut.configFolderPath.appendingPathComponent("Nested/File")))
    }

    @Test
    func `Deleted nested file is removed from disk`() throws {
        let sut = makeSUT()
        try sut.saveNestedConfigFile(contents: "nested contents", nestedFilePath: "Nested/File")

        try sut.deletedNestedConfigFile(nestedFilePath: "Nested/File")

        #expect(!FileManager.default.fileExists(atPath: sut.configFolderPath.appendingPathComponent("Nested/File")))
    }

    @Test
    func `Text appended to a nested file is written to disk`() throws {
        let sut = makeSUT()
        try sut.saveNestedConfigFile(contents: "first", nestedFilePath: "Nested/File")

        try sut.appendTextToNestedConfigFileIfNeeded(text: "second", nestedFilePath: "Nested/File", asNewLine: true)

        let contents = try String(contentsOfFile: sut.configFolderPath.appendingPathComponent("Nested/File"), encoding: .utf8)
        #expect(contents == "first\nsecond")
    }
}

// MARK: - SUT
private extension NnConfigManagerIntegrationTests {
    func makeSUT() -> NnConfigManager<TestConfig> {
        let configFolderPath = NSTemporaryDirectory().appendingPathComponent("\(UUID().uuidString)/TestProject")

        return NnConfigManager<TestConfig>(
            projectName: "TestProject",
            configFolderPath: configFolderPath,
            configFileName: nil,
            fileSystem: DefaultFileSystem(fileManager: .default)
        )
    }
}
