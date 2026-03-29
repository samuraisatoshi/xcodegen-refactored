---
title: TOON Format Reference
updated: 2026-03-29
---

# TOON — Token-Optimized Object Notation

TOON reduces token count ~40% vs JSON by eliminating key repetition in uniform arrays.

## Encoding Rules

| Structure | Syntax |
|-----------|--------|
| Object key-value | `key: value` |
| Nested object | 2-space indent per level |
| Primitive array | `key[N]: v1,v2,v3` |
| Tabular array (uniform keys) | `key[N]{f1,f2}:\n  v1,v2\n  v3,v4` |
| Mixed array | `key[N]:\n  - item1\n  - key: val` |
| Empty array | `key[0]:` |

## String Quoting

A string value MUST be quoted if it:
- Is empty
- Contains `:` `,` `"` `\` `[` `]` `{` `}` `\n` `\t`
- Equals `true`, `false`, or `null`
- Looks like a number (starts with digit or `-` + digit)

## Output Examples

**generate:**
```
status: ok
project: MyApp.xcodeproj
targets[3]: App,AppTests,Framework
```

**validate (valid):**
```
valid: true
errors[0]:
warnings[0]:
```

**validate (invalid):**
```
valid: false
errors[2]{stage,message}:
  parsing,"Unexpected token at line 5"
  validation,Target 'Missing' not found
warnings[0]:
```

**query --type targets:**
```
targets[3]{name,type,platform}:
  MyApp,application,iOS
  MyTests,bundle.unit-test,iOS
  Framework,framework,iOS
```

## Array Type Detection (TOONEncoder)

1. `[Any]` where all elements are scalars → **primitive array** (inline)
2. `[[String: Any]]` where all have identical keys → **tabular array**
3. Otherwise → **mixed array** with `-` prefix per item

## Usage

```swift
let dict: [String: Any] = [
    "status": "ok",
    "targets": ["App", "Tests", "Framework"]
]
stdout.print(TOONEncoder().encode(dict))
// status: ok
// targets[3]: App,Tests,Framework
```

Activated via `--llm-output` flag on any command.
