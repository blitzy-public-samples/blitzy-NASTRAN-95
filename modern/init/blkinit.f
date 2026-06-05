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
C     addressing one COMMON block (/SYSTEM/).
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
C     writes neither.  The nine cells BLKINIT writes -- 8,14,19,23,24,
C     29,30,34,35 -- have EMPTY intersection with that set, so every
C     write is provably BTSTRP/DBMINT-untouched and hence idempotent.
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
C  MAINTAINER FLAG 2 -- ~86 HEADER-UNREACHABLE bd-set COMMON BLOCKS
C     The 39 bd/ units seed 90 distinct COMMON blocks; only /SYSTEM/
C     (partially, via SMCOMX.COM) and /GINOX/ (collision, above) appear
C     in any of the nine *.COM headers.  The remaining 88 blocks are
C     declared by NO header and CANNOT be reached without declaring new
C     COMMON, authoring a new INCLUDE header, or adding EQUIVALENCE --
C     all forbidden by the zero-new-COMMON rule.  They are therefore
C     DEFERRED, not reproduced.  The full bd/ -> COMMON coverage table
C     belongs to modern/docs/pre_implementation_analysis.md; the in-
C     code manifest below (originating bd/ unit -> deferred blocks)
C     makes the omission impossible to miss.  Each entry reads:
C     "DEFERRED -- header-unreachable; reproduction requires a
C     maintainer-authored INCLUDE or a relaxation of zero-new-COMMON."
C
C       dpdcbd.f -> /DPDCOM/
C       exiobd.f -> /EXIO2F/ /EXIO2P/
C       flbbd.f  -> /FLBFIL/
C       gp3bd.f  -> /GP3COM/
C       gptabd.f -> /GPTA1/ /CLSTRS/
C       ifp3bd.f -> /IFP3CM/
C       ifx1bd.f -> /IFPX1/ /IFPX0/
C       ifx2bd.f -> /IFPX2/
C       ifx3bd.f -> /IFPX3/
C       ifx4bd.f -> /IFPX4/
C       ifx5bd.f -> /IFPX5/
C       ifx6bd.f -> /IFPX6/
C       ifx7bd.f -> /IFPX7/
C       itembd.f -> /ITEMDT/
C       of1pbd.f -> /OFPB1/
C       of2pbd.f -> /OFPB2/
C       of3pbd.f -> /OFPB3/
C       of3sbd.f -> /OFPB3S/
C       of4pbd.f -> /OFPB4/
C       of5pbd.f -> /OFPB5/
C       of6pbd.f -> /OFPB6/
C       of7pbd.f -> /OFPB7/
C       of7sbd.f -> /OFPB7S/
C       of8pbd.f -> /OFPB8/
C       of9pbd.f -> /OFPB9/
C       ofp1bd.f -> /OFPBD1/
C       ofp5bd.f -> /OFPBD5/
C       ofsnbd.f -> /OFSN1/
C       ofssbd.f -> /OFSS1/
C       pla4bd.f -> /PLA42C/
C       plotbd.f -> /CHAR94/ /CHRDRW/ /XXPARM/ /PLTDAT/ /SYMBLS/
C                   /PLTSCR/ /DRWAXS/
C       readbd.f -> /REGEAN/ /INVPWX/ /GIVN/   (incl. REAL goldens
C                   RMAX=100.0, RMIN=.01, EPSI=1.0E-11, EPS=.0001,
C                   LMAX=60. -- proving reproduction must handle REAL)
C       sdr2bd.f -> /SDR2X1/ /SDR2X2/ /SDR2X4/
C       sma1bd.f -> /SMA1IO/ /SMA1BK/ /SMA1DP/ /SMA1CL/ /SMA1ET/
C       sma2bd.f -> /SMA2IO/ /SMA2BK/ /SMA2CL/ /SMA2ET/
C       ta1abd.f -> /TA1ACM/
C       tabfbd.f -> /TABFTX/
C       vdrbd.f  -> /VDRCOM/
C       semdbd.f -> /XMSSG/ /NUMTPX/ /BLANK/ /NTIME/ /XLINK/ /SEM/
C                   /XFIST/ /XPFIST/ /XXFIAT/ /XFIAT/ /OSCENT/ /OUTPUT/
C                   /XDPL/ /XVPS/ /STAPID/ /STIME/ /XCEITB/ /XMDMSK/
C                   /MSGX/ /DESCRP/ /TWO/ /NAMES/ /TYPE/ /BITPOS/
C                   /SOFCOM/ /XXREAD/ /XECHOX/ /XREADX/ /MACHIN/ /LHPWX/
C                   (semdbd also seeds /SYSTEM/ and /GINOX/, handled
C                   above)
C     Note: bd/ferfbd.f is a SUBROUTINE (not a BLOCK DATA) and seeds
C     nothing; its /SYSTEM/ and /ZZZZZZ/ declarations are access-only.
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
C     The set of cells written here (the nine /SYSTEM/ DUM1 cells
C     listed above, with their golden values) MUST equal exactly the
C     set initval.f validates.  Keep the two synchronized; the decision
C     and the cell set are recorded in
C     modern/docs/init_modernization_report.md.
C=====================================================================
      SUBROUTINE BLKINIT
C
C     DUM1-TYPE note: DUM1 is declared ONLY in the SMCOMX.COM COMMON
C     statement, which gives it no explicit type.  By the FORTRAN
C     default-typing rule a name beginning with 'D' is REAL; every
C     /SYSTEM/ config cell reproduced here is INTEGER, so DUM1 is typed
C     INTEGER to guarantee integer (not floating) store semantics.  The
C     array EXTENT (37) still comes from the INCLUDEd COMMON statement;
C     this declaration only assigns a type and is NEITHER a new COMMON
C     NOR an EQUIVALENCE.  It precedes the INCLUDE so the type is in
C     force when the COMMON statement dimensions DUM1(37).
      INTEGER           DUM1
C
C     The single permitted state-access path: SMCOMX.COM is the only
C     one of the nine *.COM headers that declares /SYSTEM/.
      INCLUDE 'SMCOMX.COM'
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
      RETURN
      END
