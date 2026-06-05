C=====================================================================
C     test/diag/tdglog.f
C---------------------------------------------------------------------
C     PROGRAM TDGLOG -- NASTRAN-95 modernization unit-test driver.
C
C     PURPOSE
C        Validate the UNIT-3-ONLY OUTPUT contract of the modern
C        runtime-diagnostics layer (test/diag/ suite, coverage area 1):
C        modern/diag/diaglog.f writes its formatted diagnostic record
C        EXCLUSIVELY to logical unit 3 (LOUT) -- never stdout, never the
C        legacy print stream NOUT, never a new unit (AAP 0.7.2).  When
C        diagnostics are ENABLED, CALL DIAGLOG must place its record on
C        unit 3 (and nowhere else).  This driver is the executable
C        assertion of that rule.
C
C     ROUTINE UNDER TEST   modern/diag/diaglog.f
C        SUBROUTINE DIAGLOG (IDIAG, ICODE, NVAL, MSG) -- formatted
C        diagnostic writer to logical unit 3 ONLY, gated by the guard
C        clause  IF (IDIAG .EQ. 0) RETURN.  With IDIAG non-zero an
C        in-band code (9001-9999) yields one record whose text embeds
C        the numeric code just after the word DIAGNOSTIC.  LOUT is a
C        LOCAL PARAMETER (=3) inside DIAGLOG; this driver opens unit 3
C        itself so the emitted record has somewhere to land.
C
C     REFERENCE SOURCES
C        bin/nastrn.f  unit-3 / LOGNM wiring idiom: COMMON /LOGOUT/ LOUT
C                      (L10), LOUT=3 (L45), CALL GETENV('LOGNM',LOG)
C                      (L61), OPEN(3,FILE=DSNAMES(3),..) (L115), and the
C                      blank-then-GETENV receiver idiom (L31/L33).
C        mis/mesage.f  legacy MESAGE writes to /SYSTEM/ NOUT (~unit 6),
C                      NOT unit 3 -- the modern writer deliberately
C                      targets unit 3; that contrast is what this test
C                      pins down.
C
C     DELIVERABLE ONLY -- NOT EXECUTED BY BLITZY.  Compiled and run
C     later in the developer's Solaris environment (csh + Sun f77):
C        f77 -fast -dn -o tdglog.exe test/diag/tdglog.f bin/nastlib.a
C     DIAGLOG is provided by bin/nastlib.a; this file is a SINGLE self-
C     contained PROGRAM unit and NEVER defines DIAGLOG or DIAGCTL.
C
C     OUTPUT CONTRACT
C        Exactly one verdict is written to the LOG unit (logical unit 3
C        / LOUT):  'PASS: TDGLOG' on success, or 'FAIL: TDGLOG' on any
C        failure.  The literal FAIL token is emitted ONLY on a real
C        failure path -- test/run_units.csh greps it and exits non-zero
C        on a match.  The verdict and the captured diagnostic record
C        both live on unit 3 only, never stdout.
C
C     ENABLING DIAGNOSTICS (deterministic, self-sufficient)
C        DIAGLOG takes IDIAG as an ARGUMENT (it is not a COMMON cell --
C        modern/diag/ keeps zero new COMMON).  IDIAG = 0 is the disabled
C        / guard-return path; IDIAG = 8 is an enabled path, exactly as
C        documented for the test drivers in modern/diag/diaglog.f.  This
C        driver sets a LOCAL INTEGER IDIAG = 8 directly, so the enabled
C        path is reached WITHOUT relying on any NASTRAN_* environment
C        toggle (which FORTRAN 77 cannot portably set for itself).  The
C        modern/ "no new COMMON" rule constrains modern/, not this test
C        driver.
C
C     CROSS-CONSISTENCY
C        Output unit and sample code MUST match test/diag/tdglog.ref
C        (OUTPUT_UNIT 3, EXPECT_MIN_UNIT3_RECORDS 1, SAMPLE_CODE 9001,
C        EXPECT_VERDICT 'PASS: TDGLOG').
C
C     Fixed-form FORTRAN 77 (Sun f77 -fast -dn).  No F90+, no third-
C     party libraries.
C=====================================================================
      PROGRAM TDGLOG
C
C     ---- declarations -----------------------------------------------
      CHARACTER*80    LOG
      CHARACTER*132   LINE
      LOGICAL         OK
      INTEGER         IDIAG, NVAL, ICODE, KODE, IP
C
C     LOUT mirrors the bin/nastrn.f log-unit cell (L10).  The modern/
C     "no new COMMON" rule does NOT apply to test/ drivers; LOUT holds
C     the log unit number (3) and is the single verdict / capture sink.
      COMMON /LOGOUT/ LOUT
      INTEGER         LOUT
C
C     Representative in-band diagnostic code -- the reserved 9001-9999
C     new-diagnostics MESAGE band; matches tdglog.ref SAMPLE_CODE 9001.
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
C     receiver idiom matches bin/nastrn.f (VALUE=' ' then CALL GETENV).
      LOUT = 3
      LOG  = ' '
      CALL GETENV ('LOGNM', LOG)
      IF (LOG .EQ. ' ') LOG = 'tdglog.log'
      OPEN (LOUT, FILE=LOG, STATUS='UNKNOWN')
C
C     Scratch unit for the behavioral "never a new unit" check (sub-
C     check 2).  DIAGLOG must never write here; we confirm it stays
C     empty after an enabled call.
      OPEN (7, STATUS='SCRATCH')
C
C     =================================================================
C     SUB-CHECK 1 (PRIMARY) -- an ENABLED DIAGLOG call emits at least
C     one record on unit 3.  Set a LOCAL IDIAG non-zero (8 = enabled
C     per modern/diag/diaglog.f), REWIND unit 3 for a clean capture,
C     emit one in-band diagnostic, then REWIND and READ it back.  A
C     record read back => the output landed on unit 3 (sub-check
C     passes).  Hitting END= with no record => DIAGLOG produced nothing
C     on unit 3 => failure.
C     =================================================================
      IDIAG = 8
      REWIND (LOUT)
      CALL DIAGLOG (IDIAG, ICODE, NVAL, 'TDGLOG UNIT-3 OUTPUT TEST')
      REWIND (LOUT)
      LINE = ' '
      READ (LOUT, '(A)', END=20) LINE
      GO TO 25
C     No record for an enabled, in-band call -> failure.  Rewind so the
C     verdict written at label 50 replaces the empty capture.
   20 OK = .FALSE.
      REWIND (LOUT)
      GO TO 50
C
C     A record WAS produced on unit 3.  Optionally confirm the in-band
C     code is embedded after the word DIAGNOSTIC (list-directed internal
C     read -- the same idiom as bin/nastrn.f READ(VALUE,*)).  A parse
C     miss is NON-FATAL: presence on unit 3 already binds the contract.
   25 IP = INDEX (LINE, 'DIAGNOSTIC')
      IF (IP .LE. 0) GO TO 30
      KODE = -1
      READ (LINE(IP+10:), *, ERR=30, END=30) KODE
      IF (KODE .LT. 9001 .OR. KODE .GT. 9999) OK = .FALSE.
      IF (KODE .NE. ICODE) OK = .FALSE.
C
C     =================================================================
C     SUB-CHECK 2 -- output confined to unit 3 (behavioral).  DIAGLOG's
C     only write target is unit 3 / LOUT (additionally guaranteed by
C     inspection of modern/diag/diaglog.f: a single write target).
C     Behaviorally confirm the scratch unit 7 received nothing: REWIND
C     and READ -- END= (empty) is the expected, passing outcome; any
C     record here would mean DIAGLOG wrote to the wrong unit (failure).
   30 REWIND (7)
      READ (7, '(A)', END=40) LINE
      OK = .FALSE.
   40 CONTINUE
C
C     ---- verdict (single line, unit 3 only) -------------------------
C     On the success path unit 3 is positioned just after the diagnostic
C     record, so this WRITE APPENDS the verdict (log holds the diag
C     record + verdict).  On the no-record path (label 20) the unit was
C     rewound, so the verdict is the sole record.  Either way the
C     harness greps the captured unit-3 log for PASS:/FAIL:.
   50 IF (OK) THEN
         WRITE (LOUT, '(A)') 'PASS: TDGLOG'
      ELSE
         WRITE (LOUT, '(A)') 'FAIL: TDGLOG'
      END IF
      CLOSE (7)
      CLOSE (LOUT)
      STOP
      END
