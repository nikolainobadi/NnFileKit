# NnFileKit Testing Reference

In-memory test doubles for file system access. Import `NnFileTesting` alongside `NnFileKit`. Nothing touches disk — `MockFileSystem` and `MockDirectory` hold files and folders in memory and record the calls made against them.

---

## Class: MockFileSystem

In-memory `FileSystem` test double. Resolves directories from a preconfigured map, its in-memory home/root trees, or a single fallback directory, and records every path it's asked about.

```swift
public final class MockFileSystem: FileSystem
```

### Initialization

```swift
public init(
    homeDirectory: any Directory = MockDirectory(path: "/Users/Home"),
    currentDirectory: any Directory = MockDirectory(path: "/Users/Home/CurrentTest"),
    directoryToLoad: (any Directory)? = nil,
    directoryMap: [String: any Directory]? = nil,
    desktop: (any Directory)? = nil,
    fileContentsToRead: [String: String] = [:],
    throwError: Bool = false
)
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `homeDirectory` | `MockDirectory(path: "/Users/Home")` | Value returned by `homeDirectory` |
| `currentDirectory` | `MockDirectory(path: "/Users/Home/CurrentTest")` | Value returned by `currentDirectory` (mutable) |
| `directoryToLoad` | `nil` | Last-resort fallback returned by `directory(at:)` when neither the map nor the home/root tree matches |
| `directoryMap` | `nil` | Exact `path → Directory` lookup for `directory(at:)`, checked first |
| `desktop` | `nil` | Value returned by `desktopDirectory()`; defaults to `home/Desktop` |
| `fileContentsToRead` | `[:]` | Exact `path → contents` stub consulted first by `readFile(at:)` |
| `throwError` | `false` | When `true`, **every** operation throws — the blanket error-injection switch |

### Recorded State

| Property | Type | Description |
|----------|------|-------------|
| `capturedPaths` | `[String]` | Every path passed to `directory(at:)` or `createDirectory(at:)`, in order (read-only) |
| `pathToMoveToTrash` | `String?` | The last path passed to `moveToTrash(at:)` (read-only) |
| `writtenFilePath` | `String?` | The last path passed to `writeFile(at:contents:)` (read-only) |
| `writtenFileContents` | `String?` | The last contents passed to `writeFile(at:contents:)` (read-only) |

### Resolution Behavior

- `directory(at:)` records the path, then resolves in order:
  1. `directoryMap[path]`
  2. an existing folder in the **home tree** (when `path` is under `homeDirectory.path`, compared by whole components) or an internal in-memory **root tree** (`/`), walked with `subdirectory(atRelativePath:)`
  3. `directoryToLoad`
  4. else throws `NSError(domain: "MockFileSystem", code: 1)`
- `createDirectory(at:)` records the path and returns whatever `directory(at:)` would resolve; otherwise builds the chain with `createSubdirectory(atRelativePath:)` in the home tree (paths under home) or the root tree (everything else). Created folders then resolve through `directory(at:)`. Note that a configured `directoryToLoad` short-circuits creation
- `readFile(at:)` returns `fileContentsToRead[path]` if present → else resolves the containing directory and reads through it → else throws `FileSystemError.fileNotFound(path)`
- `writeFile(at:contents:)` **always** records into `writtenFilePath` / `writtenFileContents`, and *additionally* mutates the containing `MockDirectory` when one resolves. It does not throw for an unconfigured directory
- `moveToTrash(at:)` records the path in `pathToMoveToTrash`
- `throwError: true` short-circuits all of the above with `NSError(domain: "MockFileSystem", code: 2)`. `directory(at:)` / `createDirectory(at:)` throw *before* recording, so `capturedPaths` stays empty

### Usage Example

```swift
let projectDir = MockDirectory(path: "/work/project", containedFiles: ["Package.swift"])
let mock = MockFileSystem(directoryMap: ["/work/project": projectDir])

let dir = try mock.directory(at: "/work/project")
#expect(dir.containsFile(named: "Package.swift"))
#expect(mock.capturedPaths == ["/work/project"])
```

---

## Class: MockDirectory

In-memory `Directory` test double. Holds files and subdirectories in memory and records mutations.

```swift
public final class MockDirectory: Directory
```

### Initialization

```swift
public init(
    path: String,
    subdirectories: [any Directory] = [],
    containedFiles: Set<String> = [],
    throwError: Bool = false,
    shouldThrowOnSubdirectory: Bool = false,
    autoCreateSubdirectories: Bool = false,
    ext: String? = nil
)
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `path` | — | The directory's path, stored verbatim; `name` is derived from its last component |
| `subdirectories` | `[]` | Initial subdirectories |
| `containedFiles` | `[]` | Initial file names present |
| `throwError` | `false` | When `true`, **every** throwing method fails — the blanket error-injection switch |
| `shouldThrowOnSubdirectory` | `false` | Narrower than `throwError`: fails only `subdirectory(named:)` |
| `autoCreateSubdirectories` | `false` | When `true`, `subdirectory(named:)` synthesizes a missing subdirectory instead of throwing |
| `ext` | `nil` | Value returned by `extension` |

> `MockDirectory` stores `path` verbatim, unlike `DefaultDirectory`, which normalizes it to end in `/`. Don't write a test that asserts one path shape against both.

### Mutable / Recorded State

| Property | Type | Description |
|----------|------|-------------|
| `subdirectories` | `[any Directory]` | Current subdirectories (mutated by `createSubdirectory`, `createSubfolderIfNeeded`, and incoming `copy(to:overwrite:)`) |
| `containedFiles` | `Set<String>` | Current file names (mutated by `createFile` / `deleteFile` / incoming `copyFile`) |
| `fileContents` | `[String: String]` | In-memory file contents by name |
| `movedToParents` | `[String]` | Parent paths passed to `move(to:)` (read-only) |
| `copiedToParents` | `[CopiedDirectory]` | One record per `copy(to:overwrite:)` call on this directory (read-only) |
| `copiedFiles` | `[CopiedFile]` | One record per `copyFile(named:to:overwrite:)` call on this directory (read-only) |
| `deleteCallCount` | `Int` | Number of `delete()` calls (read-only) |

### Copy Records

Both are `Equatable` structs with public memberwise initializers, so tests can compare whole arrays.

```swift
public struct CopiedDirectory: Equatable {
    public let parentPath: String   // path of the parent copied into
    public let overwrite: Bool
}

public struct CopiedFile: Equatable {
    public let name: String
    public let destinationPath: String   // full path of the copied file
    public let overwrite: Bool
}
```

### Behavior Notes

- Every throwing method checks `throwError` first and fails with `NSError(domain: "MockDirectory", code: 4)` when it's set
- Every `named:` method then validates the name — `/` throws `FileSystemError.invalidName` (`containsFile(named:)` returns `false`), matching `DefaultDirectory`
- `subdirectory(named:)`: throws `NSError(code: 1)` if `shouldThrowOnSubdirectory`; returns a matching subdirectory; else, if `autoCreateSubdirectories`, returns a fresh `MockDirectory` (not appended); else throws `NSError(code: 2)`
- `createSubdirectory(named:)` throws `NSError(code: 6)` if a subdirectory with that name already exists, else **appends** a new `MockDirectory` — mirroring `DefaultDirectory`'s throw-if-exists behavior
- `createSubfolderIfNeeded(named:)` returns an existing match or **appends** a new `MockDirectory` to `subdirectories`
- `createFile(named:contents:)` inserts into `containedFiles` + `fileContents`, returns the joined path (`@discardableResult`)
- `copy(to:overwrite:)` records a `CopiedDirectory`, then returns a **deep copy** at `parent.path/name` (nested `MockDirectory` children are copied too, sharing no mutable state). If `parent` is a `MockDirectory`, the copy is appended to its `subdirectories`
- `copyFile(named:to:overwrite:)` throws `NSError(code: 5)` if the name isn't in `containedFiles`; otherwise records a `CopiedFile` and returns `destination.path/name`. If `destination` is a `MockDirectory`, the file name and contents are written into it
- Neither copy method enforces `overwrite` — an existing destination never makes the mock throw; assert on the recorded `overwrite` value instead
- `fileContentsEqual(named:in:)` throws `FileSystemError.fileNotFound` if the name isn't in `containedFiles`; returns `false` if `other.containsFile(named:)` is `false`; else compares `fileContents[name] ?? ""` to `other.readFile(named:)`
- `readFile(named:)` throws `NSError(code: 3)` if the name isn't in `containedFiles`, else returns `fileContents[name] ?? ""`
- `findFiles(withExtension:recursive:)` filters `containedFiles` by exact extension and recurses into `subdirectories`
- The `atRelativePath:` helpers come from the protocol extension, so they walk `MockDirectory` trees with the rules above (e.g. `createSubdirectory(atRelativePath:)` appends each missing level)

### Usage Example

```swift
let dir = MockDirectory(path: "/work", containedFiles: ["a.swift", "b.txt"])
try dir.createFile(named: "c.swift", contents: "// new")

#expect(try dir.readFile(named: "c.swift") == "// new")
#expect(try dir.findFiles(withExtension: "swift", recursive: false).count == 2)
```

---

## Complete Example

```swift
import Testing
@testable import MyFeature
import NnFileTesting

struct ConfigLoaderTests {
    @Test("Reads config from the resolved directory")
    func readsConfig() throws {
        let configDir = MockDirectory(path: "/app", containedFiles: [])
        try configDir.createFile(named: "config.json", contents: #"{"enabled":true}"#)
        let fs = MockFileSystem(directoryMap: ["/app": configDir])

        let loader = ConfigLoader(fileSystem: fs)
        let json = try loader.load(from: "/app")

        #expect(json.contains("enabled"))
        #expect(fs.capturedPaths == ["/app"])
    }

    @Test("Sends the old file to the trash")
    func trashesOldFile() throws {
        let fs = MockFileSystem()
        let cleaner = Cleaner(fileSystem: fs)

        try cleaner.removeStale(at: "/tmp/stale.log")

        #expect(fs.pathToMoveToTrash == "/tmp/stale.log")
    }
}
```

## Common Patterns

### Pattern: Map several paths to distinct directories

```swift
let fs = MockFileSystem(directoryMap: [
    "/a": MockDirectory(path: "/a", containedFiles: ["x.txt"]),
    "/b": MockDirectory(path: "/b", containedFiles: ["y.txt"])
])
```

### Pattern: Force a directory lookup to fail

```swift
// No map and no fallback → directory(at:) throws
let fs = MockFileSystem()
#expect(throws: (any Error).self) { try fs.directory(at: "/missing") }
```

### Pattern: Assert a write happened without disk I/O

```swift
let dir = MockDirectory(path: "/out")
let fs = MockFileSystem(directoryMap: ["/out": dir])
try fs.writeFile(at: "/out/report.txt", contents: "done")
#expect(dir.fileContents["report.txt"] == "done")
```

### Pattern: Verify deletions and moves

```swift
let dir = MockDirectory(path: "/old")
try dir.delete()
try dir.move(to: MockDirectory(path: "/archive"))
#expect(dir.deleteCallCount == 1)
#expect(dir.movedToParents == ["/archive"])
```

### Pattern: Verify copies

```swift
let source = MockDirectory(path: "/src", containedFiles: ["a.txt"])
source.fileContents["a.txt"] = "hello"
let backup = MockDirectory(path: "/backup")

try source.copyFile(named: "a.txt", to: backup, overwrite: false)
try source.copy(to: backup, overwrite: true)

#expect(source.copiedFiles == [CopiedFile(name: "a.txt", destinationPath: "/backup/a.txt", overwrite: false)])
#expect(source.copiedToParents == [CopiedDirectory(parentPath: "/backup", overwrite: true)])
#expect(try backup.fileContentsEqual(named: "a.txt", in: source))
#expect(backup.containsSubdirectory(named: "src"))
```

### Pattern: Directories created through `createDirectory(at:)` resolve afterward

```swift
// No directoryMap needed — the chain is built in the home tree
let fs = MockFileSystem()
try fs.createDirectory(at: "/Users/Home/.config/app")
try fs.writeFile(at: "/Users/Home/.config/app/settings.json", contents: "{}")

#expect(try fs.readFile(at: "/Users/Home/.config/app/settings.json") == "{}")
#expect(fs.capturedPaths.first == "/Users/Home/.config/app")
```

### Pattern: Subdirectory that throws

```swift
let dir = MockDirectory(path: "/locked", shouldThrowOnSubdirectory: true)
#expect(throws: (any Error).self) { try dir.subdirectory(named: "anything") }
```

### Pattern: Make every operation fail

```swift
// Exercise the error path of code under test without staging a specific failure
let dir = MockDirectory(path: "/broken", throwError: true)
#expect(throws: (any Error).self) { try dir.createFile(named: "x.txt", contents: "") }
#expect(throws: (any Error).self) { try dir.findFiles(withExtension: nil, recursive: false) }

let fs = MockFileSystem(throwError: true)
#expect(throws: (any Error).self) { try fs.writeFile(at: "/x.txt", contents: "") }
```

### Pattern: Stub a read by absolute path

```swift
// No directory wiring needed — readFile(at:) consults this map first
let fs = MockFileSystem(fileContentsToRead: ["/etc/app.conf": "debug=1"])
#expect(try fs.readFile(at: "/etc/app.conf") == "debug=1")
#expect(throws: FileSystemError.self) { try fs.readFile(at: "/etc/missing.conf") }
```

### Pattern: Assert a write without configuring any directory

```swift
// writeFile always records, even with nothing mapped
let fs = MockFileSystem()
try fs.writeFile(at: "/out/report.txt", contents: "done")
#expect(fs.writtenFilePath == "/out/report.txt")
#expect(fs.writtenFileContents == "done")
```

---

## Best Practices

- **Inject via `FileSystem` / `Directory`** — Accept the protocols in production types and supply `MockFileSystem` / `MockDirectory` in tests. Never depend on the mocks in production code.
- **Prefer `directoryMap` for clarity** — Exact path-to-directory mapping makes tests readable and order-independent. Use `directoryToLoad` only when any path should resolve to the same directory — it also makes `createDirectory(at:)` return that directory instead of building a chain.
- **`autoCreateSubdirectories` defaults to `false`** — `subdirectory(named:)` throws for an unknown name, which is what keeps `containsSubdirectory(named:)` honest. Opt in with `true` only when a test wants every lookup to succeed.
- **`createSubdirectory` throws on an existing name; `createSubfolderIfNeeded` does not** — Same contract as `DefaultDirectory`. Both append when they create, so assert against whichever your production code calls.
- **Copy mocks record, they don't enforce `overwrite`** — Assert the `overwrite` you passed via `copiedFiles` / `copiedToParents`; test the throw-on-existing behavior against `DefaultDirectory` in a temp folder.
- **Reach for `throwError` before hand-building a failure** — One flag fails every throwing method, which is usually what an error-path test wants. Use `shouldThrowOnSubdirectory` when only the lookup should fail.
- **Mock errors are mostly `NSError`** — The doubles throw `NSError` with domain `"MockFileSystem"` / `"MockDirectory"`, so assert on `any Error`. They throw `FileSystemError` where it matches the real implementation: `invalidName` for a `/` in a `named:` argument, `fileNotFound` from `MockFileSystem.readFile(at:)` and `MockDirectory.fileContentsEqual(named:in:)`.
- **Inspect in-memory state directly** — `containedFiles`, `fileContents`, `capturedPaths`, `pathToMoveToTrash`, `writtenFilePath`, `writtenFileContents`, `movedToParents`, `copiedToParents`, `copiedFiles`, and `deleteCallCount` are your assertions; you rarely need to re-read through the protocol.
