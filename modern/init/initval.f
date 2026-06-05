C=====================================================================
C     modern/init/initval.f
C---------------------------------------------------------------------
C     INITIALIZATION-STATE VALIDATOR        SUBROUTINE INITVAL (NDIV)
C
C     Branch-by-abstraction modernization (modern/ tree) of NASTRAN-95.
C     INITVAL bitwise-compares the live COMMON /SYSTEM/ configuration
C     state -- as populated by the modern explicit initializer
C     modern/init/blkinit.f -- against the legacy bd/ BLOCK DATA golden
C     values, counts the divergences, returns the count in NDIV, and
C     emits divergence diagnostics to logical unit 3 (via DIAGLOG) using
C     codes in the 9001-9999 band (init sub-band 9100-9199).  NDIV = 0
C     means a perfect bitwise match (success).
C
C     SIGNATURE (LOCKED cross-agent contract -- do not change):
C         SUBROUTINE INITVAL (NDIV)
C         INTEGER NDIV  -- OUTPUT: count of bitwise divergences between
C                          the modern init state and the legacy BLOCK
C                          DATA goldens; 0 == perfect match.
C     The one-argument form is fixed by the test/init drivers
C     (tinval.f, tinblk.f, tinnas.f all CALL INITVAL(NDIV)) and their
C     .ref files (EXPDIV 0 positive, EXPRAN 1 "validator executed").
C     No IDIAG argument is added (the drivers do not pass one); INITVAL
C     self-acquires IDIAG (see MAINTAINER FLAG 1 below).
C
C     A1 DECISION CONTEXT (AAP 0.6.1).  This validator realizes A1
C     Candidate 1 -- an explicit, inspectable, hardcoded comparison --
C     not Candidate 2 (declarative dependency metadata resolved by a
C     topological traversal).  The 39 bd/ units are order-independent
C     PURE DATA initializers, so validation is a FLAT per-cell
C     comparison, not a dependency traversal; a topological-sort engine
C     would be over-engineering.  The body below is a fixed, ascending-
C     cell-ordered series of independent per-cell comparisons.
C
C     TEMPLATE METHOD shape: setup -> compare -> report (shape shared
C     with the sibling validators dispval.f and stateval.f).
C
C  MAINTAINER FLAG 1 -- GUARD CLAUSE + IDIAG ACQUISITION
C     Every validator must begin with IF (IDIAG .EQ. 0) RETURN so it has
C     provably zero overhead when diagnostics are disabled (AAP 0.6.4,
C     0.7.2).  IDIAG is NOT a COMMON variable and NOT an argument of
C     INITVAL; modern/diag threads IDIAG as an ARGUMENT (to honor the
C     zero-new-COMMON rule), not stored in COMMON, so INITVAL self-
C     acquires it.  The ONLY statement preceding the guard is the side-
C     effect-free acquisition CALL DIAGCTL (IDIAG) -- DIAGCTL merely
C     reads the NASTRAN_* environment toggles and changes no global
C     state.  NDIV is deliberately NOT touched before the guard: the
C     drivers preset NDIV = 999999 as a sentinel, and if the guard fires
C     (no toggle set) that sentinel must survive so the driver can
C     detect that the validate path did not run.  Per-toggle selection
C     (run init validation only when NASTRAN_INIT_VALIDATE, bit 2, is
C     set) is performed by the caller modern/init/nastinit.f before it
C     calls INITVAL -- consistent with diaglog.f's "per-toggle gating is
C     the caller's responsibility"; INITVAL's own gate is the master
C     IF (IDIAG .EQ. 0) RETURN.  The harness runs with
C     NASTRAN_INIT_VALIDATE=1 (IDIAG bit 2 set) so the guard does not
C     fire and the comparison runs; INITVAL only reads COMMON and writes
C     NDIV, so it is side-effect-free / idempotent (calling it twice
C     yields an identical NDIV, as tinval.f requires).
C
C  MAINTAINER FLAG 2 -- "BITWISE" REAL COMPARISON / NO REACHABLE REAL
C     Init-state validation demands EXACT reproduction, so cells are
C     compared with an exact .NE. test -- NOT the 6-significant-figure
C     relative tolerance, which belongs to the OUTPUT comparator
C     modern/regress/outcomp.f, not to init-state validation.  For a
C     REAL cell, an exact .NE. against the same literal constant
C     compiled by the same f77 detects any divergence (equal stored
C     representations compare equal); that is the rule-compliant
C     realization of "bitwise" here.  A literal bit-pattern compare
C     would require a maintainer-authored helper or a non-F77 TRANSFER
C     and is OUT OF SCOPE.  In practice the safe, header-reachable
C     validated subset (below) is INTEGER-ONLY: the lone REAL golden
C     TOLEL (/SYSTEM/ cell 70, value 0.01) lies BEYOND SMCOMX.COM's last
C     declared cell (ISPREC, cell 55) and is therefore deferred; no new
C     COMMON and no EQUIVALENCE is introduced to reach it.
C
C  MAINTAINER FLAG 3 -- /GINOX/ NAME COLLISION (block NOT validated)
C     bd/semdbd.f declares COMMON /GINOX / CDC(244) (244 zero words),
C     but mds/GINOX.COM declares /GINOX/ with a COMPLETELY DIFFERENT
C     layout (LGINOX, IDSLIM, MDSFCB(3,89), LENSOF(10)).  Comparing
C     semdbd's /GINOX/ through mds/GINOX.COM would be semantically
C     invalid, so /GINOX/ is NOT compared and GINOX.COM is NOT included;
C     one informational note is emitted (code 9150) and NDIV is NOT
C     affected.
C
C  MAINTAINER FLAG 4 -- HEADER-UNREACHABLE bd/ COMMON BLOCKS (deferred)
C     Of the ~90 COMMON blocks the 39 bd/ units seed, only /SYSTEM/
C     (partially, via SMCOMX.COM) is reachable through the nine *.COM
C     headers.  The remaining header-unreachable blocks (/DPDCOM/,
C     /OFPB1-9/, /REGEAN/, /INVPWX/, /GIVN/, /SMA1*/, /SMA2*/, /SEM/,
C     /XLINK/, /OUTPUT/, ... including the readbd.f REAL goldens) CANNOT
C     be reached without declaring new COMMON, authoring a new INCLUDE
C     header, or adding EQUIVALENCE -- all forbidden by the zero-new-
C     COMMON rule.  They are NOT validated and NOT counted as
C     divergences; one informational note is emitted (code 9160).  The
C     full bd/ -> COMMON coverage table lives in
C     modern/docs/pre_implementation_analysis.md.
C
C  MAINTAINER FLAG 5 -- UNIT-3 TIMING CAVEAT
C     In the real solver NASTINIT (hence any INITVAL it calls) runs
C     immediately after CALL DBMINT, which is BEFORE the bootstrap opens
C     logical unit 3.  Reliable unit-3 diagnostic output therefore
C     occurs in the TEST-HARNESS context (the test/init drivers open
C     unit 3 the way the bootstrap does), which is the primary
C     validation venue for NASTRAN_INIT_VALIDATE.  All writes occur only
C     on the post-guard (validate-enabled) path through DIAGLOG, so
C     INITVAL does not crash if unit 3 is not connected: when
C     diagnostics are off the guard returns before any I/O.
C
C     INCLUDE-ONLY STATE ACCESS -- ZERO new COMMON, ZERO EQUIVALENCE.
C     /SYSTEM/ is reached ONLY through INCLUDE 'SMCOMX.COM' (file
C     mis/SMCOMX.COM), the only one of the nine *.COM headers that
C     declares /SYSTEM/.  There is NO literal COMMON statement and NO
C     EQUIVALENCE statement in this file; the golden values are LOCAL
C     INTEGER PARAMETER constants (not COMMON).  Verifiable by
C     inspection.
C
C     VALIDATED CELL SET (lock-step with modern/init/blkinit.f -- the
C     two files MUST agree; see modern/docs/init_modernization_report.md
C     and the LOCK-STEP CONTRACT note in blkinit.f).  SMCOMX.COM lays
C     out /SYSTEM/ as ISYSBF(1), NOUT(2), DUM1(37)=cells 3-39, NBPW(40),
C     DUM2(14)=cells 41-54, ISPREC(55), so /SYSTEM/ physical cell k with
C     3 <= k <= 39 is DUM1(k-2).  All nine cells are non-machine config
C     defaults proven BTSTRP/DBMINT-untouched: their cell set
C     {8,14,19,23,24,29,30,34,35} is disjoint from the BTSTRP/DBMINT
C     write set, so each compares equal in both the real solver (where
C     the bd/ units seed them at load) and the unit-test executable
C     (where blkinit.f populates them and the bd/ BLOCK DATA is not
C     linked).  Golden values are from bd/semdbd.f's DATA block,
C     array-aware (DATE(3),SYSDAT(3),ADUMEL(9),MODCOM(9),HDY(3),
C     SWITCH(3),K8890(3),LEFT(56),LEFT2(28) make /SYSTEM/ 180 words ==
C     LSYSTM, placing NBPW at cell 40 in agreement with SMCOMX.COM):
C
C        cell  8  LOAD   = 1      DUM1(6)   load / restart control flag
C        cell 14  MXLINS = 20000  DUM1(12)  max output lines per run
C        cell 19  ECHOF  = 2      DUM1(17)  input echo control flag
C        cell 23  LSYSTM = 180    DUM1(21)  declared length of /SYSTEM/
C        cell 24  ICFIAT = 11     DUM1(22)  FIAT words/entry (8 or 11)
C        cell 29  MAXFIL = 35     DUM1(27)  maximum number of files
C        cell 30  MAXOPN = 16     DUM1(28)  max simultaneously-open
C        cell 34  NBRCBU = 15     DUM1(32)  CDC FET + dummy index length
C        cell 35  LPRUS  = 64     DUM1(33)  CDC words per PRU
C
C     CELLS DELIBERATELY EXCLUDED: HICORE (cell 31, DUM1(29), 85000) is
C     reachable but is a MACHINE memory-size constant set by BTSTRP, so
C     it is excluded to avoid clobber-induced false divergence; TOLEL
C     (cell 70), LINTC (cell 85) and OSPCNT (cell 87) are bd-set and
C     non-machine but lie beyond SMCOMX.COM's last cell (55) -- deferred
C     (see MAINTAINER FLAG 2 and FLAG 4).
C
C     DIAGNOSTIC CODES (init sub-band 9100-9199; this band is shared
C     with stateval.f, which uses the 9102-9106 detail cluster --
C     deliberately avoided here to prevent numeric collision):
C        9100  validation summary               (NVAL = final NDIV)
C        9101  a /SYSTEM/ config cell diverges  (NVAL = live value)
C        9150  /GINOX/ deferred (layout collision)
C        9160  N header-unreachable bd/ blocks deferred (NVAL = N)
C     Non-fatal reporting uses DIAGLOG (logical unit 3 only).  No CALL
C     MESAGE is made: INITVAL has no unrecoverable condition (a
C     divergence is counted and reported, never fatal).  The fatal
C     convention, if ever needed, is CALL MESAGE (-9199, 0, 0) (a
C     negative code in the band; MESAGE(NO,PARM,NAME), negative NO is
C     fatal -- see mis/mesage.f).
C
C     Fixed-form FORTRAN 77; compiled by Sun/Solaris f77 -fast -dn into
C     bin/nastlib.a via an updated bin/linknas (build wiring owned by
C     the bin/ agent; this file does not edit bin/linknas).
C=====================================================================
      SUBROUTINE INITVAL (NDIV)
C
C     OUTPUT argument and the self-acquired diagnostics bitmask.
      INTEGER           NDIV, IDIAG
C
C     DUM1-TYPE note: DUM1 is named only by the SMCOMX.COM COMMON
C     statement, which gives it no explicit type; by the FORTRAN default
C     rule a name beginning with 'D' would be REAL.  Every validated
C     /SYSTEM/ cell is INTEGER, so DUM1 is typed INTEGER here to force
C     integer (not floating) load semantics.  This declaration assigns
C     only a TYPE -- the array EXTENT (37) still comes from the INCLUDEd
C     COMMON statement -- and is NEITHER a new COMMON NOR an
C     EQUIVALENCE.  It MUST precede the INCLUDE so the type is in force
C     when the COMMON statement dimensions DUM1(37).
      INTEGER           DUM1
C
C     Legacy bd/semdbd.f golden values as LOCAL constants (not COMMON),
C     in ascending /SYSTEM/ cell order; kept in lock-step with the
C     values written by modern/init/blkinit.f.
      INTEGER           GLOAD, GMXLIN, GECHOF, GLSYST, GICFIA
      INTEGER           GMAXFL, GMAXOP, GNBRCB, GLPRUS
      PARAMETER ( GLOAD = 1, GMXLIN = 20000, GECHOF = 2 )
      PARAMETER ( GLSYST = 180, GICFIA = 11, GMAXFL = 35 )
      PARAMETER ( GMAXOP = 16, GNBRCB = 15, GLPRUS = 64 )
C
C     Count of header-unreachable bd/-seeded COMMON blocks (deferred and
C     reported once via code 9160; see MAINTAINER FLAG 4).
      INTEGER           NUNRCH
      PARAMETER ( NUNRCH = 86 )
C
C     The single permitted state-access path: SMCOMX.COM is the only one
C     of the nine *.COM headers that declares /SYSTEM/.
      INCLUDE 'SMCOMX.COM'
C
C     -----------------------------------------------------------------
C     GUARD (MANDATORY; FIRST EXECUTABLE STATEMENTS).  The sole pre-
C     guard statement is the side-effect-free acquisition of IDIAG.
C     NDIV is NOT touched before the guard so the driver's 999999
C     sentinel survives a disabled (no-toggle) run.  (MAINTAINER FLAG 1)
C  MAINTAINER FLAG: guard preceded only by side-effect-free
C  CALL DIAGCTL(IDIAG); IDIAG is threaded as an argument by modern/diag,
C  not stored in COMMON.
C     -----------------------------------------------------------------
      CALL DIAGCTL (IDIAG)
      IF (IDIAG .EQ. 0) RETURN
C
C     -----------------------------------------------------------------
C     SETUP -- begin counting only after the guard has passed.
C     -----------------------------------------------------------------
      NDIV = 0
C
C     -----------------------------------------------------------------
C     COMPARE -- exact .NE. per cell (MAINTAINER FLAG 2); each validated
C     cell contributes independently to NDIV, so corrupting any single
C     cell yields NDIV .GE. 1.  NVAL on each 9101 record is the LIVE
C     value found; the message tag names the cell.
C     -----------------------------------------------------------------
      IF (DUM1(6)  .NE. GLOAD ) THEN
         NDIV = NDIV + 1
         CALL DIAGLOG (IDIAG, 9101, DUM1(6),  'LOAD C8')
      END IF
      IF (DUM1(12) .NE. GMXLIN) THEN
         NDIV = NDIV + 1
         CALL DIAGLOG (IDIAG, 9101, DUM1(12), 'MXLINS C14')
      END IF
      IF (DUM1(17) .NE. GECHOF) THEN
         NDIV = NDIV + 1
         CALL DIAGLOG (IDIAG, 9101, DUM1(17), 'ECHOF C19')
      END IF
      IF (DUM1(21) .NE. GLSYST) THEN
         NDIV = NDIV + 1
         CALL DIAGLOG (IDIAG, 9101, DUM1(21), 'LSYSTM C23')
      END IF
      IF (DUM1(22) .NE. GICFIA) THEN
         NDIV = NDIV + 1
         CALL DIAGLOG (IDIAG, 9101, DUM1(22), 'ICFIAT C24')
      END IF
      IF (DUM1(27) .NE. GMAXFL) THEN
         NDIV = NDIV + 1
         CALL DIAGLOG (IDIAG, 9101, DUM1(27), 'MAXFIL C29')
      END IF
      IF (DUM1(28) .NE. GMAXOP) THEN
         NDIV = NDIV + 1
         CALL DIAGLOG (IDIAG, 9101, DUM1(28), 'MAXOPN C30')
      END IF
      IF (DUM1(32) .NE. GNBRCB) THEN
         NDIV = NDIV + 1
         CALL DIAGLOG (IDIAG, 9101, DUM1(32), 'NBRCBU C34')
      END IF
      IF (DUM1(33) .NE. GLPRUS) THEN
         NDIV = NDIV + 1
         CALL DIAGLOG (IDIAG, 9101, DUM1(33), 'LPRUS C35')
      END IF
C
C     -----------------------------------------------------------------
C     DEFERRED-SET NOTES -- informational only; NOT counted in NDIV.
C     (See MAINTAINER FLAG 3 and MAINTAINER FLAG 4.)
C     -----------------------------------------------------------------
      CALL DIAGLOG (IDIAG, 9150, 0, 'GINOX DEFERRED COLLISION')
      CALL DIAGLOG (IDIAG, 9160, NUNRCH, 'BLOCKS HDR-UNREACHABLE')
C
C     -----------------------------------------------------------------
C     REPORT -- one summary record carrying the final divergence count.
C     NDIV = 0 means a perfect bitwise match over the validated set.
C     -----------------------------------------------------------------
      CALL DIAGLOG (IDIAG, 9100, NDIV, 'INIT VALIDATION COMPLETE')
C
      RETURN
      END
