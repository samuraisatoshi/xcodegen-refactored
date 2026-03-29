---
title: Architecture — File Map
updated: 2026-03-29
---

# Architecture — File Map

## XcodeGenKit — PBXProjGenerator (decomposed)

| File | Lines | Responsibility |
|------|-------|----------------|
| `PBXProjGenerator.swift` | 97 | Orchestrator — `generate()` 38L pure coordination |
| `+BuildPhases.swift` | 80 | Build phase generation |
| `+DependencyHelpers.swift` | 159 | Dependency helpers |
| `+Helpers.swift` | 199 | Attributes, group ordering |
| `+ProjectSetup.swift` | 194 | Init: stubs, package refs, product/subproject groups, finalize |
| `+TargetContext.swift` | 28 | Per-target generation context |
| `+TargetDependencies.swift` | 453 | Dependencies between targets |
| `+TargetGeneration.swift` | 393 | Full target generation, aggregate targets |
| `+TargetHelpers.swift` | 103 | Internal target helpers |

## XcodeGenKit — SourceGenerator (decomposed)

| File | Lines | Responsibility |
|------|-------|----------------|
| `SourceGenerator.swift` | 186 | Init + entry point |
| `+FileReferences.swift` | 129 | File reference resolution |
| `+Groups.swift` | 176 | Xcode group creation |
| `+SourceFiles.swift` | 450 | Source traversal |

## ProjectSpec — Scheme (decomposed)

| File | Lines | Responsibility |
|------|-------|----------------|
| `Scheme.swift` | 441 | Pure model |
| `Scheme+Codable.swift` | 659 | JSON serialization |

## New types (EP-001)

| File | Lines | Purpose |
|------|-------|---------|
| `CarthageResolving.swift` | 12 | DIP protocol — replaces direct `CarthageDependencyResolver` dependency |
| `ProjectDiff.swift` | 77 | In-memory vs on-disk pbxproj diff for `--dry-run` |

## New types (EP-002)

| File | Lines | Purpose |
|------|-------|---------|
| `TOONEncoder.swift` | 179 | Encodes `[String: Any]` to TOON format |
| `RichFormatter.swift` | 180 | Box-drawing tables and icons for `--enriched-output` |

## XcodeGenCLI — Commands

| File | Lines | Command |
|------|-------|---------|
| `ProjectCommand.swift` | 123 | Base: `--spec`, `--quiet`, `--no-env`, `--llm-output`, `--enriched-output`, `--guide` |
| `GenerateCommand.swift` | 175 | `generate` + `--dry-run` |
| `ValidateCommand.swift` | 129 | `validate` |
| `QueryCommand.swift` | 234 | `query` |
| `WatchCommand.swift` | 151 | `watch` (Darwin-only) |
| `PatchCommand.swift` | 176 | `patch` |
| `InferCommand.swift` | 130 | `infer` |
| `DumpCommand.swift` | 68 | `dump` (upstream) |
| `CacheCommand.swift` | 48 | `cache` (upstream) |
