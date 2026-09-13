# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
swift build
swift test

# Single suite (swift-testing suites are struct names)
swift test --filter DefaultDirectoryTests
swift test --filter MockDirectoryTests
swift test --filter NnConfigManagerTests
```

The checked-in `.build` directory was produced at a different absolute path (`~/Desktop/Nn_FileManagement/NnFileKit`). If a build fails with `PCH was compiled with module cache path ...` / `missing required module 'SwiftShims'`, that stale cache is the cause — run `swift package clean` (or `rm -rf .build`), or build with `--scratch-path <tmp>` to leave the existing cache alone.

## Architecture

Three library products from one package, layered strictly:

- **NnFileKit** — the protocol layer. `FileSystem` handles top-level directory lookup/creation, whole-path read/write, and trash; `Directory` handles files, subdirectories and relative paths, search, copying, and content comparison. `DefaultFileSystem` / `DefaultDirectory` are the `FileManager`-backed implementations; both are `Sendable` structs.
- **NnConfigKit** — depends on NnFileKit. `NnConfigManager<Config: Codable>` reads/writes a single JSON file plus arbitrary nested files under a config folder. It talks *only* through the `FileSystem`/`Directory` protocols, never `FileManager` directly — that's what makes it testable, so keep new code in this module on the protocol side of the line.
- **NnFileTesting** — depends on NnFileKit. Ships `MockFileSystem` / `MockDirectory` as a real product so downstream packages' test targets can import them. These are `final class` (mutable recorded state) while the defaults are structs.

Key invariants to preserve when touching either implementation pair:

- `DefaultDirectory` normalizes `path` to always end in `/`; `MockDirectory` stores the path verbatim. Tests assert on this difference.
- Both `Directory` implementations must stay behaviorally aligned — `MockDirectory` re-implements `findFiles(withExtension:recursive:)`, `createSubfolderIfNeeded`, etc. in memory. A change to one usually needs the matching change to the other, plus its mirror test file (`Default*Tests.swift` ↔ `Mock*Tests.swift`).
- Every `Directory` API taking `named:` accepts one path component only; use `subdirectory(atRelativePath:)` or `createSubdirectory(atRelativePath:)` for nested paths. Throwing operations reject `/` with `FileSystemError.invalidName`; predicates return `false`.
- `MockDirectory(autoCreateSubdirectories:)` defaults to `false`, so `subdirectory(named:)` throws for unknown names — which keeps `containsSubdirectory(named:)` honest. Pass `true` when a test wants lookups to always succeed.
- Both mocks take `throwError:` to fail every throwing operation at once; `MockDirectory` also has the narrower `shouldThrowOnSubdirectory:`.
- `MockDirectory` records directory copies in `copiedToParents` and file copies in `copiedFiles`; successful copies also populate a `MockDirectory` destination.
- `MockFileSystem.directory(at:)` resolves through `directoryMap`, then its home or root tree, then `directoryToLoad`, and finally throws; lookup and creation record requested paths in `capturedPaths`. `readFile(at:)` checks `fileContentsToRead` first, then falls back to the containing directory, then throws `FileSystemError.fileNotFound`.
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

- **Any PR changing `public`/`open`/`package` declarations under `Sources/` must also touch `Skills/`.** The `skill-docs` workflow enforces this. If a PR genuinely changes no documented behavior, apply the `skip-skill-check` label to waive it.
- `Skills/NnFileKit/.claude-plugin/plugin.json` **deliberately has no `version` field.** Git-based marketplace sources key their cache by commit sha, so a hand-typed version is a number nothing verifies — exactly the staleness this arrangement exists to remove. Do not reintroduce it.
- SwiftPM ignores `Skills/`; it is not a target and never will be.

### Releasing

The marketplace entry in `nikolainobadi/nn-swift-skills` pins `ref` to a **release tag**, so:

- **Skill edits ship on release, not on merge.** Merging a doc correction changes nothing for consumers until the next tag. This surprises people — it is the deliberate trade for docs that always match a shipped version.
- The `skill-ref-bump` workflow fires on tag push and opens a PR against the marketplace to move `ref` to the new tag. If that automation is ever removed, the bump becomes a manual cross-repo step. **An unbumped `ref` serves the previous release's docs forever — nothing errors and nothing warns.**

`skill-ref-bump` needs a `MARKETPLACE_TOKEN` repo secret: a fine-grained PAT with `contents:write` and `pull-requests:write` on `nikolainobadi/nn-swift-skills` and nothing else. It is **shared** with the other package repos publishing to that marketplace (`SwiftPickerKit`, `NnArgumentParser`), so rotation is fan-out — expiry breaks the bump in every repo holding it, and each needs the secret set again. A failed bump run complaining about the token means *rotate the shared token*, not *this repo's workflow is broken*. The token is stored locally under `~/Coding/Service-or-Auth-Keys/`; GitHub secrets are write-only, so it cannot be recovered from another repo.

## Release notes

`CHANGELOG.md` follows Keep a Changelog + SemVer, with compare links maintained at the bottom. Add entries under `## [Unreleased]` for user-visible changes.
