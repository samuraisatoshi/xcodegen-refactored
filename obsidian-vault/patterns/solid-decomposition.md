---
title: SOLID Decomposition Pattern
updated: 2026-03-29
---

# SOLID Decomposition Pattern

## Naming Convention

```
TypeName.swift                  ← core: init, public API, orchestration only
TypeName+Responsibility.swift   ← focused extension: one bounded concern
```

The `+Responsibility` suffix is both human-readable and machine-discoverable. An LLM agent can `glob("**/*.swift")` and infer where to look before reading any file.

## When to decompose

Decompose a file when:
- It exceeds ~300 lines with multiple distinct concerns
- An LLM agent would need to read the entire file to find one function
- The file has multiple independent "phases" (setup → process → finalize)

## Applied Examples

### PBXProjGenerator (1724 → 97L)

```
generate() was 280L doing everything. Now 38L orchestrating:

createTargetStubs()           → +ProjectSetup
setupPackageReferences()      → +ProjectSetup
setupProductAndSubprojectGroups() → +ProjectSetup
finalizeProject()             → +ProjectSetup
generateTarget()              → +TargetGeneration
generateAggregateTarget()     → +TargetGeneration
generateTargetDependency()    → +TargetDependencies
makeDerivedFrameworkGroups()  → +ProjectSetup
```

### SourceGenerator (923 → 186L)

```
getFileGroups()       → +Groups
getFileReference()    → +FileReferences
getSourceFiles()      → +SourceFiles
```

## Dependency Inversion (DIP)

Replace concrete class dependency with protocol:

```swift
// Before
let carthageResolver: CarthageDependencyResolver

// After
let carthageResolver: CarthageResolving  // protocol in CarthageResolving.swift
```

Benefits:
- Tests inject mocks without subclassing
- Implementation swappable without touching the dependent
- Protocol is 12L — agent understands contract without reading 400L implementation

## IUO Elimination

```swift
// Before — crash risk, unclear init flow
var sourceGenerator: SourceGenerator!

// After — explicit, safe
let sourceGenerator: SourceGenerator
```

## Performance Pattern: Static Cache

```swift
// Before — NSRegularExpression compiled on every call
let regex = try? NSRegularExpression(pattern: "...", options: ...)

// After — compiled once per process, deterministic input
private static let cache: [Key: NSRegularExpression] = {
    // build once at type initialization
}()
```
