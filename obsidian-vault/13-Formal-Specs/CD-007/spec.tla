---- MODULE spec ----
\* Formal specification for CD-007: TargetGenerationContext extraction
\*
\* Models the routing of dependency file references into accumulator buckets
\* and verifies three safety properties that must hold after the refactor:
\*
\* P1 EmbedMutualExclusion  - each file ref appears in at most one embed bucket
\*    Verified by: processedFiles guard (each file processed exactly once)
\*    + Route function returning exactly one destination
\*
\* P2 CustomCopyPrecedence  - files routed via custom copyPhase are isolated
\*    from all type-based buckets (custom takes priority in if/else-if chain)
\*
\* P3 RoutingTotality       - Route covers all 128 flag combinations and
\*    always returns a member of EmbedDests (no undefined/default fall-through)
\*
\* BuildPhaseOrder (sources before postCompile) is a sequential property
\* enforced by the structure of assembleBuildPhases — verified by test suite,
\* not by this TLC model.
EXTENDS Naturals, FiniteSets, TLC

CONSTANTS Files  \* model: {f0, f1, f2}

EmbedDests == {
    "copyFrameworks",
    "copyResources",
    "copyWatch",
    "extensions",
    "extensionKitExtensions",
    "systemExtensions",
    "appClips",
    "custom"
}

\* Routing function: mirrors the if/else-if chain in processTargetDependency
\* cp  = hasCopyPhase,   ext = isExtension,    ek  = isExtKitExtension
\* sys = isSystemExtension, od = isOnDemand, fw = isFramework, wa = isWatchApp
Route(cp, ext, ek, sys, od, fw, wa) ==
    IF cp              THEN "custom"
    ELSE IF ext /\ ek  THEN "extensionKitExtensions"
    ELSE IF ext        THEN "extensions"
    ELSE IF sys        THEN "systemExtensions"
    ELSE IF od         THEN "appClips"
    ELSE IF fw         THEN "copyFrameworks"
    ELSE IF wa         THEN "copyWatch"
    ELSE                    "copyResources"

VARIABLES
    buckets,        \* [EmbedDests -> SUBSET Files]
    processedFiles  \* SUBSET Files — tracks files already embedded

vars == <<buckets, processedFiles>>

Init ==
    /\ buckets        = [d \in EmbedDests |-> {}]
    /\ processedFiles = {}

TypeOK ==
    /\ \A d \in EmbedDests : buckets[d] \subseteq Files
    /\ processedFiles \subseteq Files

\* Action: embed a file — each file is processed at most once (guard)
EmbedFile(f, cp, ext, ek, sys, od, fw, wa) ==
    /\ f \notin processedFiles
    /\ LET dest == Route(cp, ext, ek, sys, od, fw, wa)
       IN  buckets' = [buckets EXCEPT ![dest] = @ \cup {f}]
    /\ processedFiles' = processedFiles \cup {f}

Next ==
    \E f \in Files,
       cp \in BOOLEAN, ext \in BOOLEAN, ek \in BOOLEAN,
       sys \in BOOLEAN, od \in BOOLEAN, fw \in BOOLEAN, wa \in BOOLEAN :
       EmbedFile(f, cp, ext, ek, sys, od, fw, wa)

\* P1: Each file appears in at most one embed bucket
EmbedMutualExclusion ==
    \A f \in Files :
        Cardinality({d \in EmbedDests : f \in buckets[d]}) <= 1

\* P2: custom bucket is disjoint from all type-based buckets at all times
CustomCopyPrecedence ==
    \A d \in (EmbedDests \ {"custom"}) :
        buckets["custom"] \cap buckets[d] = {}

\* P3: Route is total — all 128 combinations map to a valid destination
RoutingTotality ==
    \A cp \in BOOLEAN, ext \in BOOLEAN, ek \in BOOLEAN,
       sys \in BOOLEAN, od \in BOOLEAN, fw \in BOOLEAN, wa \in BOOLEAN :
        Route(cp, ext, ek, sys, od, fw, wa) \in EmbedDests

Invariant ==
    /\ TypeOK
    /\ EmbedMutualExclusion
    /\ CustomCopyPrecedence
    /\ RoutingTotality

Spec == Init /\ [][Next]_vars

====
