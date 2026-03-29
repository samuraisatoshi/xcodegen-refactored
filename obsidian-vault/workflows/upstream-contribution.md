---
title: Upstream Contribution Workflow
updated: 2026-03-29
---

# Upstream Contribution Workflow

## Strategy

Fork chain:
```
yonaskolb/XcodeGen (upstream)
    └── samuraisatoshi/XcodeGen (fork — PR staging)
            └── samuraisatoshi/xcodegen-refactored (this repo)
```

PRs to upstream are opened from `samuraisatoshi/XcodeGen` branches, not from `xcodegen-refactored` directly.

## What goes upstream vs stays in fork

| Feature | Upstream candidate? | Reason |
|---------|--------------------|----|
| `--dry-run` | ✅ Yes | Pure additive, no deps |
| `validate` command | ✅ Yes | Stripped of `--guide` infra |
| `query` command | ✅ Yes | Stripped of `--guide`/TOON/enriched |
| `watch` command | Maybe | Darwin-only, debate on value |
| `patch` / `infer` | Later | More opinionated, needs discussion |
| `--llm-output` / TOON | Fork-only | Too experimental for upstream |
| `--enriched-output` | Fork-only | Aesthetic, not upstream priority |
| `--guide` infra | Fork-only | MCP/agent specific |
| SOLID decomposition | Maybe | Large diff, upstream may resist |

## Creating a Clean PR Branch

Use a git worktree to avoid contamination from untracked files (`.claude/`, `.jarvis/`, `obsidian-vault/`):

```bash
# Create isolated worktree from upstream master
WTDIR=$(mktemp -d)/upstream-prs
git worktree add "$WTDIR" origin/master -b feat/my-feature

# Work in worktree
cd "$WTDIR"
# copy only the relevant files, no git add -A

git add Sources/... # specific files only
git commit -m "feat: ..."
git push myfork feat/my-feature

# Open PR
gh pr create --repo yonaskolb/XcodeGen \
  --head samuraisatoshi:feat/my-feature \
  --base master
```

## Current Open PRs

| PR | Branch | Status |
|----|--------|--------|
| yonaskolb/XcodeGen#1610 | `feat/generate-dry-run` | OPEN |
| yonaskolb/XcodeGen#1611 | `feat/validate-command` | OPEN |
| yonaskolb/XcodeGen#1612 | `feat/query-command` | OPEN |

## Stripping Fork-Specific Infrastructure

When porting a command upstream, remove:
- `guideContent(locale:)` override
- `import XcodeGenKit` (if only used for TOONEncoder)
- `switch outputFormat { case .llm: ... case .enriched: ... }` — keep only `.plain`
- References to `TOONEncoder`, `RichFormatter`, `GuideLocale`, `CommandGuide`
