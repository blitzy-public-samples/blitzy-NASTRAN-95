# NASTRAN-95 Modernization — Summary (Checkpoint B1: Foundation & Documentation)

> **Consolidated capstone report** — authored last of the six `modern/docs/`
> deliverables. It rolls up the **A1 / A2 / A3** algorithm decisions, the
> per-mechanism status, the cross-cutting guarantees, the risk-reduction
> metrics, the carried-forward flags, and the named next-candidate modules.
> It **synthesizes** `pre_implementation_analysis.md`,
> `init_modernization_report.md`, `state_modernization_report.md`,
> `dispatch_modernization_report.md`, and `regression_validation_report.md`;
> where a detail needs its full derivation, consult the cited report.
>
> **Checkpoint scope (READ FIRST).** This summary is published at the **B1
> "Foundation & Documentation"** checkpoint. B1 physically delivers the
> **foundational source layer** (6 `.f` units), the **6 documentation
> reports**, the **13 reference-data files** (`.ref`), and the **top-level unit
> runner** — **26 artifacts in total**. The remaining target artifacts — the
> validators / orchestrator / entry point (`nastinit.f`, `initval.f`,
> `stateval.f`, `dispval.f`, `regval.f`), the FORTRAN unit drivers
> (`test/**/*.f`), the regression harness (`test/regress/run_all.csh`), and the
> **two legacy edits** (`bin/nastrn.f`, `bin/linknas`) — are **deferred to
> B2/FINAL** and are marked **TARGET / DEFERRED** throughout. Where a section
> describes the end-state design it says so; where it states what physically
> exists today it is limited to the 26 B1 artifacts.

## Executive Summary

This effort was an **encapsulation / modularity refactor only** — a surgical
modernization of the three highest-risk maintainability mechanisms of the
APR.95 NASTRAN-95 codebase (distributed under the NASA Open Source Agreement
v1.3): (1) the link-line-dependent `BLOCK DATA` initialization, (2) the
`COMMON`-block global state, and (3) the OSCAR computed-`GO TO` dispatch ladder
in `mis/xsem00.f`. Two cross-cutting deliverables accompany them: a runtime
**diagnostics** layer and a golden-master **regression-safety** harness. The
work preserves **bit-for-bit numerical equivalence** — no numerical result, no
solver output, no module execution order, no restart/checkpoint behavior, and
no input deck changes. It is explicitly **not** a rewrite, **not** a
performance optimization, and **not** a technology-stack migration: the code
remains fixed-form FORTRAN 77 compiled by the Solaris host `f77` with the
existing `-fast -dn` flags. All new code lives under two **new** top-level
trees, `modern/` and `test/`. In the **target** design the legacy tree is
unchanged except **two permitted edits** — a single `CALL NASTINIT` line
inserted into `bin/nastrn.f` and the build-graph update to `bin/linknas`; **at
this B1 checkpoint both edits are still DEFERRED, so the legacy tree is
currently byte-for-byte unchanged.** The design applies **branch by
abstraction** inside the codebase, **strangler-fig** feature-toggle cutover
(environment toggles that default to APR.95 behavior), and **golden-master /
characterization** regression against the shipped `demoout/` reference outputs.

## Scope — B1 Delivered vs. Deferred

Every modernization artifact is a **CREATE** operation except the two noted
**UPDATE**s. The table below separates what is **physically delivered at B1**
from what is **target / deferred to B2/FINAL**. B1 delivers **6** FORTRAN-77
source files (`.f`), **6** Markdown reports (`.md`), **13** reference-data files
(`.ref`), and the top-level unit runner — **26 artifacts**.

| Area | Path | Delivered at B1 | Deferred to B2/FINAL | Operation |
|------|------|-----------------|----------------------|-----------|
| Initialization | `modern/init/` | `blkinit.f` (1) | `nastinit.f`, `initval.f` (2) | CREATE |
| Global state | `modern/state/` | `stateacc.f` (40 accessor units) (1) | `stateval.f` (1) | CREATE |
| Dispatch | `modern/dispatch/` | `disptbl.f` (1) | `dispval.f` (1) | CREATE |
| Diagnostics | `modern/diag/` | `diagctl.f`, `diaglog.f` (2) | — (area complete) | CREATE |
| Regression | `modern/regress/` | `outcomp.f` (1) | `regval.f` (1) | CREATE |
| Documentation | `modern/docs/` | the 6 `.md` reports (incl. this one) (6) | — (area complete) | CREATE |
| Unit reference data | `test/{init,state,dispatch,diag}/` | reference data `*.ref` (13) | unit drivers `*.f` (13) | CREATE |
| Regression harness | `test/regress/run_all.csh` | — | one-command deck sweep vs `demoout/` (1) | CREATE |
| Unit runner | `test/run_units.csh` | top-level driver runner; greps `FAIL:`, non-zero exit (1) | — (delivered) | CREATE |
| Bootstrap | `bin/nastrn.f` | — (legacy still unedited) | single `CALL NASTINIT` immediately after `CALL DBMINT` (L44) | **UPDATE** |
| Build script | `bin/linknas` | — (legacy still unedited) | add `modern/*.o` + test-driver objects to the `ar` archive and the `f77 -fast -dn` link line; keep all 39 `bd/` objects explicitly named | **UPDATE** |

**B1-delivered `.f` count by directory:** `init` 1 + `state` 1 + `dispatch` 1 +
`diag` 2 + `regress` 1 = **6** `.f`; plus **6** `.md`, **13** `.ref`, and
`test/run_units.csh` ⇒ **26 artifacts**. **Deferred** (target, not yet on
disk): **5** `.f` (`nastinit.f`, `initval.f`, `stateval.f`, `dispval.f`,
`regval.f`), **13** unit-driver `.f`, `test/regress/run_all.csh`, and the
**two** legacy UPDATEs (`bin/nastrn.f`, `bin/linknas`). Because the two UPDATEs
are not yet applied, the legacy tree remains byte-for-byte unchanged at B1.

## Consolidated Algorithm Decisions (A1 / A2 / A3)

The refactor required three explicit two-candidate decisions. Each is
summarized below with the **accepted** candidate, the **rejected** alternative,
and a one-line rationale; the per-mechanism reports carry the full analysis.

| Decision | Accepted | Rejected | Rationale |
|----------|----------|----------|-----------|
| **A1 — Init dependency ordering** | **Candidate 1** — explicit hardcoded ordered init sequence (`nastinit.f` / `blkinit.f`) | Candidate 2 — declarative dependency metadata resolved by a startup topological-sort engine | `BLOCK DATA` units are order-independent pure `DATA` initializers with no read-before-write coupling; a topological engine is over-engineering that adds startup cost and new failure modes. See `init_modernization_report.md`. |
| **A2 — FORTRAN-77 dispatch table** | **Candidate 1** — `IF` / `ELSE IF` chain over `MODX` calling `EXTERNAL` subroutines, single pre-dispatch `CALL TMTOGO(KTIME)` | Candidate 2 — `DATA`-initialized `INTEGER` index array driving a secondary `IF` / `ELSE IF` dispatch | The direct chain is the most readable form, makes `MODX`→subroutine coverage trivially auditable, and removes the `GO TO`-maintenance hazard; the extra indirection buys little under `f77 -fast -dn`. See `dispatch_modernization_report.md`. |
| **A3 — Regression output comparison** | **Candidate 2** — field-by-field FORTRAN comparator `outcomp.f` (6-significant-figure **relative** float tolerance, **bitwise** integer identity) | Candidate 1 — line-by-line POSIX `diff` after whitespace normalization | Volatile per-page date/page/banner headers make a naive `diff` false-fail, and `diff` cannot apply numeric tolerance to format-sensitive floating-point round-trips. See `regression_validation_report.md`. |

## Per-Mechanism Status

Status is reported **per checkpoint**. At **B1** each mechanism's **foundation**
is delivered and compiles; the **validators / orchestrator / entry point** that
complete three of the mechanisms are **deferred to B2/FINAL**. Diagnostics and
documentation are the two areas **fully delivered** at B1. The A1/A2/A3
decisions above are settled records; their realization spans B1-delivered files
(`blkinit.f`, `disptbl.f`, `outcomp.f`) and the deferred files noted below.
Everything delivered is **default-off** (dormant until a toggle is set) and
**coexists** with the unchanged legacy implementation.

- **Initialization — B1: FOUNDATION DELIVERED (`blkinit.f`); entry point &
  validator DEFERRED.** `modern/init/blkinit.f` (delivered) performs the
  explicit, ordered reproduction of the header-reachable `bd/` `COMMON` values.
  The single entry point `nastinit.f` (invoked by one `CALL NASTINIT`
  immediately after `CALL DBMINT`) and the bitwise validator `initval.f` are
  **TARGET / DEFERRED to B2/FINAL** — neither is on disk at B1, and the
  `bin/nastrn.f` `CALL NASTINIT` insertion is likewise deferred.
  All 39 `bd/` units are retained intact for validation and rollback.
  **Reachability constraint:** of the **89** distinct `bd/`-seeded `COMMON`
  blocks, only **2** are reachable through the existing nine `*.COM` headers —
  `/SYSTEM/` (via `mis/SMCOMX.COM`) and `/GINOX/` (which is flagged as a layout
  collision and therefore not actually seeded through its header). The
  remaining **87** are header-unreachable and are flagged/deferred (the full
  per-block breakdown lives in `init_modernization_report.md`).
- **Global state — B1: ACCESSORS DELIVERED (`stateacc.f`); validator
  DEFERRED.** `modern/state/stateacc.f` (delivered) provides **40**
  single-responsibility accessor units (`GET`/`SET` pairs) over the existing
  `*.COM` `COMMON`s. It introduces **zero** new `COMMON` and **zero** new
  `EQUIVALENCE`, enforcing a strict one-header-per-unit rule. The
  state-consistency validator `stateval.f` (validator diagnostics in the
  **9100–9199** sub-band) is **TARGET / DEFERRED to B2/FINAL** and is not yet
  on disk.
- **Dispatch — B1: DISPATCHER DELIVERED (`disptbl.f`); validator & live
  cutover DEFERRED.** `modern/dispatch/disptbl.f` (delivered) is the
  table-driven dispatcher receiving `MODX` as a passed argument (it never
  re-extracts `MODX` and never reads `INOSCR`), preserving exactly one
  pre-dispatch `CALL TMTOGO(KTIME)`. Coverage is **217 / 193 / 188 / 21 / 3** —
  217 `MODX` codes (1–217), 193 dispatched slots, 188 distinct subroutines
  (`XCEI` is shared across `MODX` 5, 6, 7, 11, 12, 13), 21 reserved no-op slots,
  and 3 in-range fatal slots (`MODX` 1, 2, 4). The existing `-50`
  insufficient-time code is preserved, and a new `-9301` fatal handles any
  unmapped/out-of-range code. The coverage validator `dispval.f` (asserts the
  dispatcher's entry count equals the catalogued `MODX` count with zero
  duplicate or unmapped codes) is **TARGET / DEFERRED to B2/FINAL**. The
  **live cutover** (editing the ladder to `CALL DISPTBL`) is also deferred
  because `mis/xsem00.f` is frozen.
- **Diagnostics — B1: FULLY DELIVERED.** `modern/diag/diagctl.f` reads the
  `NASTRAN_*` toggles via `GETENV` and computes the `IDIAG` bitmask once;
  `diaglog.f` writes formatted diagnostic records **directly to logical unit 3
  only** (it does **not** call `MESAGE`), using diagnostic codes confined to the
  **9001–9999** band — an out-of-band code is remapped to the in-band sentinel
  `9999` so an invalid code is never emitted. Every diagnostic **emitter**
  begins with the guard clause `IF (IDIAG .EQ. 0) RETURN` as its first
  executable statement ⇒ zero overhead when disabled; the `diagctl.f` setter is
  the one deliberate exemption, since it is the routine that *computes* `IDIAG`.
- **Regression — B1: COMPARATOR DELIVERED (`outcomp.f`); orchestrator &
  harness DEFERRED.** `modern/regress/outcomp.f` (delivered) is the
  field-by-field comparator (6-significant-figure relative float tolerance,
  bitwise integer identity, volatile date/page/banner lines skipped, and
  embedded-binary inputs such as `demoout/t01231a.out` flagged as `IRET = 1`).
  The orchestrator `regval.f` and the one-command `test/regress/run_all.csh`
  harness — which together drive the `demoout/` golden-master sweep across the
  five integration inputs and the full **132**-deck set — are **TARGET /
  DEFERRED to B2/FINAL** and are not yet on disk.

## Cross-Cutting Guarantees

- **(a) Default = APR.95.** Every new behavior is gated behind an environment
  toggle; with no toggle set the run is bit-identical to the unmodified solver.
- **(b) Toggles (read via `GETENV`, summed into `IDIAG`):**
  `NASTRAN_LEGACY_INIT` (bit 1), `NASTRAN_INIT_VALIDATE` (bit 2),
  `NASTRAN_DISPATCH_VALIDATE` (bit 4), `NASTRAN_DISPATCH_LOG` (bit 8). `IDIAG`
  is `0` when none are set and `15` when all four are set.
- **(c) Zero-overhead diagnostics.** `IF (IDIAG .EQ. 0) RETURN` is the first
  executable statement of every emitter/validator. At B1 this is realized in
  the delivered emitter `diaglog.f`; the validators `initval.f`, `stateval.f`,
  and `dispval.f` carry the same guard in the **target** design and are
  deferred to B2/FINAL. `diagctl.f` is the deliberate guard-exempt exception,
  because it is the routine that *computes* `IDIAG`.
- **(d) No new global state.** All modern `COMMON` access is `INCLUDE`-only
  through the existing nine `*.COM` headers — zero new `COMMON`, zero new
  `EQUIVALENCE` (verifiable by `grep`).
- **(e) Frozen / minimal edits.** `mis/xsem00.f` is frozen; in the target
  design `bin/nastrn.f` receives exactly one inserted line (`CALL NASTINIT`)
  and `bin/linknas` gains the modern build edges — **both edits are deferred to
  B2/FINAL, so at B1 the legacy tree (including `bin/nastrn.f`, the 39 `bd/`
  units, and the nine `*.COM` headers) is retained byte-for-byte intact.**
- **(f) Diagnostic / `MESAGE` codes confined to 9001–9999.** The delivered
  `disptbl.f` raises its unmapped-code fatal in the **9300–9399** sub-band
  (`-9301`) and `diaglog.f` emits only in-band codes (out-of-band values are
  remapped to `9999`); the deferred init/state validators are allotted the
  **9100–9199** sub-band. `um/MSSG.TXT` (highest assigned id `8015`, the
  `9001–9999` band unassigned) is **not** edited.
- **(g) All diagnostic output to logical unit 3 (`LOUT`) only** — never stdout,
  never the legacy print unit `NOUT`, never a new unit. The one documented
  exception is the post-run `regval.f` verdict, which writes to stdout / unit 6
  as a standalone developer tool run outside the solver.

## Risk-Reduction Metrics

This is a code-structure refactor, so the gains are **structural /
maintainability** gains rather than runtime performance metrics. The **After**
column describes the **target end-state**; components not yet on disk at B1 are
annotated **(deferred)** and are scheduled for B2/FINAL.

| Mechanism | Before | After (target; B1 status annotated) |
|-----------|--------|-------|
| **Dispatch** | 22-stage cascading computed-`GO TO` ladder, `MODX` 1–217, ~190 targets, embedded in the frozen `mis/xsem00.f` | Single auditable `IF` / `ELSE IF` table (`disptbl.f`, **delivered**) with an automated coverage validator (`dispval.f`, **deferred** — asserts **217 / 193 / 188 / 21 / 3**, zero duplicate/unmapped) |
| **Init** | 39 implicit, link-line-order-dependent `BLOCK DATA` objects — each must be explicitly extracted (`ar x`) and named on the `f77` link line | One explicit `CALL NASTINIT` path (`blkinit.f` **delivered**; `nastinit.f` entry point **deferred**) with a bitwise validator (`initval.f`, **deferred**) |
| **State** | Ad-hoc per-routine `COMMON` re-declarations scattered across modules | **40** single-responsibility accessors (`stateacc.f`, **delivered**) over the existing headers — zero new `COMMON` / `EQUIVALENCE`, verifiable by `grep`; consistency validator (`stateval.f`, **deferred**) |
| **Regression** | No automated equivalence check | Field-by-field golden-master comparator (`outcomp.f`, **delivered**) plus a one-command harness (`test/regress/run_all.csh`, **deferred**) reusable for every future modernization phase |
| **Safety** | n/a | Target: 100% feature-flag gating ⇒ rollback is a configuration change with **zero recompilation** and the default run is bit-identical to APR.95 (the `diagctl.f` toggle reader is **delivered**; full gating completes when the **deferred** entry point and validators land) |

## Known Flags & Discrepancies

The following items are carried forward for maintainer follow-up; each is
documented in detail in the relevant per-mechanism report.

1. **188-vs-189 distinct-subroutine reconciliation.** The AAP's "~190 / 189"
   count is an overcount originating from the comment at `mis/xsem00.f:L408`
   ("SET LINKNO TO FLAG SUBROUTINE SMA1B TO CALL EMG1B") — `EMG1B` is invoked
   internally by `SMA1B`, not dispatched directly (the dispatched call is
   `CALL EMG`). The verified distinct-subroutine count is **188** (`XCEI` is
   shared across `MODX` 5, 6, 7, 11, 12, 13).
2. **`/SYSTEM/` / `KTIME` note.** Among the nine `*.COM` headers,
   `/SYSTEM/` is declared only in `mis/SMCOMX.COM` (it is absent from
   `bin/NASNAMES.COM`, which declares only `/DOSNAM/` and `/DSNAME/`); `KTIME`
   is the output argument of `CALL TMTOGO(KTIME)`, not a named `/SYSTEM/` cell.
   `SMCOMX.COM` places `NBPW` at word 40, and the **array-aware** `bd/semdbd.f`
   layout *also* places `NBPW` at word 40 — the "word 38" figure is only a
   **naive all-scalar miscount**, not the canonical layout (corroborated by the
   `mds/btstrp.f` `EQUIVALENCE (B(40), NBPW)`), so the two layouts **agree**.
   `disptbl.f` uses a single flagged inline `/SEM/` + `/SYSTEM/` window for the
   `MODX 43` branch (`LINKNM` / `LINKNO`), consistent with NASTRAN's
   per-routine `COMMON` convention.
3. **87 header-unreachable `bd/` `COMMON` blocks.** Of the 89 distinct
   `bd/`-seeded blocks, 87 are not declared in any of the nine headers, so init
   reproduction is limited to the 2 header-reachable blocks; the remaining 87
   are deferred to a later phase.
4. **`demoout/t01231a.out` embedded-binary anomaly.** This reference file
   carries embedded binary (non-text) bytes, so the comparator must treat it as
   a special case rather than as ordinary line-printer text.
5. **Dispatch live cutover deferred.** Wiring the live ladder to
   `CALL DISPTBL` would edit the frozen `mis/xsem00.f`, so the cutover is
   intentionally deferred; the dispatcher is instead validated in coexistence
   via the `test/dispatch/` drivers and the `NASTRAN_DISPATCH_VALIDATE` path.

## Next-Candidate Modules

The same patterns extend cleanly to the next surfaces — "same patterns, next
surface":

- **Extend state encapsulation to the 87 header-unreachable `bd/` `COMMON`
  blocks** by introducing reviewed header coverage for blocks such as
  `/DPDCOM/`, `/OFPB1/`–`/OFPB9/`, `/SEM/`, `/XLINK/`, `/XFIST/`, the
  `/SMA1*/` and `/SMA2*/` families, and `/IFPX0/`–`/IFPX7/` — each behind an
  accessor facade exactly as `stateacc.f` does for the reachable subset.
- **Perform the deferred live dispatch cutover** — once the freeze on
  `mis/xsem00.f` is lifted, replace the computed-`GO TO` ladder with
  `CALL DISPTBL(MODX)`, having already proven equivalence in coexistence.
- **Modernize the next-largest computed-`GO TO` / `ASSIGN` drivers in `mis/`**
  — other executive drivers (for example, the remaining `XSEMxx` and `XGPI`
  family) using the same table-driven dispatch pattern.
- **Broaden the regression harness** from the five integration inputs to the
  full `demoout/` set, and add per-SOL coverage.
- **Extend the accessor layer to the `mds/` GINO I/O `COMMON`s**, mediating
  disk-I/O state through facades over `DSIOF.COM`, `GINOX.COM`, and
  `PAKBLK.COM`.

## Rollback Procedure (target design)

In the **target** design, rollback to exact APR.95 behavior is a
**configuration-only** change requiring **no recompilation**: unset (or flip)
the relevant `NASTRAN_*` environment variable(s) in the `bin/nastran` `csh`
wrapper. With all toggles unset, `IDIAG = 0`, every guarded modern routine
short-circuits at its first executable statement, and execution is bit-identical
to the unmodified solver. **At the B1 checkpoint this safety is trivially in
force for a stronger reason: the modern layer is not yet wired into the
executable at all** — the `CALL NASTINIT` bootstrap edit and the `bin/linknas`
build edges are deferred, so the legacy `bd/` initialization and the
`mis/xsem00.f` computed-`GO TO` ladder are the **only** live paths and the
entire `modern/` layer is dormant by construction.

## Provenance

This report synthesizes the other five `modern/docs/*.md` reports
(`pre_implementation_analysis.md`, `init_modernization_report.md`,
`state_modernization_report.md`, `dispatch_modernization_report.md`,
`regression_validation_report.md`) and the full `modern/` + `test/` source set.
It references — and modifies none of — `bin/nastrn.f`, `bin/linknas`,
`mis/xsem00.f`, the nine `*.COM` headers, the 39 `bd/*.f` units, `um/MSSG.TXT`,
the `inp/*.inp` decks, and the `demoout/*.out` golden masters.
