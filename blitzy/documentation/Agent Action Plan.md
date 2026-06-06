# Technical Specification

# 0. Agent Action Plan

## 0.1 Intent Clarification

### 0.1.1 Core Refactoring Objective

Based on the prompt, the Blitzy platform understands that the refactoring objective is to **surgically modernize the three highest-risk maintainability mechanisms of the NASTRAN-95 codebase (APR.95 vintage, distributed under the NASA Open Source Agreement v1.3) without altering a single numerical result, solver output, module execution order, restart/checkpoint behavior, or input deck.** This is explicitly a *modularity and code-structure* refactor — an encapsulation exercise — and emphatically **not** a rewrite, a performance optimization, or a technology-stack migration. The code remains fixed-form FORTRAN 77 throughout, compiled by the Solaris host `f77` with the existing `-fast -dn` flags `[bin/linknas]`.

The three mechanisms targeted, each independently confirmed in the repository, are:

- **BLOCK DATA initialization.** Global program state is seeded at load time by 39 `BLOCK DATA` units under `bd/` (e.g., `BLOCK DATA DPDCBD` declaring `COMMON/DPDCOM/` and populating it via `DATA DPOOL/101/,GPL/102/,...`) `[bd/dpdcbd.f:L1-L26]`. These units are *order-independent pure data initializers*, but they carry a build-time fragility: Fortran linkers do not auto-pull `BLOCK DATA` from an archive because nothing references their symbols, so the build script must **explicitly extract and name all 39 objects on the link line** (`ar x nastlib.a <obj>` for each, then `f77 -fast -dn -o ../bin/nastrn.exe nastrn.o <39 bd objects> nastlib.a`) `[bin/linknas]`. The objective is to introduce an **explicit, ordered, validated initialization path** under `modern/init/`, invoked exactly once.

- **COMMON-block global state.** Mutable global state is declared across nine shared `INCLUDE` files (`*.COM`) and re-declared piecemeal in individual routines. The objective is to **encapsulate the subset of COMMON variables referenced by new modernization components behind accessor/facade routines** under `modern/state/`, reading and writing exclusively through the existing `*.COM` files with zero new COMMON re-declarations and zero new `EQUIVALENCE` statements.

- **OSCAR computed-GOTO dispatch.** The executive module driver in `mis/xsem00.f` decodes an operation code and branches through a 22-stage cascading computed-`GO TO` ladder spanning `MODX` values 1–217 to roughly 190 distinct module subroutines `[mis/xsem00.f:L262-L761]`. The objective is to express this mapping as a **maintainable, table-driven dispatcher** in `modern/dispatch/disptbl.f` that receives `MODX` as a passed argument.

Two cross-cutting deliverables accompany the three mechanisms: a **runtime diagnostics layer** (`modern/diag/`) that emits only to logical unit 3 with provably zero overhead when disabled, and a **regression-safety infrastructure** (`modern/regress/` plus a `test/` tree) that proves byte-for-byte equivalence against the shipped reference outputs in `demoout/`.

The target repository is the **same repository**; all new code is isolated under two new top-level trees, `modern/` and `test/`, neither of which exists today `[/tmp/blitzy/blitzy-NASTRAN-95/master_fc613b]`.

### 0.1.2 Technical Interpretation

This refactoring translates to the following technical transformation strategy: **build a modern abstraction layer that coexists with the legacy implementation inside the same codebase, gate the new behavior behind runtime feature toggles that default to exact APR.95 behavior, and prove equivalence through golden-master regression before any caller is switched over.** The legacy `bd/` units, the nine `*.COM` files, and the frozen `mis/xsem00.f` ladder all remain physically present and fully functional; the modern layer grows alongside them rather than replacing them in place.

The mapping from current architecture to target architecture is summarized below.

| Current Mechanism | Repository Evidence | Target Abstraction | Coexistence / Cutover |
|-------------------|---------------------|--------------------|-----------------------|
| 39 implicit `BLOCK DATA` units, link-line-dependent | `bd/dpdcbd.f:L1-26`; `bin/linknas` | `modern/init/` explicit ordered init invoked by one `CALL NASTINIT` | `bd/` units retained for validation/rollback; toggle `NASTRAN_LEGACY_INIT` |
| COMMON state declared in 9 `*.COM`, re-declared per routine | `mis/SMCOMX.COM`, `mds/DSIOF.COM`, etc. | `modern/state/` accessor facades over the same `*.COM` | Legacy routines keep their declarations; accessors used only by new code |
| 22-stage computed-`GO TO` ladder, `MODX` 1–217 → ~190 subroutines | `mis/xsem00.f:L262-761` | `modern/dispatch/disptbl.f` table-driven, `MODX` passed as argument | `xsem00.f` frozen; dispatcher validated in coexistence, live cutover deferred |
| Ad-hoc diagnostics | `nastrn.f:L36` (`MESAGE`), `nastrn.f:L45` (`LOUT=3`) | `modern/diag/` controlled layer, unit 3 only, codes 9001–9999 | Guard-clause zero overhead when toggles unset |
| No automated equivalence check | `demoout/*.out` reference outputs | `modern/regress/` + `test/` golden-master harness | `demoout/` = the golden masters |

The transformation rules that govern every change are:

- **One bootstrap edit only.** The single permitted modification to the executable flow is the insertion of `CALL NASTINIT` (no arguments) immediately after the existing `CALL DBMINT` in the bootstrap, where machine constants populated by `BTSTRP` and `DBMINT` are already resident in COMMON `[bin/nastrn.f:L32,L44]`.
- **The dispatch source is frozen.** `mis/xsem00.f` is not edited; the operation-code extraction `MODX = RSHIFT(INOSCR(3),16)` `[mis/xsem00.f:L182]` and the pre-dispatch time check `CALL TMTOGO(KTIME)` `[mis/xsem00.f:L196-L197]` remain verbatim. The modern dispatcher receives `MODX` as an argument and never re-reads it.
- **No new global state.** Accessors and initializers reach global state strictly through the existing `*.COM` `INCLUDE` files; they declare no new COMMON and add no new `EQUIVALENCE`.
- **Default is APR.95.** Every new behavior is disabled unless its environment toggle is explicitly set, so an unconfigured run is bit-identical to the unmodified solver, and rollback is a configuration change with no recompilation.

The following implicit requirements were surfaced from these constraints and must be honored even though the prompt does not state them as line items: the **public `CALL` interfaces of every dispatched module must be preserved** (the dispatcher calls them unchanged); the **link-time `BLOCK DATA` semantics must be preserved** (values present at load); **`KTIME` availability via `/SYSTEM/` must be preserved** for the dispatcher's time check; the **OFP output byte layout must be preserved** except for inherently volatile per-page date and page-number header lines; **new `MESAGE` codes must be confined to the 9001–9999 band** that is unassigned in the message registry `[um/MSSG.TXT]`; and **`bin/linknas` must be updated** to compile, archive, and link the new objects (this build script is not subject to the one-edit restriction that applies solely to `bin/nastrn.f`).


## 0.2 Scope Boundaries

### 0.2.1 Exhaustively In Scope

The following file groups are in scope. All paths are relative to the repository root `[/tmp/blitzy/blitzy-NASTRAN-95/master_fc613b]`. Every new FORTRAN source uses fixed-form column conventions (comment marker in column 1; statement labels in columns 1–5; continuation in column 6; statement body in columns 7–72) and compiles into `bin/nastlib.a`.

- **Initialization modernization** — `modern/init/*.f`
    - `modern/init/nastinit.f` — the single initialization entry point invoked by `CALL NASTINIT`; reads the `NASTRAN_LEGACY_INIT` toggle via `GETENV` and orchestrates the explicit init path.
    - `modern/init/blkinit.f` — explicit, ordered initialization that reproduces the COMMON values set by all 39 `bd/` `BLOCK DATA` units, reaching state through the existing `*.COM` `INCLUDE` files.
    - `modern/init/initval.f` — initialization-state validator that compares the modern init result against the legacy `BLOCK DATA` values bitwise and reports divergence.

- **Global-state encapsulation** — `modern/state/*.f`
    - `modern/state/stateacc.f` — accessor/facade get and set routines for the COMMON variables referenced by new components, declared exclusively via existing `*.COM` `INCLUDE` files.
    - `modern/state/stateval.f` — state-consistency validator.

- **OSCAR dispatch modernization** — `modern/dispatch/*.f`
    - `modern/dispatch/disptbl.f` — table-driven dispatcher receiving `MODX` as a passed argument; preserves a single `CALL TMTOGO(KTIME)` ahead of dispatch; routes every `MODX` value to exactly one target; unmapped values raise a fatal diagnostic.
    - `modern/dispatch/dispval.f` — dispatch validator asserting that the dispatcher's entry count equals the catalogued `MODX` count with no duplicate or unmapped codes.

- **Runtime diagnostics layer** — `modern/diag/*.f`
    - `modern/diag/diagctl.f` — diagnostic control that reads the `NASTRAN_*` toggles via `GETENV` and sets the `IDIAG` state.
    - `modern/diag/diaglog.f` — formatted diagnostic writer targeting logical unit 3 only, using `MESAGE` codes 9001–9999.

- **Regression-safety infrastructure** — `modern/regress/*.f`
    - `modern/regress/regval.f` — regression orchestrator that drives benchmark deck runs and invokes the comparator.
    - `modern/regress/outcomp.f` — field-by-field OFP output comparator (6-significant-figure relative tolerance for floating-point fields, bitwise identity for integers, volatile date/page headers skipped).

- **Documentation deliverables** — `modern/docs/*.md`
    - `pre_implementation_analysis.md` (authored before any source file), `init_modernization_report.md`, `state_modernization_report.md`, `dispatch_modernization_report.md`, `regression_validation_report.md`, and `final_modernization_summary.md`.

- **Test infrastructure** — `test/**/*`
    - `test/init/*`, `test/state/*`, `test/dispatch/*`, `test/diag/*` — unit-test drivers (`*.f`) and reference-value data (`*.ref`); each driver emits `PASS:` or `FAIL:` to the log unit.
    - `test/regress/run_all.csh` and `test/regress/*` — the integration/regression harness that runs the benchmark decks and compares against `demoout/`.
    - `test/run_units.csh` — the top-level unit runner that greps for `FAIL:` and exits non-zero on any failure.

- **Bootstrap insertion (single edit)** — `bin/nastrn.f`
    - The one permitted change: insert `CALL NASTINIT` immediately after `CALL DBMINT` `[bin/nastrn.f:L44]`. No other modification to this file is permitted.

- **Build-script update** — `bin/linknas`
    - Add the new `modern/` objects (and unit-test driver objects) to the `ar` archive step and to the `f77 -fast -dn` link line, preserving the explicit naming of all 39 `bd/` objects `[bin/linknas]`.

- **Rule-mandated files** — none. The user-specified rules list is empty, so there are no additional files forced into scope beyond those the prompt's scope and file-organization sections already mandate.

### 0.2.2 Explicitly Out of Scope

The following are explicitly out of scope. They are read for reference where noted but are never modified.

- **The frozen dispatch source** — `mis/xsem00.f` must not be modified in any way; its `MODX = RSHIFT(INOSCR(3),16)` extraction `[mis/xsem00.f:L182]` and `CALL TMTOGO(KTIME)` time check `[mis/xsem00.f:L196-L197]` remain verbatim.
- **`bin/nastrn.f` beyond the single insertion** — no change other than the one `CALL NASTINIT` line.
- **The 39 `bd/` `BLOCK DATA` units** — `bd/*.f` are kept intact, present, and unmodified; they are retained as the source of truth for validation and rollback.
- **The nine `*.COM` `INCLUDE` files** — `bin/NASNAMES.COM`, `mds/NASNAMES.COM`, `mds/DSIOF.COM`, `mds/GINOX.COM`, `mds/PAKBLK.COM`, `mds/XNSTRN.COM`, `mds/ZZZZZZ.COM`, `mis/MMACOM.COM`, `mis/SMCOMX.COM` are consumed via `INCLUDE` and never edited or re-declared.
- **Solver and module computational logic** — the ~190 dispatched module subroutines and the broader `mds/` (130 `*.f`) and `mis/` (1674 `*.f`) source bodies are not edited (the sole exception being the frozen `mis/xsem00.f`, which is itself not edited either).
- **Rigid-format and alternate DMAP** — `rf/**/*` (27 files, including `NASINFO`) and `alt/**/*` (6 COSMIC alternate-DMAP files).
- **Utilities** — `utility/**/*`.
- **The message registry file** — `um/MSSG.TXT` is not edited; new diagnostics in the 9001–9999 band are *emitted* from `modern/` routines, not registered by changing this file.
- **Out-of-bounds technology and capabilities** — Fortran 90 or any non-FORTRAN-77 dialect, external/third-party libraries, parallel execution, and any graphical user interface are all out of scope.


## 0.3 Target Design

### 0.3.1 Refactored Structure Planning

The modernization introduces two new top-level trees, `modern/` and `test/`, alongside the unchanged legacy tree. Every `.f` file is fixed-form FORTRAN 77 and is compiled into `bin/nastlib.a` through an updated `bin/linknas`. The complete target layout is shown below; comments in parentheses indicate each file's purpose and its primary reference source.

<pre>
Target (additions to the existing repository):

modern/
├── init/
│   ├── nastinit.f      (single init entry point; CALL NASTINIT; reads NASTRAN_LEGACY_INIT via GETENV)
│   ├── blkinit.f       (explicit ordered init reproducing all 39 bd/ COMMON DATA values)
│   └── initval.f       (bitwise validator: modern init vs legacy BLOCK DATA)
├── state/
│   ├── stateacc.f      (accessor/facade get/set over existing *.COM COMMONs via INCLUDE)
│   └── stateval.f      (state-consistency validator)
├── dispatch/
│   ├── disptbl.f       (table-driven MODX dispatcher; MODX passed as arg; TMTOGO(KTIME) preserved)
│   └── dispval.f       (validator: entry count == MODX catalog count; no dup/unmapped)
├── diag/
│   ├── diagctl.f       (env-var toggle reader; sets IDIAG)
│   └── diaglog.f       (formatted writer to LOUT=3; MESAGE 9001-9999)
├── regress/
│   ├── regval.f        (regression orchestrator: drive decks, invoke comparator)
│   └── outcomp.f       (field-by-field OFP comparator; 6-sig-fig float, bitwise int)
└── docs/
    ├── pre_implementation_analysis.md     (authored FIRST: bd/ inventory, COMMON inventory, MODX map, test inputs)
    ├── init_modernization_report.md       (39-unit status, dependency ordering, A1 decision)
    ├── state_modernization_report.md      (accessor inventory, EQUIVALENCE handling, zero re-declaration evidence)
    ├── dispatch_modernization_report.md   (full MODX coverage, A2 decision, TMTOGO placement, sample log)
    ├── regression_validation_report.md    (A3 decision, demoout/ format evidence, test inventory)
    └── final_modernization_summary.md     (A1/A2/A3 consolidated, risk-reduction metrics, next candidates)

test/
├── init/        (unit drivers *.f + *.ref reference data for init)
├── state/       (unit drivers *.f + *.ref reference data for state accessors)
├── dispatch/    (unit drivers *.f + *.ref reference data for dispatch)
├── diag/        (unit drivers *.f + *.ref reference data for diagnostics)
├── regress/
│   └── run_all.csh   (one-command regression: all inp/*.inp vs demoout/; non-zero exit on FAIL)
└── run_units.csh     (top-level unit runner; greps FAIL:; non-zero exit)

Existing legacy tree (UNCHANGED except the two noted files):
bin/nastrn.f   (UPDATE: single CALL NASTINIT after CALL DBMINT, L44)
bin/linknas    (UPDATE: add modern/ + test objects to ar archive and f77 link line)
bd/*.f         (39 BLOCK DATA units — retained, unmodified)
*.COM (x9)     (INCLUDE'd, unmodified)
mis/xsem00.f   (FROZEN — read-only reference)
inp/*.inp, demoout/*.out  (benchmark decks and golden-master outputs — read-only)
</pre>

This refactor targets the same repository, so no standalone configuration, dependency-management, or deployment scaffolding is created — the project's existing `bin/linknas` build script and `bin/nastran` run wrapper remain the authoritative build and launch facilities and are reused.

### 0.3.2 Web Search Research Conducted

Research confirmed three established patterns that directly underpin this design.

- **Branch by Abstraction.** Guidance from AWS Prescriptive Guidance (citing Fowler) describes a pattern that <cite index="1-1">enables you to make changes to the existing code base to allow the modernized version to safely coexist alongside the legacy version without causing disruption.</cite> Crucially for this codebase, <cite index="1-4">if you want to modernize components that exist deeper in the legacy application stack and have upstream dependencies, we recommend the branch by abstraction pattern.</cite> The NASTRAN initialization, state, and dispatch mechanisms are precisely such deep-stack components, which is why the modern layer is built *inside* the codebase rather than at a perimeter.

- **Strangler Fig.** The complementary pattern provides <cite index="5-12,5-13">a controlled and phased approach to modernization. It allows the existing application to continue functioning during the modernization effort.</cite> Practitioner guidance notes the two patterns are routinely combined: <cite index="2-1">large migrations often use both patterns together: Strangler Fig at the system boundary and Branch by Abstraction inside the codebase.</cite> A key property leveraged here is rollback simplicity — each increment <cite index="3-13,3-14">can be quickly and cleanly reversed simply by setting feature flags appropriately.</cite>

- **Golden Master / Characterization testing.** This technique is the regression backbone. As described in the literature, <cite index="10-1">a characterization test (also known as Golden Master Testing) is a means to describe (characterize) the actual behavior of an existing piece of software, and therefore protect existing behavior of legacy code against unintended changes via automated testing.</cite> It is especially appropriate for complex outputs: <cite index="10-10,10-11">it is generally a sensible approach for complex results such as PDFs, XML, images, etc. where checking all relevant attributes with assertions would be both insensible due to the amount of attributes and result in unreadable/unmaintainable test code.</cite> The shipped `demoout/*.out` reference files serve directly as the golden masters against which refactored output is compared.

The practical synthesis for this project: the `modern/` tree is the in-codebase abstraction layer (branch by abstraction); the `NASTRAN_*` environment toggles are the feature flags enabling instant rollback to APR.95 behavior with no recompilation (strangler-fig cutover control); and `demoout/` supplies the golden masters that the `outcomp.f` comparator validates against with numeric tolerance.

### 0.3.3 Design Pattern Applications

| Pattern | Application in this refactor | Realized in |
|---------|------------------------------|-------------|
| Branch by Abstraction | Modern implementation coexists with legacy `bd/` init and the `xsem00.f` ladder inside one codebase | entire `modern/` tree |
| Strangler Fig (feature-toggle cutover) | New behavior gated behind env toggles; legacy remains default; gradual, reversible cutover | `diagctl.f`, `nastinit.f` |
| Accessor / Facade | All modern reads/writes of global state mediated through accessor routines over the existing `*.COM` | `modern/state/stateacc.f` |
| Strategy / table-driven dispatch | The cascading computed-`GO TO` ladder expressed as an explicit `MODX`→subroutine table | `modern/dispatch/disptbl.f` |
| Golden Master / Characterization | `demoout/` reference outputs compared field-by-field with tolerance | `modern/regress/outcomp.f` |
| Guard Clause | `IF (IDIAG .EQ. 0) RETURN` as the first executable statement of every diagnostic routine → zero overhead when disabled | `modern/diag/*.f`, validators |
| Template Method | Validators share a setup → compare → report shape | `initval.f`, `dispval.f`, `stateval.f` |

### 0.3.4 User Interface Design

User interface design is **not applicable**. NASTRAN-95 is a fixed-form FORTRAN 77 batch finite-element solver driven by input decks (`inp/*.inp`) and configured through environment variables consumed at startup `[bin/nastrn.f:L33]`; its output is classic line-printer Output File Processor (OFP) text written to file `[demoout/d01001a.out:L1-L48]`. There is no graphical, web, or interactive surface anywhere in scope, and no component library or design system is involved. Consequently the Design System Compliance protocol and any design-to-system mapping are not exercised by this refactor.


## 0.4 Transformation Mapping

### 0.4.1 File-by-File Transformation Plan

Every target file is mapped to a source file. Transformation modes are **CREATE** (new file), **UPDATE** (modify an existing file), and **REFERENCE** (an existing file read as a pattern/source of truth but not modified). New `modern/` and `test/` files are CREATE operations whose REFERENCE source is the legacy artifact they reproduce, validate, or pattern themselves on.

| Target File | Transformation | Source File | Key Changes |
|-------------|----------------|-------------|-------------|
| `modern/init/nastinit.f` | CREATE | `bin/nastrn.f` (bootstrap) | Single init entry point; `GETENV('NASTRAN_LEGACY_INIT')`; orchestrate `blkinit`/`initval` |
| `modern/init/blkinit.f` | CREATE | `bd/*.f` (39 units) + 9 `*.COM` | Explicit ordered init reproducing every COMMON value the 39 units set; reach state via `INCLUDE` |
| `modern/init/initval.f` | CREATE | `bd/*.f` (39 units) | Bitwise compare modern init vs legacy `BLOCK DATA`; emit divergence diagnostics |
| `modern/state/stateacc.f` | CREATE | 9 `*.COM` files | Accessor get/set over existing COMMONs via `INCLUDE`; zero new COMMON / `EQUIVALENCE` |
| `modern/state/stateval.f` | CREATE | `modern/state/stateacc.f` + `*.COM` | State-consistency checks |
| `modern/dispatch/disptbl.f` | CREATE | `mis/xsem00.f` ladder `[L262-761]` | Table-driven `MODX`→subroutine dispatch; `MODX` passed arg; `TMTOGO(KTIME)` preserved before dispatch |
| `modern/dispatch/dispval.f` | CREATE | `mis/xsem00.f` `[L262-761]` | Validate entry count == `MODX` catalog count; detect duplicate/unmapped codes |
| `modern/diag/diagctl.f` | CREATE | `bin/nastrn.f` `GETENV` idiom `[L33-39]` | Read `NASTRAN_*` toggles; set `IDIAG` |
| `modern/diag/diaglog.f` | CREATE | `bin/nastrn.f` `LOUT=3` `[L45]` + `MESAGE` usage | Formatted writes to unit 3; `MESAGE` codes 9001–9999 |
| `modern/regress/regval.f` | CREATE | `inp/*.inp` + `demoout/*.out` | Drive benchmark deck runs; invoke `outcomp` |
| `modern/regress/outcomp.f` | CREATE | `demoout/*.out` format `[demoout/d01001a.out:L1-48]` | Field-by-field comparator: skip volatile date/page; 6-sig-fig float, bitwise int |
| `modern/docs/*.md` (6 files) | CREATE | respective analyzed sources | Analysis/decision reports; `pre_implementation_analysis.md` authored first |
| `test/init/*.f`, `*.ref` | CREATE | `modern/init/*` (routine under test) | Unit drivers emit `PASS:`/`FAIL:` to log unit |
| `test/state/*.f`, `*.ref` | CREATE | `modern/state/*` (routine under test) | Accessor unit drivers + reference data |
| `test/dispatch/*.f`, `*.ref` | CREATE | `modern/dispatch/*` (routine under test) | Dispatch unit drivers + reference data |
| `test/diag/*.f`, `*.ref` | CREATE | `modern/diag/*` (routine under test) | Diagnostic unit drivers + reference data |
| `test/regress/run_all.csh` | CREATE | `bin/linknas` (csh idiom) + `inp/` + `demoout/` | One-command regression; non-zero exit on `FAIL` |
| `test/run_units.csh` | CREATE | `bin/linknas` (csh idiom) | Run unit drivers; grep `FAIL:`; non-zero exit |
| `bin/nastrn.f` | UPDATE | `bin/nastrn.f` `[L44]` | Insert single `CALL NASTINIT` immediately after `CALL DBMINT` — nothing else |
| `bin/linknas` | UPDATE | `bin/linknas` | Add `modern/*.o` + test-driver objects to `ar` archive and `f77 -fast -dn` link line; keep all 39 `bd/` objects explicitly named |

The following existing files are **REFERENCE-only** — read for patterns and truth, never modified: `bin/nastran` (the environment-variable / `GETENV` configuration convention), the 39 `bd/*.f` units, the nine `*.COM` files, `mis/xsem00.f` (frozen), `inp/*.inp`, `demoout/*.out`, and `um/MSSG.TXT` (the message-code band reference).

### 0.4.2 Cross-File Dependencies

- **INCLUDE-based state access.** Every `modern/*.f` file that touches global state obtains it through an `INCLUDE` of one of the existing nine `*.COM` files — for example `NASNAMES.COM` for `/DOSNAM/` and `/DSNAME/`, `mds/DSIOF.COM` for `/DSIO/`, `/FCB/`, and `/DBM/`, and `mis/SMCOMX.COM` for `/SYSTEM/` and `/SMCOMX/`. No new `COMMON` block is declared anywhere in `modern/`.
    - Old (legacy per-routine pattern): `COMMON /DSIO/ IEOR,IOERR,...`
    - New (modern accessor): `INCLUDE 'DSIOF.COM'`

- **`/SYSTEM/` and `KTIME` discrepancy (flagged).** The prompt directs that `KTIME` be obtained from `/SYSTEM/` via `INCLUDE 'NASNAMES.COM'`, but `/SYSTEM/` is **not** declared in `NASNAMES.COM`; among the nine `*.COM` files it appears only in `mis/SMCOMX.COM` `[mis/SMCOMX.COM:L23-L24]`, and `mis/xsem00.f` declares `/SYSTEM/` inline `[mis/xsem00.f:L26-L27]`. The dispatcher will therefore obtain `KTIME` through the `*.COM` that actually carries `/SYSTEM/` (`SMCOMX.COM`) or via a minimal inline `/SYSTEM/` declaration consistent with NASTRAN's per-routine convention. This ambiguity is documented for maintainer confirmation.

- **Bootstrap call insertion.** The only change to executable control flow is `bin/nastrn.f` calling `NASTINIT` once, immediately after `CALL DBMINT` `[bin/nastrn.f:L44]`.

- **Dispatch argument passing.** `mis/xsem00.f` retains `MODX = RSHIFT(INOSCR(3),16)` `[mis/xsem00.f:L182]` and conceptually passes `MODX` into `disptbl.f` as an argument. Because `xsem00.f` is frozen, the dispatcher is not wired into the live ladder in this phase; it is exercised through the `test/dispatch/` drivers and the `NASTRAN_DISPATCH_VALIDATE` path, which compare the modern dispatcher's decisions against the catalogued legacy mapping. The live cutover (editing the ladder to `CALL DISPTBL`) is deferred precisely because it would modify the frozen file.

- **Build-graph integration.** Every new `.f` file is compiled, archived into `bin/nastlib.a`, and named on the link line by an updated `bin/linknas`, which already extracts and explicitly names all 39 `bd/` objects `[bin/linknas]`.

### 0.4.3 Wildcard Patterns

Wildcards are used only where a group is genuinely uniform, and only as **trailing** patterns (never leading). The patterns in play are `modern/init/*.f`, `modern/state/*.f`, `modern/dispatch/*.f`, `modern/diag/*.f`, `modern/regress/*.f`, `modern/docs/*.md`, `test/**/*.f`, and `test/**/*.ref`. Specific singleton files — `bin/nastrn.f`, `bin/linknas`, `test/regress/run_all.csh`, and `test/run_units.csh` — are named explicitly rather than matched by a pattern.

### 0.4.4 One-Phase Execution

The entire refactor — all CREATE operations across `modern/` and `test/`, plus the two UPDATE operations on `bin/nastrn.f` and `bin/linknas` — is executed by Blitzy in a **single phase**. The work is not split into multiple phases; all files are produced together so the explicit init path, the accessor layer, the dispatcher, the diagnostics layer, and the regression harness land as one coherent, buildable increment.


## 0.5 Dependency Inventory

### 0.5.1 Key Packages and Toolchain

This refactor introduces **no new external or third-party packages**. NASTRAN-95 is a self-contained 1995 NASA FORTRAN 77 codebase with no package manifest (no `requirements.txt`, `package.json`, `pom.xml`, or equivalent), so dependency versions are those provided by the Solaris build environment rather than semantically pinnable releases; no placeholder versions are invented. The relevant existing dependencies that the new code relies upon are catalogued below.

| Registry / Source | Name | Version | Purpose |
|-------------------|------|---------|---------|
| Solaris build host | `f77` (Sun/Solaris FORTRAN 77) | As installed on the build host; invoked `f77 -fast -dn` `[bin/linknas]` | Compile fixed-form FORTRAN 77 to objects and the final executable |
| Solaris build host | `csh` (C shell) | System | Runs `bin/linknas`, `bin/nastran`, `test/run_units.csh`, `test/regress/run_all.csh` |
| Solaris build host | `ar` (Unix archiver) | System | Maintains `bin/nastlib.a`; explicitly extracts the 39 `bd/` `BLOCK DATA` objects `[bin/linknas]` |
| In-repo (`INCLUDE`) | `*.COM` headers (the 9 files) | Repo (APR.95) | COMMON-block layout declarations included by `modern/*.f` |
| In-repo (system routines) | `BTSTRP`, `DBMINT`, `MESAGE`, `TMTOGO`, `GETENV`, `OPEN`/`READ` | Repo (APR.95) | Bootstrap `[nastrn.f:L32,L44]`, messaging `[nastrn.f:L36]`, time-to-go `[xsem00.f:L196]`, env config `[nastrn.f:L33]`, OSCAR POOL I/O `[xsem00.f:L87,L91]` |
| In-repo (artifact) | `bin/nastlib.a` | Repo | Prebuilt archive to which new `modern/` objects are added |

### 0.5.2 Dependency Updates

No dependency additions, removals, or version changes are made. The only build-graph change is that `bin/linknas` is updated to compile, archive, and link the new `modern/` and unit-test driver objects — a build-graph edge, not a package dependency.

### 0.5.3 Import / INCLUDE Refactoring

The "imports" in this FORTRAN codebase are `INCLUDE` directives and `COMMON`/`EQUIVALENCE` declarations. The rules for new `modern/` files are:

- **State access is `INCLUDE`-only.** Files that touch global state `INCLUDE` the relevant existing `*.COM` header rather than re-declaring COMMON — for example `modern/state/stateacc.f` and `modern/init/blkinit.f` include `NASNAMES.COM` (for `/DOSNAM/`, `/DSNAME/`), `DSIOF.COM` (for `/DSIO/`, `/FCB/`, `/DBM/`), or `SMCOMX.COM` (for `/SYSTEM/`, `/SMCOMX/`) as needed.
- **Zero independent COMMON re-declarations.** Every COMMON reference in `modern/` resolves through an `INCLUDE`d `*.COM`. This is verifiable by inspection: no literal `COMMON/...` declaration should appear in `modern/*.f` except via an included header.
- **Zero new `EQUIVALENCE`.** No new `EQUIVALENCE` statement is introduced; any variable that is `EQUIVALENCE`d in a `*.COM` is reached through that header exactly as declared.
- **Files requiring `INCLUDE` updates:** all new `modern/**/*.f` (which gain `INCLUDE` lines). No legacy file's declaration set changes — existing modules keep their current `COMMON` declarations untouched.
- **Apply-to pattern:** `modern/**/*.f` for `INCLUDE` additions; `bin/linknas` for the corresponding build-graph edges.


## 0.6 Special Analysis

The prompt mandates an explicit, two-candidate analysis for each of three algorithmic decisions (A1, A2, A3), with a recommendation justified against the FORTRAN 77 constraints and the actual codebase, recorded in `modern/docs/`. Those analyses follow, together with the cross-cutting concerns that condition the whole refactor.

### 0.6.1 A1 — Initialization Dependency Ordering

- **Candidate 1 — explicit hardcoded sequence in `nastinit.f`,** derived from static analysis of which COMMON block each `bd/` unit sets and which init routine reads it.
- **Candidate 2 — declarative dependency metadata resolved at startup via topological traversal.**

The 39 `bd/` units are pure `DATA` initializers of distinct named COMMON blocks (for example `dpdcbd` → `/DPDCOM/` `[bd/dpdcbd.f:L1-L26]`). `BLOCK DATA` semantics are order-independent: all values are placed at load time, with no inter-unit runtime sequencing. Genuine read-before-write dependencies among pure data blocks are therefore expected to be nil, which makes a full topological-sort engine over-engineering — it adds startup cost and new failure modes for a problem that does not exist at runtime.

**Recommendation: Candidate 1.** An explicit, inspectable sequence is deterministic, carries zero startup overhead, and trivially matches the load-time semantics it replaces. Candidate 2 is reserved only if analysis surfaces real read-before-write coupling (none is expected). Both candidates and the rationale are recorded in `init_modernization_report.md`.

### 0.6.2 A2 — FORTRAN 77 Dispatch Table under `f77 -fast -dn`

- **Candidate 1 — integer-indexed `IF`-`ELSEIF` chain over `MODX`** calling `EXTERNAL` subroutines directly, with a single `CALL TMTOGO(KTIME)` at the top before branching (mirroring the legacy placement).
- **Candidate 2 — a `DATA`-initialized `INTEGER` array mapping `MODX` to a sequence index** that drives a secondary `IF`-`ELSEIF` dispatch.

Both constructs are standard FORTRAN 77 and valid under the existing compiler flags: `-fast` is an aggressive optimization bundle that does not alter integer control-flow semantics, and `-dn` (static, non-dynamic storage) is fully compatible with `DATA`-initialized static arrays `[bin/linknas]`. The legacy mechanism is a 22-stage cascading computed-`GO TO` ladder spanning `MODX` 1–217 `[mis/xsem00.f:L262-L761]`, with the time check `CALL TMTOGO(KTIME)` placed *once*, before the ladder `[mis/xsem00.f:L196-L197]`; preserving a single pre-dispatch `TMTOGO` call is mandatory.

**Recommendation: Candidate 1.** A direct `IF`-`ELSEIF` over `EXTERNAL` subroutines is the most readable form, makes `MODX`→subroutine coverage trivial to audit against the catalogue, and eliminates the `GO TO`-maintenance hazard the refactor exists to remove; Candidate 2's extra indirection buys little in FORTRAN 77. The validator `dispval.f` asserts that the dispatcher's entry count equals the catalogued `MODX` count with no duplicate or unmapped codes, and routes any unmapped code to a fatal `MESAGE`.

A critical coexistence consequence follows from the freeze on `mis/xsem00.f`. The dispatcher is built with the `MODX`-passed-argument interface and validated in coexistence; the live cutover is deferred. This is textbook branch-by-abstraction — build and validate the new implementation against the same abstraction, then switch callers later.

<pre>
mermaid
flowchart TD
    A["xsem00.f (FROZEN): MODX = RSHIFT(INOSCR(3),16)"] --> B["Legacy 22-stage computed-GOTO ladder"]
    A -. "MODX catalogue (read-only)" .-> C["disptbl.f (NEW): table-driven dispatch"]
    C --> D["dispval.f: entry count == MODX count? no dup/unmapped?"]
    D --> E["NASTRAN_DISPATCH_VALIDATE=1: compare modern vs legacy mapping"]
    B --> F["Module subroutines (XCHK, AMG, APD, ...) - unchanged interfaces"]
    C -. "live cutover DEFERRED (would edit frozen xsem00.f)" .-> B
</pre>

### 0.6.3 A3 — Regression Output Comparison

- **Candidate 1 — line-by-line POSIX `diff` after whitespace normalization.**
- **Candidate 2 — a field-by-field FORTRAN comparator (`outcomp.f`)** that parses numeric fields and applies tolerance.

The `demoout/` files are classic OFP line-printer output containing volatile per-page headers such as `/ 95 SUN SOLARIS NASTRAN / MAY 17, 95 / PAGE n` and column-1 carriage-control characters `[demoout/d01001a.out:L1-L48]`. A naive `diff` produces false failures on the date and page-number lines and cannot apply numeric tolerance, so legitimate, format-sensitive floating-point round-trip differences would spuriously fail.

**Recommendation: Candidate 2.** The field-by-field comparator skips or normalizes the volatile date, page, and banner lines, applies a 6-significant-figure **relative** tolerance to floating-point fields, and requires **bitwise** identity for integer fields. This is the golden-master / characterization approach suited to complex printer output. The decision, the `demoout/` format evidence, and the test inventory are recorded in `regression_validation_report.md`.

### 0.6.4 Cross-Cutting Concerns

- **EQUIVALENCE-safe accessors.** `stateacc.f` wraps each needed COMMON variable exactly as declared in its `*.COM` header and introduces no new `EQUIVALENCE`; where a header already contains `EQUIVALENCE`, the accessor reads and writes the declared name through the included header. Compliance is verifiable by inspection — no `COMMON/` or `EQUIVALENCE` literal should appear in `modern/*.f` outside an `INCLUDE`.

- **Zero-overhead diagnostics.** Every routine in `modern/diag/` (and every validation hook) begins with `IF (IDIAG .EQ. 0) RETURN` as its first executable statement. `IDIAG` is set once by `diagctl.f` from the environment toggles, so when diagnostics are unset each routine returns immediately and incurs no measurable cost — a property verifiable purely by inspection.

- **Configuration and rollback.** NASTRAN's existing configuration idiom is environment variables read via `GETENV` at startup `[bin/nastrn.f:L33]`. The new toggles — `NASTRAN_LEGACY_INIT`, `NASTRAN_INIT_VALIDATE`, `NASTRAN_DISPATCH_VALIDATE`, and `NASTRAN_DISPATCH_LOG` — are read the same way; when unset, behavior is exactly APR.95. Rollback is therefore a configuration change (unset or flip a variable) requiring no recompilation, and the `bin/nastran` `csh` wrapper is the natural place for operators to set them. All diagnostic output is confined to logical unit 3, which the bootstrap sets via `LOUT = 3` immediately after `DBMINT` `[bin/nastrn.f:L45]`.

- **`/SYSTEM/` / `KTIME` discrepancy.** As noted in the cross-file dependencies, `/SYSTEM/` (which carries the cells the time check needs) is not present in `NASNAMES.COM`; among the nine headers it is declared only in `mis/SMCOMX.COM` `[mis/SMCOMX.COM:L23-L24]`. The dispatcher obtains `KTIME` through the header that actually declares `/SYSTEM/` or via a minimal inline `/SYSTEM/` declaration per NASTRAN's per-routine convention, and the discrepancy is flagged for maintainer confirmation.


## 0.7 Refactoring Rules

The user-specified rules list is empty; the binding rules below are therefore drawn from the prompt's constraints, success criteria, numerical-equivalence mandate, and rollback requirement, which function as the explicit refactoring rules for this effort.

### 0.7.1 Numerical Equivalence and Behavior Preservation

- **Bit-for-bit numerical equivalence.** Every numerical result, solver output, module execution order, and restart/checkpoint behavior must remain identical to the unmodified APR.95 solver. This is a refactor, not a rewrite.
- **Input decks are inviolate.** No `inp/*.inp` deck or its required syntax changes; all 132 benchmark decks must continue to run unchanged.
- **Public interfaces preserved.** The `CALL` interfaces of every dispatched module subroutine are preserved; the dispatcher invokes them exactly as the legacy ladder does `[mis/xsem00.f:L262-L761]`.
- **Validation target.** Reproduction is proven against the shipped reference outputs in `demoout/` using the field-by-field comparator (6-significant-figure relative tolerance for floats, bitwise identity for integers).

### 0.7.2 Hard Constraints

- **`bin/nastrn.f` — one change only.** Insert `CALL NASTINIT` (no arguments) immediately after the existing `CALL DBMINT` `[bin/nastrn.f:L44]`; no other edit to this file.
- **`mis/xsem00.f` — frozen.** It must not be modified; `MODX = RSHIFT(INOSCR(3),16)` `[mis/xsem00.f:L182]` and the POOL read stay unchanged, and `disptbl.f` receives `MODX` as a passed argument and never re-extracts it.
- **`bd/` and `*.COM` retained intact.** All 39 `BLOCK DATA` units and all nine `*.COM` `INCLUDE` files are kept, never deleted or disabled.
- **Configuration toggles.** The mechanism must enable/disable legacy initialization and legacy dispatch and must default to APR.95 behavior.
- **New `MESAGE` codes.** Only the 9001–9999 band (unassigned in `[um/MSSG.TXT]`) is used for new messages.
- **Diagnostic output destination.** All diagnostic output goes to logical unit 3 (`LOUT`) only — never stdout and never a new unit `[bin/nastrn.f:L45]`.
- **`KTIME` source.** Wall-clock budget is obtained from `/SYSTEM/` COMMON (see the discrepancy flag in 0.6.4 regarding which header declares it).
- **Accessors use existing headers.** Accessor subroutines use the existing `*.COM` `INCLUDE` files with zero independent COMMON re-declarations.
- **No new `EQUIVALENCE`.** Accessors introduce no new `EQUIVALENCE`; an `EQUIVALENCE`d variable is wrapped exactly as declared in its `*.COM`.
- **Zero runtime overhead when disabled.** Every diagnostic routine begins with `IF (IDIAG .EQ. 0) RETURN` as its first executable statement, verifiable by inspection.

### 0.7.3 Success Criteria

- All 39 `bd/` values are reproduced bitwise by `blkinit.f` (with `NASTRAN_INIT_VALIDATE=1` yielding zero divergence messages).
- All COMMON access by new modernization components routes through `stateacc.f`; legacy code is not required to adopt the accessors.
- The dispatcher's entry count equals the catalogued `MODX` count with zero omissions; with `NASTRAN_DISPATCH_VALIDATE=1`, there are zero sequence divergences across the five integration inputs.
- All `inp/*.inp` decks produce output matching `demoout/` under the comparator methodology (integer fields bitwise identical).
- Every diagnostic routine implements the guard clause as its first executable statement.

### 0.7.4 Configuration and Rollback Rules

- **No recompilation to change modes.** Mode selection is purely runtime via environment variables consumed at startup `[bin/nastrn.f:L33]`.
- **Immediate rollback to APR.95.** Rollback is achieved solely through configuration changes (unset or flip the relevant `NASTRAN_*` variable); the documented procedure requires no recompilation.
- **Default safety.** With no toggles set, an execution is bit-identical to the unmodified solver.

### 0.7.5 Testing Rules

- **Test scripts are generated, not executed by Blitzy.** `test/run_units.csh` and `test/regress/run_all.csh` are produced as deliverables and run in the developer's Solaris environment; each must exit non-zero on any failure.
- **Driver output contract.** Each FORTRAN unit driver emits `PASS: <name>` or `FAIL: <name>` to the log unit; `run_units.csh` greps for `FAIL:` and exits non-zero on a match.
- **Regression reusability.** `test/regress/run_all.csh` is a single command that runs all benchmark decks, applies the comparator, reports per-file PASS/FAIL, and is reusable for future modernization phases.

### 0.7.6 Documentation Rules

Six markdown deliverables are required in `modern/docs/`. `pre_implementation_analysis.md` is authored **before** any `.f` file and must contain the complete `bd/` inventory with COMMON/variable mapping, the complete per-`*.COM` variable inventory, the full `MODX`→entry-point mapping table, and the five integration-test input filenames with their SOL types. The remaining five reports (`init_`, `state_`, `dispatch_`, `regression_validation_`, and `final_modernization_summary`) capture per-mechanism status, the A1/A2/A3 decisions with rejected alternatives, evidence of zero COMMON re-declarations, `TMTOGO` placement confirmation, `demoout/` format evidence, and consolidated risk-reduction metrics with named next-candidate modules.


## 0.8 Attachments

No attachments were provided for this project. The `review_attachments` inspection returned no files, so there are no documents, images, or PDFs to summarize, and no Figma frames or URLs to enumerate. The refactoring requirements are therefore drawn entirely from the user prompt and from direct inspection of the repository at `[/tmp/blitzy/blitzy-NASTRAN-95/master_fc613b]`.

Because no Figma designs and no component library or design system are present, the design-to-system mapping and Design System Compliance protocol are not applicable to this refactor (see also 0.3.4, User Interface Design).


