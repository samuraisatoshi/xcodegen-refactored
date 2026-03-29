# Formal Spec Report — CD-007

| Field            | Value                                |
|------------------|--------------------------------------|
| Workspace        | XCODEGEN                             |
| Card             | CD-007 — TargetGenerationContext extraction |
| Spec file        | `spec.tla`                           |
| Tool             | TLC model checker (TLA+)             |
| Validation       | **PASS**                             |
| Duration         | 774 ms                               |
| States generated | 31,105                               |
| Distinct states  | 729                                  |
| Search depth     | 4                                    |

---

## What is a Formal Spec?

A **formal specification** is a mathematically precise description of a system's behavior. Instead of prose or comments, it uses a formal language with well-defined semantics — so correctness claims can be **mechanically checked**, not just reasoned about informally.

For software, a formal spec answers two questions:
1. **What states can the system reach?** (reachability)
2. **Do invariants hold in every reachable state?** (safety)

Formal specs are not a replacement for tests. Tests sample a finite number of inputs; a model checker exhaustively explores every possible execution path within a bounded state space. This makes it especially powerful for **concurrency**, **protocol design**, and **refactoring where behavioral equivalence must be guaranteed**.

---

## What is TLA+?

**TLA+** (Temporal Logic of Actions) is a formal specification language designed by Leslie Lamport (Turing Award, 2013). It is used in production at Amazon AWS, Microsoft Azure, Intel, MongoDB, and others to verify distributed protocols and critical algorithms.

Key concepts:

| Concept | Meaning |
|---------|---------|
| **State** | An assignment of values to all variables |
| **Action** | A relation between the current state and the next state (written as a predicate over `v` and `v'`) |
| **Invariant** | A predicate that must hold in every reachable state |
| **Spec** | `Init /\ [][Next]_vars` — the system starts in `Init` and every step satisfies `Next` or leaves `vars` unchanged |
| **TLC** | The model checker that exhaustively enumerates reachable states and verifies all invariants |

TLA+ is intentionally **not executable code** — it describes what must be true, not how to compute it. This separation lets the spec remain compact and auditable even when the implementation is complex.

---

## What was specified for CD-007

CD-007 extracted `TargetGenerationContext` from `PBXProjGenerator`, which consolidates how dependency file references are routed into embed buckets (`copyFrameworks`, `copyResources`, `copyWatch`, `extensions`, `extensionKitExtensions`, `systemExtensions`, `appClips`, `custom`).

The routing is controlled by seven boolean flags per dependency:

| Flag | Meaning |
|------|---------|
| `cp`  | `hasCopyPhase` — dependency has an explicit custom copy phase |
| `ext` | `isExtension` — app extension target |
| `ek`  | `isExtKitExtension` — ExtensionKit extension |
| `sys` | `isSystemExtension` — system extension |
| `od`  | `isOnDemand` — on-demand resource / app clip |
| `fw`  | `isFramework` — dynamic framework |
| `wa`  | `isWatchApp` — watchOS app |

The `Route` function in the spec mirrors the `if/else-if` chain in `processTargetDependency` exactly. With 7 boolean inputs, there are 2⁷ = **128 flag combinations** to consider. Manually reviewing all 128 paths is error-prone; TLC checks them exhaustively in milliseconds.

---

## Properties verified

### P1 — EmbedMutualExclusion

> Each file reference appears in **at most one** embed bucket across all reachable states.

```tla
EmbedMutualExclusion ==
    \A f \in Files :
        Cardinality({d \in EmbedDests : f \in buckets[d]}) <= 1
```

**Why it matters:** if the same framework were embedded twice (e.g., once via the type-based path and once via the custom path), the resulting `.xcodeproj` would produce a build error ("multiple commands produce the same output"). This property proves that the `processedFiles` guard — which skips any file already processed — is sufficient to prevent this in all 31,105 generated states.

### P2 — CustomCopyPrecedence

> The `custom` bucket is disjoint from all type-based buckets at all times.

```tla
CustomCopyPrecedence ==
    \A d \in (EmbedDests \ {"custom"}) :
        buckets["custom"] \cap buckets[d] = {}
```

**Why it matters:** `hasCopyPhase` is the first branch in the `if/else-if` chain. P2 proves that this priority is not merely structural (first branch wins) but is a **global invariant** — no execution path can put the same file in both `custom` and a type-based bucket.

### P3 — RoutingTotality

> `Route` is a **total function**: all 128 flag combinations map to a valid member of `EmbedDests`.

```tla
RoutingTotality ==
    \A cp \in BOOLEAN, ext \in BOOLEAN, ek \in BOOLEAN,
       sys \in BOOLEAN, od \in BOOLEAN, fw \in BOOLEAN, wa \in BOOLEAN :
        Route(cp, ext, ek, sys, od, fw, wa) \in EmbedDests
```

**Why it matters:** an `if/else-if` chain without an exhaustive `else` clause silently falls through — dropping a file that should have been embedded. P3 proves that the final `ELSE "copyResources"` branch covers every combination not matched by the earlier branches, so no dependency is ever silently ignored.

---

## What was NOT modeled

**BuildPhaseOrder** (sources must precede postCompile phases) is a sequential ordering property enforced by the structure of `assembleBuildPhases`. It is not a reachability/safety property of the routing state machine, so it is verified by the unit test suite rather than by this TLC model.

---

## Errors

None.

## Warnings

None.
