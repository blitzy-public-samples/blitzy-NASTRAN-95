# NASTRAN-95 Modernization — Initialization Report

> **Mechanism:** Initialization modernization — the explicit, ordered, validated
> init path under `modern/init/` that reproduces the load-time `COMMON` state seeded
> by the 39 legacy `bd/` `BLOCK DATA` units (AAP §0.2.1, §0.6.1, §0.7.6).
>
> **Scope framing:** This is an **encapsulation / modularity refactor only** — it is
> emphatically **not** a rewrite, a performance change, or a technology migration.
> The contract is **bit-for-bit numerical equivalence**, identical **module
> execution order**, and identical **restart/checkpoint** behavior with the
> unmodified APR.95 solver. The 39 `bd/` `BLOCK DATA` units remain **linked and
> unmodified**, so in the real solver they continue to seed every `COMMON` at load
> time; the modern explicit path **coexists** with them (Branch by Abstraction) and
> is gated behind environment toggles that default to exact APR.95 behavior
> (Strangler-Fig feature-toggle cutover). The init layer introduces **zero new
> `COMMON`** and **zero new `EQUIVALENCE`** — all global state is reached only
> through the existing nine `*.COM` `INCLUDE` headers (AAP §0.5.3).
>
> **Authoring order:** this report is authored **after**
> `modern/docs/pre_implementation_analysis.md`, which supplies the authoritative
> `bd/` → `COMMON` inventory (its **Section A**) and the header-reachability
> analysis (its **Section E**) that this report references, summarizes, and builds
> upon. Where this report states counts, they are reconciled against that inventory
> and against the locked sibling source `modern/init/blkinit.f`.

---

## Purpose

This report documents the **initialization-modernization** mechanism of the
NASTRAN-95 refactor — the replacement of the implicit, link-line-dependent
`BLOCK DATA` pull with an **explicit, ordered, inspectable, validated** init path,
realized by three source files under `modern/init/`:

| File | Role |
|---|---|
| `modern/init/nastinit.f` | The single initialization entry point invoked by `CALL NASTINIT`; reads the `NASTRAN_LEGACY_INIT` toggle via `GETENV` and orchestrates the explicit init path. |
| `modern/init/blkinit.f` | The explicit, ordered initializer that reproduces the **safe subset** of `COMMON` values seeded by the 39 `bd/` units, reaching state **exclusively** through existing `*.COM` `INCLUDE` headers. |
| `modern/init/initval.f` | The bitwise initialization-state validator that compares the modern init result against the legacy `BLOCK DATA` values and reports any divergence. |

Specifically, this report records:

- the **A1 algorithm decision** — *initialization dependency ordering* — with both
  candidates and the **explicit rejection rationale** for the alternative
  (AAP §0.6.1, mandated by §0.7.6);
- the **39-unit reproduction status** — what the `bd/` tree contains, which units
  are reproduced, and the retain-intact / rollback posture;
- the **header-reachability & deferral analysis** — the crux of the init layer:
  exactly which `bd/`-seeded `COMMON` blocks are `INCLUDE`-reachable through the
  nine `*.COM` headers, which are deferred, and why;
- the **bootstrap integration** — the single permitted control-flow edit
  (`CALL NASTINIT` after `CALL DBMINT`) and the `nastinit.f` toggle behavior;
- the **validator** `initval.f` — its guard-clause, exact (non-tolerance)
  comparison, and diagnostic codes; and
- the **toggles, rollback, open flags, and success criteria** that close out the
  mechanism.

The governing patterns are **Branch by Abstraction** (the modern init path is built
*inside* the codebase and coexists with the still-linked `bd/` units),
**Strangler-Fig feature-toggle cutover** (the `NASTRAN_*` env toggles select the
path and enable instant, recompilation-free rollback), and — for `initval.f` —
the **Template Method** (setup → compare → report) and **Guard Clause**
(`IF (IDIAG .EQ. 0) RETURN` first) patterns shared across the modernization's
validators.

---

## A1 Decision: Initialization Dependency Ordering

> **Decision:** **Candidate 1 — explicit, hardcoded, inspectable initialization
> sequence — is ACCEPTED.** Candidate 2 (declarative dependency metadata resolved
> at startup by a topological-sort traversal) is **REJECTED**. This subsection
> states both candidates and the rejection rationale, as required by AAP §0.7.6.

### Candidate 1 — Explicit hardcoded ordered sequence *(ACCEPTED / RECOMMENDED)*

An explicit, hardcoded, fixed-order initialization sequence realized in
`modern/init/blkinit.f` and orchestrated by `modern/init/nastinit.f`, derived from
**static analysis** of which `COMMON` block each `bd/` unit sets and which init
consumer reads it. The sequence is a fixed, commented, ascending-cell-ordered
series of assignments — open to line-by-line inspection and trivially auditable
against the `bd/` golden values.

### Candidate 2 — Declarative dependency metadata + topological sort *(REJECTED)*

A declarative table of inter-unit dependency metadata, resolved at startup by a
topological-sort traversal that computes a safe initialization order dynamically.

### Rationale

The 39 `bd/` units are **pure `DATA` initializers of distinct named `COMMON`
blocks** (for example, `bd/dpdcbd.f` populates `COMMON /DPDCOM/` via
`DATA DPOOL/101/, GPL/102/, SIL/103/, USET/104/, …`). `BLOCK DATA` semantics are
**order-independent**: every value is placed into its `COMMON` block **at load
time**, with **no inter-unit runtime sequencing** and **no read-before-write
coupling** among the units. Genuine read-before-write dependencies among these
pure data blocks are therefore **nil**.

Consequently, a full topological-sort engine is **over-engineering**: it would add
startup cost and introduce new failure modes (cycle detection, metadata drift,
ordering bugs) to solve a problem that **does not exist at runtime**. Candidate 1,
by contrast, is:

- **deterministic** — the order is fixed and visible in source;
- **zero-overhead** — no graph construction or traversal at startup;
- **inspectable** — each assignment is a commented, single-cell store that an
  auditor can match directly to the `bd/` golden; and
- **semantically faithful** — it trivially matches the load-time `BLOCK DATA`
  semantics it mirrors.

**Candidate 2 is reserved only as a contingency** — to be revisited **if and only
if** later analysis surfaces a real read-before-write coupling among
initialization steps (none is expected, and none was found). This decision and its
rejected alternative are recorded here per AAP §0.7.6; the same A1 decision is
documented in-source in the header of `modern/init/blkinit.f`.

---

## 39-Unit Reproduction Status

The full `bd/` → `COMMON` inventory with per-unit variable mapping lives in
`modern/docs/pre_implementation_analysis.md` **Section A**; this section summarizes
that inventory and records the reproduction status. The key facts:

- The `bd/` tree contains **40 `.f` files**, of which **39 are `BLOCK DATA`
  units**. The single outlier is **`bd/ferfbd.f`**, which is a **`SUBROUTINE`**
  (a memory/file matrix reader, *not* a `BLOCK DATA`); it initializes nothing and
  is therefore **not** explicitly named on `bin/linknas` (it is auto-pulled from
  the archive like any referenced routine, unlike `BLOCK DATA` objects which must
  be named explicitly because nothing references their symbols).
- The **principal unit is `bd/semdbd.f`** — **757 lines** declaring **31 active
  `COMMON` blocks**, including `/SYSTEM/`, `/SEM/`, `/XLINK/`, `/XFIST/`,
  `/GINOX/`, `/BLANK/`, `/MACHIN/`, `/OUTPUT/`, `/OSCENT/`, `/XVPS/`, `/XDPL/`,
  `/NAMES/`, `/TYPE/`, `/BITPOS/`, `/TWO/`, and more. (A 32nd block, `/DESCRP/`,
  appears in `semdbd.f` only as **commented-out** text — it has been fully removed
  from the active declaration set since the 1992 version — so the active count is
  **31**; see the count reconciliation in the next section.)
- The legacy `bd/` units are **retained intact and unmodified** as the **source of
  truth** for validation and rollback. The toggle `NASTRAN_LEGACY_INIT` selects the
  legacy path; because the `BLOCK DATA` objects remain linked, an unconfigured run
  is bit-identical to APR.95 regardless of what the modern path does.
- `modern/init/blkinit.f` reproduces `COMMON` values by reaching state **only**
  through existing `*.COM` `INCLUDE` headers **where reachable**; it declares
  **zero new `COMMON`** and **zero new `EQUIVALENCE`**.

**Status summary**

| Mechanism | Status |
|---|---|
| `bd/` unit catalogue | **39 `BLOCK DATA` units** catalogued (40 files; `bd/ferfbd.f` is a `SUBROUTINE` outlier) |
| Principal unit `bd/semdbd.f` | 757 lines, **31 active `COMMON` blocks** — analyzed; `/SYSTEM/` config cells reproduced |
| `/SYSTEM/` (via `SMCOMX.COM`) | **`INCLUDE`-reachable & reproduced** — 9 safe, non-machine config cells written by `blkinit.f` |
| `/GINOX/` (via `GINOX.COM`) | **`INCLUDE`-reachable but NOT written** — header-layout collision (DO-NOT-WRITE; see next section) |
| Remaining `bd/`-seeded blocks | **87 header-unreachable blocks DEFERRED & flagged** (≈86–87 per `pre_implementation_analysis.md` Section E) |
| Legacy `bd/` units | **Retained intact & unmodified** — source of truth for `initval.f` and rollback |
| New `COMMON` / `EQUIVALENCE` | **Zero / Zero** — all access via existing `*.COM` `INCLUDE` |

---

## Header-Reachability & Deferral Analysis

This is the **crux of the init layer**. The "zero new `COMMON`" rule (AAP §0.5.3,
§0.7.2) means the modern initializer may touch global state **only** through one of
the nine existing `*.COM` `INCLUDE` headers. That rule, applied to the `bd/`
inventory, produces a sharp and verified reachability gap (`pre_implementation_analysis.md`
**Section E**):

- The 39 `bd/` units seed **89 distinct active `COMMON` blocks**.
- Of those, **exactly 2 are `INCLUDE`-reachable** through the nine `*.COM`
  headers: **`/SYSTEM/`** and **`/GINOX/`** (both declared by `bd/semdbd.f`).
- The other **87 are NOT `INCLUDE`-reachable** — no header declares them.

> **Count reconciliation (89/87 vs 90/88).** The locked sibling
> `modern/init/blkinit.f` (Maintainer Flag 2) cites *"90 distinct … 88 remaining"*.
> The difference is **exactly one block — `/DESCRP/`** — which `blkinit.f`
> conservatively lists in `semdbd`'s deferred manifest, but which is **commented
> out** in `bd/semdbd.f` (fully removed from the active declaration set since the
> 1992 version; it survives only as comment text). Counting **active `COMMON`
> statements** yields **89 distinct / 87 unreachable**; counting the dormant
> `/DESCRP/` yields 90 / 88. The **active-statement count (89 / 2 / 87) is
> authoritative for this report** and matches `pre_implementation_analysis.md`
> Section E; the one-block delta is purely the inactive `/DESCRP/`.

### Resulting `blkinit.f` design

`blkinit.f` `INCLUDE`s only the header it can safely use — **`SMCOMX.COM`**, the
sole one of the nine headers that declares `/SYSTEM/`. Of the two reachable blocks,
only `/SYSTEM/` is **safely writable**; `/GINOX/` is reachable but **must not be
written** (layout collision, below). Two cautions govern the design.

#### `/GINOX/` name collision — DO NOT WRITE

`bd/semdbd.f` declares `COMMON /GINOX / CDC(244)` and seeds it with
`DATA CDC / 244*0 /` (244 zero words, plus an `OTHERS(392)` tail — 636 words
total). The header `mds/GINOX.COM` declares `/GINOX/` with a **completely
different layout** — `LGINOX, IDSLIM, MDSFCB(3,89), LENSOF(10)`
(`PARAMETER NUMFCB=89, NUMSOF=10`; ≈279 words) representing the modern disk-I/O
state. Writing `semdbd`'s zero-fill *through* `mds/GINOX.COM` would be semantically
invalid and could corrupt live disk-I/O state. Therefore `blkinit.f` **does not
`INCLUDE` `GINOX.COM` and does not initialize `/GINOX/`**. Although `/GINOX/` is
nominally header-reachable, it is treated as **deferred for writing**, leaving
`/SYSTEM/` as the only block actively reproduced.

#### `/SYSTEM/` clobber caution — write only safe config cells

The `/SYSTEM/` machine cells are populated by `BTSTRP` and `DBMINT` **before**
`NASTINIT` runs, so `blkinit.f` must not overwrite them. Using the `SMCOMX.COM`
`/SYSTEM/` layout — `ISYSBF(1), NOUT(2), DUM1(37) = cells 3–39, NBPW(40), DUM2(14) = cells 41–54, ISPREC(55)` —
`blkinit.f` writes **only the safe,
non-machine, `BTSTRP`/`DBMINT`-untouched configuration cells**. The actively
reproduced set is the **nine** cells below (golden values from `bd/semdbd.f`
`DATA` block ~L555–576; each `DUM1(j)` addresses `/SYSTEM/` physical cell `j+2`):

| `/SYSTEM/` cell | Name | Value | `SMCOMX.COM` slot | Meaning |
|---|---|---|---|---|
| 8 | `LOAD` | `1` | `DUM1(6)` | load / restart control flag |
| 14 | `MXLINS` | `20000` | `DUM1(12)` | maximum output lines per run |
| 19 | `ECHOF` | `2` | `DUM1(17)` | input echo control flag |
| 23 | `LSYSTM` | `180` | `DUM1(21)` | declared length of `/SYSTEM/` (words) |
| 24 | `ICFIAT` | `11` | `DUM1(22)` | FIAT words-per-entry selector (8 or 11) |
| 29 | `MAXFIL` | `35` | `DUM1(27)` | maximum number of files |
| 30 | `MAXOPN` | `16` | `DUM1(28)` | maximum simultaneously-open files |
| 34 | `NBRCBU` | `15` | `DUM1(32)` | CDC-only FET + dummy-index length |
| 35 | `LPRUS` | `64` | `DUM1(33)` | CDC-only words per physical record unit |

**`DUM1` typing.** `DUM1` is named only by the `SMCOMX.COM` `COMMON` statement,
which gives it no explicit type; by FORTRAN default typing a `D`-initial name is
`REAL`. Because every cell above is an integer, `blkinit.f` types `DUM1` as
`INTEGER` to guarantee integer store semantics. This is a **type declaration only**
— the array extent `(37)` still comes from the `INCLUDE`d `COMMON` statement — and
is **neither a new `COMMON` nor an `EQUIVALENCE`**.

**`BTSTRP`/`DBMINT` non-clobber proof.** `BTSTRP` writes `/SYSTEM/` cells
`{1, 2, 4, 9, 22, 39, 40, 41, 42, 43, 44, 55, 91, 92}` and `DBMINT` writes none of
the configuration cells; the nine cells `blkinit.f` writes —
`{8, 14, 19, 23, 24, 29, 30, 34, 35}` — have an **empty intersection** with that
set. Every `blkinit.f` write is therefore provably `BTSTRP`/`DBMINT`-untouched and
hence **idempotent** in the real solver (it re-affirms values the linked `bd/`
units already placed) and **active** in the unit-test executable (where the
`BLOCK DATA` objects are not linked and `COMMON` starts zeroed).

> **`NBPW` cell-position note (resolved).** A naive all-scalar count would place
> `NBPW` at word 38; the **array-aware** count — honoring `DATE(3)`, `SYSDAT(3)`,
> `ADUMEL(9)`, `MODCOM(9)`, `HDY(3)`, `SWITCH(3)`, `K8890(3)`, `LEFT(56)`,
> `LEFT2(28)` in `bd/semdbd.f` — makes `/SYSTEM/` exactly **180 words**
> (`= LSYSTM`) and places `NBPW` at **cell 40**. This is corroborated independently
> by the `mds/btstrp.f` `EQUIVALENCE`s `B(40)=NBPW`, `B(22)=LINKNO`, `B(41)=NCPW`,
> `B(55)=IPREC`, so the absolute `DUM1` indices in the table above are reliable.

#### Cells deliberately excluded

Four `bd/`-set `/SYSTEM/` values are **deliberately not written** by `blkinit.f`:

| Cell | Name | Value | Reason excluded |
|---|---|---|---|
| 31 | `HICORE` | `85000` | A **machine** memory-size constant (e.g., "VAX: HICORE IS SET TO 50,000 BY BTSTRP"); excluded to avoid clobber risk. |
| 70 | `TOLEL` | `0.01` (`REAL`) | Cell lies **beyond cell 55** (`ISPREC`), the last `/SYSTEM/` cell `SMCOMX.COM` declares. |
| 85 | `LINTC` | `800` | Cell lies **beyond cell 55** — unreachable through `SMCOMX.COM`. |
| 87 | `OSPCNT` | `15` | Cell lies **beyond cell 55** — unreachable through `SMCOMX.COM`. |

`TOLEL`, `LINTC`, and `OSPCNT` are bd-set and non-machine, but reaching them would
require editing the frozen `SMCOMX.COM` or declaring new `COMMON` — both forbidden
— so they are **deferred** (see **Open Flags**). `HICORE` is reachable
(`DUM1(29)`) but excluded as a machine constant.

#### Deferral of the header-unreachable blocks

The **87** header-unreachable `COMMON` blocks (≈86–87 per
`pre_implementation_analysis.md` Section E) are **explicitly DEFERRED and flagged**
for maintainer confirmation. Reproducing them would require declaring new `COMMON`,
authoring new `INCLUDE` headers, or adding `EQUIVALENCE` — all forbidden by the
zero-new-`COMMON` rule. Creating dedicated modern headers for them is a **future
phase**. The deferred set spans, among others (originating unit → block):
`bd/dpdcbd.f` → `/DPDCOM/`; `bd/flbbd.f` → `/FLBFIL/`; `bd/of1pbd.f` → `/OFPB1/`;
`bd/readbd.f` → `/REGEAN/`, `/INVPWX/`, `/GIVN/` (whose goldens include **`REAL`**
values `RMAX=100.0`, `RMIN=.01`, `EPSI=1.0E-11`, `EPS=.0001`, `LMAX=60.`, proving
that any full reproduction must handle `REAL`, not only integers); and the ~30
further `semdbd`-declared blocks (`/SEM/`, `/XLINK/`, `/XFIST/`, `/OSCENT/`,
`/OUTPUT/`, …). The complete per-block coverage table is owned by
`pre_implementation_analysis.md` Section A; the in-source deferral manifest is in
`modern/init/blkinit.f` (Maintainer Flag 2).

---

## Bootstrap Integration (single edit)

The **only** permitted change to the executable control flow is a single inserted
line in `bin/nastrn.f`: `CALL NASTINIT` (no arguments), placed **immediately after
`CALL DBMINT`** (`bin/nastrn.f` L44) and **before `LOUT = 3`** (`bin/nastrn.f`
L45). The surrounding bootstrap is:

```text
bin/nastrn.f  (bootstrap, abridged)
   L32   CALL BTSTRP            ! seeds /SYSTEM/ machine constants
   ...
   L44   CALL DBMINT           ! database manager init
   ----> CALL NASTINIT          <-- the single inserted line (no arguments)
   L45   LOUT   = 3            ! diagnostic log unit established here
   ...
   L115  OPEN (3, ...)         ! unit 3 actually opened later
```

This insertion point is deliberate: `NASTINIT` runs **after** `BTSTRP` and `DBMINT`
have populated the machine constants in `COMMON`, so the modern initializer must —
and provably does — **not overwrite** them (see the non-clobber proof above). It
also runs **before** unit 3 is opened (`bin/nastrn.f` L115), which is why
`blkinit.f` performs **no I/O** of any kind.

> **Ownership note.** This single edit to `bin/nastrn.f` is owned by the `bin/`
> agent and is the **one** change permitted to that file (AAP §0.7.2); this
> document does **not** modify `bin/nastrn.f`. As of this report the
> `CALL NASTINIT` line is not yet present in `bin/nastrn.f`; it is described here as
> the contracted insertion that wires the init layer into the bootstrap.

### `nastinit.f` invocation behavior

`modern/init/nastinit.f` is the single init entry point. Its behavior (consistent
with the cross-references in the locked sibling `modern/init/blkinit.f`):

1. **Read the toggle.** It reads `NASTRAN_LEGACY_INIT` via `GETENV` using the
   `bin/nastrn.f` idiom (a `CHARACTER*80 VALUE` receiver pre-blanked to `' '`).
2. **Select the path.**
   - **Unset ⇒ modern path:** `CALL BLKINIT` performs the explicit, ordered
     reproduction of the safe `/SYSTEM/` config cells.
   - **Set ⇒ legacy path:** the modern explicit reproduction is skipped; the
     still-linked `bd/` `BLOCK DATA` units remain the sole initializer (exact
     APR.95 behavior).
3. **Optionally validate.** If `NASTRAN_INIT_VALIDATE` is set, it then calls
   `CALL INITVAL(NDIV)` to confirm the modern result matches the legacy goldens.

Because the `bd/` units are linked in both cases, neither path alters the numerical
result; the toggle selects **which mechanism is exercised**, not **what values end
up in `COMMON`**.

---

## Toggles & Rollback

Initialization behavior is controlled entirely at **runtime** through environment
variables, read once via `GETENV` at startup (the existing NASTRAN configuration
idiom, `bin/nastrn.f` L33). The two init-relevant toggles, and their `IDIAG` bit
values as computed by `modern/diag/diagctl.f`:

| Toggle | `IDIAG` bit | Effect when set | Default (unset) |
|---|---|---|---|
| `NASTRAN_LEGACY_INIT` | bit value `1` | Select the **legacy** `bd/` init path (skip the modern explicit reproduction) | Modern explicit path (`CALL BLKINIT`) |
| `NASTRAN_INIT_VALIDATE` | bit value `2` | Run `CALL INITVAL(NDIV)` to bitwise-compare modern vs legacy init | Validation skipped |

- **Default safety.** With **both unset**, `IDIAG = 0`, every guarded modern
  routine short-circuits, and execution is **bit-identical to the unmodified APR.95
  solver** — zero overhead.
- **Rollback.** Rollback to APR.95 is a pure **configuration change** — unset or
  flip the relevant `NASTRAN_*` variable — and requires **no recompilation**
  (AAP §0.7.4). This is the Strangler-Fig cutover-control property: the legacy
  mechanism remains the default and is always one env-var away.
- **Operator placement.** Operators set these toggles inline in the `bin/nastran`
  `csh` run wrapper's environment list (the `env NAME=val …` block preceding
  `nastrn.exe`, alongside `LOGNM=$probname.log`, the logical-unit-3 log file).

`diagctl.f` sums the set toggles into `IDIAG` (the four modernization toggles
contribute bit values `1`, `2`, `4`, `8`; `IDIAG = 0` when none are set, `15` when
all four are). `IDIAG` is returned as an **output argument**, not stored in any new
`COMMON`, to honor the zero-new-`COMMON` rule.

---

## Validation (`initval.f`)

`modern/init/initval.f` is the **bitwise initialization-state validator**. It
proves that the modern explicit init reproduces the legacy `BLOCK DATA` values
exactly. Its contract:

- **Signature:** `SUBROUTINE INITVAL(NDIV)` — `NDIV` is the **divergence count**
  returned to the caller (`0` ⇒ no divergence).
- **Guard clause first.** The **first executable statement** obtains `IDIAG` and
  guards on it: `CALL DIAGCTL(IDIAG)` then `IF (IDIAG .EQ. 0) RETURN`. When no
  toggle is set the validator returns immediately with zero overhead — the
  zero-cost-when-disabled property (AAP §0.6.4, §0.7.2). The validator then acts on
  the **`NASTRAN_INIT_VALIDATE` bit (bit value `2`)** set by `diagctl.f`.
- **Exact comparison (not tolerance).** Initialization values are integers (and
  exact `REAL` constants), so `initval.f` uses an **exact `.NE.` comparison**, not
  a numeric tolerance. (Tolerance-based comparison is the regression comparator's
  job for *solver output*, `modern/regress/outcomp.f`; it is **not** appropriate
  for init goldens.)
- **Lock-step contract with `blkinit.f`.** The set of cells `initval.f` validates
  **must equal exactly** the **nine** `/SYSTEM/` cells that `blkinit.f` writes
  (`LOAD, MXLINS, ECHOF, LSYSTM, ICFIAT, MAXFIL, MAXOPN, NBRCBU, LPRUS`). The two
  files are kept synchronized; this cell set is the authoritative record of that
  contract.
- **Reporting via `DIAGLOG`.** Divergences are reported through
  `modern/diag/diaglog.f` (logical unit 3 only) using `MESAGE` codes in the
  **`9100`–`9199`** sub-band:

  | Code | Meaning |
  |---|---|
  | `9100` | Validation summary line (e.g., `NDIV` total) |
  | `9101` | A `/SYSTEM/` cell value diverges from its `bd/` golden |
  | `9150` | `/GINOX/` collision — block intentionally not reproduced (deferred) |
  | `9160` | A header-unreachable `bd/`-seeded block — deferred, not reproduced |

- **Test-driver sentinel.** The `test/init/` unit drivers preset `NDIV` to a
  sentinel (e.g., `999999`) before calling `INITVAL`, so that a clean run that
  **actively sets `NDIV = 0`** demonstrably proves zero divergence (rather than a
  value that merely *defaulted* to zero). On the guarded (`IDIAG .EQ. 0`) early
  return, `NDIV` is left untouched, so callers needing a defined value seed it
  first.
- **Success.** With `NASTRAN_INIT_VALIDATE=1`, `initval.f` yields **zero
  divergence messages** (`NDIV = 0`) — every reproduced cell bitwise-matches its
  `bd/semdbd.f` golden.

---

## Open Flags

The following items are flagged for maintainer confirmation. None blocks the
encapsulation-only, bit-for-bit deliverable (the `bd/` units remain linked and
authoritative); each is a future-phase decision.

1. **Shared `9100`–`9199` diagnostic sub-band (init + state).** The init validator
   `initval.f` and the state validator `modern/state/stateval.f` **both** draw
   their codes from the `9100`–`9199` sub-band. This shared allocation is
   **intentional** — both are load-time / startup-consistency validators — and is
   ratified in `modern/docs/final_modernization_summary.md` (item *f*) and in the
   "Shared sub-band — maintainer note" of `modern/docs/state_modernization_report.md`.
   To avoid numeric collisions within the shared band, `initval.f` uses
   `9100`/`9101`/`9150`/`9160` and deliberately avoids `stateval.f`'s
   `9102`–`9106` detail cluster; the lone numeric overlap (`9100` summary, `9101`
   divergence) is disambiguated at the point of emission by the distinct routine
   and the `DIAGLOG` `MSG` label. **Flag:** if strict per-code exclusivity is later
   desired, `initval.f`'s detail codes can shift to a reserved init-only slice
   (e.g., `9110`–`9169`) without affecting `stateval.f`. The dispatch validator,
   by contrast, uses `9300`–`9399`.

2. **`/SYSTEM/` cells beyond `SMCOMX.COM` cell 55.** `TOLEL` (cell 70, `REAL`
   `0.01`), `LINTC` (cell 85, `800`), and `OSPCNT` (cell 87, `15`) are bd-set and
   non-machine, yet lie **beyond cell 55** (`ISPREC`), the last `/SYSTEM/` cell
   `SMCOMX.COM` declares. They are therefore **not** reproduced by `blkinit.f`;
   reaching them would require editing the frozen `SMCOMX.COM` or declaring new
   `COMMON`, both forbidden. **Flag:** a future phase may add a maintainer-authored
   modern header that exposes these cells.

3. **`/GINOX/` header-layout collision.** `bd/semdbd.f`'s `/GINOX/` view
   (`CDC(244)` = `244*0`, plus `OTHERS(392)`) differs entirely from
   `mds/GINOX.COM`'s disk-I/O layout (`LGINOX, IDSLIM, MDSFCB(3,89), LENSOF(10)`).
   `blkinit.f` deliberately does **not** write `/GINOX/`. **Flag:** confirm that no
   modern component requires the `semdbd` `/GINOX/` zero-fill view; if one does, a
   separate, correctly-named header is needed.

4. **`87` header-unreachable `bd/`-seeded blocks deferred.** The bulk of the
   `bd/` state (e.g., `/DPDCOM/`, `/FLBFIL/`, `/OFPB1/`, `/REGEAN/`, `/INVPWX/`,
   `/GIVN/`, and the ~30 further `semdbd` blocks) is unreachable through any of the
   nine headers and is **deferred**. Note that `bd/readbd.f`'s goldens include
   `REAL` constants, so any future reproduction of those blocks must handle `REAL`
   values, not only integers. **Flag:** creating dedicated modern `INCLUDE` headers
   for these blocks is a future phase that would relax (in a controlled way) the
   strict "reach existing headers only" posture.

5. **`KTIME` / `/SYSTEM/` header note.** `/SYSTEM/` is **not** declared in
   `NASNAMES.COM`; among the nine headers it is declared **only** in
   `mis/SMCOMX.COM`. This report's init layer reaches `/SYSTEM/` through
   `SMCOMX.COM` accordingly. The related `KTIME`-from-`/SYSTEM/` question for the
   dispatcher is documented in `modern/docs/dispatch_modernization_report.md`; it
   is noted here only because it shares the same `/SYSTEM/` header reality.

6. **Count reconciliation already noted.** The `89`/`87` (active) vs `90`/`88`
   (`blkinit.f` Maintainer Flag 2, counting the dormant `/DESCRP/`) delta is
   reconciled in the **Header-Reachability & Deferral Analysis** section; the
   active-statement count is authoritative.

---

## Success Criteria

The init-mechanism success criteria (AAP §0.7.3), with status:

- [x] **A1 decision recorded with rejected alternative.** Candidate 1 (explicit
      hardcoded sequence) accepted; Candidate 2 (topological sort) rejected with
      the order-independent-pure-`DATA` rationale (AAP §0.7.6).
- [x] **Safe `/SYSTEM/` config cells reproduced bitwise.** The nine reachable,
      non-machine config cells are reproduced by `blkinit.f` from the
      `bd/semdbd.f` goldens; with `NASTRAN_INIT_VALIDATE=1`, `initval.f` reports
      **zero divergence** over that set. Header-unreachable blocks are deferred and
      flagged (not silently skipped).
- [x] **Legacy `bd/` units retained intact** as the source of truth for validation
      and rollback; selectable via `NASTRAN_LEGACY_INIT`.
- [x] **Validator guard clause first.** `initval.f` begins with
      `CALL DIAGCTL(IDIAG)` / `IF (IDIAG .EQ. 0) RETURN` (zero overhead when
      disabled). `blkinit.f` is deliberately guard-exempt because it is an
      *initializer*, not a diagnostic, and must perform its idempotent
      initialization whenever invoked.
- [x] **Zero new `COMMON`, zero new `EQUIVALENCE`.** All state access is via
      `INCLUDE 'SMCOMX.COM'`; the only declaration is the `INTEGER DUM1` type
      assignment, which is neither a `COMMON` nor an `EQUIVALENCE`.
- [x] **Default safety & rollback.** Both toggles unset ⇒ `IDIAG = 0` ⇒
      bit-identical to APR.95; rollback is a configuration change with no
      recompilation (AAP §0.7.4).
- [x] **Single bootstrap edit contracted.** Exactly one inserted line
      (`CALL NASTINIT` after `CALL DBMINT`, `bin/nastrn.f` L44), owned by the
      `bin/` agent; no other change to `bin/nastrn.f`.

---

## Provenance (read-only)

The following existing artifacts were read as references / sources of truth and are
**not modified** by this document:

- `bd/*.f` — the 39 `BLOCK DATA` units, especially `bd/semdbd.f` (principal, 757
  lines, 31 active `COMMON` blocks), `bd/dpdcbd.f` (`/DPDCOM/`), `bd/of1pbd.f`
  (`/OFPB1/`), `bd/readbd.f` (`/REGEAN/`, `/INVPWX/`, `/GIVN/`; `REAL` goldens),
  and `bd/flbbd.f` (`/FLBFIL/`).
- `mds/GINOX.COM`, `mis/SMCOMX.COM`, `mds/DSIOF.COM`, `bin/NASNAMES.COM` — the
  `*.COM` `INCLUDE` headers consulted for `/SYSTEM/`, `/GINOX/`, and reachability.
- `bin/nastrn.f` — the bootstrap (`CALL BTSTRP` L32, `CALL DBMINT` L44, `LOUT = 3`
  L45, `OPEN(3,…)` L115).
- `bin/linknas` — the build script (39 `bd/` objects explicitly named;
  `f77 -fast -dn`).

Sibling modern sources referenced (analyzed for alignment, not modified here):
`modern/init/nastinit.f`, `modern/init/blkinit.f`, `modern/init/initval.f`,
`modern/diag/diagctl.f`, `modern/diag/diaglog.f`. Companion documentation:
`modern/docs/pre_implementation_analysis.md` (the authoritative `bd/`/`COMMON`
inventory, Sections A and E), `modern/docs/state_modernization_report.md`, and
`modern/docs/final_modernization_summary.md`. None of these files is modified by
this report.

