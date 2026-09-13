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
    @discardableResult func createDirectory(at path: String) throws -> any Directory
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
| `createDirectory(at: String)` | `any Directory` | Get-or-create counterpart of `directory(at:)`: returns the directory at an absolute path, creating it and any missing intermediates (`@discardableResult`) |
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

func prepareCache(using fs: FileSystem) throws -> any Directory {
    return try fs.createDirectory(at: "/Users/me/.cache/myapp/v2")   // creates missing intermediates
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
    @discardableResult func copy(to parent: any Directory, overwrite: Bool) throws -> any Directory
    func containsFile(named name: String) -> Bool
    func subdirectory(named name: String) throws -> any Directory
    func createSubdirectory(named name: String) throws -> any Directory
    func createSubfolderIfNeeded(named name: String) throws -> any Directory
    func deleteFile(named name: String) throws
    @discardableResult func createFile(named name: String, contents: String) throws -> String
    @discardableResult func copyFile(named name: String, to destination: any Directory, overwrite: Bool) throws -> String
    func fileContentsEqual(named name: String, in other: any Directory) throws -> Bool
    func readFile(named name: String) throws -> String
    func findFiles(withExtension extension: String?, recursive: Bool) throws -> [String]
}
```

### Names are single path components

Every `named:` parameter accepts **one path component only**. A name containing `/`:

- makes **throwing** methods (`subdirectory`, `createSubdirectory`, `createSubfolderIfNeeded`, `createFile`, `readFile`, `deleteFile`, `copyFile`, `fileContentsEqual`) throw `FileSystemError.invalidName(name)`
- makes the **predicates** `containsFile(named:)` / `containsSubdirectory(named:)` return `false`

Use the `atRelativePath:` helpers below to address nested subdirectories.

### Members

| Member | Returns | Description |
|--------|---------|-------------|
| `path` | `String` | Absolute path of the directory |
| `name` | `String` | Last path component |
| `extension` | `String?` | File extension of the name, or `nil` |
| `subdirectories` | `[any Directory]` | Immediate subdirectories |
| `delete()` | `Void` | Deletes this directory and all contents |
| `move(to: any Directory)` | `Void` | Moves this directory into a parent directory |
| `copy(to:overwrite:)` | `any Directory` | Copies this directory tree into `parent` under its own name; returns the copy (`@discardableResult`). Parent must exist; `overwrite: false` throws if the destination exists |
| `containsFile(named:)` | `Bool` | Whether a file with that name exists here |
| `subdirectory(named:)` | `any Directory` | Existing subdirectory; throws if absent |
| `createSubdirectory(named:)` | `any Directory` | Creates a new subdirectory (non-recursive) |
| `createSubfolderIfNeeded(named:)` | `any Directory` | Returns existing subdirectory or creates it (recursive intermediates) |
| `deleteFile(named:)` | `Void` | Deletes a file by name |
| `createFile(named:contents:)` | `String` | Creates a file, returns its absolute path (`@discardableResult`) |
| `copyFile(named:to:overwrite:)` | `String` | Copies a file into `destination` under the same name, returns the destination path (`@discardableResult`). Destination must exist; `overwrite: false` throws if the file exists there |
| `fileContentsEqual(named:in:)` | `Bool` | Whether the file here has the same bytes as the same-named file in `other`. `false` if they differ **or** `other` lacks the file; throws `FileSystemError.fileNotFound` if **this** directory lacks it |
| `readFile(named:)` | `String` | Reads a file by name; throws `FileSystemError.fileNotFound` if absent |
| `findFiles(withExtension:recursive:)` | `[String]` | Absolute paths of files, optionally filtered by extension / searched recursively |

### Protocol Extension Helper

| Method | Returns | Description |
|--------|---------|-------------|
| `containsSubdirectory(named:)` | `Bool` | `true` if `subdirectory(named:)` succeeds |
| `subdirectory(atRelativePath:)` | `any Directory` | Walks `"a/b"` via `subdirectory(named:)`; throws if any component is missing |
| `createSubdirectory(atRelativePath:)` | `any Directory` | Walks `"a/b"` via `createSubfolderIfNeeded(named:)`, creating missing intermediates (`@discardableResult`) |

Both relative-path helpers collapse repeated separators (`"a//b"` → `a/b`), return `self` for an empty path, and throw `FileSystemError.invalidName(path)` for a path beginning with `/`. Because they only call protocol methods, they work identically on every conformer, including the mocks.

### Usage Example

```swift
func exportLogs(in dir: Directory, archive: Directory) throws {
    let logs = try dir.createSubdirectory(atRelativePath: "output/logs")
    try logs.createFile(named: "run.txt", contents: "started")

    if try !logs.fileContentsEqual(named: "run.txt", in: archive) {
        try logs.copyFile(named: "run.txt", to: archive, overwrite: true)
    }

    let swiftFiles = try dir.findFiles(withExtension: "swift", recursive: true)
    print("found \(swiftFiles.count) Swift files")
}
```

### `FileSystem` vs `Directory` — which to use

| Need | Use |
|:-----|:----|
| An entry point from an absolute path | `FileSystem.directory(at:)` / `readFile(at:)` / `writeFile(at:)` |
| Ensure an absolute directory path exists | `FileSystem.createDirectory(at:)` |
| Work relative to a known directory | `Directory` methods (`createFile`, `readFile(named:)`, subdirectories) |
| Nested relative paths (`"a/b"`) | `Directory.subdirectory(atRelativePath:)` / `createSubdirectory(atRelativePath:)` |
| Copy or compare across directories | `Directory.copy(to:overwrite:)` / `copyFile(named:to:overwrite:)` / `fileContentsEqual(named:in:)` |
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
- `createDirectory(at:)` uses `withIntermediateDirectories: true`, so it is idempotent for an existing directory
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
- Every `named:` method validates the name first — `/` throws `FileSystemError.invalidName` (predicates return `false`)
- `containsFile(named:)` is `true` only for files — a subdirectory with that name returns `false`
- `createSubdirectory(named:)` throws if the subdirectory already exists; `createSubfolderIfNeeded(named:)` returns the existing folder if present
- `subdirectory(named:)` throws `FileSystemError.directoryNotFound` when absent or not a directory
- `copy(to:overwrite:)` / `copyFile(named:to:overwrite:)` use `FileManager.copyItem` — bytes, nested structure, and symlinks are preserved. With `overwrite: true` an existing destination is **removed first** (not atomic); with `false`, an existing destination makes the copy throw
- `fileContentsEqual(named:in:)` uses `FileManager.contentsEqual` (byte comparison, binary-safe)
- `findFiles` recursive mode uses `FileManager.enumerator`; non-recursive uses `contentsOfDirectory`; extension match is exact (`pathExtension == ext`)
- `readFile(named:)` throws `FileSystemError.fileNotFound` when the file is absent

---

## Enum: FileSystemError

Errors thrown by `FileSystem` and `Directory` operations.

```swift
public enum FileSystemError: Error {
    case directoryNotFound(String)
    case fileNotFound(String)
    case invalidName(String)
}
```

| Case | Associated Value | Thrown When |
|------|------------------|-------------|
| `directoryNotFound` | `String` (path) | `directory(at:)` / `subdirectory(named:)` find no directory at the path |
| `fileNotFound` | `String` (path) | `readFile(named:)` is called for a file that doesn't exist, or `fileContentsEqual(named:in:)` for a file missing from the receiver |
| `invalidName` | `String` (name or path) | A `named:` argument contains `/`, or an `atRelativePath:` argument begins with `/` |

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
- **Know the two "create subfolder" semantics** — `createSubdirectory(named:)` throws if the folder already exists; `createSubfolderIfNeeded(named:)` is idempotent. Reach for the latter unless you specifically want the failure.
- **Never pass `"a/b"` to a `named:` parameter** — It throws `invalidName`. Use `subdirectory(atRelativePath:)` / `createSubdirectory(atRelativePath:)` for nested folders, or `FileSystem.createDirectory(at:)` for an absolute path.
- **Choose `overwrite` deliberately** — `copy` and `copyFile` require it at every call site. `true` deletes the existing destination before copying, so a failed copy can leave nothing behind.
- **`createFile`, `copyFile`, `copy`, and `createDirectory` are `@discardableResult`** — Ignore the return value when you only need the side effect.
- **Catch `FileSystemError` for the package's own cases** — `directoryNotFound`, `fileNotFound`, and `invalidName`; other failures surface as Foundation errors.
- **`DefaultDirectory` paths carry a trailing slash** — Account for this if you compare `path` strings directly.
- **`moveToTrash` is macOS-only** — It relies on `FileManager.trashItem`.
