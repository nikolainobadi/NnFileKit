---
name: NnFileKit
description: NnFileKit Swift API reference for file system access. USE WHEN importing NnFileKit, reading or writing files from Swift, navigating directories, using the FileSystem or Directory protocols, DefaultFileSystem, DefaultDirectory, moveToTrash, findFiles, file system error handling, or MockFileSystem / MockDirectory in tests.
user-invocable: true
---

# NnFileKit

Lightweight Swift package for file system access with a protocol-based, fully mockable design.

**Dependency:** `https://github.com/nikolainobadi/NnFileKit.git` (from `0.7.0`)
**Platforms:** macOS | **Swift:** 6.0

> This skill lives in the package repo at `Skills/NnFileKit/` and ships pinned to a release tag, so it describes the API as of that release.

## Context Files

| File | Purpose | Load When |
|------|---------|-----------|
| `ApiReference.md` | `FileSystem`, `Directory`, `DefaultFileSystem`, `DefaultDirectory`, `FileSystemError` — full API with behavioral docs | Reading/writing files, navigating directories, choosing between `FileSystem` and `Directory` operations, handling errors |
| `TestingReference.md` | `MockFileSystem`, `MockDirectory` — in-memory test doubles with complete examples | Writing tests for code that uses `FileSystem` / `Directory` |

## Quick Reference

### Production
- **FileSystem** — Top-level protocol: `homeDirectory`, `currentDirectory`, `desktopDirectory()`, `directory(at:)`, `readFile(at:)`, `writeFile(at:contents:)`, `moveToTrash(at:)`
- **Directory** — Per-directory protocol: `path`/`name`/`extension`/`subdirectories`, plus `createFile`, `readFile(named:)`, `createSubdirectory`, `createSubfolderIfNeeded`, `findFiles(withExtension:recursive:)`, `move(to:)`, `delete()`
- **DefaultFileSystem** — `FileManager`-backed production implementation (`struct`, `Sendable`); `init(fileManager: .default)`
- **DefaultDirectory** — `FileManager`-backed directory (`struct`, `Sendable`); normalizes paths with a trailing slash; static `.temporary` / `.home`
- **FileSystemError** — `enum` with `.directoryNotFound(String)` / `.fileNotFound(String)`
- `FileSystem` is the absolute-path entry point; `Directory` is the working handle you navigate from there

### Testing
- **MockFileSystem** — `final class` conforming to `FileSystem`; in-memory, records `capturedPaths`, `pathToMoveToTrash`, `writtenFilePath` / `writtenFileContents`; resolves directories via `directoryMap` / `directoryToLoad` and reads via `fileContentsToRead`
- **MockDirectory** — `final class` conforming to `Directory`; in-memory `containedFiles` / `fileContents`, records `movedToParents` / `deleteCallCount`; `subdirectory(named:)` throws for unknown names unless `autoCreateSubdirectories: true`
- Both mocks take `throwError: true` to fail every throwing operation at once

### Sibling product (not covered here)
- **NnConfigKit** — same package ships `NnConfigManager<Config: Codable>` for JSON-based config persistence. Distinct concern; warrants its own explainer.

## Examples

- "How do I read a file at an absolute path?" -> Loads ApiReference.md
- "What's the difference between FileSystem and Directory?" -> Loads ApiReference.md
- "How do I find all `.swift` files in a folder recursively?" -> Loads ApiReference.md
- "How do I mock the file system in tests?" -> Loads TestingReference.md
- "How do I assert a file was written without touching disk?" -> Loads TestingReference.md
- "How do I test what happens when a file write fails?" -> Loads TestingReference.md
