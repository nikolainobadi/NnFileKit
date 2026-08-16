# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.0] - 2026-08-16

### Added
- Add `throwError` flag to `MockFileSystem` and `MockDirectory` for exercising error paths
- Add `fileContentsToRead` to `MockFileSystem` for stubbing `readFile(at:)` by path
- Add `writtenFilePath` and `writtenFileContents` to `MockFileSystem` for verifying writes

### Changed
- `MockDirectory.createSubdirectory(named:)` now registers the new subdirectory in `subdirectories`
- **Breaking:** `MockDirectory(autoCreateSubdirectories:)` now defaults to `false`, so `subdirectory(named:)` throws for unknown names instead of synthesizing one
- The `NnFileKit` Claude Code skill now ships from this repo (`Skills/NnFileKit/`) via the `nn-swift-skills` marketplace instead of `nelix-swift-tools`. Existing installs must be reinstalled from the new marketplace

### Fixed
- Add missing `NnFileTesting` dependency to the `NnFileKitTests` target, which prevented the test suite from compiling
- `MockFileSystem.readFile(at:)` now throws `FileSystemError.fileNotFound` instead of an opaque `NSError`

## [0.6.0] - 2026-03-22

### Added
- Add NnConfigKit module for managing JSON configuration files with type-safe read/write support
- Add `JSONEncoder.prettyOutput()` convenience method for formatted JSON encoding

### Fixed
- Fix typo in README dependency name (`NnFileTesing` → `NnFileTesting`)

[Unreleased]: https://github.com/nikolainobadi/NnFileKit/compare/0.7.0...HEAD
[0.7.0]: https://github.com/nikolainobadi/NnFileKit/compare/0.6.0...0.7.0
[0.6.0]: https://github.com/nikolainobadi/NnFileKit/compare/0.5.0...0.6.0
