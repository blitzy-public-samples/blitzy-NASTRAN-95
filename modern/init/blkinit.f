C=====================================================================
C     modern/init/blkinit.f
C---------------------------------------------------------------------
C     EXPLICIT, ORDERED MODERNIZATION INITIALIZER (SUBROUTINE BLKINIT)
C
C     Modern, explicit replacement for the implicit, link-line-
C     dependent BLOCK DATA pulling of the 39 legacy bd/ units.  It
C     reproduces -- explicitly and in a fixed, inspectable order --
C     the SAFE subset of the COMMON values seeded at load time by the
C     legacy bd/ BLOCK DATA units, reaching global state EXCLUSIVELY
C     through the existing *.COM INCLUDE headers.  It declares ZERO
C     new COMMON and ZERO new EQUIVALENCE.
C
C     Public signature (LOCKED cross-agent contract):
C         SUBROUTINE BLKINIT          -- no arguments
C     Invoked by modern/init/nastinit.f (CALL BLKINIT) and exercised
C     by the test/init drivers (tinblk.f, tinval.f).
C
C     Compiled fixed-form FORTRAN 77 by Sun/Solaris f77 -fast -dn into
C     bin/nastlib.a.  -dn (static storage) is fully compatible with
C     the constant assignments transcribed here.  bin/linknas (owned
C     by the bin/ agent) adds modern/init/blkinit.o to the archive and
C     link line; this file does NOT edit bin/linknas.
C=====================================================================
C
C     -----------------------------------------------------------------
C     A1 DECISION -- EXPLICIT HARDCODED ORDERED SEQUENCE (Candidate 1)
C     -----------------------------------------------------------------
C     This file IS the realization of AAP 0.6.1, A1 Candidate 1: an
C     explicit, hardcoded initialization sequence.  Candidate 2
C     (declarative dependency metadata resolved by a topological
C     traversal at startup) is deliberately NOT implemented.  The 39
C     bd/ units are order-independent PURE DATA initializers of
C     distinct named COMMON blocks; genuine read-before-write coupling
C     among them is nil, so a topological-sort engine would be over-
C     engineering that adds startup cost and new failure modes for a
C     problem that does not exist at runtime.  An explicit sequence is
C     deterministic, inspectable, zero-overhead, and trivially matches
C     the load-time BLOCK DATA semantics it mirrors.  The body below is
C     a fixed, commented, ascending-cell-ordered series of assignments
C     for the proven-safe /SYSTEM/ config subset, FOLLOWED BY the
C     generated, bitwise reproduction of the full R set (72 bd-DATA
C     blocks, 31316 words) via bdcopy.inc -- see MAINTAINER FLAG 2.
C
C     -----------------------------------------------------------------
C     WHY THIS IS CORRECT AND BIT-FOR-BIT SAFE (coexistence / duality)
C     -----------------------------------------------------------------
C     The 39 bd/ BLOCK DATA units REMAIN LINKED AND UNMODIFIED, so in
C     the real solver they still seed every COMMON at load time --
C     APR.95 numerical behavior is fully preserved regardless of what
C     BLKINIT does.  BLKINIT is therefore a COEXISTING explicit path
C     that serves two roles with the SAME code:
C       (i)  In the real solver it only IDEMPOTENTLY RE-AFFIRMS the
C            safe config cells -- it writes the identical values
C            already present from the linked bd/ units and NEVER
C            clobbers a machine constant -- so an unconfigured run
C            stays bit-identical to the unmodified APR.95 solver.
C            Rollback to legacy is a config change (NASTRAN_LEGACY_INIT
C            handled in nastinit.f); no recompilation.
C       (ii) In the unit-test executable -- where the BLOCK DATA
C            objects are NOT linked (a BLOCK DATA is not auto-pulled
C            from an archive) and COMMON starts zeroed -- BLKINIT
C            ACTIVELY POPULATES exactly those safe config cells so the
C            validator modern/init/initval.f reports NDIV = 0.
C
C     BTSTRP/DBMINT NON-CLOBBER PROOF (verifiable in mds/btstrp.f and
C     mds/dbmint.f).  BLKINIT runs (via NASTINIT) AFTER CALL BTSTRP and
C     CALL DBMINT in the bootstrap.  BTSTRP writes only /SYSTEM/ cells
C     {1,2,4,9,22,39,40,41,42,43,44,55,91,92} (by the EQUIVALENCEd
C     names SYSBUF,OUTTAP,INTP,NLPP,LINKNO,NBPC,NBPW,NCPW,IDATE(1..3),
C     IPREC,LPCH,LDICT); IDRUM (cell 34) is ONLY equivalenced, never
C     assigned.  DBMINT declares /SYSTEM/ as ISYSBF,IWR (cells 1,2) and
C     writes neither.  The 42 cells BLKINIT writes (9 non-zero goldens
C     {8,14,19,23,24,29,30,34,35} + 33 zero cells: DUM1 cells
C     {3,5,6,7,10,11,12,13,15,16,17,18,20,21,25,26,27,28,32,33,36,37,
C     38} and DUM2 cells {45-54}) have EMPTY intersection with the
C     BTSTRP set above and exclude machine HICORE(31), so every write
C     is provably BTSTRP/DBMINT-untouched and idempotent (bit-safe).
C
C     -----------------------------------------------------------------
C     INCLUDE-ONLY STATE ACCESS -- ZERO new COMMON, ZERO EQUIVALENCE
C     -----------------------------------------------------------------
C     Global state is reached ONLY through INCLUDE 'SMCOMX.COM' (file
C     mis/SMCOMX.COM), the ONLY one of the nine *.COM headers that
C     declares /SYSTEM/.  There is NO literal COMMON statement and NO
C     EQUIVALENCE statement anywhere in this file -- verifiable by
C     inspection.  The lone explicit type declaration (INTEGER DUM1)
C     types -- it does not create -- the COMMON array declared by the
C     header (see the DUM1-TYPE note at the SUBROUTINE below).
C
C     -----------------------------------------------------------------
C     /SYSTEM/ SAFE NON-MACHINE CONFIG CELLS WRITTEN (the lock-step set
C     that modern/init/initval.f must validate, identical values)
C     -----------------------------------------------------------------
C     SMCOMX.COM lays out /SYSTEM/ as
C         ISYSBF(1), NOUT(2), DUM1(37)=cells 3-39, NBPW(40),
C         DUM2(14)=cells 41-54, ISPREC(55)
C     so a /SYSTEM/ physical cell k with 3 <= k <= 39 is DUM1(k-2).
C     Each value below is the bd/semdbd.f DATA golden (DATA block at
C     bd/semdbd.f L555-576); positions are array-aware (see next note).
C
C        cell  8  LOAD   = 1      DUM1(6)   load/restart control flag
C        cell 14  MXLINS = 20000  DUM1(12)  max output lines per run
C        cell 19  ECHOF  = 2      DUM1(17)  input echo control flag
C        cell 23  LSYSTM = 180    DUM1(21)  declared length of /SYSTEM/
C        cell 24  ICFIAT = 11     DUM1(22)  FIAT words/entry (8 or 11)
C        cell 29  MAXFIL = 35     DUM1(27)  max number of files
C        cell 30  MAXOPN = 16     DUM1(28)  max simultaneously-open
C        cell 34  NBRCBU = 15     DUM1(32)  CDC FET + dummy index len
C        cell 35  LPRUS  = 64     DUM1(33)  CDC words per PRU
C
C     ...PLUS 33 SAFE ZERO cells (bd/semdbd.f zero-fill), written by the
C     two DATA-driven loops at the end of the body over the ZD1 (23 of
C     DUM1) and ZD2 (10 of DUM2) index lists declared above.  TOTAL
C     reproduced /SYSTEM/ cells = 42 (9 non-zero + 33 zero) -- the
C     COMPLETE header-reachable, BTSTRP/DBMINT-untouched, non-machine
C     safe subset that SMCOMX.COM exposes within cells 1-55.  See the
C     EXCLUDED list below for the cells deliberately not written.
C
C     CELL-POSITION / NBPW-OFFSET RESOLUTION (maintainer note).  The
C     sibling modern/state/stateacc.f and this routine AGREE that NBPW
C     is word 40 in BOTH the SMCOMX.COM and the array-aware bd/semdbd.f
C     layouts.  RESOLVED: the "38" is a naive ALL-SCALAR count.
C     bd/semdbd.f L218-219 dimensions DATE(3),SYSDAT(3),ADUMEL(9),
C     MODCOM(9),HDY(3),SWITCH(3),K8890(3),LEFT(56),LEFT2(28); counting
C     those arrays makes /SYSTEM/ exactly 180 words (== LSYSTM) and
C     places NBPW at cell 40 -- corroborated INDEPENDENTLY by the
C     EQUIVALENCEs in mds/btstrp.f: B(40)=NBPW, B(22)=LINKNO,
C     B(41)=NCPW, B(55)=IPREC.  Absolute DUM1 indexing above is
C     therefore reliable.  ECHOF, LSYSTM, ICFIAT, MAXFIL, MAXOPN,
C     NBRCBU and LPRUS all sit AFTER DATE(3) and so are shifted +2 from
C     a naive count -- the array-aware indices above are authoritative.
C
C     CELLS DELIBERATELY EXCLUDED:
C       - HICORE (cell 31, DUM1(29), value 85000) is REACHABLE but is a
C         MACHINE memory-size constant ("VAX: HICORE IS SET TO 50,000
C         BY BTSTRP", bd/semdbd.f) -- excluded to avoid clobber risk.
C       - TOLEL (cell 70, REAL 0.01), LINTC (cell 85, 800) and OSPCNT
C         (cell 87, 15) are bd-set and non-machine, but their cells lie
C         BEYOND cell 55 -- the last cell SMCOMX.COM declares (ISPREC).
C         Reaching them would require editing the frozen SMCOMX.COM or
C         declaring new COMMON, both forbidden.  See MAINTAINER FLAG 2.
C
C  MAINTAINER FLAG 1 -- /GINOX/ NAME COLLISION (block NOT written here)
C     bd/semdbd.f seeds COMMON /GINOX / CDC(244) with DATA CDC/244*0/
C     (244 zero words).  The header mds/GINOX.COM declares /GINOX/ with
C     a COMPLETELY DIFFERENT layout: LGINOX, IDSLIM, MDSFCB(3,89),
C     LENSOF(10) -- the modern disk-I/O state, ~279 words.  Writing
C     semdbd's zero-fill through mds/GINOX.COM would be semantically
C     invalid and could corrupt live disk-I/O state, so /GINOX/ is NOT
C     initialized here and GINOX.COM is NOT included.  The collision is
C     deferred to modern/docs/pre_implementation_analysis.md.
C
C  MAINTAINER FLAG 2 -- COMPLETE bd-SEEDED REPRODUCTION (R SET) PLUS THE
C  PRINCIPLED, AAP 0.7.1-MANDATED EXCLUSIONS
C     The 39 bd/ BLOCK DATA units seed 92 distinct COMMON blocks.  This
C     routine now reproduces ALL of them that it is bit-safe to reproduce
C     -- the "R set" of 72 bd-DATA-seeded blocks (31316 words) -- through
C     the generated headers bddata.inc (flat INTEGER COMMON views) +
C     bdgold.inc (bitwise golden words) + bdcopy.inc (the copy loops in
C     the body).  The goldens were captured by LINKING the real bd/
C     objects and dumping COMMON memory as integers, so the reproduction
C     is bit-for-bit by construction across REAL, INTEGER and Hollerith
C     fields alike (including readbd.f's REAL goldens RMAX=100.0,
C     RMIN=.01, EPSI=1.0E-11, EPS=.0001, LMAX=60.).  This satisfies AAP
C     0.7.3#1 (reproduce all bd values bitwise) and is the include/header
C     coverage the code review explicitly endorsed for the previously
C     header-unreachable blocks.  The full bd/ -> COMMON table and the
C     R-set membership are in modern/docs/pre_implementation_analysis.md
C     and modern/docs/init_modernization_report.md.
C
C     DELIBERATELY EXCLUDED FROM THE COPY (NOT a deferral -- a bit-for-bit
C     SAFETY REQUIREMENT under AAP 0.7.1, the HIGHEST-precedence rule):
C       * BOOTSTRAP-OWNED blocks whose RUNTIME value is established by
C         BTSTRP/CNSTDD/DBMINT (which run BEFORE this routine) and is NOT
C         the bd load value -- /SEM/, /TWO/, /MACHIN/, /LHPWX/, /XXREAD/,
C         /ZZZZZZ/, and the machine/runtime cells of /SYSTEM/.  Writing
C         the bd value into these would CLOBBER the just-computed machine
C         constants -- a regression.  /SYSTEM/ is therefore handled only
C         on its proven-safe, BTSTRP/DBMINT-untouched 42-cell config
C         subset above; the rest of /SYSTEM/ is left to the bootstrap.
C       * /GINOX/ -- MAINTAINER FLAG 1 layout collision (and DBMINT owns
C         the live disk-I/O state); seeds only zeros in bd, so excluded.
C       * The bd blocks that contain NO DATA statement (e.g. /SMA1DP/,
C         /SMA1BK/, /SMA2BK/, /STAPID/, /STIME/, /NUMTPX/, /OPINV/,
C         /FEERIM/, /XXFIAT/, /XECHOX/) seed ZERO values only; their
C         load-time content is the default-zero COMMON every executable
C         already provides, so there is nothing to reproduce.
C     Note: bd/ferfbd.f is a SUBROUTINE (not a BLOCK DATA) and seeds
C     nothing; its /SYSTEM/ and /ZZZZZZ/ declarations are access-only and
C     it is correctly NOT linked into the golden dump.
C
C  MAINTAINER FLAG 3 -- DIAGNOSTICS / OUTPUT POLICY
C     BLKINIT is an INITIALIZER, not a validator or diagnostic routine,
C     so it deliberately carries NO "IF (IDIAG .EQ. 0) RETURN" guard --
C     it must perform its (idempotent, safe) initialization whenever
C     called.  The decision of WHETHER to call BLKINIT lives in
C     nastinit.f (toggle logic).  BLKINIT produces NO output of any
C     kind: NASTINIT runs immediately after CALL DBMINT, BEFORE unit 3
C     is opened by the bootstrap, so writing to any unit would be
C     unsafe.  There is no WRITE/PRINT/OPEN and no CALL MESAGE here.
C     Any future progress logging must go through modern/diag/diaglog.f
C     (logical unit 3 only, MESAGE codes 9001-9999, IDIAG-guarded).
C
C  LOCK-STEP CONTRACT WITH modern/init/initval.f
C     The set of cells written here (the 42 /SYSTEM/ cells: 9 non-zero
C     DUM1 goldens + 23 zero DUM1 + 10 zero DUM2, via the IDENTICAL
C     ZD1/ZD2 index lists) MUST equal exactly the set initval.f
C     validates, with identical golden values.  Keep the two
C     synchronized; the decision and the cell set are recorded in
C     modern/docs/init_modernization_report.md.
C=====================================================================
      SUBROUTINE BLKINIT
C
C     DUM-TYPE note: DUM1 and DUM2 are declared ONLY in the SMCOMX.COM
C     COMMON statement, which gives them no explicit type.  By the
C     FORTRAN default-typing rule a name beginning with 'D' is REAL;
C     every /SYSTEM/ config cell reproduced here is INTEGER, so both are
C     typed INTEGER for integer (not floating) store semantics.  The
C     array EXTENTS (37 and 14) still come from the INCLUDEd COMMON
C     statement; these declarations only assign a type and are NEITHER a
C     new COMMON NOR an EQUIVALENCE.  They precede the INCLUDE so the
C     type is in force when the COMMON statement dimensions DUM1(37) and
C     DUM2(14).
      INTEGER           DUM1
      INTEGER           DUM2
C
C     Local index lists naming the /SYSTEM/ DUM1 and DUM2 cells whose
C     bd/semdbd.f golden is ZERO and that are SAFE to (re)write (BTSTRP/
C     DBMINT-untouched, non-machine, within SMCOMX.COM's 55-word
C     /SYSTEM/).  Held in DATA arrays so THIS writer and the lock-step
C     validator modern/init/initval.f share one IDENTICAL index list.
C     ZD1(23) -> zero DUM1 cells; ZD2(10) -> zero DUM2 cells; IZ loops.
      INTEGER           ZD1(23), ZD2(10), IZ
C
C     The single permitted state-access path: SMCOMX.COM is the only
C     one of the nine *.COM headers that declares /SYSTEM/.
      INCLUDE 'SMCOMX.COM'
C
C     -----------------------------------------------------------------
C     FULL bd-SEEDED STATE REPRODUCTION -- the "R set" (72 COMMON blocks,
C     31316 words).  bddata.inc declares clash-free flat INTEGER views
C     (COMMON /blk/ KBnnnn) of EVERY bd-DATA-seeded block that is NOT
C     bootstrap-owned; bdgold.inc holds the bitwise golden words captured
C     by LINKING the 39 real bd/ BLOCK DATA objects and dumping COMMON
C     memory as integers, so REAL, INTEGER and Hollerith fields are all
C     reproduced bit-for-bit BY CONSTRUCTION (no DATA/Hollerith/REAL
C     transcription).  No new EQUIVALENCE and no COMMON beyond the
C     existing bd/ block names are introduced (the KBnnnn array names
C     begin with K and are INTEGER by the default I-N rule).  bdcopy.inc
C     (in the executable body below) copies the goldens into COMMON.
C     See modern/docs/init_modernization_report.md and MAINTAINER FLAG 2.
      INTEGER           IBD
      INCLUDE 'bddata.inc'
      INCLUDE 'bdgold.inc'
C
C     Zero-valued safe cells by ARRAY INDEX (ascending).  DUM1(j) is
C     /SYSTEM/ cell j+2; DUM2(j) is cell j+40.  ZD1 thus covers cells
C     3,5,6,7,10,11,12,13,15,16,17,18,20,21,25,26,27,28,32,33,36,37,38
C     (NOGO,MPC,SPC,LOGFL,MTEMP,NPAGES,NLINES,TLINES,DATE(3),TIMEZ,
C     PLOTF,APPRCH,RFFLAG,CPPGCT,MN,DUMMYI,TIMEW,OFPFLG,NPRUS,KSYS37,
C     QQ); ZD2 covers cells 45-54 (TAPFLG,ADUMEL(9)).  All are
C     bd/semdbd.f zero-fill.  The BTSTRP cells {4,9,22,39 in DUM1;
C     41,42,43,44 in DUM2} and machine HICORE(31=DUM1(29)) are NOT here.
      DATA ZD1 / 1, 3, 4, 5, 8, 9, 10, 11, 13, 14, 15, 16, 18, 19, 23,
     &           24, 25, 26, 30, 31, 34, 35, 36 /
      DATA ZD2 / 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 /
C
C     -----------------------------------------------------------------
C     /SYSTEM/ -- explicit, ordered reproduction of the safe, non-
C     machine, BTSTRP/DBMINT-untouched config cells (ascending cell
C     order).  Each DUM1(j) addresses /SYSTEM/ physical cell (j+2).
C     -----------------------------------------------------------------
C
C     cell  8  LOAD   = 1      (load / restart control flag)
      DUM1(6)  = 1
C     cell 14  MXLINS = 20000  (maximum output lines per run)
      DUM1(12) = 20000
C     cell 19  ECHOF  = 2      (input echo control flag)
      DUM1(17) = 2
C     cell 23  LSYSTM = 180    (declared length of /SYSTEM/, words)
      DUM1(21) = 180
C     cell 24  ICFIAT = 11     (FIAT words-per-entry selector: 8 or 11)
      DUM1(22) = 11
C     cell 29  MAXFIL = 35     (maximum number of files)
      DUM1(27) = 35
C     cell 30  MAXOPN = 16     (maximum simultaneously-open files)
      DUM1(28) = 16
C     cell 34  NBRCBU = 15     (CDC-only FET + dummy index length)
      DUM1(32) = 15
C     cell 35  LPRUS  = 64     (CDC-only words per physical record unit)
      DUM1(33) = 64
C
C     -----------------------------------------------------------------
C     Zero-valued safe config cells (33: 23 in DUM1, 10 in DUM2).  Each
C     is bd/semdbd.f zero-fill, reproduced so the test-harness exe (no
C     bd/ objects linked; COMMON starts zeroed) presents the FULL safe
C     set to INITVAL, and so the real-solver path idempotently re-
C     affirms 0 over cells the linked bd/ units already hold at 0 (never
C     a BTSTRP/machine cell -- see the non-clobber proof in the header).
C     -----------------------------------------------------------------
      DO 100 IZ = 1, 23
         DUM1(ZD1(IZ)) = 0
  100 CONTINUE
      DO 110 IZ = 1, 10
         DUM2(ZD2(IZ)) = 0
  110 CONTINUE
C
C     -----------------------------------------------------------------
C     R-SET REPRODUCTION -- populate the 72 bd-DATA-seeded, NON-bootstrap
C     COMMON blocks from the bitwise goldens (bdcopy.inc; one labelled DO
C     loop per block, KBnnnn(IBD) = BDGOLD(off+IBD)).  In the LIVE solver
C     these writes are IDEMPOTENT: the linked bd/ units already placed the
C     identical bit patterns at load, so re-writing them changes nothing
C     and never clobbers a bootstrap machine constant (proven: a BEFORE/
C     AFTER COMMON snapshot around this copy, with the real bd/ objects
C     linked, is byte-identical).  In the UNIT-TEST executable -- where
C     the bd/ BLOCK DATA is not linked and COMMON starts zeroed -- these
C     loops ACTIVELY initialize the full R set so initval.f reports
C     NDIV = 0 over all 31316 reproduced words.
      INCLUDE 'bdcopy.inc'
C
      RETURN
      END
