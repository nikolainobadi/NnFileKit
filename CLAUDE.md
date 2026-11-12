# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

`Package.swift` declares minimum deployment targets of macOS 15 and iOS 18.

```bash
swift build
swift test

# Single suite (swift-testing suites are struct names)
swift test --filter DefaultDirectoryTests
swift test --filter MockDirectoryTests
swift test --filter NnConfigManagerTests
```

`.github/workflows/ci.yml` runs `swift build` and `swift test` for pull requests targeting `main`, using the `macos-26` runner and Xcode 26.3.

The checked-in `.build` directory was produced at a different absolute path (`~/Desktop/Nn_FileManagement/NnFileKit`). If a build fails with `PCH was compiled with module cache path ...` / `missing required module 'SwiftShims'`, that stale cache is the cause — run `swift package clean` (or `rm -rf .build`), or build with `--scratch-path <tmp>` to leave the existing cache alone.

## Architecture

Three library products from one package, layered strictly:

- **NnFileKit** — the protocol layer. `FileSystem` handles top-level directory lookup/creation, whole-path read/write, exclusive advisory locking, and trash; `Directory` handles files, subdirectories and relative paths, search, copying, and content comparison. Both protocols inherit `Sendable`. `DefaultFileSystem` / `DefaultDirectory` are the `FileManager`-backed implementations; both are `Sendable` structs. `DefaultFileSystem()` uses `FileManager.default` and takes no initializer arguments.
- **NnConfigKit** — depends on NnFileKit. `NnConfigManager<Config: Codable>` reads/writes a single JSON file plus arbitrary nested files under a config folder. It talks *only* through the `FileSystem`/`Directory` protocols, never `FileManager` directly — that's what makes it testable, so keep new code in this module on the protocol side of the line.
- **NnFileTesting** — depends on and re-exports NnFileKit, so `import NnFileTesting` also exposes NnFileKit's public API. Ships `MockFileSystem` / `MockDirectory` as a real product so downstream packages' test targets can import them. These are `Sendable` structs whose mutable state lives in shared storage guarded by `Synchronization.Mutex`; copying a mock value shares its state and recorded calls.

Key invariants to preserve when touching either implementation pair:

- `DefaultDirectory` normalizes `path` to always end in `/`; `MockDirectory` stores the path verbatim. Tests assert on this difference.
- Both `Directory` implementations must stay behaviorally aligned — `MockDirectory` re-implements `findFiles(withExtension:recursive:)`, `createSubfolderIfNeeded`, etc. in memory. A change to one usually needs the matching change to the other, plus its mirror test file (`Default*Tests.swift` ↔ `Mock*Tests.swift`).
- Every `Directory` API taking `named:` accepts one path component only; use `subdirectory(atRelativePath:)` or `createSubdirectory(atRelativePath:)` for nested paths. Throwing operations reject `/` with `FileSystemError.invalidName`; predicates return `false`.
- `MockDirectory(autoCreateSubdirectories:)` defaults to `false`, so `subdirectory(named:)` throws for unknown names — which keeps `containsSubdirectory(named:)` honest. Pass `true` when a test wants lookups to always succeed.
- Both mocks take `throwError:` to fail every throwing operation at once; `MockDirectory` also has the narrower `shouldThrowOnSubdirectory:`.
- `MockDirectory` records directory copies in `copiedToParents` and file copies in `copiedFiles`; successful copies also populate a `MockDirectory` destination.
- `MockFileSystem.directory(at:)` resolves through `directoryMap`, then its home or root tree, then `directoryToLoad`, and finally throws `FileSystemError.directoryNotFound` (matching `DefaultFileSystem`); `MockDirectory.subdirectory(named:)` likewise throws `directoryNotFound` for an unknown name; lookup and creation record requested paths in `capturedPaths`. `readFile(at:)` checks `fileContentsToRead` first, then falls back to the containing directory, then throws `FileSystemError.fileNotFound`.
- Missing-file reads throw `FileSystemError.fileNotFound` with the full path in `DefaultFileSystem.readFile(at:)` and both `Directory` implementations’ `readFile(named:)`; injected mock failures still use `NSError`.
- `DefaultFileSystem.withExclusiveLock(at:_:)` creates the lock file and blocks on `flock(LOCK_EX)`, releasing the lock when the body returns or throws. The parent directory must already exist. The lock is advisory and not reentrant; leave the lock file in place. Open/lock failures throw `FileSystemError.lockFailed(path:reason:)`; body errors pass through.
- `MockFileSystem.withExclusiveLock(at:_:)` records `lockedPaths` and runs the body without a real file lock, outside its internal mutex so other mock methods can be called. `throwError: true` fails before recording or running the body.
- `MockFileSystem.writeFile(at:contents:)` always records into `writtenFilePath`/`writtenFileContents`, and additionally mutates the containing `MockDirectory` when one is configured.
- `NnConfigManager` creates its config folder through `FileSystem.createDirectory(at:)` and traverses nested config paths with the `Directory` relative-path helpers. A leading `/` in a nested file path is stripped into relative components.
- Config paths default to `DEFAULT_CONFIGLIST_FOLDER_PATH/<projectName>` (`~/.config/NnConfigList/…`), and `configFileName` gets `.json` appended via the private `String.json` helper.

## Testing conventions

- Both test targets use swift-testing (`@Test`, `#expect`) with `struct` suites, running in parallel with no `.serialized`.
- Every suite ends with a `// MARK: - SUT` private extension exposing `makeSUT(...)`; tests never construct types inline.
- Test function names are backtick-escaped full sentences describing behavior (``func `Recursive search includes files in subdirectories`()``), not restatements of the API name.
- `DefaultDirectory`/`DefaultFileSystem` tests hit the real file system inside `NSTemporaryDirectory()/UUID().uuidString`.
- `NnConfigManagerTests` runs against `MockFileSystem`; `NnConfigManagerIntegrationTests` runs against `DefaultFileSystem` with a unique temp config folder per test. Nothing writes to the real `~/.config/NnConfigList`. Keep every test on its own path — a fixed shared path is what would force `.serialized` back in.

## The NnFileKit skill

`Skills/NnFileKit/` holds the Claude Code skill documenting this package's public API. It lives here, not in NobadiScripts, so that an API change and its documentation land in the same PR — a cross-repo convention had no enforcement point and silently failed.

- **Any PR changing `public`/`open`/`package` declarations under `Sources/` must also touch `Skills/`.** There is no CI workflow enforcing this requirement. If a PR genuinely changes no documented behavior, apply the `skip-skill-check` label to waive it.
- `Skills/NnFileKit/.claude-plugin/plugin.json` **deliberately has no `version` field.** Git-based marketplace sources key their cache by commit sha, so a hand-typed version is a number nothing verifies — exactly the staleness this arrangement exists to remove. Do not reintroduce it.
- SwiftPM ignores `Skills/`; it is not a target and never will be.

### Releasing

The marketplace entry in `nikolainobadi/nn-swift-skills` pins `ref` to a **release tag**, so:

- **Skill edits ship on release, not on merge.** Merging a doc correction changes nothing for consumers until the next tag. This surprises people — it is the deliberate trade for docs that always match a shipped version.
- Updating the marketplace `ref` to the new release tag is a manual cross-repo step; this repository has no `skill-ref-bump` workflow. **An unbumped `ref` serves the previous release's docs forever — nothing errors and nothing warns.**

## Release notes

`CHANGELOG.md` follows Keep a Changelog + SemVer, with compare links maintained at the bottom. Add entries under `## [Unreleased]` for user-visible changes.
