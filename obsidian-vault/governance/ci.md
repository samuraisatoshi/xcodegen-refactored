---
title: CI Configuration
updated: 2026-03-29
---

# CI Configuration

File: `.github/workflows/ci.yml`

## Jobs

### macOS (`macos-15`, Xcode 16.2)
1. Resolve packages
2. `swift build`
3. `swift test` (110 tests)
4. `scripts/gen-fixtures.sh` — regenerate fixtures using built binary
5. `scripts/diff-fixtures.sh` — fail if generated fixtures differ from committed

### Linux (`ubuntu-latest`)
1. `swift test --enable-test-discovery`

## Known Limitations

### Build fixtures removed
`scripts/build-fixtures.sh` compiles the TestProject fixtures via `xcodebuild` and requires the iOS simulator runtime. This is not pre-installed on the `macos-15`/Xcode 16.2 runner. Step removed — `swift test` and `diff-fixtures` provide sufficient coverage.

### WatchCommand — Darwin only
`WatchCommand` uses `DispatchSourceFileSystemObject` and `O_EVTONLY` (Darwin APIs). Guarded with `#if canImport(Darwin)` — Linux build returns `WatchUnsupportedError`.

## Fixture Stability Notes

The SPM fixture (`Tests/Fixtures/SPM/`) previously referenced the repo root via `path: ../../..`, causing the generated fixture to embed the directory name. Fixed by replacing with a stable `LocalPackage/` inside the fixture directory.

If `diff-fixtures.sh` fails in CI after a spec or generator change, run locally:
```bash
scripts/gen-fixtures.sh
git diff Tests/Fixtures/
# review, then commit
```
