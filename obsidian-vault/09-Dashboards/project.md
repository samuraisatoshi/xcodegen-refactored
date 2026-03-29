---
title: Project Status
updated: 2026-03-29
---

# XcodeGen Refactored — Project Status

## Release

| Item | Value |
|------|-------|
| Version | v0.1.0 |
| Base | yonaskolb/XcodeGen v2.45.3 |
| Repo | https://github.com/samuraisatoshi/xcodegen-refactored |
| Release | https://github.com/samuraisatoshi/xcodegen-refactored/releases/tag/v0.1.0 |

## CI

| Job | Status |
|-----|--------|
| macOS (Xcode 16.2) | ✅ passing |
| Linux | ✅ passing |

Badge: `https://github.com/samuraisatoshi/xcodegen-refactored/actions/workflows/ci.yml/badge.svg`

### CI Steps
- Resolve → Build → Test (`swift test`, 110 tests) → Gen fixtures → Check fixtures
- Build fixtures removed: requires iOS simulator not available on runner

## Upstream PRs (yonaskolb/XcodeGen)

| PR | Title | Status |
|----|-------|--------|
| #1610 | feat(generate): add --dry-run flag | OPEN |
| #1611 | feat(validate): add validate command | OPEN |
| #1612 | feat(query): add query command | OPEN |

Branches on `samuraisatoshi/XcodeGen`:
- `feat/generate-dry-run`
- `feat/validate-command`
- `feat/query-command`

## Tests

110 tests, 0 failures (75 upstream + 35 new)

New test suites:
- `TOONEncoderTests` (19 tests)
- `ValidateCommandLogicTests` (3 tests)
- `QueryCommandLogicTests` (6 tests)
- `XcodeProjInferrerTests` (3 tests)
- `XcodeSpecPatcherTests` (4 tests)
