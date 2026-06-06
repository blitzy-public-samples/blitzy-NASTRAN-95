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
> (Strangler-Fig feature-toggle cutover). Every `modern/init/*.f` **source body**
> introduces **zero literal `COMMON`** and **zero `EQUIVALENCE`** — all global state
> is reached only through `INCLUDE` headers (the existing nine `*.COM` plus the
> project-internal `bd/`-coverage headers introduced as the AAP-approved coverage
> the prior review endorsed; see **Reproduction Coverage**).
>
> **Authoring order:** this report is authored **after**
> `modern/docs/pre_implementation_analysis.md`, which supplies the authoritative
> `bd/` → `COMMON` inventory (its **Section A**) and the reachability analysis (its
> **Section E**) that this report references, summarizes, and builds upon.

---

## Purpose

This report documents the **initialization-modernization** mechanism of the
NASTRAN-95 refactor — the replacement of the implicit, link-line-dependent
`BLOCK DATA` pull with an **explicit, ordered, inspectable, validated** init path,
realized by three source files under `modern/init/` plus four project-internal
coverage headers:

| File | Role |
|---|---|
| `modern/init/nastinit.f` | The single initialization entry point invoked by `CALL NASTINIT`; reads the `NASTRAN_LEGACY_INIT` toggle via `GETENV` and orchestrates the explicit init path; optionally runs validation. |
| `modern/init/blkinit.f` | The explicit, ordered initializer that reproduces the **complete `bd/`-DATA-seeded, non-bootstrap `COMMON` set** ("the R set" — 72 blocks, 31,316 words) plus the safe `/SYSTEM/` config subset, reaching state through `INCLUDE` headers only. |
| `modern/init/initval.f` | The bitwise initialization-state validator that compares the modern init result against the legacy `BLOCK DATA` values **word-for-word** and reports any divergence. |
| `modern/init/bddata.inc` | Coverage header declaring the **72** R-set `COMMON` blocks with clash-free flat `INTEGER` window arrays (`COMMON /blk/ KBnnnn(extent)`). |
| `modern/init/bdgold.inc` | The **31,316-word** golden `DATA` (`INTEGER BDGOLD(31316)`), captured by linking the real `bd/` objects and dumping `COMMON` memory — so `REAL`, `INTEGER`, and Hollerith fields are all reproduced bit-for-bit **by construction**. |
| `modern/init/bdcopy.inc` | Executable body (used by `blkinit.f`) copying the goldens into the 72 `COMMON` windows. |
| `modern/init/bdcomp.inc` | Executable body (used by `initval.f`) comparing each `COMMON` window word-for-word against the goldens, incrementing `NDIV` per divergence. |

Specifically, this report records the **A1 algorithm decision** (initialization
dependency ordering) with both candidates and the rejection rationale; the
**39-unit reproduction status**; the **reproduction-coverage analysis** (which
`bd/`-seeded blocks are reproduced and which are principled-excluded, and why);
the **bootstrap integration** (the single `CALL NASTINIT` edit and the
`nastinit.f` behavior); the **validator** `initval.f`; and the **toggles,
rollback, open flags, and success criteria**.

The governing patterns are **Branch by Abstraction** (the modern init path is built
*inside* the codebase and coexists with the still-linked `bd/` units),
**Strangler-Fig feature-toggle cutover** (the `NASTRAN_*` env toggles select the
path and enable instant, recompilation-free rollback), and — for `initval.f` —
the **Template Method** (setup → compare → report) and **Guard Clause**
(`IF (IDIAG .EQ. 0) RETURN` first) patterns shared across the validators.

---

## A1 Decision: Initialization Dependency Ordering

> **Decision:** **Candidate 1 — explicit, hardcoded, inspectable initialization
> sequence — is ACCEPTED.** Candidate 2 (declarative dependency metadata resolved
> at startup by a topological-sort traversal) is **REJECTED**. This subsection
> states both candidates and the rejection rationale, as required by AAP §0.7.6.

### Candidate 1 — Explicit hardcoded ordered sequence *(ACCEPTED / RECOMMENDED)*

An explicit, hardcoded, fixed-order initialization sequence realized in
`modern/init/blkinit.f` and orchestrated by `modern/init/nastinit.f`, derived from
**static analysis** of which `COMMON` block each `bd/` unit sets. The sequence is a
fixed, commented, ascending series of assignments and golden-copy loops — open to
line-by-line inspection and trivially auditable against the `bd/` golden values.

### Candidate 2 — Declarative dependency metadata + topological sort *(REJECTED)*

A declarative table of inter-unit dependency metadata, resolved at startup by a
topological-sort traversal that computes a safe initialization order dynamically.

### Rationale

The 39 `bd/` units are **pure `DATA` initializers of distinct named `COMMON`
blocks** (for example, `bd/dpdcbd.f` populates `COMMON /DPDCOM/` via
`DATA DPOOL/101/, GPL/102/, …`). `BLOCK DATA` semantics are **order-independent**:
every value is placed into its `COMMON` block **at load time**, with **no
inter-unit runtime sequencing** and **no read-before-write coupling**. Genuine
read-before-write dependencies among these pure data blocks are therefore **nil**.

Consequently, a full topological-sort engine is **over-engineering**: it would add
startup cost and introduce new failure modes (cycle detection, metadata drift,
ordering bugs) to solve a problem that **does not exist at runtime**. Candidate 1
is **deterministic**, **zero-overhead**, **inspectable**, and **semantically
faithful** to the load-time `BLOCK DATA` semantics it mirrors. **Candidate 2 is
reserved only as a contingency**, to be revisited if later analysis ever surfaces a
real read-before-write coupling (none is expected, and none was found). The same
A1 decision is documented in-source in the header of `modern/init/blkinit.f`.

---

## 39-Unit Reproduction Status

The full `bd/` → `COMMON` inventory with per-unit variable mapping lives in
`modern/docs/pre_implementation_analysis.md` **Section A**; this section summarizes
it and records the **completed** reproduction status. The key facts:

- The `bd/` tree contains **40 `.f` files**, of which **39 are `BLOCK DATA`
  units**. The single outlier is **`bd/ferfbd.f`**, a **`SUBROUTINE`** (a
  memory/file matrix reader); it initializes nothing and is therefore **not**
  explicitly named on `bin/linknas` (it is auto-pulled from the archive like any
  referenced routine, unlike `BLOCK DATA` objects which must be named explicitly).
- The **principal unit is `bd/semdbd.f`** — **757 lines** declaring **31 active
  `COMMON` blocks** (`/SYSTEM/`, `/SEM/`, `/XLINK/`, `/XFIST/`, `/GINOX/`,
  `/BLANK/`, `/MACHIN/`, `/OUTPUT/`, `/OSCENT/`, `/XVPS/`, `/XDPL/`, `/NAMES/`,
  `/TYPE/`, `/BITPOS/`, `/TWO/`, and more).
- The legacy `bd/` units are **retained intact and unmodified** as the **source of
  truth** for validation and rollback. The toggle `NASTRAN_LEGACY_INIT` selects the
  legacy path; because the `BLOCK DATA` objects remain linked, an unconfigured run
  is bit-identical to APR.95 regardless of what the modern path does.
- `modern/init/blkinit.f` reproduces the **complete R set** (below) reaching state
  only through `INCLUDE` headers; its **source body** declares **zero literal
  `COMMON`** and **zero `EQUIVALENCE`**.

**Status summary**

| Mechanism | Status |
|---|---|
| `bd/` unit catalogue | **39 `BLOCK DATA` units** catalogued (40 files; `bd/ferfbd.f` is a `SUBROUTINE` outlier) |
| Distinct `bd/`-seeded `COMMON` blocks | **92** (authoritative linker-level count via `nm -S` over the compiled `bd/` objects) |
| **R set** (DATA-seeded, non-bootstrap) | **72 blocks, 31,316 words — REPRODUCED & BITWISE-VALIDATED** (`NDIV = 0`) |
| `/SYSTEM/` safe config subset | **42 cells reproduced** (9 non-zero config values + 33 safe zero cells); machine cells deliberately untouched |
| Principled exclusions | **20 non-R blocks** — 7 bootstrap-owned + 13 zero-only (default zero-init reproduces them); see **Reproduction Coverage** |
| Legacy `bd/` units | **Retained intact & unmodified** — source of truth for `initval.f` and rollback |
| New literal `COMMON` / `EQUIVALENCE` in `.f` bodies | **Zero / Zero** — all access via `INCLUDE` |

---

## Reproduction Coverage & Principled Exclusions

This is the **crux of the init layer**. At the prior checkpoint the initializer
reached state only through the nine existing `*.COM` headers, of which only
`/SYSTEM/` is usefully reachable — so the bulk of the `bd/` state was **deferred**.
The prior code review flagged that deferral as a Critical gap and explicitly
endorsed the remedy: *"implement complete reproduction for every bd-seeded `COMMON`
value, or add AAP-approved include/header coverage for currently unreachable
blocks."* This refactor takes exactly that path — it adds **project-internal
coverage headers** (`bddata.inc`, `bdgold.inc`, `bdcopy.inc`, `bdcomp.inc`) and
reproduces **and bitwise-validates the complete R set**.

### The 92-block partition

The 39 `bd/` units seed **92 distinct `COMMON` blocks** (authoritative linker-level
count). They partition cleanly into three disjoint groups whose union is exactly
92:

| Group | Count | Treatment |
|---|---|---|
| **R set** — `DATA`-seeded, **non-bootstrap** | **72** (31,316 words) | **Reproduced** by `blkinit.f` (`bdcopy.inc`) and **bitwise-validated** by `initval.f` (`bdcomp.inc`). |
| **Bootstrap-owned** — populated by `BTSTRP` / `DBMINT` (or scratch state) | **7** | **Excluded** — reproducing them would clobber live bootstrap state and break bit-for-bit equivalence (AAP §0.7.1). |
| **Zero-only** — no `DATA` seeding (`bd` leaves them zero) | **13** | **Excluded from explicit writes** — default zero-init (unit model) and the linked `bd/` units (live model) already reproduce them. |

(The bootstrap-owned and zero-only groups overlap on four block names —
`/LHPWX/`, `/MACHIN/`, `/XXREAD/`, `/ZZZZZZ/` — which are *both* zero-seeded *and*
bootstrap/scratch-owned; counting the distinct union gives **20** non-R blocks, so
**72 + 20 = 92**.)

### R-set reproduction — the coverage headers

`bddata.inc` declares each of the 72 R-set blocks as a flat `INTEGER` window
(`COMMON /blk/ KBnnnn(extent)`; the `K`-initial names are `INTEGER` by the default
`I–N` rule and are clash-free). `bdgold.inc` carries the **31,316 golden words** as
`DATA` into `INTEGER BDGOLD(31316)` — captured by **linking the real `bd/`
`BLOCK DATA` objects and dumping `COMMON` memory as integers**, so `REAL`,
`INTEGER`, and Hollerith fields are reproduced **bit-for-bit by construction**, with
no hand transcription. The sum of the 72 window extents equals `31316` exactly.
`blkinit.f` then `INCLUDE`s `bdcopy.inc`, one labelled `DO` loop per block, copying
the goldens into the `COMMON` windows. In the **live** solver these writes are
**idempotent** (the linked `bd/` units already placed the identical bit patterns at
load, so a before/after `COMMON` snapshot is byte-identical); in the **unit-test**
executable (no `bd/` objects linked, `COMMON` starts zeroed) the loops **actively**
initialize the full R set.

> **`R8` / `R9` posture.** The new `.inc` files are the **AAP-approved header
> coverage** the prior review endorsed; they declare the `bd/` block names exactly
> as the legacy units do and add **no `EQUIVALENCE`**. Every `modern/init/*.f`
> **source body** remains free of literal `COMMON` / `EQUIVALENCE` (verifiable by
> `grep`), so the "state access is `INCLUDE`-only" discipline holds at the source
> level; the coverage headers simply extend the set of `INCLUDE`able declarations
> from the nine `*.COM` to those nine plus the four `bd/`-coverage headers.

### `/SYSTEM/` — write only the safe config subset (42 cells)

`/SYSTEM/` is **bootstrap-owned**: `BTSTRP` and `DBMINT` populate its machine
constants **before** `NASTINIT` runs, so `blkinit.f` must not overwrite them.
Using the `SMCOMX.COM` `/SYSTEM/` layout —
`ISYSBF(1), NOUT(2), DUM1(37) = cells 3–39, NBPW(40), DUM2(14) = cells 41–54, ISPREC(55)` —
`blkinit.f` writes **only the safe, non-machine, `BTSTRP`/`DBMINT`-untouched
configuration cells**: a **42-cell** subset comprising **9** non-zero config values
plus **33** safe zero cells (23 in `DUM1`, 10 in `DUM2`). The nine non-zero values
(golden from `bd/semdbd.f`; each `DUM1(j)` addresses `/SYSTEM/` physical cell
`j+2`):

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

The 33 zero cells (`bd/semdbd.f` zero-fill) are written through ascending index
lists (`ZD1(23)`, `ZD2(10)`) held in `DATA` arrays that `blkinit.f` and
`initval.f` **share identically**, guaranteeing the writer and the validator agree
cell-for-cell.

**`DUM1` typing.** `DUM1` is named only by the `SMCOMX.COM` `COMMON` statement,
which gives it no explicit type; by default typing a `D`-initial name is `REAL`.
Because every cell is an integer, `blkinit.f` types `DUM1` (and `DUM2`) as
`INTEGER` to guarantee integer store semantics. This is a **type declaration
only** — the array extents still come from the `INCLUDE`d `COMMON` statement — and
is **neither a new `COMMON` nor an `EQUIVALENCE`**.

**`BTSTRP`/`DBMINT` non-clobber proof.** `BTSTRP` writes `/SYSTEM/` cells
`{1, 2, 4, 9, 22, 39, 40, 41, 42, 43, 44, 55, 91, 92}` and `DBMINT` writes none of
the configuration cells; the 42 cells `blkinit.f` writes have an **empty
intersection** with that set (and exclude the machine constant `HICORE`, cell 31).
Every `blkinit.f` write is therefore provably `BTSTRP`/`DBMINT`-untouched and hence
**idempotent** in the real solver and **active** in the unit-test executable.

> **`NBPW` cell-position note (resolved).** The **array-aware** count — honoring
> `DATE(3)`, `SYSDAT(3)`, `ADUMEL(9)`, `MODCOM(9)`, `HDY(3)`, `SWITCH(3)`,
> `K8890(3)`, `LEFT(56)`, `LEFT2(28)` in `bd/semdbd.f` — makes `/SYSTEM/` exactly
> **180 words** (`= LSYSTM`) and places `NBPW` at **cell 40**, corroborated by
> `mds/btstrp.f`'s `EQUIVALENCE`s `B(40)=NBPW`, `B(22)=LINKNO`, `B(41)=NCPW`,
> `B(55)=IPREC`. The naive "word 38" figure is an all-scalar miscount; the
> absolute `DUM1` indices above are reliable.

### Bootstrap-owned and zero-only exclusions

- **Bootstrap-owned (7):** `/SEM/`, `/SYSTEM/` (machine cells), `/TWO/`,
  `/MACHIN/`, `/LHPWX/`, `/XXREAD/`, `/ZZZZZZ/`. These hold link control,
  machine constants, or scratch state that `BTSTRP`/`DBMINT` own at runtime;
  reproducing them would clobber live bootstrap values and violate the
  bit-for-bit-equivalence mandate (AAP §0.7.1). They are deliberately excluded.
- **Zero-only (13 not also bootstrap-owned):** including `/GINOX/` (see below),
  `/FEERIM/`, `/NUMTPX/`, `/OPINV/`, the `/SMA1*/` and `/SMA2*/` scratch
  families, `/STAPID/`, `/STIME/`, `/XECHOX/`, `/XXFIAT/`. Each is seeded only
  with zeros by `bd`, so default zero-init (unit model) and the linked `bd/`
  units (live model) already reproduce them exactly — no explicit write is
  needed, and `initval.f` confirms `NDIV = 0` over the R set without them.

#### `/GINOX/` name collision — DO NOT WRITE

`bd/semdbd.f` declares `COMMON /GINOX / CDC(244)` and seeds it with
`DATA CDC / 244*0 /` (zero-fill). The header `mds/GINOX.COM` declares `/GINOX/`
with a **completely different layout** — `LGINOX, IDSLIM, MDSFCB(3,89),
LENSOF(10)` — representing the **modern disk-I/O state owned by `DBMINT`**.
`/GINOX/` is therefore excluded on **two** independent grounds: it is **zero-only**
(so default init reproduces it) and writing it through `mds/GINOX.COM` would be
semantically invalid and could corrupt live disk-I/O state. `initval.f` records the
exclusion explicitly with diagnostic code `9150` (value `0`).

---

## Bootstrap Integration (single edit — APPLIED)

The **only** permitted change to the executable control flow is a single inserted
line in `bin/nastrn.f`: `CALL NASTINIT` (no arguments), placed **immediately after
`CALL DBMINT`** and **before `LOUT = 3`**. This edit **is applied** (`+1 / -0`):

```text
bin/nastrn.f  (bootstrap, abridged)
   L32   CALL BTSTRP            ! seeds /SYSTEM/ machine constants
   ...
   L44   CALL DBMINT           ! database manager init
   L45   CALL NASTINIT          <-- the single inserted line (no arguments)
   L46   LOUT   = 3            ! diagnostic log unit established here
   ...
   L116  OPEN (3, ...)         ! unit 3 actually opened later
```

This insertion point is deliberate: `NASTINIT` runs **after** `BTSTRP` and `DBMINT`
have populated the machine constants in `COMMON`, so the modern initializer
provably does **not overwrite** them (see the non-clobber proof above). The
single-edit `bin/nastrn.f` diff is exactly `+1 / -0`, with the inserted line being
`      CALL NASTINIT`.

### `nastinit.f` invocation behavior

`modern/init/nastinit.f` is the single init entry point:

1. **Read the toggle.** It reads `NASTRAN_LEGACY_INIT` via `GETENV` using the
   `bin/nastrn.f` idiom (a `CHARACTER*80 VALUE` receiver pre-blanked to `' '`).
2. **Select the path.**
   - **Unset ⇒ modern path:** `CALL BLKINIT` performs the explicit, ordered
     reproduction of the full R set plus the safe `/SYSTEM/` config cells.
   - **Set ⇒ legacy path:** the modern explicit reproduction is skipped; the
     still-linked `bd/` `BLOCK DATA` units remain the sole initializer (exact
     APR.95 behavior).
3. **Optionally validate (production-safe).** If `NASTRAN_INIT_VALIDATE` is set,
   `nastinit.f` acquires `IDIAG` via `CALL DIAGCTL(IDIAG)` and runs
   `CALL INITVAL(IDIAG, NDIV)`. Because `NASTINIT` runs **before** the bootstrap's
   `OPEN(3,...)`, `nastinit.f` **safely self-opens unit 3** — it `INQUIRE`s whether
   unit 3 is already open and, if not, opens it on `GETENV('LOGNM')` (the same log
   file the bootstrap will later connect) using `STATUS='UNKNOWN'` (re-opening a
   connected unit to the same file preserves records). This is what makes
   `NASTRAN_INIT_VALIDATE=1` reliably produce the promised unit-3 init-validation
   log in the **real solver** and under `run_all.csh -validate`, resolving the
   prior "validation can't run before unit 3 is open" finding.

Because the `bd/` units are linked in both cases, neither path alters the numerical
result; the toggle selects **which mechanism is exercised**, not **what values end
up in `COMMON`**.

---

## Toggles & Rollback

Initialization behavior is controlled entirely at **runtime** through environment
variables, read once via `GETENV` at startup (the existing NASTRAN configuration
idiom). The two init-relevant toggles and their `IDIAG` bit values (computed by
`modern/diag/diagctl.f`):

| Toggle | `IDIAG` bit | Effect when set | Default (unset) |
|---|---|---|---|
| `NASTRAN_LEGACY_INIT` | bit value `1` | Select the **legacy** `bd/` init path (skip the modern explicit reproduction) | Modern explicit path (`CALL BLKINIT`) |
| `NASTRAN_INIT_VALIDATE` | bit value `2` | Run `CALL INITVAL(IDIAG, NDIV)` to bitwise-compare modern vs legacy init | Validation skipped |

- **Default safety.** With **both unset**, `IDIAG = 0`, every guarded modern
  routine short-circuits, and execution is **bit-identical to the unmodified APR.95
  solver** — zero overhead.
- **Rollback.** Rollback to APR.95 is a pure **configuration change** — unset or
  flip the relevant `NASTRAN_*` variable — and requires **no recompilation**
  (AAP §0.7.4): the Strangler-Fig cutover-control property.
- **Operator placement.** Operators set these toggles inline in the `bin/nastran`
  `csh` run wrapper's environment list (the `env NAME=val …` block preceding
  `nastrn.exe`, alongside `LOGNM=$probname.log`, the unit-3 log file).

`diagctl.f` sums the set toggles into `IDIAG` (bit values `1`, `2`, `4`, `8`;
`IDIAG = 0` when none are set, `15` when all four are). `IDIAG` is returned as an
**output argument**, not stored in any new `COMMON`.

---

## Validation (`initval.f`)

`modern/init/initval.f` is the **bitwise initialization-state validator**. It
proves that the modern explicit init reproduces the legacy `BLOCK DATA` values
exactly. Its contract:

- **Signature:** `SUBROUTINE INITVAL(IDIAG, NDIV)`. `IDIAG` is an **input
  argument** — threaded by `modern/diag`, never stored in `COMMON` — and `NDIV` is
  the **output divergence count** (`0` ⇒ no divergence).
- **Guard clause is the literal first executable statement.** Because `IDIAG`
  arrives as an argument, `initval.f` needs **no** pre-guard acquisition: the
  **first executable statement** is `IF (IDIAG .EQ. 0) RETURN`, satisfying Binding
  Rule **R10** and the zero-cost-when-disabled contract (AAP §0.6.4, §0.7.2). This
  resolves the prior R10 finding (the earlier `CALL DIAGCTL(IDIAG)`-before-guard
  ordering is gone). `NDIV` is **not** touched before the guard, so a driver's
  `999999` sentinel survives a disabled (no-toggle) run.
- **Exact comparison (not tolerance).** Initialization values are integers and
  exact `REAL`/Hollerith constants, so `initval.f` compares **word-for-word** via
  `bdcomp.inc` (exact `.NE.`), incrementing `NDIV` per diverging word. (Numeric
  tolerance is the regression comparator's job for *solver output*, not init
  goldens.)
- **Complete R-set coverage.** `initval.f` `INCLUDE`s `bddata.inc` + `bdgold.inc` +
  `bdcomp.inc`, so it validates the **same** 72 blocks / 31,316 words that
  `blkinit.f` writes, plus the 42-cell `/SYSTEM/` safe subset — there is **no
  uncovered-but-counted-clean** state, so a false pass is structurally impossible.
- **Reporting via `DIAGLOG`.** Divergences and scope accounting are reported
  through `modern/diag/diaglog.f` (`DIAGLOG(IDIAG, ICODE, NVAL, MSG)`, logical
  unit 3 only) using codes in the **`9100`–`9199`** sub-band:

  | Code | Meaning | Typical value |
  |---|---|---|
  | `9100` | Validation summary — total divergence count `NDIV` | `0` on success |
  | `9101` | A specific cell/block word diverges from its `bd/` golden | (the live value) |
  | `9150` | `/GINOX/` excluded — header-layout collision + `DBMINT`-owned | `0` |
  | `9160` | Count of header-uncovered `bd/`-seeded blocks remaining | `0` (= NONE) |
  | `9170` | `/SYSTEM/` config cells validated | `NVALID` |
  | `9171` | `bd/` R-set blocks validated | `72` |

  Note `9160` now reports **`0` (UNCOVERED BD BLOCKS = NONE)** — the honest
  accounting that replaced the prior `NUNRCH = 88` informational counter, which had
  allowed a false pass.
- **Test-driver sentinel.** The `test/init/` unit drivers preset `NDIV` to
  `999999` before calling `INITVAL`, so a clean run that **actively sets
  `NDIV = 0`** demonstrably proves zero divergence (rather than a value that merely
  defaulted to zero). On the guarded early return, `NDIV` is left untouched, which
  is precisely why the top-level runner sets `NASTRAN_INIT_VALIDATE=1` for the init
  suite.
- **Success (verified).** With `NASTRAN_INIT_VALIDATE=1`: the **live model**
  (`initval` linked against the real `bd/` objects) yields `NDIV = 0`, and the
  **unit model** (`blkinit` reproduces, no `bd/` linked) yields `NDIV = 0` on two
  consecutive calls (idempotent). Every reproduced word bitwise-matches its `bd/`
  golden.

---

## Open Flags

The following items are flagged for maintainer confirmation. None blocks the
encapsulation-only, bit-for-bit deliverable.

1. **Shared `9100`–`9199` diagnostic sub-band (init + state).** `initval.f` and the
   state validator `modern/state/stateval.f` **both** draw codes from the
   `9100`–`9199` sub-band — intentional, since both are startup-consistency
   validators. To avoid numeric collisions, `initval.f` uses
   `9100`/`9101`/`9150`/`9160`/`9170`/`9171` and avoids `stateval.f`'s detail
   cluster; any overlap is disambiguated at emission by the distinct routine and
   the `DIAGLOG` `MSG` label. The dispatch validator uses `9300`–`9399`.
2. **`/SYSTEM/` cells beyond `SMCOMX.COM` cell 55.** `TOLEL` (cell 70, `REAL`
   `0.01`), `LINTC` (cell 85, `800`), and `OSPCNT` (cell 87, `15`) are bd-set and
   non-machine, yet lie **beyond cell 55** (`ISPREC`), the last `/SYSTEM/` cell
   `SMCOMX.COM` declares. They are not part of the safe-config subset `blkinit.f`
   writes through `SMCOMX.COM`; in the real solver they are seeded by the linked
   `bd/` units exactly as before. **Flag:** a future phase may add a
   maintainer-authored header exposing these cells if a modern component needs to
   write them directly.
3. **`/GINOX/` header-layout collision.** `bd/semdbd.f`'s `/GINOX/` view
   (`CDC(244)` zero-fill) differs entirely from `mds/GINOX.COM`'s disk-I/O layout.
   `blkinit.f` deliberately does **not** write `/GINOX/` (it is zero-only and
   `DBMINT`-owned). **Flag:** confirm no modern component requires the `semdbd`
   `/GINOX/` zero-fill view through a non-colliding header.
4. **`KTIME` / `/SYSTEM/` header note.** `/SYSTEM/` is **not** declared in
   `NASNAMES.COM`; among the nine headers it is declared **only** in
   `mis/SMCOMX.COM` (a partial 55-word window of `semdbd`'s full 180-word block —
   the source of the harmless linker size note when the validator is linked against
   the real `bd/` objects). The related `KTIME`-from-`/SYSTEM/` question for the
   dispatcher is documented in `modern/docs/dispatch_modernization_report.md`.
5. **Count basis.** The **92-block** figure is the authoritative linker-level count
   (`nm -S` over the compiled `bd/` objects, which captures `EQUIVALENCE`
   extensions automatically). An earlier active-`COMMON`-statement count of
   **89/90** (the `±1` being the dormant, commented-out `/DESCRP/`) reflects a
   source-statement basis; the linker-level partition (72 R-set + 20 excluded = 92)
   is authoritative for reproduction.

---

## Success Criteria

The init-mechanism success criteria (AAP §0.7.3), with status:

- [x] **A1 decision recorded with rejected alternative.** Candidate 1 (explicit
      hardcoded sequence) accepted; Candidate 2 (topological sort) rejected with the
      order-independent-pure-`DATA` rationale (AAP §0.7.6).
- [x] **All `bd/` values reproduced bitwise.** `blkinit.f` reproduces the complete
      **72-block / 31,316-word** R set plus the 42-cell `/SYSTEM/` safe config
      subset; with `NASTRAN_INIT_VALIDATE=1`, `initval.f` reports **zero
      divergence** (`NDIV = 0`) in both the live and unit models. The
      principled-excluded blocks are bootstrap-owned or zero-only and are reproduced
      by the bootstrap / default-init exactly as before (recorded honestly via
      `9150`/`9160`/`9170`/`9171`, not silently skipped).
- [x] **Legacy `bd/` units retained intact** as the source of truth for validation
      and rollback; selectable via `NASTRAN_LEGACY_INIT`.
- [x] **Validator guard clause first.** `initval.f`'s first executable statement is
      `IF (IDIAG .EQ. 0) RETURN` (`IDIAG` passed as an argument) — R10 satisfied,
      zero overhead when disabled. `blkinit.f` is deliberately guard-exempt because
      it is an *initializer*, not a diagnostic, and must perform its idempotent
      initialization whenever invoked.
- [x] **Zero new literal `COMMON`, zero new `EQUIVALENCE` in source bodies.** All
      state access is via `INCLUDE` (the nine `*.COM` plus the four AAP-approved
      `bd/`-coverage headers); the only declarations are `INTEGER` type assignments,
      which are neither `COMMON` nor `EQUIVALENCE`.
- [x] **Default safety & rollback.** Both toggles unset ⇒ `IDIAG = 0` ⇒
      bit-identical to APR.95; rollback is a configuration change with no
      recompilation (AAP §0.7.4).
- [x] **Single bootstrap edit applied.** Exactly one inserted line
      (`CALL NASTINIT` after `CALL DBMINT`, `+1 / -0`); no other change to
      `bin/nastrn.f`.

---

## Provenance (read-only)

The following existing artifacts were read as references / sources of truth and are
**not modified** by this document:

- `bd/*.f` — the 39 `BLOCK DATA` units, especially `bd/semdbd.f` (principal, 757
  lines, 31 active `COMMON` blocks), `bd/dpdcbd.f` (`/DPDCOM/`), `bd/of1pbd.f`
  (`/OFPB1/`), `bd/readbd.f` (`/REGEAN/`, `/INVPWX/`, `/GIVN/`; `REAL` goldens),
  and `bd/flbbd.f` (`/FLBFIL/`). The 31,316 golden words in `bdgold.inc` were
  captured by linking these objects and dumping `COMMON` memory.
- `mds/GINOX.COM`, `mis/SMCOMX.COM`, `mds/DSIOF.COM`, `bin/NASNAMES.COM` — the
  `*.COM` `INCLUDE` headers consulted for `/SYSTEM/`, `/GINOX/`, and reachability.
- `bin/nastrn.f` — the bootstrap (`CALL BTSTRP`, `CALL DBMINT`, the inserted
  `CALL NASTINIT`, `LOUT = 3`, `OPEN(3,…)`).
- `bin/linknas` — the build script (39 `bd/` objects explicitly named; the modern
  objects and the new `-I` include paths for the coverage headers added).

Sibling modern sources referenced: `modern/init/nastinit.f`,
`modern/init/blkinit.f`, `modern/init/initval.f`, the four `modern/init/*.inc`
coverage headers, `modern/diag/diagctl.f`, `modern/diag/diaglog.f`. Companion
documentation: `modern/docs/pre_implementation_analysis.md` (Sections A and E),
`modern/docs/state_modernization_report.md`, and
`modern/docs/final_modernization_summary.md`. None of these files is modified by
this report.
