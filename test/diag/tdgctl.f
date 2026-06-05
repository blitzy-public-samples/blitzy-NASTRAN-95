C=====================================================================
C     test/diag/tdgctl.f
C---------------------------------------------------------------------
C     PROGRAM TDGCTL -- NASTRAN-95 modernization unit-test driver.
C
C     PURPOSE
C        Validate TOGGLE WIRING and the DEFAULT-SILENT (APR.95)
C        behavior of the modern runtime-diagnostics control routine
C        (test/diag/ suite, coverage area 4):  modern/diag/diagctl.f
C        reads the NASTRAN_* environment toggles via GETENV and sets
C        the diagnostics-enable state IDIAG once.  With NO toggle set
C        the default is IDIAG = 0 -- silent, bit-identical to the
C        unmodified APR.95 solver.  This driver is the executable
C        assertion of that default-safety / rollback guarantee.
C
C     ROUTINE UNDER TEST   modern/diag/diagctl.f
C        SUBROUTINE DIAGCTL (IDIAG) -- the NASTRAN_* env-toggle reader.
C        IDIAG is an OUTPUT argument:  0 when no toggle is set (clean
C        environment), a non-zero bitmask when one or more are set
C        (LEGACY_INIT=1, INIT_VALIDATE=2, DISPATCH_VALIDATE=4,
C        DISPATCH_LOG=8).  DIAGCTL is the SETTER and therefore has, by
C        design, NO guard clause of its own.
C
C     ALSO EXERCISED       modern/diag/diaglog.f
C        SUBROUTINE DIAGLOG (IDIAG, ICODE, NVAL, MSG) -- the unit-3
C        writer whose FIRST executable statement is the guard clause
C        IF (IDIAG .EQ. 0) RETURN.  Used here as the BEHAVIORAL probe:
C        called with the IDIAG returned by DIAGCTL (0 in a clean env)
C        it must write NOTHING to unit 3 (the guard suppresses output).
C
C     REFERENCE SOURCES
C        bin/nastrn.f  unit-3 / LOGNM wiring idiom: COMMON /LOGOUT/ LOUT
C                      (L10), LOUT=3 after CALL DBMINT (L44/L45),
C                      CALL GETENV('LOGNM',LOG) (L61), and OPEN(3,
C                      FILE=DSNAMES(3),..) (L115); plus the blank-then-
C                      GETENV receiver idiom (L31/L33).
C        bin/nastran   csh wrapper: operator toggles are inline env vars
C                      in the "env ... LOGNM=$probname.log ..." block
C                      ahead of nastrn.exe (L523-L532).  Rollback to
C                      APR.95 is unsetting them -- no recompilation.
C
C     DELIVERABLE ONLY -- NOT EXECUTED BY BLITZY.  Compiled and run
C     later in the developer's Solaris environment (csh + Sun f77):
C        f77 -fast -dn -o tdgctl.exe test/diag/tdgctl.f bin/nastlib.a
C     DIAGCTL and DIAGLOG are provided by bin/nastlib.a; this file is a
C     SINGLE self-contained PROGRAM unit and NEVER defines either one.
C
C     OUTPUT CONTRACT
C        Exactly one verdict is written to the LOG unit (logical unit 3
C        / LOUT):  'PASS: TDGCTL' on success, or the failure verdict on
C        any sub-check failure.  The literal failure token is emitted
C        ONLY on a genuine failure path -- test/run_units.csh greps the
C        captured output for it and exits non-zero on a match -- so that
C        token appears in NO comment, banner, or success message here.
C
C     CLEAN-ENVIRONMENT REQUIREMENT
C        The default-silent assertion is meaningful only when the four
C        NASTRAN_* toggles are UNSET.  test/run_units.csh invokes each
C        driver setting only LOGNM (never a NASTRAN_* toggle), so
C        DIAGCTL returns IDIAG = 0 here.  A run with a toggle set would
C        legitimately ENABLE diagnostics and is not the scenario under
C        test (see the documented enabled-mapping note at sub-check 3).
C
C     CROSS-CONSISTENCY
C        Expected values MUST match test/diag/tdgctl.ref:
C        DEFAULT_IDIAG 0, TOGGLE_COUNT 4, ALL_SET_IDIAG 15,
C        EXPECT_VERDICT 'PASS: TDGCTL'.
C
C     Fixed-form FORTRAN 77 (Sun f77 -fast -dn).  No F90+, no third-
C     party libraries.
C=====================================================================
      PROGRAM TDGCTL
C
C     ---- declarations -----------------------------------------------
      CHARACTER*80    LOG
      CHARACTER*132   LINE
      LOGICAL         OK
      INTEGER         IDIAG, JDIAG, ICODE, NVAL
C
C     LOUT mirrors the bin/nastrn.f log-unit cell (L10).  The modern/
C     "no new COMMON" rule does NOT apply to test/ drivers; LOUT holds
C     the log unit number (3) and is the single verdict / capture sink.
      COMMON /LOGOUT/ LOUT
      INTEGER         LOUT
C
C     Representative in-band diagnostic code -- the reserved 9001-9999
C     new-diagnostics MESAGE band; used by the DIAGLOG probes below.
      DATA ICODE /9001/
C
      OK   = .TRUE.
      NVAL = 0
C
C     ---- unit-3 (log) wiring -- mirror bin/nastrn.f -----------------
C     Read the log-file name from LOGNM (set per driver by
C     test/run_units.csh); fall back to a fixed name when unset so the
C     driver also runs standalone.  Open it on unit 3 and record LOUT=3
C     as the single diagnostic / verdict sink.  The blank-then-GETENV
C     receiver idiom matches bin/nastrn.f (LOG=' ' then CALL GETENV).
      LOUT = 3
      LOG  = ' '
      CALL GETENV ('LOGNM', LOG)
      IF (LOG .EQ. ' ') LOG = 'tdgctl.log'
      OPEN (LOUT, FILE=LOG, STATUS='UNKNOWN')
C
C     =================================================================
C     SUB-CHECK 1 -- DIAGCTL runs cleanly and returns the DEFAULT state.
C     In a clean environment (no NASTRAN_* set) CALL DIAGCTL(IDIAG)
C     must complete and yield IDIAG = 0.  Because DIAGCTL returns IDIAG
C     as an OUTPUT argument it is directly readable, so assert the
C     default state directly -- the strongest form of the toggle-wiring
C     check (DEFAULT_IDIAG = 0 per test/diag/tdgctl.ref).  IDIAG is
C     pre-set to a poison value (-1) so this also proves DIAGCTL itself
C     writes the argument rather than leaving it untouched.
C     =================================================================
      IDIAG = -1
      CALL DIAGCTL (IDIAG)
      IF (IDIAG .NE. 0) OK = .FALSE.
C
C     =================================================================
C     SUB-CHECK 2 (PRIMARY / BINDING) -- DEFAULT IS SILENT (behavioral).
C     With the IDIAG just returned by DIAGCTL (0 in a clean env) a
C     DIAGLOG call must write NOTHING to unit 3:  DIAGLOG's first
C     executable statement IF (IDIAG .EQ. 0) RETURN short-circuits
C     before any I/O.  Probe behaviorally so the test needs no knowledge
C     of how IDIAG is stored:  REWIND unit 3 for a clean capture, CALL
C     DIAGLOG, then REWIND and attempt to READ a record back.  Reaching
C     the END= label (immediate EOF, no record) confirms default-
C     silence.  A record read back would mean the guard failed to
C     suppress output -> set OK false.  This silence check is THE
C     binding pass/fail criterion for this driver.
C     =================================================================
      REWIND (LOUT)
      CALL DIAGLOG (IDIAG, ICODE, NVAL, 'TDGCTL SILENT CHK')
      REWIND (LOUT)
      LINE = ' '
      READ (LOUT, '(A)', END=20) LINE
C     Falling through (a record was read) means a disabled (IDIAG=0)
C     call still produced output -> not silent -> sub-check failed.
      OK = .FALSE.
   20 CONTINUE
C
C     =================================================================
C     SUB-CHECK 3 -- ENABLED-PATH POSITIVE CONTROL (deterministic).
C     The complementary expectation is that when a NASTRAN_* toggle is
C     set DIAGCTL returns a NON-ZERO IDIAG and diagnostics are enabled
C     (NASTRAN_DISPATCH_LOG => IDIAG=8; all four => ALL_SET_IDIAG=15 per
C     test/diag/tdgctl.ref).  FORTRAN 77 cannot portably set its own
C     environment, so that env -> IDIAG mapping is DOCUMENTED here and
C     exercised in the Solaris environment by setting the toggles.  As a
C     deterministic positive control -- proving the silence observed in
C     sub-check 2 is due to the guard clause and not a dead unit 3 or a
C     no-op writer -- set a LOCAL IDIAG non-zero (15 = ALL_SET_IDIAG)
C     and confirm DIAGLOG now DOES emit exactly one record to unit 3.
C     =================================================================
      JDIAG = 15
      REWIND (LOUT)
      CALL DIAGLOG (JDIAG, ICODE, NVAL, 'TDGCTL ENABLED CHK')
      REWIND (LOUT)
      LINE = ' '
      READ (LOUT, '(A)', END=30) LINE
      GO TO 40
C     No record when diagnostics are enabled -> positive control could
C     not reach the enabled path -> sub-check failed.
   30 OK = .FALSE.
   40 CONTINUE
C
C     ---- verdict (single line, unit 3 only) -------------------------
C     Rewind so the captured log holds exactly the verdict the harness
C     greps.  The failure token is written ONLY in the .NOT. OK branch
C     (it appears nowhere else in this file).
      REWIND (LOUT)
      IF (OK) THEN
         WRITE (LOUT, '(A)') 'PASS: TDGCTL'
      ELSE
         WRITE (LOUT, '(A)') 'FAIL: TDGCTL'
      END IF
      CLOSE (LOUT)
      STOP
      END
