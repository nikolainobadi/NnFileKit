//
//  NnConfigManager.swift
//
//
//  Created by Nikolai Nobadi on 6/19/24.
//

import NnFileKit
import Foundation

/// The default folder path for configuration lists.
public let DEFAULT_CONFIGLIST_FOLDER_PATH = "\(DefaultFileSystem().homeDirectory.path).config/NnConfigList"

/// A manager for handling configuration operations such as loading, saving, and managing nested configuration files.
public struct NnConfigManager<Config: Codable>: Sendable {
    public let projectName: String
    public let configFolderPath: String
    public let configFileName: String
    nonisolated(unsafe) let fileSystem: any FileSystem

    /// Initializes a new configuration manager with the specified project name, configuration folder path, and configuration file name.
    /// - Parameters:
    ///   - projectName: The name of the project.
    ///   - configFolderPath: An optional custom path to the configuration folder. Defaults to a standard path based on the project name.
    ///   - configFileName: An optional custom name for the configuration file. Defaults to the project name.
    ///   - fileSystem: The file system implementation to use. Defaults to `DefaultFileSystem()`.
    public init(projectName: String, configFolderPath: String? = nil, configFileName: String? = nil, fileSystem: any FileSystem = DefaultFileSystem()) {
        self.projectName = projectName
        self.fileSystem = fileSystem
        self.configFolderPath = configFolderPath ?? "\(DEFAULT_CONFIGLIST_FOLDER_PATH)/\(projectName)"
        self.configFileName = configFileName ?? projectName
    }
}

// MARK: - Load
public extension NnConfigManager {
    /// Loads the configuration from the configuration file.
    /// - Throws: An error if the configuration file cannot be read or decoded.
    /// - Returns: The loaded configuration object.
    func loadConfig() throws -> Config {
        let configDir = try fileSystem.directory(at: configFolderPath)
        let jsonString = try configDir.readFile(named: configFileName.json)
        let data = Data(jsonString.utf8)

        return try JSONDecoder().decode(Config.self, from: data)
    }
}

// MARK: - Save
public extension NnConfigManager {
    /// Saves the configuration to the configuration file.
    /// - Parameter config: The configuration object to be saved.
    /// - Throws: An error if the configuration file cannot be written.
    func saveConfig(_ config: Config) throws {
        let configDir = try fileSystem.createDirectory(at: configFolderPath)
        let data = try JSONEncoder.prettyOutput().encode(config)
        let jsonString = String(data: data, encoding: .utf8) ?? ""

        try configDir.createFile(named: configFileName.json, contents: jsonString)
    }
}

// MARK: - NestedConfigFiles
public extension NnConfigManager {
    /// Saves a nested configuration file with the specified contents.
    /// - Parameters:
    ///   - contents: The contents to be written to the nested file.
    ///   - nestedFilePath: The path to the nested file.
    /// - Throws: An error if the nested file cannot be created or written.
    func saveNestedConfigFile(contents: String, nestedFilePath: String) throws {
        let configDir = try fileSystem.createDirectory(at: configFolderPath)
        let (directoryPath, fileName) = parseNestedPath(nestedFilePath)
        let targetDir = try configDir.createSubdirectory(atRelativePath: directoryPath)

        try targetDir.createFile(named: fileName, contents: contents)
    }

    /// Deletes a nested configuration file at the specified path.
    /// - Parameter nestedFilePath: The path to the nested file.
    /// - Throws: An error if the nested file cannot be deleted.
    func deletedNestedConfigFile(nestedFilePath: String) throws {
        guard let configDir = try? fileSystem.directory(at: configFolderPath) else { return }

        let (directoryPath, fileName) = parseNestedPath(nestedFilePath)

        guard let current = try? configDir.subdirectory(atRelativePath: directoryPath) else { return }

        if current.containsFile(named: fileName) {
            try current.deleteFile(named: fileName)
        }
    }

    /// Appends text to a nested configuration file if the text does not already exist in the file.
    /// - Parameters:
    ///   - text: The text to be appended.
    ///   - nestedFilePath: The path to the nested file.
    ///   - asNewLine: Whether to append the text as a new line.
    /// - Throws: An error if the nested file cannot be created or written.
    func appendTextToNestedConfigFileIfNeeded(text: String, nestedFilePath: String, asNewLine: Bool = true) throws {
        let configDir = try fileSystem.createDirectory(at: configFolderPath)
        let (directoryPath, fileName) = parseNestedPath(nestedFilePath)
        let targetDir = try configDir.createSubdirectory(atRelativePath: directoryPath)

        if !targetDir.containsFile(named: fileName) {
            try targetDir.createFile(named: fileName, contents: "")
        }

        try appendTextToFileIfNeeded(text: text, inDirectory: targetDir, fileName: fileName, asNewLine: asNewLine)
    }

    /// Removes text from a nested configuration file.
    /// - Parameters:
    ///   - text: The text to be removed.
    ///   - nestedFilePath: The path to the nested file.
    /// - Throws: An error if the nested file cannot be read or written.
    func removeTextFromNestedConfigFile(text: String, nestedFilePath: String) throws {
        guard let configDir = try? fileSystem.directory(at: configFolderPath) else { return }

        let (directoryPath, fileName) = parseNestedPath(nestedFilePath)

        guard let current = try? configDir.subdirectory(atRelativePath: directoryPath) else { return }

        try removeTextFromFile(text: text, inDirectory: current, fileName: fileName)
    }
}

// MARK: - Private Methods
private extension NnConfigManager {
    /// Splits a nested file path into its relative directory path and file name.
    /// Components are rejoined, so a leading `/` in `nestedFilePath` never reaches a relative-path API.
    func parseNestedPath(_ nestedFilePath: String) -> (directoryPath: String, fileName: String) {
        let components = nestedFilePath.split(separator: "/").map(String.init)
        let fileName = components.last ?? nestedFilePath
        let directoryPath = components.dropLast().joined(separator: "/")

        return (directoryPath, fileName)
    }

    func appendTextToFileIfNeeded(text: String, inDirectory directory: any Directory, fileName: String, asNewLine: Bool) throws {
        let existingContents = try directory.readFile(named: fileName)

        if !existingContents.contains(text) {
            let updatedContents = asNewLine ? existingContents + "\n\(text)" : existingContents + text

            try directory.createFile(named: fileName, contents: updatedContents)
        }
    }

    func removeTextFromFile(text: String, inDirectory directory: any Directory, fileName: String) throws {
        let existingContents = try directory.readFile(named: fileName)
        var lines = existingContents.components(separatedBy: .newlines)

        lines.removeAll { line in
            line == text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let updatedContents = lines.joined(separator: "\n")

        try directory.createFile(named: fileName, contents: updatedContents)
    }
}

// MARK: - Extension Dependencies
extension String {
    /// Ensures the string ends with the ".json" extension.
    var json: String {
        if self.isEmpty { return "" }
        return self.hasSuffix(".json") ? self : "\(self).json"
    }
}
