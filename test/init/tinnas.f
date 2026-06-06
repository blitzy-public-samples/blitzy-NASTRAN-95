      PROGRAM TINNAS
C***********************************************************************
C   FILE     : test/init/tinnas.f
C   PURPOSE  : Unit-test driver for modern/init/nastinit.f. Verifies the
C              single init entry point orchestrates the explicit modern
C              init path under the default toggle state: after a bare
C              CALL NASTINIT the COMMON state must validate with zero
C              divergence (proving NASTINIT drove blkinit internally).
C
C   DELIVERABLE: produced by Blitzy; executed later in the developer's
C              Solaris environment.  NOT run by Blitzy.
C
C   BUILD    : f77 -fast -dn -o tinnas.exe tinnas.f bin/nastlib.a
C
C   ROUTINES UNDER TEST (resolved from nastlib.a -- do NOT define here):
C              modern/init/nastinit.f (exercised end to end), with
C              modern/init/initval.f used for independent post-check.
C
C   CROSS-AGENT ASSUMED INTERFACE (owned by modern/ agents):
C              SUBROUTINE NASTINIT           ! no args; reads
C                                            ! NASTRAN_LEGACY_INIT
C              SUBROUTINE DIAGCTL ( IDIAG )  ! sets IDIAG from NASTRAN_*
C              SUBROUTINE INITVAL (IDIAG,NDIV) ! IDIAG in (guard 1st),
C                                            ! INTEGER NDIV out; 0=match
C
C   TOGGLE ASSUMPTION (flagged for maintainer confirmation):
C              NASTRAN_LEGACY_INIT unset (default) -> modern explicit
C              path (NASTINIT calls BLKINIT).  The legacy path (toggle
C              set) is proven equivalent by the regression harness, not
C              by this unit driver.  Run with NASTRAN_INIT_VALIDATE=1.
C
C   OUTPUT CONTRACT: writes exactly one verdict to the log unit (logical
C              unit 3 / LOUT) -- a PASS or FAIL line tagged 'TINNAS' --
C              consumed by test/run_units.csh, which greps the log for
C              the failure tag and exits non-zero on a match.
C***********************************************************************
      COMMON / LOGOUT / LOUT
      INTEGER          LOUT
      INTEGER          NDIV, NEXP, NRAN, IVAL, IDIAG
      LOGICAL          OK
      CHARACTER*80     LOG, RPATH, BUF
      CHARACTER*16     KEY
C
C     --- connect the log unit exactly as bin/nastrn.f does -----------
      LOG = ' '
      CALL GETENV ( 'LOGNM', LOG )
      IF ( LOG .EQ. ' ' ) LOG = 'tinnas.log'
      OPEN ( UNIT=3, FILE=LOG, STATUS='UNKNOWN' )
      LOUT = 3
      OK   = .TRUE.
      WRITE ( 3, 9000 )
C
C     --- echo run-mode toggles (informational; never a FAIL token) ---
      BUF = ' '
      CALL GETENV ( 'NASTRAN_INIT_VALIDATE', BUF )
      WRITE ( 3, 9001 ) BUF(1:16)
      BUF = ' '
      CALL GETENV ( 'NASTRAN_LEGACY_INIT', BUF )
      WRITE ( 3, 9002 ) BUF(1:16)
C
C     --- read expectations from the ref (best effort) ----------------
      NEXP  = 0
      NRAN  = 1
      RPATH = ' '
      CALL GETENV ( 'TINREF', RPATH )
      IF ( RPATH .EQ. ' ' ) RPATH = 'test/init/tinnas.ref'
      OPEN ( UNIT=8, FILE=RPATH, STATUS='OLD', ERR=200 )
  100 READ ( 8, '(A)', END=190 ) BUF
      IF ( BUF(1:1) .EQ. '#' ) GO TO 100
      IF ( BUF .EQ. ' ' )      GO TO 100
      READ ( BUF, *, ERR=100 ) KEY, IVAL
      IF ( KEY .EQ. 'EXPDIV' ) NEXP = IVAL
      IF ( KEY .EQ. 'EXPRAN' ) NRAN = IVAL
      GO TO 100
  190 CLOSE ( UNIT=8 )
  200 CONTINUE
C
C     --- exercise the orchestrator, then independently validate ------
C     DIAGCTL returns the NASTRAN_* mask in its IDIAG OUTPUT argument;
C     INITVAL takes IDIAG as its first argument so its guard is the
C     first executable statement (Binding Rule R10).
      CALL NASTINIT
      CALL DIAGCTL ( IDIAG )
      NDIV = 999999
      CALL INITVAL ( IDIAG, NDIV )
      WRITE ( 3, 9004 ) NDIV
C
C     --- evaluate the result -----------------------------------------
      IF ( NRAN .EQ. 1 .AND. NDIV .EQ. 999999 ) THEN
         WRITE ( 3, 9005 )
         OK = .FALSE.
      END IF
      IF ( NDIV .NE. NEXP ) THEN
         WRITE ( 3, 9006 ) NDIV, NEXP
         OK = .FALSE.
      END IF
C
      IF ( OK ) THEN
         WRITE ( 3, 9100 )
      ELSE
         WRITE ( 3, 9200 )
      END IF
      CLOSE ( UNIT=3 )
      STOP
C
 9000 FORMAT ('TINNAS: unit test for modern/init/nastinit.f')
 9001 FORMAT ('TINNAS: NASTRAN_INIT_VALIDATE=[', A, ']')
 9002 FORMAT ('TINNAS: NASTRAN_LEGACY_INIT =[', A, ']')
 9004 FORMAT ('TINNAS: post-NASTINIT divergence  = ', I8)
 9005 FORMAT ('TINNAS: validator did not run; set INIT_VALIDATE=1')
 9006 FORMAT ('TINNAS: divergence ', I8, ' .ne. expected ', I8)
 9100 FORMAT ('PASS: TINNAS')
 9200 FORMAT ('FAIL: TINNAS')
      END
