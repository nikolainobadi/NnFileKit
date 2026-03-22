# NnFileKit

![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)
![macOS](https://img.shields.io/badge/macOS-14.0+-blueviolet.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey.svg)

## Overview

A lightweight Swift package providing protocol-based abstractions for file system operations and JSON configuration management. NnFileKit decouples your code from `FileManager` through the `FileSystem` and `Directory` protocols, making file operations easy to test with the included mock implementations. The `NnConfigKit` module builds on these protocols to provide generic, testable JSON configuration file management.

## Features

- **Protocol-driven design** — `FileSystem` and `Directory` protocols abstract all file operations
- **Full directory management** — create, move, delete, and traverse directories
- **File operations** — read, write, create, delete, and search files by extension
- **Recursive file search** — find files with optional extension filtering across nested directories
- **Desktop and home directory access** — convenient accessors for common locations
- **Trash support** — move items to trash instead of permanent deletion
- **Generic config management** — `NnConfigManager<Config: Codable>` for type-safe JSON configuration files
- **Nested config files** — create, append, remove, and delete files within config directory hierarchies
- **Sendable conformance** — safe for use in Swift 6 strict concurrency
- **Shared test doubles** — `MockFileSystem` and `MockDirectory` ship as a separate `NnFileTesting` library

## Requirements

- Swift 6.0+
- macOS 14.0+

## Installation

### Swift Package Manager

Add the package to your `Package.swift`:

```swift
.package(url: "https://github.com/nikolainobadi/NnFileKit.git", from: "0.5.0")
```

Then include the libraries you need in your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "NnFileKit", package: "NnFileKit"),
        .product(name: "NnConfigKit", package: "NnFileKit"),
    ]
)
```

For test targets, add the testing library:

```swift
.testTarget(
    name: "YourTests",
    dependencies: [
        .product(name: "NnFileTesting", package: "NnFileKit")
    ]
)
```

## Usage

### Working with the File System

```swift
import NnFileKit

let fileSystem = DefaultFileSystem()

// Access directories
let home = fileSystem.homeDirectory
let desktop = try fileSystem.desktopDirectory()
let projectDir = try fileSystem.directory(at: "/path/to/project")

// Read and write files
let contents = try fileSystem.readFile(at: "/path/to/file.txt")
try fileSystem.writeFile(at: "/path/to/output.txt", contents: "Hello, world!")

// Move to trash
try fileSystem.moveToTrash(at: "/path/to/unwanted-file.txt")
```

### Working with Directories

```swift
let dir = DefaultDirectory(path: "/path/to/directory")

// File operations
try dir.createFile(named: "config.json", contents: "{}")
let data = try dir.readFile(named: "config.json")
try dir.deleteFile(named: "config.json")

// Subdirectory management
let sub = try dir.createSubdirectory(named: "output")
let existing = try dir.createSubfolderIfNeeded(named: "cache")

// Search
let swiftFiles = try dir.findFiles(withExtension: "swift", recursive: true)
```

### Managing JSON Configurations

```swift
import NnConfigKit

struct AppConfig: Codable {
    var theme: String
    var maxRetries: Int
}

// Create a manager (configs stored at ~/.config/NnConfigList/MyApp/)
let manager = NnConfigManager<AppConfig>(projectName: "MyApp")

// Save and load
try manager.saveConfig(AppConfig(theme: "dark", maxRetries: 3))
let config = try manager.loadConfig()

// Nested config files within the config directory
try manager.saveNestedConfigFile(contents: "key=value", nestedFilePath: "settings/overrides.txt")
try manager.appendTextToNestedConfigFileIfNeeded(text: "new_key=new_value", nestedFilePath: "settings/overrides.txt")
try manager.removeTextFromNestedConfigFile(text: "key=value", nestedFilePath: "settings/overrides.txt")
try manager.deletedNestedConfigFile(nestedFilePath: "settings/overrides.txt")
```

### Testing with Mocks

```swift
import NnFileTesting

let mockDir = MockDirectory(path: "/fake/path", containedFiles: ["data.json"])
mockDir.fileContents["data.json"] = "{\"key\": \"value\"}"

let mockFS = MockFileSystem(
    homeDirectory: MockDirectory(path: "/Users/Test"),
    currentDirectory: mockDir
)

// Use mockFS anywhere a FileSystem is expected
// NnConfigManager accepts a FileSystem for testability
let manager = NnConfigManager<MyConfig>(
    projectName: "TestProject",
    configFolderPath: "/Users/Test/configs",
    fileSystem: mockFS
)
```

## Architecture

NnFileKit is organized into three library products:

| Module | Purpose |
|--------|---------|
| **NnFileKit** | Core protocols (`FileSystem`, `Directory`) and their `FileManager`-backed implementations (`DefaultFileSystem`, `DefaultDirectory`) |
| **NnConfigKit** | Generic JSON configuration management (`NnConfigManager<Config>`) built on `NnFileKit` protocols |
| **NnFileTesting** | Shared test doubles (`MockFileSystem`, `MockDirectory`) for consumer test targets |

## License

MIT License. See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome. Please open an issue or submit a pull request.
