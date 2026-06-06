# NASTRAN-95 Modernization — Pre-Implementation Analysis

> **Authored-first deliverable.** Per the project rules (AAP §0.7.6), this document is written **before any `.f` source file** anywhere in `modern/` or `test/`. Every downstream report (`init_`, `state_`, `dispatch_`, `regression_validation_`, `final_modernization_summary`) and every FORTRAN source unit consumes the inventories established here. **All facts in this document were extracted by direct inspection of the frozen APR.95 repository**; no value is assumed or invented, and the full `MODX` table in Section C was regenerated programmatically from the frozen `mis/xsem00.f`.

> **Refactor framing — encapsulation/modularity only.** This is an **encapsulation and code-structure refactor**, *not* a rewrite, a performance optimization, or a technology migration. The code remains fixed-form FORTRAN 77 compiled by the Solaris `f77 -fast -dn` toolchain. **Bit-for-bit numerical equivalence is mandatory.** Nothing in the legacy solver is changed except two files owned by the `bin/` agent: a single one-line insert in `bin/nastrn.f` (`CALL NASTINIT` after `CALL DBMINT` `[bin/nastrn.f:L44]`) and build-graph edits in `bin/linknas`. The 39 `bd/` `BLOCK DATA` units, the nine `*.COM` headers, and the dispatch ladder in `mis/xsem00.f` all remain physically present, unmodified, and fully functional.

## Purpose and Scope

This analysis is the foundational inventory for modernizing the three highest-risk maintainability mechanisms of NASTRAN-95: (1) link-line-dependent `BLOCK DATA` initialization, (2) COMMON-block global state, and (3) the OSCAR computed-`GO TO` dispatch ladder. It catalogues, with file/line provenance:

- **Section A** — the complete `bd/` `BLOCK DATA` inventory with COMMON-block / variable mapping.
- **Section B** — the complete per-header COMMON-block variable inventory for the nine `*.COM` files.
- **Section C** — the full `MODX` → entry-point dispatch mapping (217 codes) extracted from the frozen `mis/xsem00.f`.
- **Section D** — the five integration-test input decks with their solution-sequence (`SOL`) types.
- **Section E** — the critical analytical finding: which `bd/` COMMON blocks are reachable through the nine headers and which are not.
- **Section F** — cross-cutting constraints and open flags that condition all downstream work.

All paths are relative to the repository root `[/tmp/blitzy/blitzy-NASTRAN-95/master_fc613b]`. File references are cited in backticks with line numbers where applicable.

## Table of Contents

1. [Purpose and Scope](#purpose-and-scope)
2. [Section A: bd/ BLOCK DATA Inventory](#section-a-bd-block-data-inventory)
3. [Section B: Per-Header COMMON-Block Inventory](#section-b-per-header-common-block-inventory)
4. [Section C: MODX Dispatch Mapping](#section-c-modx-dispatch-mapping)
5. [Section D: Five Integration-Test Inputs](#section-d-five-integration-test-inputs)
6. [Section E: Header-Unreachable bd/ COMMONs](#section-e-header-unreachable-bd-commons)
7. [Section F: Cross-Cutting Constraints and Open Flags](#section-f-cross-cutting-constraints-and-open-flags)

---

## Section A: bd/ BLOCK DATA Inventory

**Headline fact: the `bd/` directory contains 40 `.f` files but exactly 39 `BLOCK DATA` units.** The single outlier is **`bd/ferfbd.f`, which is `SUBROUTINE FERFBD(V1,V2,V3,VB)`** `[bd/ferfbd.f:L1]` — a modified FRBK2 (forward-backward substitution) solver routine, **not** a `BLOCK DATA` unit, and **not** on the `bin/linknas` link line.

**Why the 39-vs-40 distinction matters.** Fortran linkers do not auto-pull a `BLOCK DATA` unit from an archive, because nothing *references* its symbols — a `BLOCK DATA` only seeds named COMMON at load time and exports no callable entry point. Consequently `bin/linknas` must **explicitly `ar x`-extract and name all 39 `BLOCK DATA` objects on the `f77` link line** `[bin/linknas:L2-L20]`; otherwise their `DATA` values would never be loaded. By contrast, `ferfbd.o` is a normal referenced subroutine: it is pulled automatically when the linker resolves a `CALL FERFBD`, so it is correctly excluded from the explicit list of 39. Direct verification confirms the link line names exactly the 39 `BLOCK DATA` objects and that `ferfbd.o` appears nowhere in `bin/linknas`.

### A.1 The 39 BLOCK DATA units

The following table lists all 39 `BLOCK DATA` units with their source-line count, the number of `EQUIVALENCE` statements, and the named COMMON block(s) each `DATA`-initializes. (Values verified by direct inspection of `bd/*.f`.)

| Unit (`.f`) | Lines | EQUIV | COMMON block(s) DATA-initialized |
|-------------|------:|------:|----------------------------------|
| `dpdcbd.f` | 74 | 0 | `/DPDCOM/` |
| `exiobd.f` | 71 | 0 | `/EXIO2F/`, `/EXIO2P/` |
| `flbbd.f` | 36 | 0 | `/FLBFIL/` |
| `gp3bd.f` | 93 | 0 | `/GP3COM/` |
| `gptabd.f` | 548 | 4 | `/CLSTRS/`, `/GPTA1/` |
| `ifp3bd.f` | 126 | 0 | `/IFP3CM/` |
| `ifx1bd.f` | 247 | 0 | `/IFPX0/`, `/IFPX1/` |
| `ifx2bd.f` | 99 | 0 | `/IFPX2/` |
| `ifx3bd.f` | 84 | 0 | `/IFPX3/` |
| `ifx4bd.f` | 84 | 0 | `/IFPX4/` |
| `ifx5bd.f` | 84 | 0 | `/IFPX5/` |
| `ifx6bd.f` | 83 | 0 | `/IFPX6/` |
| `ifx7bd.f` | 235 | 0 | `/IFPX7/` |
| `itembd.f` | 92 | 1 | `/ITEMDT/` |
| `of1pbd.f` | 58 | 0 | `/OFPB1/` |
| `of2pbd.f` | 114 | 0 | `/OFPB2/` |
| `of3pbd.f` | 58 | 0 | `/OFPB3/` |
| `of3sbd.f` | 61 | 0 | `/OFPB3S/` |
| `of4pbd.f` | 113 | 0 | `/OFPB4/` |
| `of5pbd.f` | 58 | 0 | `/OFPB5/` |
| `of6pbd.f` | 110 | 0 | `/OFPB6/` |
| `of7pbd.f` | 58 | 0 | `/OFPB7/` |
| `of7sbd.f` | 61 | 0 | `/OFPB7S/` |
| `of8pbd.f` | 108 | 0 | `/OFPB8/` |
| `of9pbd.f` | 88 | 0 | `/OFPB9/` |
| `ofp1bd.f` | 499 | 0 | `/OFPBD1/` |
| `ofp5bd.f` | 182 | 0 | `/OFPBD5/` |
| `ofsnbd.f` | 15 | 0 | `/OFSN1/` |
| `ofssbd.f` | 10 | 0 | `/OFSS1/` |
| `pla4bd.f` | 43 | 0 | `/PLA42C/` |
| `plotbd.f` | 263 | 3 | `/CHAR94/`, `/CHRDRW/`, `/DRWAXS/`, `/PLTDAT/`, `/PLTSCR/`, `/SYMBLS/`, `/XXPARM/` |
| `readbd.f` | 31 | 0 | `/GIVN/`, `/INVPWX/`, `/REGEAN/` |
| `sdr2bd.f` | 67 | 1 | `/SDR2X1/`, `/SDR2X2/`, `/SDR2X4/` |
| `semdbd.f` | 757 | 1 | **PRINCIPAL (31 blocks):** `/BITPOS/`, `/BLANK/`, `/GINOX/`, `/LHPWX/`, `/MACHIN/`, `/MSGX/`, `/NAMES/`, `/NTIME/`, `/NUMTPX/`, `/OSCENT/`, `/OUTPUT/`, `/SEM/`, `/SOFCOM/`, `/STAPID/`, `/STIME/`, `/SYSTEM/`, `/TWO/`, `/TYPE/`, `/XCEITB/`, `/XDPL/`, `/XECHOX/`, `/XFIAT/`, `/XFIST/`, `/XLINK/`, `/XMDMSK/`, `/XMSSG/`, `/XPFIST/`, `/XREADX/`, `/XVPS/`, `/XXFIAT/`, `/XXREAD/` |
| `sma1bd.f` | 37 | 0 | `/SMA1BK/`, `/SMA1CL/`, `/SMA1DP/`, `/SMA1ET/`, `/SMA1IO/` |
| `sma2bd.f` | 30 | 0 | `/SMA2BK/`, `/SMA2CL/`, `/SMA2ET/`, `/SMA2IO/` |
| `ta1abd.f` | 27 | 0 | `/TA1ACM/` |
| `tabfbd.f` | 182 | 22 | `/TABFTX/` (22 `EQUIVALENCE` lines — the most of any unit) |
| `vdrbd.f` | 43 | 0 | `/VDRCOM/` |

> **Note on `semdbd.f` size.** Direct inspection (`wc -l` and an `awk 'END{print NR}'` line count) shows `bd/semdbd.f` is **757 lines**; that verified figure is used consistently throughout this document. `semdbd.f` is the principal `BLOCK DATA` unit: it seeds machine/system configuration including the `/SYSTEM/` cells (canonical layout `SYSBUF,OUTTAP,NOGO,INTP,...` at `[bd/semdbd.f:L220-L226+]`).

### A.2 Variable-level example (COMMON / variable mapping)

The canonical pattern is `bd/dpdcbd.f`, the dynamics-pool distributor. It declares `COMMON/DPDCOM/DPOOL,GPL,SIL,USET,...` `[bd/dpdcbd.f:L19-L25]` and populates the cells by `DATA`:

- **Input files:** `DATA DPOOL/101/, GPL/102/, SIL/103/, USET/104/` `[bd/dpdcbd.f:L29]`.
- **Output files:** `GPLD/201/ ... SDT/212/` (the `201–212` band) `[bd/dpdcbd.f:L33-L35]`.
- **Scratch files:** `DATA SCR1/301/, SCR2/302/, SCR3/303/, SCR4/304/` `[bd/dpdcbd.f:L39]`.
- **DMAP card-data tables:** `EPOINT`, `SEQEP`, `LOADS`, `NOLIN`, `TIC`, `TSTEP`, `TF`, `EIGR/EIGB/EIGC`, etc. `[bd/dpdcbd.f:L43-L68]`.
- **Module name tag:** `DATA NAM/4HDPD ,4H    /` `[bd/dpdcbd.f:L73]`.

This file/cell-number convention (inputs `101+`, outputs `201+`, scratch `301+`, name tags as Hollerith `4H...`) recurs across the pool-distributor and OFP `BLOCK DATA` units and is the kind of value `modern/init/blkinit.f` must reproduce bitwise.

### A.3 Order-independence (basis of the A1 decision)

`BLOCK DATA` semantics are **order-independent**: every `DATA` value is placed into its named COMMON **at load time**, with **no inter-unit runtime sequencing** and no read-before-write coupling between units. Each of the 39 units initializes a *distinct* set of named COMMON blocks. This load-time, order-free property is the analytical basis for the **A1 decision** (recorded in `init_modernization_report.md`): an explicit, inspectable, hardcoded initialization sequence in `modern/init/` is sufficient and correct — a full topological-sort engine would be over-engineering for a problem that has no genuine runtime ordering dependency.

---

## Section B: Per-Header COMMON-Block Inventory

The modern layer reaches global state **exclusively** through `INCLUDE` of the existing nine `*.COM` headers — it declares no new COMMON and adds no new `EQUIVALENCE`. The COMMON block(s) each header declares (verified) are:

| Header | COMMON block(s) declared |
|--------|--------------------------|
| `bin/NASNAMES.COM` | `/DOSNAM/`, `/DSNAME/` |
| `mds/NASNAMES.COM` | `/DOSNAM/`, `/DSNAME/` (identical to `bin/NASNAMES.COM`) |
| `mds/DSIOF.COM` | `/DBM/`, `/DSDEVC/`, `/DSIO/`, `/DSNAME/`, `/FCB/` |
| `mds/GINOX.COM` | `/GINOX/` |
| `mds/PAKBLK.COM` | `/PAKBLK/` |
| `mds/XNSTRN.COM` | `/ZZZZZZ/` (declared as `IBASE(700000)`) |
| `mds/ZZZZZZ.COM` | `/ZZZZZZ/` (declared as `MEM(10)`) |
| `mis/MMACOM.COM` | `/MMACOM/` |
| `mis/SMCOMX.COM` | `/SMCOMX/`, `/SMCOMY/`, `/SYSTEM/`, `/SFACT/`, `/STURMX/` |

**Header-reachable COMMON union = 15 distinct blocks:** `DBM`, `DOSNAM`, `DSDEVC`, `DSIO`, `DSNAME`, `FCB`, `GINOX`, `MMACOM`, `PAKBLK`, `SFACT`, `SMCOMX`, `SMCOMY`, `STURMX`, `SYSTEM`, `ZZZZZZ`.

### B.1 Key variable-level layouts

These drive the accessor (`stateacc.f`) and dispatcher (`disptbl.f`) work:

- **`bin/NASNAMES.COM`** `[L1-L8]`: `COMMON /DOSNAM/ DIRTRY,RFDIR,INPUT,OUTPUT,LOG,PUNCH,PLOT,NPTP,DIC,OPTP,RDIC,IN12,OUT11,INP1,INP2` — 15 names, all `CHARACTER*72`; `COMMON /DSNAME/ DSNAMES(89)` with `CHARACTER*80 DSNAMES`.
- **`mds/DSIOF.COM`** `[L1-L22]`: `/DSIO/` (includes `LCW,LWORDS,NWORDS,MAXDSN,NBUFF`), `/DBM/` (includes `NBLOCK,MAXBLK,IDBLEN,IDBADR,LENOPC`), `/DSNAME/` here named `MDSNAM(MAXFCB)` with `CHARACTER*80` and `MAXFCB=89` (the **same** block as `NASNAMES`' `DSNAMES`, under a different name), `/DSDEVC/ NUMDEV,DEV(10)`, and `INTEGER FCB; COMMON /FCB/ FCB(17,MAXFCB)` → `FCB(17,89)`.
- **`mds/GINOX.COM`** `[L1-L3]`: `COMMON /GINOX/ LGINOX, IDSLIM, MDSFCB(3,NUMFCB), LENSOF(NUMSOF)` with `NUMFCB=89, NUMSOF=10` → `LGINOX,IDSLIM,MDSFCB(3,89),LENSOF(10)`.
- **`mis/SMCOMX.COM`** `[L1-L21]`: `/SMCOMX/ NCOL,IERROR,IVWRDS,...,MBLK(15),MOBLK(15)`; `/SMCOMY/ DAJJR,DAJJI,AJJR,AJJI`; `/SYSTEM/ ISYSBF,NOUT,DUM1(37),NBPW,DUM2(14),ISPREC`; `/SFACT/ MCB(7),LLL(7),DBC(7),...`; `/STURMX/ STURM,SHFTPT,KEEP,PTSHFT,NR`.

### B.2 Three name/layout conflicts the modern code must navigate

These conflicts are surfaced here and re-stated in the state and dispatch reports:

1. **`/DSNAME/` — one block under two names.** It is `DSNAMES(89)` in `NASNAMES.COM` `[bin/NASNAMES.COM:L7]` but `MDSNAM(89)` in `DSIOF.COM` `[mds/DSIOF.COM:L13]`. The two headers must **never be combined in one program unit** (the same storage would be declared twice under different names).
2. **`/ZZZZZZ/` — conflicting layouts.** `IBASE(700000)` in `mds/XNSTRN.COM:L1` vs `MEM(10)` in `mds/ZZZZZZ.COM:L1`, plus a third, inline open-core layout `IZ(14000000)` in `bin/nastrn.f:L12`. These are mutually exclusive views of the same open-core block.
3. **`/SYSTEM/` — three layouts.** The `SMCOMX.COM` window `ISYSBF,NOUT,DUM1(37),NBPW,DUM2(14),ISPREC` `[mis/SMCOMX.COM:L16-L17]`; the canonical `bd/semdbd.f` layout `SYSBUF,OUTTAP,NOGO,INTP,...` `[bd/semdbd.f:L220+]`; and the bootstrap layout `ISYSTM(94),SPERLK` in `bin/nastrn.f:L8`. **Among the nine headers, `/SYSTEM/` is declared in `mis/SMCOMX.COM` only.**

---

## Section C: MODX Dispatch Mapping

This section maps the legacy executive dispatch in the **frozen** `mis/xsem00.f` (read-only reference; 761 lines).

### C.1 The legacy mechanism

`mis/xsem00.f` decodes the OSCAR operation code with `MODX = RSHIFT(INOSCR(3),16)` `[mis/xsem00.f:L182]`, performs a **single** pre-dispatch wall-clock check `CALL TMTOGO (KTIME)` `[mis/xsem00.f:L196]` immediately followed by `IF (KTIME.LE.0 .AND. WORDB(2).NE.EXIT) CALL MESAGE (-50,0,WORDB(2))` `[mis/xsem00.f:L197-L198]`, and then branches through a **22-stage cascading computed-`GO TO` ladder** spanning `MODX` 1–217 `[mis/xsem00.f:L262-L761]`. Each stage has the shape:

```
IF ( MODX .GE. 1 .AND. MODX .LE. 10 ) GO TO (l1,...,l10), MODX
MODX = MODX - 10
```

so the 22 stages partition `MODX` into the bands 1–10, 11–20, …, 211–217. Dispatch targets follow the label convention **`label = 2000 + MODX`** (e.g. `MODX 3` → label `2003`), while the three link-spec error codes branch to the shared fatal label `940`.

### C.2 Authoritative, reconciled coverage counts

These counts were regenerated programmatically from the frozen source and **must** match `test/dispatch/tdscnt.ref`:

- **`MODX` range: 1–217 (217 total codes).**
- **193 CALL dispatch slots** routing to **188 distinct module subroutines.**
- **21 RESERVED `CONTINUE` no-op slots.**
- **3 FATAL slots** (link-spec error). **193 + 21 + 3 = 217 ✓.**

Enumerated precisely:

- **FATAL (3):** `MODX` **1, 2, 4** → shared label `940` (`940 CONTINUE; WRITE(NOUT,991) KODE` → system fatal message 1006, `CALL MESAGE(-37,0,SUBNAM)`). These are codes with no module in this link.
- **RESERVED `CONTINUE` no-op (21):** `MODX` = {**25, 36, 41, 49, 61, 74, 84, 94, 102, 113, 123, 132, 140, 143, 153, 157, 163, 172, 187, 202, 213**} — each a bare `NNNN CONTINUE` that falls through to `GO TO 10`.
- **Only reused subroutine — `XCEI` (dispatched 6×):** `MODX` **5, 6, 7, 11, 12, 13** all `CALL XCEI`. All other 187 distinct subroutines are dispatched exactly once. (193 CALL slots − 5 `XCEI` duplicates = **188 distinct**.)
- **Special case — `MODX` 43:** label `2043` executes `LINKNO = LINKNM(8)`, then `CALL EMG`, then restores `LINKNO = LINKNM(1)` `[mis/xsem00.f:L409-L412]`. `EMG` is one of the 188 distinct subroutines; this row is counted as a CALL.

### C.3 The 188-vs-189 discrepancy (explicitly flagged)

The AAP narrative cites "≈190" / "189 distinct subroutines"; the **verified** count is **188**. The "189" is a **comment-induced overcount**. A naive `grep`/regex for `CALL <name>` matches the token `CALL EMG1B` inside the **comment** line `[mis/xsem00.f:L408]`:

```
C         SET LINKNO TO FLAG SUBROUTINE SMA1B TO CALL EMG1B
```

`EMG1B` is invoked **inside** `SMA1B`, not by the ladder, and is **not** a dispatch target. The authoritative figure recorded here — and asserted by `dispval.f` / `tdscnt.ref` — is **188**.

### C.4 Extraction method (reproducibility)

The full 217-row table below was regenerated directly from `mis/xsem00.f` by the following deterministic procedure, so any maintainer can reproduce it:

1. Join fixed-form continuation lines (a non-blank, non-`0` character in column 6 continues the prior statement); skip comment lines (`C`/`c`/`*` in column 1).
2. Collect the 22 computed-`GO TO` label tuples in order; the *k*-th label of stage *s* maps `MODX = 10·(s−1) + k` to that label.
3. For each target label, read the statement at that label: a leading `CALL <name>` → **CALL** (target `<name>`); a bare `CONTINUE` → **RESERVED no-op**; label `940` → **FATAL**; the `MODX 43` `LINKNO`-guarded `CALL EMG` → **CALL** (`EMG`).

The table is consistent with these seeded, independently-checked rows: `1→940 FATAL`, `2→940 FATAL`, `3→2003 XCHK`, `4→940 FATAL`, `5→2005 XCEI`, `6→2006 XCEI`, `7→2007 XCEI`, `8→2008 XSAVE`, `9→2009 XPURGE`, `10→2010 XEQUIV`, `11→2011 XCEI`, `12→2012 XCEI`, `13→2013 XCEI`, `14→2014 DADD`, `15→2015 DADD5`, `16→2016 AMG`, `17→2017 AMP`, `18→2018 APD`, `19→2019 BMG`, `25→2025 CONTINUE (RESERVED)`, `42→2042 EMA1`, `43→2043 EMG (special)`, `44→2044 FA1`, `213→2213 CONTINUE (RESERVED)`, `214→2214 QPARMD`, `215→2215 GINOFL`, `216→2216 DBASE`, `217→2217 NORMAL`.

### C.5 Full MODX → label → target table (217 rows)

The public `CALL` interfaces of every dispatched module are **preserved verbatim** — the modern dispatcher (`modern/dispatch/disptbl.f`) invokes them exactly as the legacy ladder does, with `MODX` passed in as an argument and never re-extracted. `mis/xsem00.f` itself is **FROZEN** (read-only reference; never edited).

| `MODX` | Label | Target | Kind |
|-------:|:-----:|--------|------|
| 1 | 940 | *(none — link-spec error)* | FATAL |
| 2 | 940 | *(none — link-spec error)* | FATAL |
| 3 | 2003 | `XCHK` | CALL |
| 4 | 940 | *(none — link-spec error)* | FATAL |
| 5 | 2005 | `XCEI` | CALL |
| 6 | 2006 | `XCEI` | CALL |
| 7 | 2007 | `XCEI` | CALL |
| 8 | 2008 | `XSAVE` | CALL |
| 9 | 2009 | `XPURGE` | CALL |
| 10 | 2010 | `XEQUIV` | CALL |
| 11 | 2011 | `XCEI` | CALL |
| 12 | 2012 | `XCEI` | CALL |
| 13 | 2013 | `XCEI` | CALL |
| 14 | 2014 | `DADD` | CALL |
| 15 | 2015 | `DADD5` | CALL |
| 16 | 2016 | `AMG` | CALL |
| 17 | 2017 | `AMP` | CALL |
| 18 | 2018 | `APD` | CALL |
| 19 | 2019 | `BMG` | CALL |
| 20 | 2020 | `CASE` | CALL |
| 21 | 2021 | `CYCT1` | CALL |
| 22 | 2022 | `CYCT2` | CALL |
| 23 | 2023 | `CEAD` | CALL |
| 24 | 2024 | `CURV` | CALL |
| 25 | 2025 | *(reserved no-op)* | RESERVED no-op |
| 26 | 2026 | `DDR` | CALL |
| 27 | 2027 | `DDR1` | CALL |
| 28 | 2028 | `DDR2` | CALL |
| 29 | 2029 | `DDRMM` | CALL |
| 30 | 2030 | `DDCOMP` | CALL |
| 31 | 2031 | `DIAGON` | CALL |
| 32 | 2032 | `DPD` | CALL |
| 33 | 2033 | `DSCHK` | CALL |
| 34 | 2034 | `DSMG1` | CALL |
| 35 | 2035 | `DSMG2` | CALL |
| 36 | 2036 | *(reserved no-op)* | RESERVED no-op |
| 37 | 2037 | `DUMOD1` | CALL |
| 38 | 2038 | `DUMOD2` | CALL |
| 39 | 2039 | `DUMOD3` | CALL |
| 40 | 2040 | `DUMOD4` | CALL |
| 41 | 2041 | *(reserved no-op)* | RESERVED no-op |
| 42 | 2042 | `EMA1` | CALL |
| 43 | 2043 | `EMG` *(special: `LINKNO=LINKNM(8)`; `CALL EMG`; `LINKNO=LINKNM(1)`)* | CALL |
| 44 | 2044 | `FA1` | CALL |
| 45 | 2045 | `FA2` | CALL |
| 46 | 2046 | `DFBS` | CALL |
| 47 | 2047 | `FRLG` | CALL |
| 48 | 2048 | `FRRD` | CALL |
| 49 | 2049 | *(reserved no-op)* | RESERVED no-op |
| 50 | 2050 | `GI` | CALL |
| 51 | 2051 | `GKAD` | CALL |
| 52 | 2052 | `GKAM` | CALL |
| 53 | 2053 | `GP1` | CALL |
| 54 | 2054 | `GP2` | CALL |
| 55 | 2055 | `GP3` | CALL |
| 56 | 2056 | `GP4` | CALL |
| 57 | 2057 | `GPCYC` | CALL |
| 58 | 2058 | `GPFDR` | CALL |
| 59 | 2059 | `DUMOD5` | CALL |
| 60 | 2060 | `GPWG` | CALL |
| 61 | 2061 | *(reserved no-op)* | RESERVED no-op |
| 62 | 2062 | `INPUT` | CALL |
| 63 | 2063 | `INPTT1` | CALL |
| 64 | 2064 | `INPTT2` | CALL |
| 65 | 2065 | `INPTT3` | CALL |
| 66 | 2066 | `INPTT4` | CALL |
| 67 | 2067 | `MATGEN` | CALL |
| 68 | 2068 | `MATGPR` | CALL |
| 69 | 2069 | `MATPRN` | CALL |
| 70 | 2070 | `PRTINT` | CALL |
| 71 | 2071 | `MCE1` | CALL |
| 72 | 2072 | `MCE2` | CALL |
| 73 | 2073 | `MERGE1` | CALL |
| 74 | 2074 | *(reserved no-op)* | RESERVED no-op |
| 75 | 2075 | `MODA` | CALL |
| 76 | 2076 | `MODACC` | CALL |
| 77 | 2077 | `MODB` | CALL |
| 78 | 2078 | `MODC` | CALL |
| 79 | 2079 | `DMPYAD` | CALL |
| 80 | 2080 | `MTRXIN` | CALL |
| 81 | 2081 | `OFP` | CALL |
| 82 | 2082 | `OPTPR1` | CALL |
| 83 | 2083 | `OPTPR2` | CALL |
| 84 | 2084 | *(reserved no-op)* | RESERVED no-op |
| 85 | 2085 | `OUTPT` | CALL |
| 86 | 2086 | `OUTPT1` | CALL |
| 87 | 2087 | `OUTPT2` | CALL |
| 88 | 2088 | `OUTPT3` | CALL |
| 89 | 2089 | `OUTPT4` | CALL |
| 90 | 2090 | `QPARAM` | CALL |
| 91 | 2091 | `PARAML` | CALL |
| 92 | 2092 | `QPARMR` | CALL |
| 93 | 2093 | `PARTN1` | CALL |
| 94 | 2094 | *(reserved no-op)* | RESERVED no-op |
| 95 | 2095 | `MRED1` | CALL |
| 96 | 2096 | `MRED2` | CALL |
| 97 | 2097 | `CMRD2` | CALL |
| 98 | 2098 | `PLA1` | CALL |
| 99 | 2099 | `PLA2` | CALL |
| 100 | 2100 | `PLA3` | CALL |
| 101 | 2101 | `PLA4` | CALL |
| 102 | 2102 | *(reserved no-op)* | RESERVED no-op |
| 103 | 2103 | `DPLOT` | CALL |
| 104 | 2104 | `DPLTST` | CALL |
| 105 | 2105 | `PLTTRA` | CALL |
| 106 | 2106 | `PRTMSG` | CALL |
| 107 | 2107 | `PRTPRM` | CALL |
| 108 | 2108 | `RANDOM` | CALL |
| 109 | 2109 | `RBMG1` | CALL |
| 110 | 2110 | `RBMG2` | CALL |
| 111 | 2111 | `RBMG3` | CALL |
| 112 | 2112 | `RBMG4` | CALL |
| 113 | 2113 | *(reserved no-op)* | RESERVED no-op |
| 114 | 2114 | `REIG` | CALL |
| 115 | 2115 | `RMG` | CALL |
| 116 | 2116 | `SCALAR` | CALL |
| 117 | 2117 | `SCE1` | CALL |
| 118 | 2118 | `SDR1` | CALL |
| 119 | 2119 | `SDR2` | CALL |
| 120 | 2120 | `SDR3` | CALL |
| 121 | 2121 | `SDRHT` | CALL |
| 122 | 2122 | `SEEMAT` | CALL |
| 123 | 2123 | *(reserved no-op)* | RESERVED no-op |
| 124 | 2124 | `SETVAL` | CALL |
| 125 | 2125 | `SMA1` | CALL |
| 126 | 2126 | `SMA2` | CALL |
| 127 | 2127 | `SMA3` | CALL |
| 128 | 2128 | `SMP1` | CALL |
| 129 | 2129 | `SMP2` | CALL |
| 130 | 2130 | `SMPYAD` | CALL |
| 131 | 2131 | `SOLVE` | CALL |
| 132 | 2132 | *(reserved no-op)* | RESERVED no-op |
| 133 | 2133 | `SSG1` | CALL |
| 134 | 2134 | `SSG2` | CALL |
| 135 | 2135 | `SSG3` | CALL |
| 136 | 2136 | `SSG4` | CALL |
| 137 | 2137 | `SSGHT` | CALL |
| 138 | 2138 | `TA1` | CALL |
| 139 | 2139 | `TABPCH` | CALL |
| 140 | 2140 | *(reserved no-op)* | RESERVED no-op |
| 141 | 2141 | `TABFMT` | CALL |
| 142 | 2142 | `TABPT` | CALL |
| 143 | 2143 | *(reserved no-op)* | RESERVED no-op |
| 144 | 2144 | `TIMTST` | CALL |
| 145 | 2145 | `TRD` | CALL |
| 146 | 2146 | `TRHT` | CALL |
| 147 | 2147 | `TRLG` | CALL |
| 148 | 2148 | `DTRANP` | CALL |
| 149 | 2149 | `DUMERG` | CALL |
| 150 | 2150 | `DUPART` | CALL |
| 151 | 2151 | `VDR` | CALL |
| 152 | 2152 | `VEC` | CALL |
| 153 | 2153 | *(reserved no-op)* | RESERVED no-op |
| 154 | 2154 | `XYPLOT` | CALL |
| 155 | 2155 | `XYPRPT` | CALL |
| 156 | 2156 | `XYTRAN` | CALL |
| 157 | 2157 | *(reserved no-op)* | RESERVED no-op |
| 158 | 2158 | `COMB1` | CALL |
| 159 | 2159 | `COMB2` | CALL |
| 160 | 2160 | `EXIO` | CALL |
| 161 | 2161 | `RCOVR` | CALL |
| 162 | 2162 | `EMFLD` | CALL |
| 163 | 2163 | *(reserved no-op)* | RESERVED no-op |
| 164 | 2164 | `RCOVR3` | CALL |
| 165 | 2165 | `REDUCE` | CALL |
| 166 | 2166 | `SGEN` | CALL |
| 167 | 2167 | `SOFI` | CALL |
| 168 | 2168 | `SOFO` | CALL |
| 169 | 2169 | `SOFUT` | CALL |
| 170 | 2170 | `SUBPH1` | CALL |
| 171 | 2171 | `PLTMRG` | CALL |
| 172 | 2172 | *(reserved no-op)* | RESERVED no-op |
| 173 | 2173 | `COPY` | CALL |
| 174 | 2174 | `SWITCH` | CALL |
| 175 | 2175 | `MPY3` | CALL |
| 176 | 2176 | `DDCMPS` | CALL |
| 177 | 2177 | `LODAPP` | CALL |
| 178 | 2178 | `GPSTGN` | CALL |
| 179 | 2179 | `EQMCK` | CALL |
| 180 | 2180 | `ADR` | CALL |
| 181 | 2181 | `FRRD2` | CALL |
| 182 | 2182 | `GUST` | CALL |
| 183 | 2183 | `IFT` | CALL |
| 184 | 2184 | `LAMX` | CALL |
| 185 | 2185 | `EMA` | CALL |
| 186 | 2186 | `ANISOP` | CALL |
| 187 | 2187 | *(reserved no-op)* | RESERVED no-op |
| 188 | 2188 | `GENCOS` | CALL |
| 189 | 2189 | `DDAMAT` | CALL |
| 190 | 2190 | `DDAMPG` | CALL |
| 191 | 2191 | `NRLSUM` | CALL |
| 192 | 2192 | `GENPAR` | CALL |
| 193 | 2193 | `CASEGE` | CALL |
| 194 | 2194 | `DESVEL` | CALL |
| 195 | 2195 | `PROLAT` | CALL |
| 196 | 2196 | `MAGBDY` | CALL |
| 197 | 2197 | `COMUGV` | CALL |
| 198 | 2198 | `FLBMG` | CALL |
| 199 | 2199 | `GFSMA` | CALL |
| 200 | 2200 | `TRAIL` | CALL |
| 201 | 2201 | `SCAN` | CALL |
| 202 | 2202 | *(reserved no-op)* | RESERVED no-op |
| 203 | 2203 | `PTHBDY` | CALL |
| 204 | 2204 | `VARIAN` | CALL |
| 205 | 2205 | `FVRST1` | CALL |
| 206 | 2206 | `FVRST2` | CALL |
| 207 | 2207 | `ALG` | CALL |
| 208 | 2208 | `APDB` | CALL |
| 209 | 2209 | `PROMPT` | CALL |
| 210 | 2210 | `OLPLOT` | CALL |
| 211 | 2211 | `INPTT5` | CALL |
| 212 | 2212 | `OUTPT5` | CALL |
| 213 | 2213 | *(reserved no-op)* | RESERVED no-op |
| 214 | 2214 | `QPARMD` | CALL |
| 215 | 2215 | `GINOFL` | CALL |
| 216 | 2216 | `DBASE` | CALL |
| 217 | 2217 | `NORMAL` | CALL |

---

## Section D: Five Integration-Test Inputs

Five benchmark decks are selected from the `inp/*.inp` corpus (**132 decks total**) to drive the `NASTRAN_DISPATCH_VALIDATE` cross-check in `dispval.f` and the regression flow in `regval.f`. Executive-control `APP`/`SOL` lines are confirmed in each deck, and the golden masters are confirmed present in `demoout/`.

| Deck (`inp/`) | APP | SOL | Solution type | Title | Golden master (`demoout/`) |
|---------------|-----|-----|---------------|-------|----------------------------|
| `d01001a.inp` | `DISP` | `SOL 1` | Static Analysis | "NASTRAN TITLEOPT=-1" | `d01001a.out` (279 lines) |
| `d03011a.inp` | `DISPLACEMENT` | `SOL 3,1` | Normal Modes / Real Eigenvalue | "VIBRATIONS OF A 10 BY 20 PLATE" | `d03011a.out` (1389 lines) |
| `d05011a.inp` | `DISPLACEMENT` | `SOL 5,1` | Buckling | "SYMMETRIC BUCKLING OF A CYLINDER" | `d05011a.out` (1636 lines) |
| `d08011a.inp` | `DISPLACEMENT` | `SOL 8,1` | Direct Frequency Response | "FREQUENCY RESPONSE OF A 10X10 PLATE" | `d08011a.out` (981 lines) |
| `d09011a.inp` | `DISPLACEMENT` | `SOL 9,1` | Direct Transient Response | "TRANSIENT ANALYSIS WITH DIRECT MATRIX INPUT" | `d09011a.out` (1027 lines) |

**Rationale.** These five span static, modal, buckling, frequency-response, and transient solution sequences — diverse rigid-format paths that exercise distinct `MODX` dispatch sequences, making them a strong cross-check set. (`d01001a` is a `NASTRAN TITLEOPT=-1` / `DIAG 48` demonstration deck whose `.out` banner echoes `NASTRAN TITLEOPT=-1` on line 1.) The full regression sweep in `test/regress/run_all.csh` still runs **all 132** `inp/*.inp` decks against `demoout/`.

> **Format note.** The `demoout/*.out` golden masters are classic line-printer OFP text with CRLF line endings and volatile per-page headers (date, page number, banner). The `outcomp.f` comparator therefore skips/normalizes those volatile lines, applies a 6-significant-figure relative tolerance to floating-point fields, and requires bitwise identity for integer fields.

---

## Section E: Header-Unreachable bd/ COMMONs

This is the headline analytical finding of the pre-implementation analysis.

Across the 39 `bd/` units there are **89 distinct COMMON blocks**. Of these, **only 2 are reachable through the nine `*.COM` headers** — **`/GINOX/` and `/SYSTEM/`** (both initialized by `bd/semdbd.f`). The remaining **87 `bd/` COMMON blocks are not declared in any of the nine headers** and are therefore **not `INCLUDE`-reachable**.

### E.1 Representative header-unreachable blocks (from Section A)

`/DPDCOM/`; the OFP page blocks `/OFPB1/`…`/OFPB9/`, `/OFPB3S/`, `/OFPB7S/`, `/OFPBD1/`, `/OFPBD5/`, `/OFSN1/`, `/OFSS1/`; the executive/SEM blocks `/SEM/`, `/XLINK/`, `/XFIST/`, `/XFIAT/`, `/XVPS/`, `/XPFIST/`, `/XXFIAT/`, `/XXREAD/`, `/XREADX/`, `/XECHOX/`, `/XDPL/`, `/XCEITB/`, `/XMDMSK/`, `/XMSSG/`; `/MACHIN/`, `/OUTPUT/`, `/OSCENT/`, `/BITPOS/`, `/BLANK/`, `/NAMES/`, `/NTIME/`, `/NUMTPX/`, `/STIME/`, `/STAPID/`, `/SOFCOM/`, `/TWO/`, `/TYPE/`, `/LHPWX/`; the structural-matrix blocks `/SMA1BK/`…`/SMA1IO/` (5) and `/SMA2BK/`…`/SMA2IO/` (4); `/GP3COM/`; `/IFPX0/`…`/IFPX7/` (8) and `/IFP3CM/`; `/ITEMDT/`, `/CLSTRS/`, `/GPTA1/`, `/TABFTX/`, `/VDRCOM/`, `/PLA42C/`, `/TA1ACM/`, `/EXIO2F/`, `/EXIO2P/`, `/FLBFIL/`, `/GIVN/`, `/INVPWX/`, `/REGEAN/`, `/SDR2X1/`, `/SDR2X2/`, `/SDR2X4/`; and the plot blocks `/CHAR94/`, `/CHRDRW/`, `/DRWAXS/`, `/PLTDAT/`, `/PLTSCR/`, `/SYMBLS/`, `/XXPARM/`.

### E.2 Consequence for the init layer

This finding (consumed by `init_modernization_report.md` and `blkinit.f`) means the explicit initializer can only reach **`/GINOX/` and `/SYSTEM/`** by `INCLUDE` — and even those two carry hazards:

- **`/GINOX/` name collision.** The `bd/semdbd.f` `/GINOX/` view differs from the `mds/GINOX.COM` layout `LGINOX,IDSLIM,MDSFCB(3,89),LENSOF(10)`; the two are **not** the same variable list, so `/GINOX/` must **not** be blindly written through `mds/GINOX.COM`.
- **`/SYSTEM/` clobber caution.** The `/SYSTEM/` machine cells are populated at bootstrap by `BTSTRP` and `DBMINT` `[bin/nastrn.f:L32,L44]`; the initializer must **not** clobber them.

Therefore the **87** header-unreachable blocks are **deferred and flagged for maintainer confirmation** in this phase. This analysis surfaces precisely which `bd/` COMMONs are `INCLUDE`-reachable (2) versus not (87), so maintainers can decide whether to introduce dedicated modern headers in a future phase. Deferring honors the hard rule **"zero new COMMON / zero new EQUIVALENCE outside an `INCLUDE`"** — the modern initializer adds no COMMON declaration of its own and only validates/writes the two header-reachable blocks with the cautions above.

---

## Section F: Cross-Cutting Constraints and Open Flags

These binding constraints condition all downstream work:

- **Message-code band.** `um/MSSG.TXT` documents functional-module messages under the heading "FUNCTIONAL MODULE MESSAGES (8001 THROUGH 9000)" `[um/MSSG.TXT:L5995]`; the highest **actually-assigned** id is **8015**, and **no id exists in 9001–9999** (the tokens `9000` and `9999` appear only in the band header and inside message *text* value-ranges, never as assigned ids). The **9001–9999 band is therefore free** for *emitted* (never registered) modern diagnostics. `um/MSSG.TXT` is **not** edited. Modern sub-band allocation: init & state validators use **9100–9199**; dispatch validation/log uses **9300–9399** (the dispatcher's unmapped-`MODX` fatal is code **`-9301`**).
- **Diagnostics destination.** All diagnostic output goes to **logical unit 3 only** (`LOUT = 3` `[bin/nastrn.f:L46]`) — never stdout, never a new unit. Every diagnostic/validator routine begins with the guard clause **`IF (IDIAG .EQ. 0) RETURN`** as its first executable statement ⇒ provably zero overhead when disabled.
- **Toggles (default unset = exact APR.95 behavior).** `NASTRAN_LEGACY_INIT` (bit 1), `NASTRAN_INIT_VALIDATE` (bit 2), `NASTRAN_DISPATCH_VALIDATE` (bit 4), `NASTRAN_DISPATCH_LOG` (bit 8). They are read via `GETENV`, mirroring the bootstrap idiom `[bin/nastrn.f:L31-L33]`. Rollback is a **configuration change with no recompilation** (unset or flip a variable).
- **Bootstrap insertion (owned by the `bin/` agent).** A single `CALL NASTINIT` is inserted immediately **after `CALL DBMINT` `[bin/nastrn.f:L44]`** and before `LOUT = 3` `[bin/nastrn.f:L46]` — the one and only permitted change to executable control flow.
- **`/SYSTEM/` / `KTIME` flag.** `KTIME` is **not** a named `/SYSTEM/` cell — it is the **output argument** of `CALL TMTOGO(KTIME)` `[mis/xsem00.f:L196]`. The `/SYSTEM/` block whose context the time check needs appears, among the nine headers, **only in `mis/SMCOMX.COM`**. The dispatcher therefore obtains `/SYSTEM/` through `SMCOMX.COM` (or a minimal inline `/SYSTEM/` declaration per NASTRAN's per-routine convention). **Flagged for maintainer confirmation.**
- **Build integration.** Every new `modern/**/*.f` (and unit-test driver object) compiles into `bin/nastlib.a` via an updated `bin/linknas`, which already `ar x`-extracts and explicitly names the 39 `bd/` `BLOCK DATA` objects on the `f77 -fast -dn` link line `[bin/linknas:L2-L20]`.

### Provenance (read-only references)

`bd/*.f` (39 `BLOCK DATA` + `ferfbd.f`); the nine `*.COM` headers (`bin/NASNAMES.COM`, `mds/NASNAMES.COM`, `mds/DSIOF.COM`, `mds/GINOX.COM`, `mds/PAKBLK.COM`, `mds/XNSTRN.COM`, `mds/ZZZZZZ.COM`, `mis/MMACOM.COM`, `mis/SMCOMX.COM`); `mis/xsem00.f` (frozen ladder); `inp/d0{1,3,5,8,9}*.inp` (decks + `SOL` types); `demoout/*.out` (golden masters); `um/MSSG.TXT` (message band); `bin/nastrn.f` (bootstrap / `GETENV` / `LOUT=3`); `bin/linknas` (build). **None are modified by this document.**
