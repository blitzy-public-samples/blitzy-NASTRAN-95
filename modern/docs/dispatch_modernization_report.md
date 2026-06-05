# NASTRAN-95 Modernization — Dispatch Report

> **Mechanism:** OSCAR computed-`GO TO` dispatch modernization
> (AAP §0.2.1, §0.6.2, §0.7.6).
> **Scope framing:** This is an **encapsulation / modularity refactor only** —
> **bit-for-bit numerical equivalence**, identical **module execution order**,
> and identical restart/checkpoint behavior with the unmodified APR.95 solver
> are the contract. The legacy dispatch source `mis/xsem00.f` is **FROZEN**
> (read-only) and is **not edited**; the modern dispatcher
> `modern/dispatch/disptbl.f` is built **alongside** it as a faithful
> functional twin (branch by abstraction). The live cutover is **deferred**
> precisely because wiring it in would modify the frozen file.
> **Authoring order:** this report is authored **after**
> `pre_implementation_analysis.md`, which supplies the authoritative full
> `MODX`→entry-point catalogue (its **Section C**) that every coverage number
> below is measured against.

---

## Purpose

This report documents the **OSCAR dispatch modernization** mechanism: the
table-driven module dispatcher `modern/dispatch/disptbl.f` and its validator
`modern/dispatch/dispval.f`, which together replace — in coexistence — the
22-stage cascading computed-`GO TO` ladder embedded in the frozen
`mis/xsem00.f` `[L262-L761]`. Specifically, it records:

- the **A2 algorithm decision** (how the `MODX`→subroutine mapping is expressed
  in FORTRAN 77 under `f77 -fast -dn`) together with its **rejected
  alternative** (required by §0.7.6);
- the **full `MODX` coverage proof** — the authoritative
  **217 / 193 / 188 / 21 / 3** breakdown that `dispval.f` and
  `test/dispatch/tdscnt.ref` assert, including the explicit
  **188-vs-189 reconciliation**;
- confirmation of the single pre-dispatch **`CALL TMTOGO(KTIME)`** placement,
  mirroring the legacy `mis/xsem00.f:L196`;
- the **`/SYSTEM/` / `KTIME` discrepancy** flagged for maintainer confirmation;
- the **`MESAGE` code handling** — the preserved legacy `-50` and the new
  fatal `-9301` for unmapped codes;
- the **coexistence / deferred-cutover** consequence of freezing `xsem00.f`;
- a representative **sample dispatch log**; and
- the **validator** contract and the **success criteria** that close out the
  mechanism.

The design pattern is **Strategy / table-driven dispatch**: the cascading
computed-`GO TO` ladder is re-expressed as an explicit, auditable
`MODX`→subroutine table, removing the `GO TO`-maintenance hazard that motivated
the refactor while preserving every dispatched module's public `CALL`
interface exactly.

---

## A2 Decision: FORTRAN-77 Dispatch Table under `f77 -fast -dn`

The dispatcher must express the legacy `MODX`→subroutine mapping in a form that
is (a) standard fixed-form FORTRAN 77, (b) valid under the existing
`f77 -fast -dn` flags `[bin/linknas]`, and (c) maintainable and trivially
auditable against the catalogue. Two constructs were evaluated.

### Candidate 1 — integer-`MODX` `IF`-`ELSEIF` chain over `EXTERNAL` subroutines *(RECOMMENDED / ACCEPTED)*

A single `IF` / `ELSE IF` chain that tests `MODX` directly
(`IF (MODX .EQ. n) THEN ... CALL <SUB>`), with **exactly one**
`CALL TMTOGO(KTIME)` at the top before branching (mirroring the legacy
placement), one bare argument-less `CALL <SUB>` per dispatched code, a
`CONTINUE` no-op per reserved slot, and a terminal `ELSE` that raises a fatal
diagnostic for any unmapped or out-of-range code.

**Why accepted:**

- **Most readable / trivially auditable.** Each branch is one line of the form
  `ELSE IF (MODX .EQ. n) THEN` followed by `CALL <SUB>`, so the
  `MODX`→subroutine mapping can be read off the source and checked one-to-one
  against the catalogue in `pre_implementation_analysis.md` (Section C) and the
  golden `test/dispatch/tdsmap.ref`.
- **Eliminates the `GO TO`-maintenance hazard.** A flat `IF`-`ELSEIF` chain
  has no cascading labels, no `MODX = MODX - 10` index arithmetic, and no
  multi-block fall-through — precisely the fragility the refactor exists to
  remove.
- **Standard and flag-safe.** An `IF`-`ELSEIF` chain over `MODX` calling
  `EXTERNAL` subroutines is core FORTRAN 77; `-fast` is an aggressive
  optimization bundle that does **not** alter integer control-flow semantics,
  and `-dn` (static, non-dynamic storage) imposes no constraint on it.
- **Interface-preserving.** Every dispatched call is a bare, argument-less
  `CALL <SUB>` identical to the legacy ladder, so the public `CALL` interface
  of every dispatched module is preserved exactly (no signature changes).

### Candidate 2 — `DATA`-initialized `INTEGER` index array driving a secondary dispatch *(REJECTED)*

A `DATA`-initialized `INTEGER` array of length 217 maps each `MODX` to a
sequence index, and that index then drives a secondary `IF`-`ELSEIF` (or
computed-`GO TO`) dispatch.

**Why rejected:**

- **Extra indirection for little gain.** In FORTRAN 77 the array lookup adds a
  second level of mapping (`MODX` → index → subroutine) that must itself be
  kept in sync with the subroutine list, reintroducing a coupling the direct
  chain avoids.
- **Harder to audit.** Coverage can no longer be read off a single construct;
  a reviewer must cross-reference the `DATA` table against the secondary
  dispatch, which is exactly the kind of two-place bookkeeping that breeds
  drift.
- **No semantic benefit under the flags.** `-dn` is fully compatible with
  `DATA`-initialized static arrays, so the array form is *valid* — but it buys
  nothing over the direct chain in readability, performance, or correctness.

> The rejected alternative and its rationale are recorded here in full as
> required by **§0.7.6**.

### Decision summary

| | Candidate 1 — direct `IF`-`ELSEIF` chain | Candidate 2 — `DATA` index array |
|---|---|---|
| Readability of `MODX`→subroutine map | ✅ one branch per code, read directly | ⚠️ split across table + secondary dispatch |
| Auditability vs. catalogue | ✅ one-to-one against `tdsmap.ref` | ⚠️ two-place cross-reference |
| `GO TO`-maintenance hazard removed | ✅ flat chain, no label arithmetic | ⚠️ may reintroduce computed-`GO TO` |
| Public `CALL` interfaces preserved | ✅ bare `CALL <SUB>` per branch | ✅ bare `CALL <SUB>` per branch |
| Valid under `f77 -fast -dn` | ✅ integer control flow unaffected | ✅ `-dn` allows `DATA` static arrays |
| **Decision** | **Accepted** | **Rejected** |

The accepted form is realized in `modern/dispatch/disptbl.f` as
`SUBROUTINE DISPTBL (MODX)` — a flat `IF` / `ELSE IF` cascade on `MODX` from
`3` through `217`, with reserved `CONTINUE` slots and a terminal fatal `ELSE`.

---

## Full MODX Coverage Proof

The complete `MODX`→entry-point catalogue is tabulated in
`pre_implementation_analysis.md` (**Section C**) and pinned, byte-identical to
the frozen ladder, in `test/dispatch/tdsmap.ref`. This report presents the
**authoritative aggregate coverage numbers** that the validator
`modern/dispatch/dispval.f` and the reference `test/dispatch/tdscnt.ref`
assert. Any dispatcher that does not reproduce these numbers exactly fails the
audit.

### Authoritative coverage breakdown

| Category | Count | Meaning |
|----------|------:|---------|
| **TOTAL** | **217** | every `MODX` operation code in the range **1–217** |
| **CALL** | **193** | dispatched slots that issue a `CALL <SUB>` |
| **DISTINCT** | **188** | distinct module subroutines reached by those 193 calls |
| **RESERVED** | **21** | reserved no-op `CONTINUE` slots (no module call) |
| **FATAL** | **3** | in-range slots (`MODX` 1, 2, 4) that fall through to the fatal handler |

The two closure identities the validator checks:

- **`193 + 21 + 3 = 217`** ✓ — every code in 1–217 is exactly one of: a
  dispatched `CALL`, a reserved `CONTINUE`, or an in-range fatal slot.
- **`193 − 5 = 188`** ✓ — the 193 dispatched slots resolve to 188 *distinct*
  subroutines because **`XCEI` is the sole reused subroutine**, shared by the
  **six** `MODX` values **5, 6, 7, 11, 12, 13** (six calls = five duplicates).

These are the same numbers consolidated in `final_modernization_summary.md`
("**217 / 193 / 188 / 21 / 3**") and asserted line-by-line in
`test/dispatch/tdscnt.ref`
(`EXPECT_TOTAL 217 / EXPECT_CALL 193 / EXPECT_DISTINCT 188 /
EXPECT_RESERVED 21 / EXPECT_FATAL 3 / EXPECT_DUP 0 / EXPECT_UNMAPPED 0`).

### The 21 RESERVED `CONTINUE` no-op slots

These `MODX` values are valid catalogue entries that perform **no** module
call (they map to a bare `CONTINUE` in `disptbl.f`, mirroring the legacy
ladder's reserved gaps). They are **not** fatal:

```
25  36  41  49  61  74  84  94  102  113  123  132
140  143  153  157  163  172  187  202  213
```

(21 values — matches `EXPECT_RESERVED 21`.)

### The 3 FATAL in-range slots

`MODX` **1, 2, 4** are in range but carry no module; in the legacy ladder the
first computed-`GO TO` block routes them to the shared label **`940`**
(`( 940, 940, 2003, 940, 2005, ...)` `[mis/xsem00.f:L264-L265]`), the
"link specifications incorrect" / link-spec error path. In `disptbl.f` these
three codes simply have **no branch**, so they fall through the `IF`-`ELSEIF`
chain to the terminal `ELSE` and are handled exactly like any other
unmapped/out-of-range code (fatal — see *MESAGE Codes & Unmapped Handling*).

### Special case — `MODX` 43 (`EMG`)

`MODX` 43 dispatches `EMG`, but the legacy ladder brackets the call with a
`LINKNO`/`LINKNM` swap `[mis/xsem00.f:L409-L411]`. `disptbl.f` preserves this
sequence **verbatim**:

```fortran
ELSE IF (MODX .EQ. 43) THEN
   LINKNO = LINKNM(8)
   CALL EMG
   LINKNO = LINKNM(1)
```

This is the only dispatched slot that touches global state directly; the
`/SEM/` and `/SYSTEM/` windows it relies on are discussed under
*`/SYSTEM/` / `KTIME` Discrepancy*.

### 188-vs-189 reconciliation *(critical)*

The AAP narrative cites "roughly 190" and, more precisely, "**189** distinct
subroutines." The **verified, authoritative** distinct-subroutine count is
**188**. The discrepancy is a **comment-induced overcount**, documented here so
the catalogue is not "corrected" back to the wrong number:

- A naive `CALL <name>` text scan of `mis/xsem00.f` matches the token `EMG1B`
  inside a **comment**, not an executable statement:
  `[mis/xsem00.f:L408]` reads
  `C  SET LINKNO TO FLAG SUBROUTINE SMA1B TO CALL EMG1B`.
- `EMG1B` is invoked **inside `SMA1B`**, not by the executive ladder, so it is
  **not** a dispatch target. The `MODX` 43 dispatched call is `CALL EMG`
  `[mis/xsem00.f:L410]`, already counted.
- Removing the spurious comment match yields **188** distinct dispatch targets
  for **193** `CALL` branches.

Accordingly `disptbl.f` contains **193 `CALL` branches → 188 distinct
subroutines**, and `test/dispatch/tdscnt.ref` asserts
`EXPECT_TOTAL 217 / EXPECT_CALL 193 / EXPECT_DISTINCT 188 /
EXPECT_RESERVED 21 / EXPECT_FATAL 3`.

### Argument-passing contract

The dispatcher preserves the public `CALL` interface of every dispatched
module **exactly** as the legacy ladder does (no signature changes — each
branch is a bare argument-less `CALL <SUB>`). It receives `MODX` as a **passed
argument** — `SUBROUTINE DISPTBL (MODX)` — and **never re-extracts it**: the
extraction `MODX = RSHIFT(INOSCR(3),16)` stays in the frozen
`mis/xsem00.f:L182`, and `disptbl.f` never reads `INOSCR`. `MODX` is treated as
read-only inside the dispatcher (the legacy `MODX = MODX - 10` indexing
arithmetic is unnecessary because each branch tests `MODX` directly).

---

## TMTOGO(KTIME) Placement

The legacy executive performs the wall-clock budget check **once, before** the
dispatch ladder. In `mis/xsem00.f` this is:

```fortran
250 CALL TMTOGO (KTIME)                                  [L196]
    IF (KTIME.LE.0.AND.WORDB(2).NE.EXIT)                 [L197]
   *   CALL MESAGE (-50, 0, WORDB(2))                    [L198]
```

placed once at label `250` `[L196]`, ahead of the computed-`GO TO` ladder that
begins at `1000 CALL SSWTCH` `[L262]`.

The modern `disptbl.f` mirrors this exactly: it performs a **single
`CALL TMTOGO(KTIME)` before its `IF`-`ELSEIF` chain**, immediately followed by
the time-exhaustion guard:

```fortran
CALL TMTOGO (KTIME)
IF (KTIME .LE. 0) CALL MESAGE (-50, 0, SUBNAM)
```

— preserving the existing legacy **`-50`** insufficient-time code (this is the
EXISTING code, **not** a new one). There is **exactly one** `CALL TMTOGO` in
the whole routine, which `test/dispatch/tdstmt.ref` pins with
`EXPECT_TMTOGO_CALLS 1` (the driver invokes the dispatcher with a reserved
no-op `MODX` such as `25` so only the single pre-dispatch `TMTOGO` is
exercised).

**Simplification flag.** The legacy qualifier `.AND. WORDB(2).NE.EXIT` is
omitted because the `MODX`-only interface carries no `WORDB`, and the `EXIT`
pseudo-op is handled by the executive **before** the ladder is reached, so the
test is always true at the dispatch point — behaviorally equivalent. The
`NAME` argument is `SUBNAM` (`'DISPTBL '`) rather than the legacy module BCD
name `WORDB(2)`: a cosmetic message-identification difference only.

**Hot-path discipline.** The dispatcher hot path carries **zero diagnostic
overhead**: there is **no** `IDIAG`, **no** `IF (IDIAG .EQ. 0) RETURN` guard
clause, and **no** logging inside the dispatch branches — it is the
performance-critical path. All diagnostic and logging behavior lives in the
validator (`dispval.f`) and the optional logger (`diaglog.f`), each of which
*does* implement the guard clause as its first executable statement.

---

## `/SYSTEM/` / `KTIME` Discrepancy

This discrepancy is flagged for maintainer confirmation.

- **`/SYSTEM/` is not in `NASNAMES.COM`.** The AAP narrative suggests obtaining
  `KTIME` from `/SYSTEM/` via `NASNAMES.COM`, but `/SYSTEM/` is **not** declared
  in `NASNAMES.COM`. Among the nine `*.COM` headers it appears **only** in
  `mis/SMCOMX.COM` (`COMMON /SYSTEM/ ISYSBF, NOUT, DUM1(37), NBPW, ...`), and
  `mis/xsem00.f` declares `/SYSTEM/` **inline** `[mis/xsem00.f:L24]`.
- **`KTIME` is not a `/SYSTEM/` cell at all.** Critically, `KTIME` is **not** a
  named cell of `/SYSTEM/`; it is the **output argument** of
  `CALL TMTOGO(KTIME)` — `mis/tmtogo.f` declares `SUBROUTINE TMTOGO (TOGO)`
  with `INTEGER TOGO`, and fills the passed argument. The dispatcher therefore
  obtains `KTIME` **directly from `TMTOGO`**, exactly as the legacy ladder does,
  and needs no `/SYSTEM/` access for the time check.

- **The single flagged inline COMMON exception (`MODX` 43 only).** The one place
  `disptbl.f` needs `/SYSTEM/` cells is the `MODX` 43 `LINKNO` swap, which also
  needs `LINKNM` from `/SEM/`. Neither `LINKNO` nor `LINKNM` is exposed by name
  in the nine `*.COM` headers, so — consistent with NASTRAN's per-routine
  COMMON convention and the AAP's explicit allowance — `disptbl.f` declares
  **minimal inline windows** of these two **existing** blocks:

  ```fortran
  COMMON /SEM/    ISEM(3), LINKNM(15)
  COMMON /SYSTEM/ ISYS(21), LINKNO
  ```

  These windows are positioned to match `mis/xsem00.f` **exactly**:
  `ISEM(3)` places `LINKNM` at `/SEM/` words 4–18 (so `LINKNM(8)` = word 11 and
  `LINKNM(1)` = word 4), matching `[mis/xsem00.f:L22]`; `ISYS(21)` places
  `LINKNO` at `/SYSTEM/` word 22, matching `[mis/xsem00.f:L24]`. They are used
  **only** by the `MODX` 43 branch.

  This is the **only** inline `COMMON` anywhere in the `modern/` tree. It
  introduces **no new `COMMON` block** and **no `EQUIVALENCE`** — it is a window
  onto two pre-existing blocks, an intentional NASTRAN overlay convention,
  **explicitly flagged for maintainer confirmation**.

---

## MESAGE Codes & Unmapped Handling

`disptbl.f` uses exactly two `MESAGE` codes, one preserved and one new:

- **Preserved legacy `-50` (time exhaustion).** The pre-dispatch guard
  `IF (KTIME .LE. 0) CALL MESAGE (-50, 0, SUBNAM)` reuses the **existing**
  insufficient-time code `-50`, identical to the legacy
  `CALL MESAGE (-50, 0, WORDB(2))` `[mis/xsem00.f:L198]`. No new code is
  introduced for this path.
- **New fatal `-9301` (unmapped / out-of-range).** Any `MODX` that reaches the
  terminal `ELSE` of the `IF`-`ELSEIF` chain — the three in-range fatal slots
  (`MODX` 1, 2, 4) **and** any out-of-range code (`MODX ≤ 0` or `MODX ≥ 218`) —
  raises:

  ```fortran
  ELSE
     CALL MESAGE (-9301, MODX, SUBNAM)
  END IF
  ```

  A **negative** `NO` argument is fatal in `mis/mesage.f`
  (`SUBROUTINE MESAGE (NO,PARM,NAME)`; `NO ≤ 0` terminates the run), so
  `-9301` is a fatal diagnostic. `IABS(-9301) = 9301` lies in the unassigned
  **9001–9999** band (dispatch sub-band **9300–9399**), per **§0.7.2**. The
  legacy `-37`/`-50` codes are deliberately **not** reused for this path, so
  an unmapped-dispatch fatal is unambiguously attributable to the modern layer.

The message-identification name is carried as a 2-word Hollerith array,
`DATA SUBNAM /4HDISP,4HTBL /` (i.e. `'DISPTBL '`), matching the
`INTEGER NAME(2)` signature of `MESAGE`.

**Registry untouched.** `um/MSSG.TXT` is **not** edited. The 9001–9999 band is
free (the registry's highest assigned id is **8015**; there is no `9xxx`
entry), so the new code is **emitted at runtime, never registered** by editing
the message file. `test/dispatch/tdsunm.ref` pins the contract:
`OUT_OF_RANGE 0 -1 218`, `INRANGE_FATAL 1 2 4`, `BAND_LOW 9001`,
`BAND_HIGH 9999`.

---

## Coexistence / Deferred Cutover (branch by abstraction)

Freezing `mis/xsem00.f` has a direct architectural consequence: the modern
dispatcher cannot be wired into the live ladder in this phase, because doing so
would edit the frozen file. This is **textbook branch by abstraction** — build
and validate the new implementation against the same abstraction the legacy
caller uses, then switch callers later.

- **Built to the target interface now.** `disptbl.f` is written with the
  final `MODX`-passed-argument interface (`SUBROUTINE DISPTBL (MODX)`), a
  faithful functional twin of the ladder, so a future cutover preserves
  bit-for-bit results and module execution order.
- **Validated in coexistence now.** The dispatcher's decisions are exercised
  and checked against the catalogued legacy mapping through the
  `test/dispatch/` unit drivers and the **`NASTRAN_DISPATCH_VALIDATE`** path
  (the `IDIAG` bit-4 toggle read by `diagctl.f`), which compares modern
  decisions against the golden `tdsmap.ref`/Section-C catalogue.
- **Live cutover deferred.** The live cutover — editing the ladder so the
  executive issues `CALL DISPTBL(MODX)` in place of the computed-`GO TO`
  cascade — is **deferred precisely because it would modify the frozen
  `mis/xsem00.f`**. The extraction `MODX = RSHIFT(INOSCR(3),16)`
  `[mis/xsem00.f:L182]` and the single pre-ladder `CALL TMTOGO(KTIME)`
  `[mis/xsem00.f:L196]` remain verbatim in the frozen file; the dispatcher
  consumes `MODX` as an argument and never re-extracts it.

This is the same feature-toggle / strangler-fig cutover control used elsewhere
in the modernization: when no `NASTRAN_*` toggle is set, behavior is exactly
APR.95, and the modern dispatcher is inert (built and unit-tested, not yet on
the live path).

---

## Sample Dispatch Log

An **optional** dispatch log is available for debugging. It is gated by the
**`NASTRAN_DISPATCH_LOG`** toggle — **bit 8** of the `IDIAG` bitmask computed
once by `modern/diag/diagctl.f` (`NASTRAN_LEGACY_INIT`=1,
`NASTRAN_INIT_VALIDATE`=2, `NASTRAN_DISPATCH_VALIDATE`=4,
`NASTRAN_DISPATCH_LOG`=8). When the bit is set, dispatch records are emitted
via `modern/diag/diaglog.f` to **logical unit 3 only**, using dispatch-band
codes **9300–9399**.

Representative records (illustrative):

```
 *** MODERN DIAGNOSTIC   9300 DISPATCH MODX -> XCHK     (VALUE=           3)
 *** MODERN DIAGNOSTIC   9300 DISPATCH MODX -> AMG      (VALUE=          16)
 *** MODERN DIAGNOSTIC   9300 DISPATCH MODX -> EMG      (VALUE=          43)
 *** MODERN DIAGNOSTIC   9300 DISPATCH MODX -> NORMAL   (VALUE=         217)
```

These lines are produced by
`CALL DIAGLOG (IDIAG, 9300, MODX, 'DISPATCH MODX -> <NAME>')`, whose writer
`diaglog.f` uses the format

```fortran
100 FORMAT (' *** MODERN DIAGNOSTIC ', I6, 1X, A, 1X, '(VALUE=', I12, ')')
```

The leading blank is line-printer carriage control; `I6` prints the code
(`9300`); `A` prints the caller-supplied label (the target subroutine name
arrives as the `CHARACTER*8 NAME` from `DSPMAP`, which is why the names align
in an 8-column field); and `I12` prints the `MODX` value. Two points of
clarity:

- This is **illustrative** of the *format* — the exact text is caller-supplied
  via the `MSG` argument; `diaglog.f` does not itself know about dispatch.
- **Logging is the caller's responsibility.** `diaglog.f` applies only the
  master guard `IF (IDIAG .EQ. 0) RETURN`; per-toggle gating (log dispatch
  **only** when `NASTRAN_DISPATCH_LOG` / bit 8 is set, e.g.
  `IF (IAND(IDIAG,8) .NE. 0) CALL DIAGLOG (...)`) is performed by the caller
  **before** calling `DIAGLOG`. The dispatcher hot path itself carries no such
  call; the optional log is driven from the validation/coexistence harness, not
  from `disptbl.f`'s dispatch branches.

---

## Validator — `modern/dispatch/dispval.f`

The validator proves the dispatcher's coverage against the catalogue. It
comprises two units, both following the modernization's guard-clause and
`DIAGLOG`-reporting conventions.

### `SUBROUTINE DISPVAL (IDIAG, NENT, NDUP, NUNMAP, IST)`

- **Guard clause first.** `IF (IDIAG .EQ. 0) RETURN` is the first executable
  statement (zero overhead when diagnostics are disabled — §0.6.4 / §0.7.2).
- **Asserts the coverage identity.** It confirms the dispatcher's entry count
  equals the catalogued `MODX` count with no duplicate or unmapped codes,
  reporting `NENT = 217`, `NDUP = 0`, `NUNMAP = 0`, `IST = 0` on success.

It reports via `DIAGLOG` (unit 3, dispatch band) with these codes:

| Code | Meaning |
|-----:|---------|
| `9300` | OK / per-entry confirmation |
| `9302` | entry-count mismatch |
| `9303` | duplicate code detected |
| `9304` | unmapped code detected |
| `9305` | per-`MODX` detail |
| `9399` | run summary |

### `SUBROUTINE DSPMAP (MODX, NAME, IKIND)`

`DSPMAP` returns the dispatched target name (or the reserved token) in
`CHARACTER*8 NAME` and classifies each `MODX` via `IKIND`:

| `IKIND` | Classification |
|--------:|----------------|
| `0` | mapped (a real `CALL <SUB>` target) |
| `1` | reserved `CONTINUE` no-op |
| `2` | in-range FATAL (`MODX` 1, 2, 4) |
| `-1` | out-of-range (`MODX ≤ 0` or `MODX ≥ 218`) |
| `3` | gap |

For a reserved slot the returned token is `'CONTINUE'`.

The **217-row map encoded in `dispval.f` / `DSPMAP` must agree exactly** with
the catalogue in `pre_implementation_analysis.md` (Section C) and the golden
`test/dispatch/tdsmap.ref` — same total, same reserved set, same fatal set,
same `MODX` 43 → `EMG` special case.

---

## Success Criteria

The dispatch mechanism is satisfied when (per **§0.7.3**):

- **Full, exact coverage.** The dispatcher's entry count equals the catalogued
  `MODX` count with **zero omissions** — the authoritative
  **217 / 193 / 188 / 21 / 3** breakdown, with `NDUP = 0` and `NUNMAP = 0`.
- **Coexistence equivalence.** With **`NASTRAN_DISPATCH_VALIDATE=1`** there are
  **zero sequence divergences** across the five integration inputs —
  `inp/d01001a.inp` (SOL 1, static), `inp/d03011a.inp` (SOL 3, normal modes),
  `inp/d05011a.inp` (SOL 5, buckling), `inp/d08011a.inp` (SOL 8, direct
  frequency/random response), and `inp/d09011a.inp` (SOL 9, direct transient
  response) — between the modern dispatcher's decisions and the catalogued
  legacy mapping.
- **Fatal on unmapped.** Any unmapped or out-of-range `MODX` raises the fatal
  **`-9301`** (9300–9399 sub-band of the free 9001–9999 band); `um/MSSG.TXT`
  is not edited.
- **Single pre-dispatch time check.** Exactly **one** pre-dispatch
  `CALL TMTOGO(KTIME)` is preserved, with the legacy `-50` insufficient-time
  code intact.

---

## Provenance (read-only)

This document is derived from the following artifacts. **None is modified** by
this report.

- **Frozen dispatch source:** `mis/xsem00.f` — the `MODX` extraction
  `[L182]`, the single pre-dispatch `CALL TMTOGO(KTIME)` `[L196]` and its
  `-50` guard `[L197-L198]`, the computed-`GO TO` ladder `[L262-L761]`, the
  `EMG1B` **comment** `[L408]`, the `MODX` 43 / `EMG` special case
  `[L409-L411]`, and the inline `/SEM/` `[L22]` and `/SYSTEM/` `[L24]`
  declarations.
- **`/SYSTEM/` header:** `mis/SMCOMX.COM` (the only one of the nine `*.COM`
  headers that declares `/SYSTEM/`).
- **Time check:** `mis/tmtogo.f` (`SUBROUTINE TMTOGO (TOGO)`; `KTIME` is the
  output argument, not a `/SYSTEM/` cell).
- **Fatal convention:** `mis/mesage.f` (`SUBROUTINE MESAGE (NO,PARM,NAME)`;
  `NO ≤ 0` is fatal).
- **Message band:** `um/MSSG.TXT` (highest assigned id 8015; 9001–9999 free).
- **Integration inputs (SOL types):** `inp/d01001a.inp`, `inp/d03011a.inp`,
  `inp/d05011a.inp`, `inp/d08011a.inp`, `inp/d09011a.inp`.
- **Catalogue reference:** `pre_implementation_analysis.md` (Section C — the
  full `MODX`→entry-point table) and the golden reference data
  `test/dispatch/tdsmap.ref`, `test/dispatch/tdscnt.ref`,
  `test/dispatch/tdstmt.ref`, `test/dispatch/tdsunm.ref`.
- **Sibling sources (the implementations this report documents):**
  `modern/dispatch/disptbl.f`, `modern/dispatch/dispval.f`,
  `modern/diag/diaglog.f`.
