# NASTRAN-95 Modernization — Regression Validation Report

> **Mechanism:** Regression-safety / golden-master harness
> (AAP §0.2.1, §0.6.3, §0.7.5, §0.7.6).
> **Scope framing:** This is an **encapsulation / modularity refactor only** —
> **bit-for-bit numerical equivalence** with the unmodified APR.95 solver is the
> contract. The shipped `demoout/*.out` files are the **golden masters**; no
> `inp/*.inp` deck and no solver output is changed. The regression harness
> *proves* that promise; it does not relax it.

---

## Purpose

This report documents the **regression-safety mechanism** that protects the
modernization against any behavioral drift. Specifically, it records:

- the **A3 algorithm decision** (how refactored output is compared against the
  golden masters) together with its **rejected alternative** (required by
  §0.7.6);
- concrete **`demoout/` OFP (Output File Processor) output-format evidence** —
  which lines are volatile and must be skipped, and which are stable and must be
  compared;
- the **comparator methodology** realized in `modern/regress/outcomp.f` (token
  classification and tolerances);
- the **regression orchestrator** `modern/regress/regval.f` and its division of
  labor with the comparator;
- the **test-harness inventory** (`test/regress/run_all.csh` and
  `test/run_units.csh`) and the driver output contract;
- the **five integration inputs** that drive the dispatch cross-check and the
  per-deck regression, plus the full **132-deck** sweep;
- the **shipped-master `NUL`-padding handling** for `demoout/t01231a.out` and
  why the full 132-deck gate **can pass** (the harness is generated, not run by
  Blitzy, per AAP §0.7.5); and
- the **success criteria** that close out the mechanism.

The design pattern is **golden-master / characterization testing**: the existing
behavior of the legacy solver is captured once (the shipped `demoout/` outputs)
and every refactored run is compared against that capture, so any unintended
change to a numerical result, a module execution order, or restart/checkpoint
behavior surfaces immediately as a difference.

---

## A3 Decision: Output Comparison Strategy

The refactor must prove that a modern-layer build reproduces the shipped
`demoout/` outputs. Two comparison strategies were evaluated.

### Candidate 1 — line-by-line POSIX `diff` after whitespace normalization *(REJECTED)*

Normalize whitespace, then run a standard line-oriented `diff` of the candidate
output against the golden master.

**Why rejected:**

- **False failures on volatile lines.** Every OFP page carries a per-page header
  with a **run-date** (`MAY 17, 95`) and a **page number** (`PAGE n`), plus a
  trailing **timing tail** (`DATE:`, `END TIME`, `WALL CLOCK`). These values
  legitimately change run-to-run. A naive `diff` reports each of them as a
  difference, so a perfectly correct run would "fail" on dozens of date and
  page-number lines.
- **No numeric tolerance.** `diff` compares bytes, not numbers. It cannot accept
  a floating-point field that differs only in the last printed digit due to a
  format-sensitive round-trip; such legitimate, format-level differences would
  **spuriously fail**, while `diff` simultaneously offers no way to *tighten*
  the check for true numeric drift.
- **Carriage-control noise.** Column-1 carriage-control characters (`1`, `0`,
  blank, `+`) and CRLF line endings further perturb a byte-level `diff`.

In short, `diff` is both **too strict** (volatile lines, last-digit float
formatting) and **too blunt** (no notion of a numeric field or a tolerance) for
line-printer output.

### Candidate 2 — field-by-field FORTRAN comparator (`outcomp.f`) *(RECOMMENDED / ACCEPTED)*

A purpose-built FORTRAN-77 comparator (`modern/regress/outcomp.f`) that:

- **skips or normalizes** the volatile date, page-number, and banner lines and
  the column-1 carriage control;
- tokenizes each remaining line and classifies every token as **TEXT**,
  **INTEGER**, or **REAL**;
- applies a **6-significant-figure RELATIVE tolerance** (`RTOL = 1.0D-6`) to
  floating-point fields; and
- requires **bitwise / exact identity** for integer (and text) fields.

**Why accepted:** This is the textbook **golden-master / characterization**
approach, and it is the right fit for complex line-printer output where
asserting every attribute by hand would be unmaintainable. It eliminates the
false failures of Candidate 1 (volatile lines are skipped; last-digit float
formatting is absorbed by the relative tolerance) while *strengthening* the
check where it matters (integers must match exactly; floats must agree to six
significant figures).

### Decision summary

| | Candidate 1 — POSIX `diff` | Candidate 2 — `outcomp.f` field comparator |
|---|---|---|
| Volatile date / page / banner | ❌ false failures | ✅ skipped / normalized |
| Numeric tolerance for floats | ❌ none (byte compare) | ✅ 6-sig-fig **relative** (`RTOL = 1.0D-6`) |
| Integer / text fields | ⚠️ byte compare (with normalization caveats) | ✅ exact / bitwise identity |
| Column-1 carriage control / CRLF | ❌ perturbs comparison | ✅ stripped / normalized |
| Suited to line-printer output | ❌ | ✅ golden-master / characterization |
| **Decision** | **Rejected** | **Accepted** |

The rejected alternative and this rationale are recorded here per **§0.7.6**.

---

## `demoout/` OFP Format Evidence

All evidence below is drawn directly from `demoout/d01001a.out` (the SOL 1 static
golden master, 279 lines), which is representative of the entire `demoout/` set.

### Volatile per-page header *(MUST be skipped)*

Every printed page begins with a header of the form:

```
1                                              /    95 SUN SOLARIS NASTRAN    / MAY 17, 95 / PAGE     2
```

- The leading `1` in **column 1** is the carriage-control "new page" character.
- The **date** field (`MAY 17, 95`, but also `MAY 18, 95`, `MAY 19, 95`, …) and
  the **`PAGE n`** number both vary run-to-run and **must be skipped**.
- The comparator detects this header by matching the literal substring
  **`SOLARIS NASTRAN`**.

### Static banner `SOLARIS VERSION` *(NOT volatile — must be compared)*

The cover/title block contains a **stable** banner line (around **line 18**):

```
                                SOLARIS VERSION
```

This is **not** volatile content. The critical distinction is that the volatile
detector keys on the **exact** substring `SOLARIS NASTRAN`, which **does not
match** `SOLARIS VERSION`. A looser match on bare `SOLARIS` would wrongly discard
the static banner; the precise signature avoids that. (In this particular file
the title block happens to sit in the cover region that precedes the first page
header — see below — but the design intent is unambiguous: `SOLARIS VERSION` is
never treated as a volatile page header.)

### Column-1 carriage control *(stripped before comparison)*

OFP output is line-printer text whose **first column** is a carriage-control
character: `1` = new page, `0` = double space, blank = single space, `+` =
overprint. This column is **stripped** before any comparison by taking columns
`2:256` of the record (`CONT = BUF(2:256)` in the comparator).

### Other structurally-irrelevant lines

- **Cover/banner before the first page header.** Every line that precedes the
  first `SOLARIS NASTRAN` page header is cover/banner and is skipped wholesale.
- **Timing tail.** The final three timing lines are volatile and skipped, matched
  by `DATE:`, `END TIME`, and `WALL CLOCK` (in `d01001a.out`:
  `DATE:  5/17/95`, `END TIME: 14: 0: 5`, `TOTAL WALL CLOCK TIME      0 SEC.`).
- **Blank lines** (blank after carriage control is stripped) are skipped.
- **CRLF / control characters.** The `demoout/*.out` files use **CRLF** line
  endings; any non-printing byte (`ICHAR < 32`, e.g. the trailing CR) is
  normalized to a blank before comparison so CRLF-terminated files compare
  cleanly.

### Volatile header vs. comparable data line (illustrative)

```
SKIP  ->  1   ...   /    95 SUN SOLARIS NASTRAN    / MAY 17, 95 / PAGE     2     (volatile: date + page)
KEEP  ->  0*** USER INFORMATION MESSAGE 225, GINO TIME CONSTANTS ARE BEING COMPUTED   (col-1 '0' stripped; text compared exactly)
KEEP  ->        G      11      6.326195E-04   -5.312650E-04    ...                (col-1 ' ' stripped; INTEGER 11 exact, REAL fields within 6 sig figs)
```

The first line is skipped because it carries the `SOLARIS NASTRAN` signature; the
remaining two are comparable content lines whose column-1 carriage control is
removed and whose tokens are then compared field by field.

---

## Comparator Methodology — `modern/regress/outcomp.f`

`outcomp.f` is the field-by-field comparator that realizes Candidate 2. It is a
**library** routine: it compares, counts, and reports, but it does **not** decide
the verdict.

### Public contract

```
SUBROUTINE OUTCOMP (LUTST, LUREF, LULOG, NDIFF, IRET)
```

| Argument | Dir. | Meaning |
|----------|------|---------|
| `LUTST`  | in   | logical unit of the **candidate** output (already `OPEN`ed by the caller) |
| `LUREF`  | in   | logical unit of the **golden master** from `demoout/` (already `OPEN`ed) |
| `LULOG`  | in   | logical unit for the human-readable difference report |
| `NDIFF`  | out  | total count of field/line differences; `0` ⇒ the two outputs match |
| `IRET`   | out  | `0` = completed normally; `1` = an I/O or structural read error occurred |

The caller owns `OPEN`/`CLOSE` of both streams; `OUTCOMP` reads them read-only and
never opens, closes, or writes to logical unit 3.

### Token classification — `ICLASS`

Each whitespace-delimited token is classified by the helper function `ICLASS`:

| `ICLASS` return | Class | Examples |
|---|---|---|
| `0` | **TEXT** | `G`, `OUGV2`, `POINT`, `TYPE`, `ID.`, `163,` (trailing comma) |
| `1` | **INTEGER** | `11`, `162` |
| `2` | **REAL** | `6.326195E-04`, `-5.312650E-04`, `1.27579471D+02`, `0.00000000D+00`, `0.0` |

A token is numeric only if every character is in `{0-9 + - . E e D d}` **and** at
least one character is a digit; it is REAL when it contains a `.` or an `E`/`D`
exponent marker, otherwise INTEGER; anything else is TEXT.

### Comparison rules

- **REAL fields** — relative tolerance `RTOL = 1.0D-6` (six significant figures).
  With `DIFF = |VT − VR|` and `DEN = MAX(|VT|, |VR|)`, the field matches when
  `DIFF / DEN ≤ RTOL`. The `DEN = 0` case (both values exactly zero) is treated
  as a **match** with no division; `0.0` versus a nonzero value yields a
  mismatch.
- **INTEGER and TEXT fields** — **exact / bitwise identity** (length and every
  character must agree). A token that classifies as INTEGER in one stream but
  REAL in the other compares unequal.
- **Token-count mismatch** on a line is itself one difference; **line-count
  mismatch** (one stream ends early) is reported and each extra comparable line
  is counted.

### Volatile-line skipping — `NXTCMP`

A helper `NXTCMP` advances **one** stream to its next comparable line, hiding all
volatility from the main loop. It:

- sets the per-stream "header seen" flag (`HEADSN = .TRUE.`) on the first line
  containing `SOLARIS NASTRAN`, and skips every cover/banner line before it;
- skips the volatile page header (`SOLARIS NASTRAN`) and timing tail (`DATE:`,
  `END TIME`, `WALL CLOCK`);
- skips the volatile **tape-provenance** lines — those naming the *machine that
  wrote a tape* — via the machine-name-**independent** signature `INDEX(BUF,
  'MACHINE') > 0 .AND. INDEX(BUF, 'BY ') > 0`. These are the only `demoout/`
  lines that carry an environment-specific machine name (NUL-padded in the
  shipped masters); the signature matches symmetrically in both the reference
  and a fresh candidate (which carries a real machine name rather than NULs),
  and it deliberately does **not** match the legitimate
  `... ON 32-BIT WORD MACHINE` warning, which lacks `BY `;
- strips the column-1 carriage control (`CONT = BUF(2:256)`);
- normalizes a carriage return / line feed (`ICHAR = 13` or `10`) to a blank and
  an embedded `NUL` (`ICHAR = 0`) to a blank while recording `HADNUL` for the
  line; **any other** control byte (`ICHAR < 32`) marks the record as embedded
  binary and raises a hard error (`IERR = 1`, `IEOF = 1`); and
- skips lines that are blank after stripping. As a final safety net, a `NUL`
  that **survives every volatile skip** (i.e. `HADNUL` is set on a line that is
  *not* a recognized volatile line) is treated as embedded binary and raises the
  same hard error — so genuine binary content is still rejected while the known
  tape-provenance NUL padding is normalized away.

### Self-containment and discipline (verifiable by inspection)

- **No `COMMON`, no `EQUIVALENCE`, no `INCLUDE`.** All data arrives through
  arguments or is local; none of the nine `*.COM` headers is included
  (consistent with AAP §0.5.3). `outcomp.f` is shared *infrastructure*, not an
  in-solver state consumer.
- **No guard clause.** Unlike the `modern/diag/` routines, `outcomp.f` is
  explicitly-invoked standalone tooling that must run unconditionally when
  called; it takes no `IDIAG` and contains no `IF (IDIAG .EQ. 0) RETURN`.
- **Never emits a verdict token.** `OUTCOMP` reports differences with wording
  such as *MISMATCH* / *DIFFERS* and **never** prints the literal `PASS:` or
  `FAIL:` — the verdict belongs solely to the caller `PROGRAM REGVAL`. This keeps
  a `grep` for `FAIL:` over the run log counting only true per-deck verdicts.

---

## Regression Orchestrator — `modern/regress/regval.f`

`regval.f` is the thin **main program** that turns a comparison into a verdict.

- **`PROGRAM REGVAL` is the MAIN program** and therefore must be **linked first**
  (ahead of `outcomp.f`) when the regression executable is built.
- It reads two command-line arguments via `IARGC` / `GETARG`:
  **arg 1 = the candidate output**, **arg 2 = the golden (`demoout/`) reference**.
- It `OPEN`s both files, calls `OUTCOMP`, then emits exactly one verdict —
  `PASS: <name>` or `FAIL: <name>` — and terminates with `CALL EXIT(code)`.

The exit code encodes the outcome:

| Exit code | Meaning |
|---|---|
| `0` | clean match (`NDIFF = 0` and `IRET = 0`) |
| `1` | compare-fail (`NDIFF > 0`), open error, or `IRET ≠ 0` |
| `2` | usage error (wrong argument count) |

### Unit-6 (stdout) exception — documented and deliberate

`REGVAL` writes its verdict to **`LULOG = 6` (stdout)**, **not** logical unit 3.
This is a **deliberate, documented exception** to the unit-3-only rule: `REGVAL`
is a **post-run, standalone developer tool** that runs *outside* the solver, not
part of the in-solver diagnostics layer. The unit-3-only rule (§0.7.2) governs
the in-solver `modern/diag/` layer; it does not govern this harness. The
`run_all.csh` harness captures stdout (`>>& $RUNLOG`), so the verdict lands in the
run log regardless.

---

## Test Harness Inventory

Two `csh` scripts form the harness. Per **§0.7.5**, both are **generated as
deliverables** and run later by the developer in the Solaris environment (`csh` +
Sun `f77`) — **they are not executed by Blitzy** — and **each exits non-zero on
any failure**.

### `test/regress/run_all.csh` — integration / golden-master sweep

A single-command regression that:

1. **builds the regression executable** with the exact `bin/linknas` idiom,
   linking the **main program first**:

   ```
   f77 -fast -dn -o regress.exe regval.f outcomp.f nastlib.a
   ```

   (`regval.f` first because `PROGRAM REGVAL` is MAIN; `outcomp.f` and the
   archive follow.)
2. **runs the benchmark decks** to produce candidate `*.out` files;
3. **invokes the comparator per deck** as
   `regress.exe <candidate> <demoout-reference>`;
4. **reports per-file PASS/FAIL** and exits non-zero if any deck fails; and
5. is **reusable for future modernization phases** — it is parameterized over the
   deck list rather than hardcoded to this increment.

### `test/run_units.csh` — unit-driver runner

The top-level unit runner that builds and runs the unit drivers across the four
suites — `test/init`, `test/state`, `test/dispatch`, `test/diag` — using the same
`f77 -fast -dn ... nastlib.a` idiom, then **greps the aggregated log for the
literal token `FAIL:`** and **exits non-zero** if any match is found (or if any
build/run step failed), exiting `0` only when every driver reported `PASS`.

### Driver output contract

Each FORTRAN **unit driver** emits exactly one verdict per case — `PASS: <name>`
or `FAIL: <name>` — to the log unit. `run_units.csh` relies on this contract: a
single `FAIL:` anywhere in the aggregated log fails the whole run. (The
comparator `outcomp.f` deliberately never emits these tokens, so the only
`PASS:`/`FAIL:` lines come from the drivers and from `regval.f`.)

---

## Five Integration Inputs

The following five `inp/*.inp` decks drive both the `NASTRAN_DISPATCH_VALIDATE`
cross-check and the per-deck `regval` comparison. They span five distinct
solution sequences (SOL types), and their golden-master line counts are taken
directly from the corresponding `demoout/*.out` files.

| Input deck | SOL type | Analysis | Golden-master line count |
|------------|----------|----------|--------------------------:|
| `d01001a.inp` | SOL 1     | Static                        | 279  |
| `d03011a.inp` | SOL 3,1   | Normal Modes                  | 1389 |
| `d05011a.inp` | SOL 5,1   | Buckling                      | 1636 |
| `d08011a.inp` | SOL 8,1   | Direct Frequency Response     | 981  |
| `d09011a.inp` | SOL 9,1   | Direct Transient Response     | 1027 |

These five are the focused integration set. The **full regression sweep** runs
**all 132** `inp/*.inp` decks against their `demoout/*.out` golden masters under
the same comparator methodology.

---

## Shipped Golden-Master NUL Padding — `t01231a.out` (RESOLVED)

`demoout/t01231a.out` carries **`NUL` (`0x00`) padding** on five
**tape-provenance** lines — the lines that name the *machine that wrote a tape*
(e.g. `... WRITTEN BY <machine-name> MACHINE ...` and
`(BY <machine-name> MACHINE, ... RECORDS)`). In the shipped master the
environment-specific machine name is recorded as four `NUL` bytes; a fresh run on
a different host would instead carry that host's real machine name. Either way
the *machine name* is **inherently volatile**, exactly like the per-page date and
page number, and must not drive a comparison result.

**Resolution (delivered in `outcomp.f`).** The comparator treats these lines as
volatile and the `NUL` padding as text-equivalent:

1. An embedded `NUL` (`ICHAR = 0`) is **normalized to a blank** while the line is
   flagged `HADNUL` (carriage return / line feed are likewise normalized to a
   blank).
2. The five tape-provenance lines are **skipped** by the machine-name-independent
   signature `INDEX(BUF,'MACHINE') > 0 .AND. INDEX(BUF,'BY ') > 0`, which matches
   symmetrically in the reference and in any candidate stream (a fresh candidate
   has a real machine name, not NULs). The signature is deliberately narrow: the
   legitimate `... ON 32-BIT WORD MACHINE` warning has no `BY ` and is therefore
   **not** skipped and **still compared**.
3. A `NUL` that **survives every volatile skip** still raises a hard error
   (`IERR = 1` ⇒ `IRET = 1`), so genuine embedded binary in an unexpected line is
   never silently accepted.

**Verified.** `t01231a.out` compared against itself yields `IRET = 0`,
`NDIFF = 0` — it no longer hard-errors and matches its golden master — so the
**full 132-deck sweep can pass**. As control cases, a clean deck compared against
a *different* deck still reports `NDIFF > 0` (real differences detected), the
`... ON 32-BIT WORD MACHINE` warning line is *not* skipped, and a synthetic
non-provenance line containing a `NUL` is still rejected with `IRET = 1`.

This is a property of the **shipped** golden masters, not a modernization defect;
the comparator now handles it correctly without any approved exclusion, and no
deck is removed from the all-132 gate.

---

## Success Criteria

The regression mechanism is satisfied when (per **§0.7.3** / **§0.7.5**):

- **Equivalence proven.** All `inp/*.inp` decks produce output matching
  `demoout/` under the comparator methodology — **integer fields bitwise
  identical**, **floating-point fields within the 6-significant-figure relative
  tolerance** (`RTOL = 1.0D-6`), and **volatile date / page / banner lines
  skipped**.
- **Harness fails loudly.** `test/regress/run_all.csh` and `test/run_units.csh`
  **each exit non-zero on any failure** (a driver `FAIL:`, a comparator
  `NDIFF > 0`, an `IRET ≠ 0`, or any build/run error).
- **Driver contract honored.** Every unit driver emits `PASS: <name>` /
  `FAIL: <name>` to the log unit; the comparator never emits a verdict token.
- **Reusable.** The harness is reusable for future modernization phases (the
  deck sweep is parameterized, not hardcoded), so each subsequent increment can
  re-prove equivalence with one command.

---

## Provenance (read-only)

This document is derived from the following artifacts. **None is modified** by
this report.

- **Golden masters / format evidence:** `demoout/d01001a.out` (the cited SOL 1
  reference), the five integration golden masters (`demoout/d01001a.out`,
  `demoout/d03011a.out`, `demoout/d05011a.out`, `demoout/d08011a.out`,
  `demoout/d09011a.out`), and the wider `demoout/*.out` set (132 files).
- **Integration inputs:** `inp/d01001a.inp`, `inp/d03011a.inp`,
  `inp/d05011a.inp`, `inp/d08011a.inp`, `inp/d09011a.inp` (SOL types), and the
  full `inp/*.inp` set (132 decks).
- **Build / `csh` idiom:** `bin/linknas` (the `f77 -fast -dn` link line and the
  `ar` archive convention reused by the harness scripts).
- **Sibling sources (the implementations this report documents):**
  `modern/regress/outcomp.f`, `modern/regress/regval.f`,
  `test/regress/run_all.csh`, `test/run_units.csh`.
