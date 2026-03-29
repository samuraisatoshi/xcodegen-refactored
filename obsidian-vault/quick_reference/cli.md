---
title: CLI Quick Reference
updated: 2026-03-29
---

# XcodeGen CLI — Quick Reference

## Global Flags (all commands)

| Flag | Description |
|------|-------------|
| `--spec` / `-s` | Path to spec file(s), comma-separated. Default: `project.yml` |
| `--project-root` / `-r` | Project root directory |
| `--quiet` / `-q` | Suppress informational output |
| `--no-env` / `-n` | Disable environment variable expansion |
| `--llm-output` | Output in TOON format (LLM/agent consumption) |
| `--enriched-output` | Output in rich terminal format (box-drawing, icons) |
| `--guide [--lang en\|pt-br\|es]` | Print structured JSON documentation and exit |

## Commands

### generate
```bash
xcodegen generate [--spec path] [--project dir] [--use-cache] [--dry-run] [--only-plists]
```
- `--dry-run`: diff in memory, print JSON, no files written
- `--use-cache` / `--cache-path`: skip generation if spec unchanged

### validate
```bash
xcodegen validate [--spec path]
```
Output: `{ "valid": bool, "errors": [...], "warnings": [...] }`
Exit code 1 if invalid.

### query
```bash
xcodegen query --type targets|target|sources|settings|dependencies [--name TARGET] [--config CONFIG]
```

| Type | Requires | Output |
|------|----------|--------|
| `targets` | — | Array of `{name, type, platform}` |
| `target` | `--name` | Full target detail |
| `sources` | `--name` | Array of source paths |
| `settings` | `--name` | Build settings map (optional `--config`) |
| `dependencies` | `--name` | Array of `{type, reference}` |

### watch
```bash
xcodegen watch [--spec path]
```
Auto-regenerates on spec file changes. Debounced 300ms. macOS only.

### patch
```bash
xcodegen patch --target NAME --operation add-source|add-dependency|set-setting [--value VALUE]
```
Edits the spec semantically and regenerates atomically.

### infer
```bash
xcodegen infer --project path/to/App.xcodeproj [--output project.yml]
```
Generates a `project.yml` from an existing `.xcodeproj`.

### dump
```bash
xcodegen dump [--spec path] [--type json|yaml|raw-json] [--file path]
```
Outputs the resolved spec. Upstream command.

## Output Format Examples

```bash
# Plain (default)
xcodegen validate

# TOON for LLM agents
xcodegen query --type targets --llm-output

# Rich terminal
xcodegen generate --enriched-output

# Structured docs for MCP
xcodegen validate --guide
xcodegen query --guide --lang pt-br
```
