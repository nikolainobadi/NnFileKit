# NnFileKit API Reference

File system access from Swift with a protocol-based, fully mockable design. Two protocols: `FileSystem` (the absolute-path entry point) and `Directory` (the working handle you navigate from there).

---

## Protocol: FileSystem

The top-level abstraction. Depend on this protocol for testability; resolve a `Directory` from it, then do most work through the directory.

```swift
public protocol FileSystem {
    var homeDirectory: any Directory { get }
    var currentDirectory: any Directory { get }
    func moveToTrash(at path: String) throws
    func directory(at path: String) throws -> any Directory
    func desktopDirectory() throws -> any Directory
    func readFile(at path: String) throws -> String
    func writeFile(at path: String, contents: String) throws
}
```

### Members

| Member | Returns | Description |
|--------|---------|-------------|
| `homeDirectory` | `any Directory` | The current user's home directory |
| `currentDirectory` | `any Directory` | The process's current working directory |
| `directory(at: String)` | `any Directory` | The directory at an absolute path. Throws `FileSystemError.directoryNotFound` if missing or not a directory |
| `desktopDirectory()` | `any Directory` | The current user's Desktop directory |
| `readFile(at: String)` | `String` | Reads a file's contents as UTF-8 |
| `writeFile(at: String, contents: String)` | `Void` | Writes a string to a file, creating or overwriting |
| `moveToTrash(at: String)` | `Void` | Moves the item at an absolute path to the trash |

### Protocol Extension Helper

| Method | Returns | Description |
|--------|---------|-------------|
| `getDirectoryAtPathOrCurrent(path: String?)` | `any Directory` | Returns `directory(at: path)`, or `currentDirectory` when `path` is `nil` |

### Usage Example

```swift
func loadConfig(using fs: FileSystem) throws -> String {
    let dir = try fs.getDirectoryAtPathOrCurrent(path: nil)   // currentDirectory
    return try dir.readFile(named: "config.json")
}
```

### Implementations

| Implementation | Key Difference |
|----------------|----------------|
| `DefaultFileSystem` | Production — real `FileManager` operations, `Sendable` |
| `MockFileSystem` | Testing — in-memory, records calls, returns preconfigured directories |

---

## Protocol: Directory

A handle to one directory. This is where most file work happens once you have a directory from the `FileSystem`.

```swift
public protocol Directory {
    var path: String { get }
    var name: String { get }
    var `extension`: String? { get }
    var subdirectories: [any Directory] { get }
    func delete() throws
    func move(to parent: any Directory) throws
    func containsFile(named name: String) -> Bool
    func subdirectory(named name: String) throws -> any Directory
    func createSubdirectory(named name: String) throws -> any Directory
    func createSubfolderIfNeeded(named name: String) throws -> any Directory
    func deleteFile(named name: String) throws
    @discardableResult func createFile(named name: String, contents: String) throws -> String
    func readFile(named name: String) throws -> String
    func findFiles(withExtension extension: String?, recursive: Bool) throws -> [String]
}
```

### Members

| Member | Returns | Description |
|--------|---------|-------------|
| `path` | `String` | Absolute path of the directory |
| `name` | `String` | Last path component |
| `extension` | `String?` | File extension of the name, or `nil` |
| `subdirectories` | `[any Directory]` | Immediate subdirectories |
| `delete()` | `Void` | Deletes this directory and all contents |
| `move(to: any Directory)` | `Void` | Moves this directory into a parent directory |
| `containsFile(named:)` | `Bool` | Whether a file with that name exists here |
| `subdirectory(named:)` | `any Directory` | Existing subdirectory; throws if absent |
| `createSubdirectory(named:)` | `any Directory` | Creates a new subdirectory (non-recursive) |
| `createSubfolderIfNeeded(named:)` | `any Directory` | Returns existing subdirectory or creates it (recursive intermediates) |
| `deleteFile(named:)` | `Void` | Deletes a file by name |
| `createFile(named:contents:)` | `String` | Creates a file, returns its absolute path (`@discardableResult`) |
| `readFile(named:)` | `String` | Reads a file by name; throws `FileSystemError.fileNotFound` if absent |
| `findFiles(withExtension:recursive:)` | `[String]` | Absolute paths of files, optionally filtered by extension / searched recursively |

### Protocol Extension Helper

| Method | Returns | Description |
|--------|---------|-------------|
| `containsSubdirectory(named:)` | `Bool` | `true` if `subdirectory(named:)` succeeds |

### Usage Example

```swift
func exportLogs(in dir: Directory) throws {
    let logs = try dir.createSubfolderIfNeeded(named: "logs")
    try logs.createFile(named: "run.txt", contents: "started")
    let swiftFiles = try dir.findFiles(withExtension: "swift", recursive: true)
    print("found \(swiftFiles.count) Swift files")
}
```

### `FileSystem` vs `Directory` — which to use

| Need | Use |
|:-----|:----|
| An entry point from an absolute path | `FileSystem.directory(at:)` / `readFile(at:)` / `writeFile(at:)` |
| Work relative to a known directory | `Directory` methods (`createFile`, `readFile(named:)`, subdirectories) |
| Well-known locations | `FileSystem.homeDirectory` / `currentDirectory` / `desktopDirectory()` |
| Recursive file search | `Directory.findFiles(withExtension:recursive:)` |
| Send something to the trash | `FileSystem.moveToTrash(at:)` |

---

## Struct: DefaultFileSystem

Production `FileSystem` implementation backed by `FileManager`.

```swift
public struct DefaultFileSystem: FileSystem, Sendable
```

### Initialization

| Initializer | Description |
|-------------|-------------|
| `init(fileManager: FileManager = .default)` | Creates a file system backed by the given `FileManager` |

### Behavior Notes

- `homeDirectory` uses `NSHomeDirectory()`; `currentDirectory` uses `fileManager.currentDirectoryPath`
- `desktopDirectory()` resolves `~/Desktop` then validates it via `directory(at:)` — throws `directoryNotFound` if it doesn't exist
- `directory(at:)` checks existence **and** that the path is a directory before returning a `DefaultDirectory`
- `readFile`/`writeFile` use UTF-8; `writeFile` is atomic (`atomically: true`)
- `moveToTrash(at:)` calls `fileManager.trashItem(at:resultingItemURL:)` (macOS)

### Usage Example

```swift
let fs = DefaultFileSystem()
let home = fs.homeDirectory
try fs.writeFile(at: home.path.appendingPathComponent("note.txt"), contents: "hi")
let text = try fs.readFile(at: home.path.appendingPathComponent("note.txt"))
```

---

## Struct: DefaultDirectory

Production `Directory` implementation backed by `FileManager`. **Paths are normalized to always end in a trailing slash.**

```swift
public struct DefaultDirectory: Directory, Sendable
```

### Initialization

| Initializer | Description |
|-------------|-------------|
| `init(path: String)` | Creates a directory reference; appends a trailing `/` if absent |

### Static Helpers

| Property | Description |
|----------|-------------|
| `DefaultDirectory.temporary` | `NSTemporaryDirectory()` |
| `DefaultDirectory.home` | `NSHomeDirectory()` |

### Behavior Notes

- `name` strips the trailing slash before taking the last path component
- `createSubdirectory(named:)` is **non-recursive** (`withIntermediateDirectories: false`) — throws if intermediates are missing
- `createSubfolderIfNeeded(named:)` is **recursive** (`withIntermediateDirectories: true`) and returns the existing folder if present
- `findFiles` recursive mode uses `FileManager.enumerator`; non-recursive uses `contentsOfDirectory`; extension match is exact (`pathExtension == ext`)
- `readFile(named:)` throws `FileSystemError.fileNotFound` when the file is absent

---

## Enum: FileSystemError

Errors thrown by `DefaultFileSystem` and `DefaultDirectory`.

```swift
public enum FileSystemError: Error {
    case directoryNotFound(String)
    case fileNotFound(String)
}
```

| Case | Associated Value | Thrown When |
|------|------------------|-------------|
| `directoryNotFound` | `String` (path) | `directory(at:)` / `subdirectory(named:)` find no directory at the path |
| `fileNotFound` | `String` (path) | `readFile(named:)` is called for a file that doesn't exist |

### Usage Example

```swift
do {
    _ = try fs.directory(at: "/no/such/dir")
} catch FileSystemError.directoryNotFound(let path) {
    print("missing directory: \(path)")
}
```

---

## Extension: String.appendingPathComponent(_:)

```swift
public extension String {
    func appendingPathComponent(_ path: String) -> String
}
```

Joins two path segments, inserting a `/` only when the receiver doesn't already end in one. Useful for building absolute paths to pass to `FileSystem` methods.

```swift
let p = "/Users/me".appendingPathComponent("Desktop")  // "/Users/me/Desktop"
```

---

## Best Practices

- **Depend on `FileSystem` / `Directory`, not the `Default*` types** — Accept the protocols in your types for testability. Instantiate `DefaultFileSystem` only at the composition root.
- **Resolve a `Directory` early, then work through it** — `FileSystem` is the absolute-path door; `Directory` is the ergonomic handle. Prefer `dir.readFile(named:)` over re-building absolute paths.
- **Know the two "create subfolder" semantics** — `createSubdirectory(named:)` is non-recursive and throws on missing intermediates; `createSubfolderIfNeeded(named:)` is recursive and idempotent. Reach for the latter unless you specifically want the failure.
- **`createFile` is `@discardableResult`** — It returns the new file's absolute path; ignore it when you only need the side effect.
- **Catch `FileSystemError` for the two "not found" cases** — `directoryNotFound` and `fileNotFound` are the package's own errors; other failures surface as Foundation errors.
- **`DefaultDirectory` paths carry a trailing slash** — Account for this if you compare `path` strings directly.
- **`moveToTrash` is macOS-only** — It relies on `FileManager.trashItem`.
