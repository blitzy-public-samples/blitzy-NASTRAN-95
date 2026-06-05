# NASTRAN-95 Modernization — State Encapsulation Report

> **Mechanism:** Global-state (`COMMON`-block) encapsulation
> (AAP §0.2.1, §0.5.3, §0.6.4, §0.7.6).
> **Scope framing:** This is an **encapsulation / modularity refactor only** —
> **bit-for-bit numerical equivalence**, identical **module execution order**,
> and identical restart/checkpoint behavior with the unmodified APR.95 solver
> are the contract. Mutable global state continues to live in the existing nine
> `*.COM` `INCLUDE` headers; the modern layer adds a thin **accessor/facade**
> over the subset of that state referenced by new components and introduces
> **zero new `COMMON`** and **zero new `EQUIVALENCE`** (AAP §0.5.3). The
> accessors are used **only by new code** — legacy routines keep their own
> `COMMON` declarations untouched and are **not** required to adopt the facade.
> **Authoring order:** this report is authored **after**
> `pre_implementation_analysis.md`, which supplies the authoritative
> per-`*.COM` variable inventory that the accessor table below maps onto.

---

## Purpose

This report documents the **global-state encapsulation** mechanism: the
accessor/facade layer `modern/state/stateacc.f` and its companion validator
`modern/state/stateval.f`, which together mediate every modern read and write of
the legacy `COMMON` state without altering, re-declaring, or aliasing any of it.
Specifically, it records:

- the **accessor/facade inventory** — the full set of **40** `GET`/`SET`
  program units in `modern/state/stateacc.f`, grouped by the single `*.COM`
  header each one `INCLUDE`s, with the exact `COMMON`-block cell each pair wraps;
- the mandatory **one-header-per-unit rule** and the two cross-header
  **layout conflicts** (`/DSNAME/` and `/ZZZZZZ/`) that make the rule necessary;
- the **`EQUIVALENCE` handling** — why "zero new `EQUIVALENCE`" is automatic for
  the accessor layer;
- the **zero re-declaration evidence** — the exact, inspectable `grep` checks
  that prove no literal `COMMON` and no `EQUIVALENCE` appears anywhere in the
  state layer, plus the single, fully-documented inline-`COMMON` exception that
  lives in the *dispatch* layer (not here);
- the **state validator** `modern/state/stateval.f` — its `Guard Clause`,
  accessor-only state access, and its `9100`–`9199` diagnostic codes; and
- the deliberate **scope omissions and flags**, and the **success criteria**
  that close out the mechanism.

The governing design pattern is **Accessor / Facade**: every modern touch of the
shared `COMMON` state is funneled through small, single-responsibility `GET`/`SET`
subroutines, each reaching state **exclusively through an `INCLUDE` of one
existing `*.COM` header**. That `INCLUDE` is the single, auditable mediation
point — the one place global state is named — which is precisely what makes the
"zero new `COMMON` / zero new `EQUIVALENCE`" property verifiable by inspection.
The validator additionally applies the **Template Method** (setup → compare →
report) and **Guard Clause** (`IF (IDIAG .EQ. 0) RETURN` first) patterns shared
across the modernization's validators.

---

## Accessor/Facade Inventory — `modern/state/stateacc.f`

`modern/state/stateacc.f` contains **40 program units** — `GET`/`SET` accessor
pairs (two of them indexed) over the subset of legacy `COMMON` state that the new
modernization components reference. Each unit is a pure store/fetch: it `INCLUDE`s
**exactly one** `*.COM` header, declares its dummy argument, and copies the one
`COMMON` cell to or from that argument. There is no I/O, no `CALL MESAGE`, no
guard clause, and no `EXTERNAL`/`SAVE` in the accessors themselves — the guard
clause belongs to the validators and loggers (`diaglog.f`, `initval.f`,
`stateval.f`, `dispval.f`), not to these accessors.

The 40 units divide into three header-groups, as follows.

### Group A — every routine `INCLUDE 'DSIOF.COM'` (22 routines, all `INTEGER`)

These wrap the GINO/data-set I/O and database-manager scalar cells of `/DSIO/`
and `/DBM/`, plus the indexed file-control block `/FCB/` (declared
`INTEGER FCB(17,89)` in `mds/DSIOF.COM`).

| Accessor pair | `COMMON` cell |
|---|---|
| `GETLCW` / `SETLCW`   | `/DSIO/ LCW` |
| `GETLWRD` / `SETLWRD` | `/DSIO/ LWORDS` |
| `GETNWRD` / `SETNWRD` | `/DSIO/ NWORDS` |
| `GETMDSN` / `SETMDSN` | `/DSIO/ MAXDSN` |
| `GETNBUF` / `SETNBUF` | `/DSIO/ NBUFF` |
| `GETDBLN` / `SETDBLN` | `/DBM/ IDBLEN` |
| `GETDBAD` / `SETDBAD` | `/DBM/ IDBADR` |
| `GETNBLK` / `SETNBLK` | `/DBM/ NBLOCK` |
| `GETMBLK` / `SETMBLK` | `/DBM/ MAXBLK` |
| `GETLNOP` / `SETLNOP` | `/DBM/ LENOPC` |
| `GETFCB` / `SETFCB`   | `/FCB/ FCB(I,J)` — indexed (`INTEGER FCB(17,89)`); args `(I, J, IVAL)` |

Eleven `GET`/`SET` pairs ⇒ **22 program units**.

### Group B — every routine `INCLUDE 'SMCOMX.COM'` (10 routines, all `INTEGER`)

These wrap two cells of the executive system block `/SYSTEM/` and two cells of
the sparse-matrix communication block `/SMCOMX/`, all declared in
`mis/SMCOMX.COM`.

| Accessor pair | `COMMON` cell | Note |
|---|---|---|
| `GETSBUF` / `SETSBUF` | `/SYSTEM/ ISYSBF` | word 1 — consistent across all `/SYSTEM/` layouts (**SAFE**) |
| `GETNOUT` / `SETNOUT` | `/SYSTEM/ NOUT`   | word 2 (print-output unit) — consistent across all `/SYSTEM/` layouts (**SAFE**) |
| `GETNBPW` / `SETNBPW` | `/SYSTEM/ NBPW`   | **FLAG**: word 40 in the `SMCOMX.COM` layout vs word 38 in the canonical `bd/semdbd.f` layout — these accessors rely on the `SMCOMX.COM` layout (see *Scope Omissions & Flags*) |
| `GETNCOL` / `SETNCOL` | `/SMCOMX/ NCOL`   | |
| `GETIERR` / `SETIERR` | `/SMCOMX/ IERROR` | |

Five `GET`/`SET` pairs ⇒ **10 program units**.

### Group C — every routine `INCLUDE 'NASNAMES.COM'` (8 routines, all `CHARACTER`)

These wrap the data-set-name table `/DSNAME/` and three of the file-path cells of
`/DOSNAM/`, all declared in `NASNAMES.COM` (verified identical in `bin/` and
`mds/`). The dummy `NAME` argument is assumed-length `CHARACTER*(*)`; FORTRAN 77
blank-pads or truncates on assignment as usual.

| Accessor pair | `COMMON` cell |
|---|---|
| `GETDSN` / `SETDSN` | `/DSNAME/ DSNAMES(I)` — indexed, `CHARACTER*80`, dim 89; args `(I, NAME)` |
| `GETLOG` / `SETLOG` | `/DOSNAM/ LOG` (`CHARACTER*72`) |
| `GETINP` / `SETINP` | `/DOSNAM/ INPUT` (`CHARACTER*72`) |
| `GETOUT` / `SETOUT` | `/DOSNAM/ OUTPUT` (`CHARACTER*72`) |

Four `GET`/`SET` pairs ⇒ **8 program units**.

> **Maintainer note — `GETLOG` name collision.** The accessor `GETLOG` shares
> its name with the Unix/GNU library routine `getlog` (`getlogin`). The name is
> **retained verbatim** per the published contract (the test/state drivers expect
> `GETLOG`). Under Sun `f77` (the production target) `CALL GETLOG` binds to this
> accessor; under `gfortran` (the Linux validation stand-in) `GETLOG` is an
> intrinsic, so a caller must declare `EXTERNAL GETLOG` to bind to the accessor.
> `SETLOG` has no such collision. This is a *naming* note only — it does not
> introduce any `COMMON` or `EQUIVALENCE`.

### Inventory total

**22 (Group A) + 10 (Group B) + 8 (Group C) = 40 program units.**

All names are ≤ 7 characters and are accepted by Sun `f77`. The complete
`GET`/`SET` → `COMMON`-block.cell mapping above is the **published contract**
that `modern/state/stateval.f` and the `test/state/` drivers reconcile against
(see `test/state/tstacc.ref`).

---

## One-Header-Per-Unit Rule & Layout Conflicts

A single program unit `INCLUDE`s **only one** `*.COM` header. This is a hard
rule, and it is required because two `COMMON` block **names** are re-declared with
a **different layout** across the nine headers:

- **`/DSNAME/`** is declared as `DSNAMES(89)*80` in `NASNAMES.COM` but as
  `MDSNAM(89)*80` in `DSIOF.COM` — the **same memory** under **two different
  names**. A single program unit that `INCLUDE`d both headers would re-declare
  `/DSNAME/` twice with conflicting member names, which is illegal.
- **`/ZZZZZZ/`** is declared as `IBASE(700000)` in `XNSTRN.COM` but as `MEM(10)`
  in `ZZZZZZ.COM` — again the same block name with a different layout. (Neither
  view is wrapped by the state layer; see *Scope Omissions & Flags*.)

Because each accessor is its **own** scoping unit, the conflict matters **only
within a single unit**. No accessor `INCLUDE`s more than one header, so placing
all three header-groups (A, B, C) in the **one file** `stateacc.f` is entirely
safe — the file is a flat collection of independent subroutines, and the
`/DSNAME/` ↔ `MDSNAM` and `/ZZZZZZ/` conflicts never co-occur inside any one of
them.

For the same reason, **Group C** deliberately uses the **`NASNAMES.COM` /
`DSNAMES`** view of `/DSNAME/` and does **not** also wrap the `DSIOF.COM` /
`MDSNAM` alias. Wrapping `MDSNAM` would be a **redundant alias** of the very same
storage (`GETDSN` already reaches it) and would tempt a future maintainer to pull
both headers into one unit — exactly the two-header hazard the rule forbids. One
name, one view, one header per unit.

---

## `EQUIVALENCE` Handling

The rule is stated precisely by AAP §0.5.3 and §0.7.2: **no new `EQUIVALENCE` is
introduced anywhere in `modern/`.** Each accessor wraps the needed `COMMON`
variable **exactly as declared** in the header it `INCLUDE`s — same name, same
type, same dimensionality — and copies it to/from its argument.

A verified fact makes "zero new `EQUIVALENCE`" automatic for this layer: **none
of the nine `*.COM` headers contains an `EQUIVALENCE` statement.** Since every
accessor reaches state *only* by `INCLUDE`ing one of those headers, and adds no
storage-association of its own, no `EQUIVALENCE` can enter the state layer by any
path. Where a header (or a legacy `*.COM`) *did* already contain an `EQUIVALENCE`,
the rule would be unchanged: the accessor would read and write the **declared
name** through the included header and would **never add its own** alias. As it
happens, that case does not arise for the headers in scope here.

---

## Zero Re-Declaration Evidence

This is the headline compliance section. The inspectable evidence rule is:

> **No literal `COMMON/...` statement and no `EQUIVALENCE` statement appears in
> any `modern/*.f` file except by way of an `INCLUDE`d header.**

For the state layer the property is provable with three quick `grep` checks
against `modern/state/stateacc.f`. The expected results are:

```text
$ grep -in '^[ ]*COMMON' modern/state/stateacc.f
$            # (no output) -> 0 matches

$ grep -in 'EQUIVALENCE'  modern/state/stateacc.f
$            # (no output) -> 0 matches

$ grep -cE '^      INCLUDE' modern/state/stateacc.f
40           # exactly one executable INCLUDE per program unit
```

Notes on reading these checks accurately:

- **`COMMON` ⇒ 0.** There is no literal `COMMON` statement in the file. The
  header comments discuss the *word* "COMMON" in prose, but every comment line
  begins with `C` in column 1, so the column-anchored pattern `^[ ]*COMMON`
  (optional leading blanks immediately followed by `COMMON`) does not match them.
- **`EQUIVALENCE` ⇒ 0.** The file contains the token `EQUIVALENCE` **nowhere at
  all** — the header comments deliberately describe the prohibition using the
  phrase "storage-association (aliasing)" rather than the keyword, so even an
  unanchored search returns zero.
- **`INCLUDE` ⇒ 40.** Use the **column-anchored** pattern `^      INCLUDE`
  (six leading blanks, i.e. the fixed-form statement field) to count the
  **executable** `INCLUDE` statements — exactly one per program unit, 40 in all
  (24 lines of prose in the header block also mention `INCLUDE`, so a naïve
  `grep -c INCLUDE` reports a larger number and must **not** be used for the
  count). The 40 break down as 22 × `'DSIOF.COM'` (Group A), 10 × `'SMCOMX.COM'`
  (Group B), and 8 × `'NASNAMES.COM'` (Group C).

**The one flagged exception lives elsewhere in `modern/`, not here.** The
dispatcher `modern/dispatch/disptbl.f` carries **two minimal inline `COMMON`
window declarations** — `COMMON /SEM/ ISEM(3), LINKNM(15)` and
`COMMON /SYSTEM/ ISYS(21), LINKNO` — used **only** by the `MODX 43` (`EMG`)
special case, because the `LINKNM`/`LINKNO` cells it needs are not exposed by
name in any of the nine `*.COM` headers. That exception is documented in full in
`dispatch_modernization_report.md`. The **state layer itself has zero inline
`COMMON`** — the counts above stand.

Finally, the encapsulation is **additive**: legacy routines keep their own
`COMMON` declarations untouched. The refactor does **not** require legacy code to
adopt the accessors; only new modernization components call them.

---

## State Validator — `modern/state/stateval.f`

`modern/state/stateval.f` provides the state-consistency validator
`SUBROUTINE STATEVAL (IDIAG, IST)`. It follows the **Template Method** shape
shared by the modernization's validators (setup → compare → report) and opens
with the **Guard Clause** common to every diagnostic routine.

- **Guard clause first.** The **first executable statement** is
  `IF (IDIAG .EQ. 0) RETURN`. Nothing — not even `IST = 0` — precedes it. When
  `IDIAG` is `0` (the default, no `NASTRAN_*` toggle set) the routine returns
  immediately and does no work, so the validator imposes provably **zero
  overhead** on an unconfigured APR.95 run.
- **No global-state declarations.** `STATEVAL` contains **no `COMMON`, no
  `EQUIVALENCE`, and no `INCLUDE`.** It reads state **only** by calling the
  `stateacc.f` `GET` accessors into local variables, then checks coherence
  relations among those locals. This keeps the validator fully inside the
  "zero new `COMMON`" rule without even needing a header.
- **Reporting.** Each violation is reported via `CALL DIAGLOG` — whose signature
  is `DIAGLOG (IDIAG, ICODE, NVAL, MSG)` (see `diaglog.f`) — using diagnostic
  codes in the **`9100`–`9199`** sub-band, followed by a summary line. The
  coherence invariants and their codes are:

  | Code | Condition reported (a *violation* of the invariant) |
  |---|---|
  | `9101` | `NWORDS > LWORDS` (working words exceed the logical-record word budget) |
  | `9102` | `NBLOCK > MAXBLK` (allocated blocks exceed the block ceiling) |
  | `9103` | `NOUT <= 0` (print-output unit not positive) |
  | `9104` | `NBPW <= 0` (bits-per-word not positive) |
  | `9105` | `LCW < 0` (current-word pointer negative) |
  | `9106` | `IDBLEN < 0` (database length negative) |
  | `9100` | consistent-state summary (no divergences found) |
  | `9199` | divergences summary (one or more violations found) |

- **Status return.** `IST` is the **divergence count** — `0` means the state is
  consistent. It is set **only on the `IDIAG .NE. 0` path**; on the guarded
  (`IDIAG .EQ. 0`) early return, `IST` is left untouched (callers that need a
  defined value seed it before the call, as the `test/state/tstval.ref`
  contract does).

> **Shared sub-band — maintainer note.** The `9100`–`9199` sub-band is **shared**
> with the initialization validator: both `modern/init/initval.f` and
> `modern/state/stateval.f` draw their codes from `9100`–`9199`. This shared
> allocation is intentional (both are "load-time / startup consistency"
> validators) and is recorded here so maintainers do not assume the sub-band is
> exclusive to one validator. The dispatch validator, by contrast, uses the
> `9300`–`9399` sub-band (see `dispatch_modernization_report.md`).

---

## Scope Omissions & Flags

**Deliberate omissions (AAP §0.4.2).** Accessors are provided **only** for the
subset of `COMMON` blocks that the new modernization components actually
reference: `/DSIO/`, `/DBM/`, `/FCB/` (via `DSIOF.COM`); `/SYSTEM/`, `/SMCOMX/`
(via `SMCOMX.COM`); and `/DSNAME/`, `/DOSNAM/` (via `NASNAMES.COM`). The
following blocks are **intentionally NOT wrapped** because no modern component
references them; they remain available, as-is, for a future modernization phase:

- **`/GINOX/`** (`mds/GINOX.COM`) — GINO buffer/file-control words.
- **`/PAKBLK/`** (`mds/PAKBLK.COM`) — pack/unpack block descriptors.
- **`/ZZZZZZ/`** (`mds/ZZZZZZ.COM` / `mds/XNSTRN.COM`) — the open-core base
  block, additionally subject to the `IBASE`/`MEM` layout conflict noted above.
- **`/MMACOM/`** (`mis/MMACOM.COM`) — matrix-multiply/add communication words.

**`/SYSTEM/` `NBPW` word-offset flag (maintainer confirmation requested).** The
`/SYSTEM/` accessors rely on the `SMCOMX.COM` `/SYSTEM/` layout
(`ISYSBF, NOUT, DUM1(37), NBPW, DUM2(14), ISPREC`), in which **`NBPW` is word
40**. The canonical `bd/semdbd.f` layout is documented as placing **`NBPW` at
word 38**, so the offset differs between the two declarations. This discrepancy
is **FLAGGED for maintainer confirmation** and the accessors are committed to the
`SMCOMX.COM` view. Crucially, it does **not** affect correctness of a `SET`-then-
`GET` round-trip: `SETNBPW` writes, and `GETNBPW` reads back, the **same cell**
within the `SMCOMX.COM` layout, so the round-trip is exact regardless of which
absolute word the cell occupies. Words 1 (`ISYSBF`) and 2 (`NOUT`) are consistent
across every NASTRAN `/SYSTEM/` declaration and are **SAFE**.

**`KTIME` is not a `/SYSTEM/` cell.** For the avoidance of doubt, `KTIME` (the
dispatcher's wall-clock budget) is **not** a named `/SYSTEM/` variable and is not
wrapped by any state accessor. It is the **output argument** of
`CALL TMTOGO(KTIME)` (`mis/tmtogo.f`), obtained by the dispatcher immediately
before dispatch; see `dispatch_modernization_report.md`.

---

## Success Criteria (AAP §0.7.3)

- **All modern `COMMON` access routes through `stateacc.f`.** Every modern
  read/write of the in-scope global state goes through a `GET`/`SET` accessor;
  there is no direct `COMMON` access in the new state-consuming code.
- **No legacy adoption required.** Legacy routines retain their own `COMMON`
  declarations; the refactor does not force them onto the accessors.
- **Zero new `COMMON` re-declarations and zero new `EQUIVALENCE`**, verifiable by
  inspection — the `grep` checks above return `0` for both, and every state cell
  is reached via an `INCLUDE`d `*.COM` header (40 executable `INCLUDE`s, one per
  unit).
- **Validator guard clause is the first executable statement.** `STATEVAL`
  begins with `IF (IDIAG .EQ. 0) RETURN`, guaranteeing zero overhead when
  diagnostics are disabled.

---

## Provenance (read-only)

The following existing files were read as the sources of truth for this report
and were **not modified** by it: the nine `*.COM` headers — especially
`mds/DSIOF.COM`, `mis/SMCOMX.COM`, and `bin/NASNAMES.COM` / `mds/NASNAMES.COM`
(verified identical) — together with `bd/semdbd.f` (canonical `/SYSTEM/` layout
context), `bin/nastrn.f` (fixed-form column style and the bare-filename
`INCLUDE 'NASNAMES.COM'` idiom), and `mis/tmtogo.f` (`KTIME` via `TMTOGO`).
Sibling modern sources referenced for their published contracts:
`modern/state/stateacc.f`, `modern/state/stateval.f`, and
`modern/diag/diaglog.f`. This document is Markdown only and changes no source.
