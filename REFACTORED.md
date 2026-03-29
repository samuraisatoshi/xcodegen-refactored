# XcodeGen — Refactored Fork

**Fork:** [samuraisatoshi/xcodegen-refactored](https://github.com/samuraisatoshi/xcodegen-refactored)
**Upstream:** [yonaskolb/XcodeGen](https://github.com/yonaskolb/XcodeGen)
**Base version:** 2.45.3
**Branch base:** `master` (2026-03-28)

---

## What this fork adds

This fork applies two independent layers of improvement on top of the upstream XcodeGen:

1. **SOLID/DDD/Performance refactoring** — internal code quality improvements with no external behaviour change
2. **Agent & Developer Experience** — new CLI commands and output formats designed for automation, LLM agents, and CI pipelines

---

## EP-001 — SOLID / DDD / Performance Refactoring

### CD-001 — NSRegularExpression cache in SourceGenerator

`makeDestinationFilters` was compiling the same `NSRegularExpression` on every call — potentially thousands of times in large projects. The expression is deterministic, so it is now compiled once per process via a static cache.

### CD-002 — Decompose PBXProjGenerator

`PBXProjGenerator.swift` (1724 lines) was split into focused extension files:

| File | Responsibility |
|------|---------------|
| `PBXProjGenerator.swift` | Orchestrator (1308L) |
| `PBXProjGenerator+BuildPhases.swift` | Build phase generation |
| `PBXProjGenerator+DependencyHelpers.swift` | Dependency resolution helpers |
| `PBXProjGenerator+Helpers.swift` | Attribute and group ordering helpers |

### CD-003 — CarthageResolving protocol + remove IUO

`PBXProjGenerator` previously depended directly on the concrete `CarthageDependencyResolver`. A `CarthageResolving` protocol was introduced (Dependency Inversion), allowing alternative implementations and proper test mocking without subclassing.

The `var sourceGenerator: SourceGenerator!` Implicitly Unwrapped Optional was replaced with `let sourceGenerator: SourceGenerator`, making the initialisation flow explicit and removing a source of silent crashes.

### CD-004 — Include path traversal validation (security)

`SpecFile` accepted arbitrary include paths (e.g. `../../etc/passwd`) with no boundary check. In CI/CD environments, a malicious include could exfiltrate environment variables into the generated `.xcodeproj`. A `validateIncludePaths` option was added (opt-in, default `false` for backwards compatibility):

```yaml
options:
  validateIncludePaths: true
```

### CD-005 — Decompose SourceGenerator

`SourceGenerator.swift` (923 lines) was split into focused extension files:

| File | Responsibility |
|------|---------------|
| `SourceGenerator.swift` | Init + main entry (186L) |
| `SourceGenerator+FileReferences.swift` | File reference resolution |
| `SourceGenerator+Groups.swift` | Xcode group creation |
| `SourceGenerator+SourceFiles.swift` | Source tree traversal |

### CD-006 — Extract Scheme+Codable

`Scheme.swift` (1095 lines) was split: the pure model remains in `Scheme.swift` (441L) and all JSON serialisation was extracted to `Scheme+Codable.swift` (659L).

### CD-007 — Extract TargetGenerationContext

A `TargetGenerationContext` value type was extracted from `generateTarget`, replacing a long parameter list with a structured context object and making the function signature readable.

### CD-008 — Extract Scheme factory init

Four local functions inside `generateScheme` were promoted to private methods. The Scheme factory initialiser was extracted to `Scheme+XcodeGenKit.swift`.

### CD-009 — Decompose SpecValidation by domain

`SpecValidation.swift` was split into domain-specific files (`SpecValidation+Targets.swift`, `SpecValidation+Settings.swift`, etc.), each responsible for a single validation domain.

---

## EP-002 — Agent & Developer Experience

### New CLI commands

#### `xcodegen validate`

Validates the project spec without generating a project. Returns structured JSON with `valid`, `errors`, and `warnings` arrays. Distinguishes `parsing` vs `validation` stages. Exits 0 when valid, 1 on errors.

```bash
xcodegen validate --spec project.yml
```

```json
{
  "valid": true,
  "errors": [],
  "warnings": []
}
```

#### `xcodegen query`

Queries the resolved spec and returns focused JSON. Supports five query types:

```bash
xcodegen query --type targets
xcodegen query --type target --name MyApp
xcodegen query --type sources --name MyApp
xcodegen query --type settings --name MyApp --config Release
xcodegen query --type dependencies --name MyApp
```

#### `xcodegen generate --dry-run`

Generates the project in memory, diffs against the existing project (UUID-stable by target name and file path), and emits a JSON summary — without writing any files.

```json
{
  "changed": true,
  "targets_added": [],
  "targets_removed": [],
  "files_added": ["Sources/NewFeature.swift"],
  "files_removed": []
}
```

#### `xcodegen watch`

Auto-regenerates the project whenever the spec file (or any included file) changes. Useful during active development.

```bash
xcodegen watch --spec project.yml
```

#### `xcodegen patch`

Semantically edits the spec and atomically regenerates the project. Supports three operations:

```bash
xcodegen patch --operation add-source --target MyApp --path Sources/NewFile.swift
xcodegen patch --operation add-dependency --target MyApp --sdk CoreML.framework
xcodegen patch --operation set-setting --target MyApp --key SWIFT_VERSION --value 5.9
```

Add `--dry-run` to print the modified YAML without writing or regenerating.

#### `xcodegen infer`

Reads an existing `.xcodeproj` and generates a `project.yml` from it. Useful for migrating projects to XcodeGen.

```bash
xcodegen infer                          # auto-detects .xcodeproj in cwd
xcodegen infer --xcodeproj MyApp.xcodeproj
xcodegen infer --dry-run                # print YAML to stdout
```

### New output flags (all commands)

#### `--llm-output`

Outputs in **TOON** (Token-Optimized Object Notation) format — ~40% fewer tokens than JSON for tabular data, designed for LLM agent consumption.

```
targets[3]{name,platform,type}:
  MyApp,iOS,application
  MyTests,iOS,bundle.unit-test
  Framework,iOS,framework
```

#### `--enriched-output`

Outputs in rich terminal format with box-drawing characters, Unicode status icons, and auto-sized tables.

```
┌────────────────────────────────────────┐
│  ○  targets (3)                        │
├─────────────────┬──────────────┬───────┤
│  Name           │  Type        │  Plt  │
├─────────────────┼──────────────┼───────┤
│  MyApp          │  application │  iOS  │
│  MyTests        │  unit-test   │  iOS  │
│  Framework      │  framework   │  iOS  │
└─────────────────┴──────────────┴───────┘
```

#### `--guide`

Prints structured JSON documentation for the command — useful for LLM agents and MCP servers discovering available tools at runtime. Supports `--lang en|pt-br|es`.

---

## Why SOLID/DDD for an LLM-assisted codebase

Large files hurt LLM-assisted development in several ways:

- **Token cost** — reading an 1800-line file to answer a question about 30 lines wastes context
- **Hallucination risk** — the model must hold more unrelated context
- **Destructive edits** — a patch to one concern may silently break adjacent code

After this refactor, each file has a single clear responsibility. An agent that needs to change how Xcode groups are created reads `SourceGenerator+Groups.swift` (176L), not a 923-line file.

The `Type+Responsibility.swift` naming convention is machine-readable: `glob("**/*.swift")` gives a structural map of the codebase before reading a single line.

---

## What did not change

- No external behaviour was altered
- The public API of `ProjectSpec` and `XcodeGenKit` is identical to upstream
- All upstream tests pass
- Backwards compatible with existing spec files (`validateIncludePaths` is opt-in)
- No new dependencies were added

---

## Running

```bash
swift build
swift test

# Validate a spec
.build/debug/xcodegen validate --spec project.yml

# Query targets in TOON format
.build/debug/xcodegen query --type targets --llm-output

# Generate with dry-run diff
.build/debug/xcodegen generate --spec project.yml --dry-run
```
