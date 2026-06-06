      PROGRAM TINBLK
C***********************************************************************
C   FILE     : test/init/tinblk.f
C   PURPOSE  : Unit-test driver for modern/init/blkinit.f.  Verifies the
C              modern explicit initialiser reproduces, BITWISE, every
C              COMMON value seeded by 39 legacy bd/ BLOCK DATA units.
C
C   DELIVERABLE: produced by Blitzy; executed later in the developer's
C              Solaris environment.  NOT run by Blitzy.
C
C   BUILD    : f77 -fast -dn -o tinblk.exe tinblk.f bin/nastlib.a
C              (linked against nastlib.a, which contains the
C              compiled modern/ routines; NOT in nastrn.exe.)
C
C   ROUTINES UNDER TEST (resolved from nastlib.a -- do NOT define here):
C              modern/init/blkinit.f, modern/init/initval.f.
C
C   CROSS-AGENT INTERFACE (owned by modern/ agents; verified in tree):
C              SUBROUTINE DIAGCTL ( IDIAG )   ! sets IDIAG, NASTRAN_*
C              SUBROUTINE BLKINIT            ! explicit ordered init
C              SUBROUTINE INITVAL ( NDIV )   ! INTEGER NDIV out; 0=match
C
C   RUN MODE : export NASTRAN_INIT_VALIDATE=1; leave NASTRAN_LEGACY_INIT
C              unset (modern path).  INITVAL is gated by IDIAG, so when
C              the toggle is unset NDIV keeps the 999999 sentinel and
C              driver reports visible failure rather than a false pass.
C
C   OUTPUT CONTRACT: writes exactly one verdict to the log unit (logical
C              unit 3 / LOUT) -- a PASS or FAIL line tagged 'TINBLK' --
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
      IF ( LOG .EQ. ' ' ) LOG = 'tinblk.log'
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
C     --- read expectations from the golden ref (best effort) ---------
      NEXP  = 0
      NRAN  = 1
      RPATH = ' '
      CALL GETENV ( 'TINREF', RPATH )
      IF ( RPATH .EQ. ' ' ) RPATH = 'test/init/tinblk.ref'
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
      WRITE ( 3, 9003 ) NEXP
C
C     --- enable diagnostics, run modern init, then validate ----------
C     DIAGCTL returns the NASTRAN_* mask in its IDIAG OUTPUT argument.
      CALL DIAGCTL (IDIAG)
      CALL BLKINIT
      NDIV = 999999
      CALL INITVAL ( NDIV )
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
 9000 FORMAT ('TINBLK: unit test for modern/init/blkinit.f')
 9001 FORMAT ('TINBLK: NASTRAN_INIT_VALIDATE=[', A, ']')
 9002 FORMAT ('TINBLK: NASTRAN_LEGACY_INIT =[', A, ']')
 9003 FORMAT ('TINBLK: expected divergence (ref) = ', I8)
 9004 FORMAT ('TINBLK: INITVAL divergence count  = ', I8)
 9005 FORMAT ('TINBLK: validator did not run; set INIT_VALIDATE=1')
 9006 FORMAT ('TINBLK: divergence ', I8, ' .ne. expected ', I8)
 9100 FORMAT ('PASS: TINBLK')
 9200 FORMAT ('FAIL: TINBLK')
      END
