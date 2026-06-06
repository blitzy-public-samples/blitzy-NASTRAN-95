      PROGRAM TINVAL
C***********************************************************************
C   FILE     : test/init/tinval.f
C   PURPOSE  : Unit-test driver for modern/init/initval.f.  Verifies the
C              initialisation-state validator (a) honours the
C              NASTRAN_INIT_VALIDATE gate (it actually executes), (b)
C              reports zero divergence after a correct modern init, and
C              (c) is side-effect-free: a second call returns the same
C              count.
C
C   DELIVERABLE: produced by Blitzy; executed later in the developer's
C              Solaris environment.  NOT run by Blitzy.
C
C   BUILD    : f77 -fast -dn -o tinval.exe tinval.f bin/nastlib.a
C
C   ROUTINES UNDER TEST (resolved from nastlib.a -- do NOT define here):
C              modern/init/initval.f (with modern/init/blkinit.f used to
C              establish a correct state first).
C
C   CROSS-AGENT INTERFACE (owned by modern/ agents; verified in tree):
C              SUBROUTINE DIAGCTL ( IDIAG )   ! sets IDIAG, NASTRAN_*
C              SUBROUTINE BLKINIT            ! explicit ordered init
C              SUBROUTINE INITVAL (IDIAG,NDIV) ! IDIAG in (guard 1st),
C                                            ! INTEGER NDIV out; 0=match
C
C   RUN MODE : export NASTRAN_INIT_VALIDATE=1; leave NASTRAN_LEGACY_INIT
C              unset.  The 999999 sentinel makes a disabled validator a
C              visible failure rather than a false pass.
C
C   OUTPUT CONTRACT: writes exactly one verdict to the log unit (logical
C              unit 3 / LOUT) -- a PASS or FAIL line tagged 'TINVAL' --
C              consumed by test/run_units.csh, which greps the log for
C              the failure tag and exits non-zero on a match.
C***********************************************************************
      COMMON / LOGOUT / LOUT
      INTEGER          LOUT
      INTEGER          NDIV1, NDIV2, NEXP, NRAN, IVAL, IDIAG
      LOGICAL          OK
      CHARACTER*80     LOG, RPATH, BUF
      CHARACTER*16     KEY
C
C     --- connect the log unit exactly as bin/nastrn.f does -----------
      LOG = ' '
      CALL GETENV ( 'LOGNM', LOG )
      IF ( LOG .EQ. ' ' ) LOG = 'tinval.log'
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
      IF ( RPATH .EQ. ' ' ) RPATH = 'test/init/tinval.ref'
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
C     --- establish a correct state, then validate twice --------------
C     DIAGCTL returns the NASTRAN_* mask in its IDIAG OUTPUT argument.
      CALL DIAGCTL (IDIAG)
      CALL BLKINIT
      NDIV1 = 999999
      CALL INITVAL ( IDIAG, NDIV1 )
      NDIV2 = 999999
      CALL INITVAL ( IDIAG, NDIV2 )
      WRITE ( 3, 9004 ) NDIV1, NDIV2
C
C     --- evaluate: gate honoured, zero divergence, idempotent --------
      IF ( NRAN .EQ. 1 .AND. NDIV1 .EQ. 999999 ) THEN
         WRITE ( 3, 9005 )
         OK = .FALSE.
      END IF
      IF ( NDIV1 .NE. NEXP ) THEN
         WRITE ( 3, 9006 ) NDIV1, NEXP
         OK = .FALSE.
      END IF
      IF ( NDIV2 .NE. NDIV1 ) THEN
         WRITE ( 3, 9007 ) NDIV1, NDIV2
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
 9000 FORMAT ('TINVAL: unit test for modern/init/initval.f')
 9001 FORMAT ('TINVAL: NASTRAN_INIT_VALIDATE=[', A, ']')
 9002 FORMAT ('TINVAL: NASTRAN_LEGACY_INIT =[', A, ']')
 9004 FORMAT ('TINVAL: INITVAL counts (call1,call2) = ', I8, I8)
 9005 FORMAT ('TINVAL: validator did not run; set INIT_VALIDATE=1')
 9006 FORMAT ('TINVAL: divergence ', I8, ' .ne. expected ', I8)
 9007 FORMAT ('TINVAL: not idempotent: ', I8, ' .ne. ', I8)
 9100 FORMAT ('PASS: TINVAL')
 9200 FORMAT ('FAIL: TINVAL')
      END
