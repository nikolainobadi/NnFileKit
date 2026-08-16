# NnFileKit Testing Reference

In-memory test doubles for file system access. Import `NnFileTesting` alongside `NnFileKit`. Nothing touches disk — `MockFileSystem` and `MockDirectory` hold files and folders in memory and record the calls made against them.

---

## Class: MockFileSystem

In-memory `FileSystem` test double. Resolves directories from a preconfigured map (or a single fallback directory) and records every path it's asked about.

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
| `directoryToLoad` | `nil` | Single fallback directory returned by `directory(at:)` when no map entry matches |
| `directoryMap` | `nil` | Exact `path → Directory` lookup for `directory(at:)` |
| `desktop` | `nil` | Value returned by `desktopDirectory()`; defaults to `home/Desktop` |
| `fileContentsToRead` | `[:]` | Exact `path → contents` stub consulted first by `readFile(at:)` |
| `throwError` | `false` | When `true`, **every** operation throws — the blanket error-injection switch |

### Recorded State

| Property | Type | Description |
|----------|------|-------------|
| `capturedPaths` | `[String]` | Every path passed to `directory(at:)`, in order (read-only) |
| `pathToMoveToTrash` | `String?` | The last path passed to `moveToTrash(at:)` (read-only) |
| `writtenFilePath` | `String?` | The last path passed to `writeFile(at:contents:)` (read-only) |
| `writtenFileContents` | `String?` | The last contents passed to `writeFile(at:contents:)` (read-only) |

### Resolution Behavior

- `directory(at:)` records the path, then: returns the `directoryMap[path]` match if present → else `directoryToLoad` if set → else throws `NSError(domain: "MockFileSystem", code: 1)`
- `readFile(at:)` returns `fileContentsToRead[path]` if present → else resolves the containing directory and reads through it → else throws `FileSystemError.fileNotFound(path)`
- `writeFile(at:contents:)` **always** records into `writtenFilePath` / `writtenFileContents`, and *additionally* mutates the containing `MockDirectory` when one is configured. It does not throw for an unconfigured directory
- `moveToTrash(at:)` records the path in `pathToMoveToTrash`
- `throwError: true` short-circuits all of the above. `directory(at:)` throws *before* recording, so `capturedPaths` stays empty

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
| `subdirectories` | `[any Directory]` | Current subdirectories (mutated by `createSubdirectory` and `createSubfolderIfNeeded`) |
| `containedFiles` | `Set<String>` | Current file names (mutated by `createFile` / `deleteFile`) |
| `fileContents` | `[String: String]` | In-memory file contents by name |
| `movedToParents` | `[String]` | Parent paths passed to `move(to:)` (read-only) |
| `deleteCallCount` | `Int` | Number of `delete()` calls (read-only) |

### Behavior Notes

- Every throwing method checks `throwError` first and fails with `NSError(domain: "MockDirectory", code: 4)` when it's set
- `subdirectory(named:)`: throws `NSError(code: 1)` if `shouldThrowOnSubdirectory`; returns a matching subdirectory; else, if `autoCreateSubdirectories`, returns a fresh `MockDirectory` (not appended); else throws `NSError(code: 2)`
- `createSubdirectory(named:)` delegates to `createSubfolderIfNeeded(named:)` — so it **appends**, and is idempotent rather than mirroring `DefaultDirectory`'s throw-if-exists behavior
- `createSubfolderIfNeeded(named:)` returns an existing match or **appends** a new `MockDirectory` to `subdirectories`
- `createFile(named:contents:)` inserts into `containedFiles` + `fileContents`, returns the joined path (`@discardableResult`)
- `readFile(named:)` throws `NSError(code: 3)` if the name isn't in `containedFiles`, else returns `fileContents[name] ?? ""`
- `findFiles(withExtension:recursive:)` filters `containedFiles` by exact extension and recurses into `subdirectories`

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
- **Prefer `directoryMap` for clarity** — Exact path-to-directory mapping makes tests readable and order-independent. Use `directoryToLoad` only when any path should resolve to the same directory.
- **`autoCreateSubdirectories` defaults to `false`** — `subdirectory(named:)` throws for an unknown name, which is what keeps `containsSubdirectory(named:)` honest. Opt in with `true` only when a test wants every lookup to succeed.
- **Both `createSubdirectory` and `createSubfolderIfNeeded` append** — Either one mutates `subdirectories`, so assert against whichever your production code calls.
- **Reach for `throwError` before hand-building a failure** — One flag fails every throwing method, which is usually what an error-path test wants. Use `shouldThrowOnSubdirectory` when only the lookup should fail.
- **Mock errors are `NSError`, with one exception** — The doubles throw `NSError` with domain `"MockFileSystem"` / `"MockDirectory"`, so assert on `any Error`. The exception is `MockFileSystem.readFile(at:)`, which throws `FileSystemError.fileNotFound` to match `DefaultFileSystem`.
- **Inspect in-memory state directly** — `containedFiles`, `fileContents`, `capturedPaths`, `pathToMoveToTrash`, `writtenFilePath`, `writtenFileContents`, `movedToParents`, and `deleteCallCount` are your assertions; you rarely need to re-read through the protocol.
