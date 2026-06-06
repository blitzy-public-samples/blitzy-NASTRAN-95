C=====================================================================
C     test/diag/tdggrd.f
C---------------------------------------------------------------------
C     PROGRAM TDGGRD -- NASTRAN-95 modernization unit-test driver.
C
C     PURPOSE
C        Validate the GUARD-CLAUSE ZERO-OVERHEAD property of the modern
C        runtime-diagnostics layer (test/diag/ suite, coverage area 3):
C        every diagnostic EMITTER in modern/diag/ begins with the guard
C        clause  IF (IDIAG .EQ. 0) RETURN  as its FIRST executable
C        statement, so when diagnostics are DISABLED (IDIAG = 0, the
C        APR.95 default with no NASTRAN_* toggle set) the routine
C        returns at once and performs NO I/O -- provably zero overhead.
C        The only portable behavioral proof is "disabled => zero
C        output": a CALL DIAGLOG while IDIAG = 0 must write ZERO records
C        to logical unit 3 (LOUT).  This driver is the executable
C        assertion of that rule.
C
C     ROUTINE UNDER TEST   modern/diag/diaglog.f
C        SUBROUTINE DIAGLOG (IDIAG, ICODE, NVAL, MSG) -- formatted
C        diagnostic writer to logical unit 3 ONLY, gated by the guard
C        clause  IF (IDIAG .EQ. 0) RETURN.  With IDIAG = 0 the guard
C        short-circuits before any write; no record reaches unit 3.
C        IDIAG is an ARGUMENT (not a COMMON cell -- modern/diag/ keeps
C        zero new COMMON), so the caller selects the path it tests.
C
C     CONTROL ROUTINE      modern/diag/diagctl.f
C        SUBROUTINE DIAGCTL (IDIAG) -- maps the NASTRAN_* environment
C        toggles to the enable mask IDIAG (its output argument).  In the
C        clean runner environment (only LOGNM set, no NASTRAN_*) it
C        returns IDIAG = 0 -- the documented mechanism for establishing
C        the DISABLED path exercised here.
C
C     REFERENCE SOURCES
C       bin/nastrn.f  unit-3 / LOGNM wiring (COMMON /LOGOUT/ LOUT,
C                     LOUT=3, GETENV('LOGNM',LOG), OPEN(3,..)).
C       mis/mesage.f  legacy MESAGE targets NOUT (~unit 6), not unit 3.
C
C     DELIVERABLE ONLY -- NOT EXECUTED BY BLITZY.  Compiled and run
C     later in the developer's Solaris environment (csh + Sun f77):
C        f77 -fast -dn -o tdggrd.exe test/diag/tdggrd.f bin/nastlib.a
C     DIAGLOG and DIAGCTL are provided by bin/nastlib.a; this file is a
C     SINGLE self-contained PROGRAM unit and NEVER defines either one.
C
C     OUTPUT CONTRACT
C        Exactly one verdict is written to the LOG unit (logical unit 3
C        / LOUT):  'PASS: TDGGRD' on success, or the failure verdict on
C        any failure.  The literal failure token is emitted ONLY on a
C        genuine failure path (the verdict block below) and never in any
C        comment, banner or success text -- test/run_units.csh greps for
C        it and exits non-zero on a match.  The verdict goes to unit 3
C        only, never stdout.
C
C     ENABLE STATE (deterministic, self-sufficient)
C        IDIAG = 0 is the DISABLED / guard-return path under test.  The
C        driver obtains the disabled state from DIAGCTL (clean env) and
C        then forces IDIAG to the reference constant 0, so the disabled
C        path is exercised deterministically regardless of any stray
C        host environment.  IDIAG is a plain local INTEGER (DIAGCTL
C        output / DIAGLOG input); a direct set is fully F77-legal and
C        the modern/ "no new COMMON" rule does NOT bind this driver.
C
C     CROSS-CONSISTENCY
C        The asserted constants MUST match test/diag/tdggrd.ref
C        (DISABLED_IDIAG 0, EXPECT_UNIT3_RECORDS 0, and the verdict
C        'PASS: TDGGRD').
C
C     Fixed-form FORTRAN 77 (Sun f77 -fast -dn).  No F90+, no third-
C     party libraries.
C=====================================================================
      PROGRAM TDGGRD
C
C     ---- declarations ----------------------------------------------
      CHARACTER*80    LOG
      CHARACTER*132   LINE
      LOGICAL         OK
      INTEGER         IDIAG, IDIS, NEXP, NREC, I
      INTEGER         SAMPLE(3)
C
C     LOUT mirrors the bin/nastrn.f log-unit cell.  The modern/ "no new
C     COMMON" rule does NOT apply to test/ drivers; LOUT holds the log
C     unit number (3) and is the single verdict / capture sink.
      COMMON /LOGOUT/ LOUT
      INTEGER         LOUT
C
C     Reference constants -- MUST match test/diag/tdggrd.ref:
C        DISABLED_IDIAG       0  -> IDIS  (the disabled enable mask)
C        EXPECT_UNIT3_RECORDS 0  -> NEXP  (records expected on unit 3)
      DATA IDIS, NEXP /0, 0/
C
C     Representative IN-BAND codes (reserved 9001-9999 new-diagnostics
C     MESAGE band) used to show the guard short-circuits EVERY disabled
C     call regardless of code (idempotent silence); same band as tdgbnd.
      DATA SAMPLE /9001, 9500, 9999/
C
      OK = .TRUE.
C
C     ---- unit-3 (log) wiring -- mirror bin/nastrn.f ----------------
C     Read the log-file name from LOGNM (set per driver by
C     test/run_units.csh); fall back to a fixed name when unset so the
C     driver also runs standalone.  Open it on unit 3 and record LOUT=3
C     as the single diagnostic / verdict sink.  The blank-then-GETENV
C     receiver idiom matches bin/nastrn.f (VALUE=' ' then CALL GETENV).
      LOUT = 3
      LOG  = ' '
      CALL GETENV ('LOGNM', LOG)
      IF (LOG .EQ. ' ') LOG = 'tdggrd.log'
      OPEN (LOUT, FILE=LOG, STATUS='UNKNOWN')
C
C     Guarantee an EMPTY capture region on unit 3 before the test.  The
C     runner does not pre-remove a driver's per-run log, and an OPEN
C     with STATUS='UNKNOWN' does not truncate an existing file, so a
C     stale log from a prior run could otherwise be misread as DIAGLOG
C     output.  REWIND then ENDFILE truncates unit 3 to zero length; the
C     second REWIND repositions at the (now empty) start of file.
      REWIND (LOUT)
      ENDFILE (LOUT)
      REWIND (LOUT)
C
C     ---- establish the DISABLED diagnostic state -------------------
C     DIAGCTL is the single authority that maps the NASTRAN_*
C     environment toggles to the enable mask IDIAG.  In the clean runner
C     environment (only LOGNM set, no NASTRAN_*) it returns IDIAG = 0;
C     this is the documented mechanism for obtaining the disabled path.
      CALL DIAGCTL (IDIAG)
C
C     DETERMINISM: this guard-clause proof requires the DISABLED state
C     IDIAG = 0 (tdggrd.ref DISABLED_IDIAG 0).  Force IDIAG to the
C     reference constant IDIS so the disabled path is exercised
C     deterministically even if the host carried a stray NASTRAN_*
C     toggle.  IDIAG is a plain local INTEGER (DIAGCTL output / DIAGLOG
C     input), not COMMON state, so this direct assignment is F77-legal;
C     test drivers are not bound by the modern/ "no new COMMON" rule.
      IDIAG = IDIS
C
C     ================================================================
C     SUB-CHECK 1 (PRIMARY) and SUB-CHECK 2 (idempotent silence).
C     With diagnostics DISABLED (IDIAG = 0), call DIAGLOG once for each
C     representative in-band code.  Because the guard clause
C     IF (IDIAG .EQ. 0) RETURN is DIAGLOG's first executable statement,
C     every call must return immediately and write NOTHING to unit 3.
C     Issuing several calls with different codes shows the guard short-
C     circuits EVERY disabled call, not merely the first.
C     ================================================================
      DO 10 I = 1, 3
         CALL DIAGLOG (IDIAG, SAMPLE(I), 0, 'TDGGRD GUARD')
   10 CONTINUE
C
C     ---- verify ZERO records were written to unit 3 ----------------
C     Rewind and read every record on unit 3, counting them.  A
C     correctly guarded DIAGLOG wrote nothing, so the first READ must
C     hit END= immediately and NREC must remain 0 (== NEXP).  Any record
C     read back means the guard clause failed to short-circuit a
C     disabled call -- the zero-overhead property is violated.
      NREC = 0
      REWIND (LOUT)
   20 READ (LOUT, '(A)', END=30) LINE
      NREC = NREC + 1
      GO TO 20
   30 CONTINUE
      IF (NREC .NE. NEXP) OK = .FALSE.
C
C     ---- verdict (single line, unit 3 only) ------------------------
C     Rewind so the log holds exactly the verdict the harness greps.
C     Unit 3 was truncated to empty and no diagnostic record was
C     written, so the verdict is the sole record in the log.
      REWIND (LOUT)
      IF (OK) THEN
         WRITE (LOUT, '(A)') 'PASS: TDGGRD'
      ELSE
         WRITE (LOUT, '(A)') 'FAIL: TDGGRD'
      END IF
      CLOSE (LOUT)
      STOP
      END
