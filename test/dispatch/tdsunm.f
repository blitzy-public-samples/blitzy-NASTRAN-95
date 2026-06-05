C=====================================================================
C     test/dispatch/tdsunm.f
C---------------------------------------------------------------------
C     PROGRAM TDSUNM -- NASTRAN-95 modernization unit-test driver.
C
C     PURPOSE
C        Validate UNMAPPED -> FATAL (test/dispatch/ suite, coverage
C        area 4):  an unmapped / out-of-range MODX code -- and the
C        in-range slots 1,2,4 that the legacy ladder routes to its
C        GO TO 940 fall-through -- must reach a FATAL MESAGE in the
C        modern dispatcher modern/dispatch/disptbl.f.  Per AAP 0.7.2 a
C        NEW fatal MESAGE code must lie in the 9001-9999 band, so this
C        driver asserts the captured fatal code is negative with IABS
C        in [9001,9999] rather than accepting the legacy code -37.
C
C     ROUTINE UNDER TEST   modern/dispatch/disptbl.f
C        Table-driven OSCAR MODX dispatcher.  This driver only CALLs
C        DISPTBL; DISPTBL is resolved from bin/nastlib.a at link time
C        and is NEVER defined in this file.
C
C     CROSS-AGENT ASSUMED INTERFACE  (reconcile with the real source)
C        modern/dispatch/disptbl.f is authored in the SAME build
C        phase.  The interface assumed here is
C           CALL DISPTBL (MODX)
C        a table-driven dispatcher that, for an unmapped/out-of-range
C        MODX, issues a FATAL  CALL MESAGE (<negative code>,...)  and
C        RETURNs without CALLing any module.  The negative code's
C        magnitude must lie in 9001..9999 (AAP band for new codes).
C        If the real disptbl reused a legacy code (e.g. -37), the band
C        assertion below would (correctly) FAIL -- a cross-agent
C        signal that the modern dispatcher must adopt a 9001-9999
C        unmapped-fatal code.  The real disptbl.f was reconciled and
C        uses  CALL MESAGE (-9301,MODX,SUBNAM), so |NO|=9301 is in
C        band and this driver's assertion is satisfied.
C
C     LINK-OVERRIDE TECHNIQUE  (central -- intentional and standard)
C        This driver PROVIDES its own TMTOGO and MESAGE (after the
C        program END, in this same file) so the dispatcher's fatal
C        path can be OBSERVED without aborting the process.  With the
C        standard Unix link
C           f77 -fast -dn -o tdsunm.exe test/dispatch/tdsunm.f
C           bin/nastlib.a
C        the command-line object (this driver) resolves TMTOGO and
C        MESAGE BEFORE the archive, so mis/tmtogo.o and mis/mesage.o
C        are NOT pulled (no duplicate-symbol error).  DISPTBL is
C        pulled from the archive and its internal CALL TMTOGO / CALL
C        MESAGE bind to the driver stubs.  The ~188 module subroutines
C        referenced by DISPTBL are resolved from the archive but are
C        NEVER executed on the fatal / reserved-no-op paths exercised
C        here.  FALLBACK: should a stricter Solaris linker object to
C        the override, compile the two stubs into a separate object
C        and place it BEFORE bin/nastlib.a on the link line (the same
C        precedence rule yields the identical effect).
C
C     /SYSTEM/ AVOIDANCE
C        The driver does NOT declare /SYSTEM/ (its overlay differs
C        across files).  The TMTOGO stub simply fills the passed
C        TOGO/KTIME argument with a large positive value so the
C        dispatcher's time-budget guard (IF (KTIME .LE. 0) ...) is
C        NOT taken and cannot pollute the captured fatal code.
C
C     TEST CODES  (hardcoded; mirrored in test/dispatch/tdsunm.ref)
C        OUT_OF_RANGE  : 0, -1, 218   (MODX <= 0 or >= 218)
C        INRANGE_FATAL : 1, 2, 4      (in-range slots that fall to the
C                                      legacy GO TO 940 fatal path)
C        BAND          : 9001 .. 9999 (AAP new-message-code band)
C        RESERVED      : 25 (also 36) valid no-ops -- NOT fatal; 25 is
C                                      used below as a negative control
C
C     OUTPUT CONTRACT
C        Exactly one verdict to the log unit (logical unit 3 / LOUT):
C        'PASS: TDSUNM' on success, else 'FAIL: TDSUNM'.  The literal
C        failure token appears ONLY on the genuine failure branch --
C        test/run_units.csh greps captured output for 'FAIL:' and
C        exits non-zero on a match -- so it is in NO banner/info line.
C
C     DELIVERABLE ONLY -- NOT EXECUTED BY BLITZY.  Compiled and run
C        later in the developer's Solaris environment (csh + Sun f77).
C        This is a SINGLE self-contained file: exactly one PROGRAM
C        plus the local TMTOGO and MESAGE stubs; it never defines
C        DISPTBL.  Fixed-form FORTRAN 77 only (Sun f77 -fast -dn).
C
C     SENTINEL code sets and band bounds are kept identical to the
C        KEY/VALUE lines of test/dispatch/tdsunm.ref (consistency
C        coupling): OUT_OF_RANGE, INRANGE_FATAL, BAND_LOW/BAND_HIGH,
C        and RESERVED_SAMPLE.
C=====================================================================
      PROGRAM TDSUNM
C
C     ---- declarations ---------------------------------------------
      CHARACTER*80    LOG
      LOGICAL         OK
      INTEGER         KODES(6), ILOW, IHIGH, K, I, IAB
C     Shared cells: the MESAGE stub WRITES (LASTNO,NCALL) and this
C     program READS them through COMMON /TMESG/.  LOUT is the NASTRAN
C     log-unit cell, set to 3 exactly as the bin/nastrn.f bootstrap
C     does.  No /SYSTEM/ and no re-declared dispatcher COMMON appear
C     anywhere in this driver.
      INTEGER         LASTNO, NCALL, LOUT
      COMMON /LOGOUT/ LOUT
      COMMON /TMESG/  LASTNO, NCALL
C
C     The six fatal test codes, in the SAME order as the OUT_OF_RANGE
C     then INRANGE_FATAL lines of test/dispatch/tdsunm.ref.
      DATA KODES / 0, -1, 218, 1, 2, 4 /
C
      OK    = .TRUE.
      ILOW  = 9001
      IHIGH = 9999
C
C     ---- unit-3 (log) wiring -- mirror bin/nastrn.f ---------------
C     Read the log-file name from LOGNM (set per driver by
C     test/run_units.csh); fall back to a fixed name when unset so the
C     driver also runs standalone.  Open it on the LITERAL unit 3 and
C     record the unit in /LOGOUT/ LOUT exactly as the bootstrap does.
      LOG = ' '
      CALL GETENV ('LOGNM', LOG)
      IF (LOG .EQ. ' ') LOG = 'tdsunm.log'
      OPEN (3, FILE=LOG, STATUS='UNKNOWN')
      LOUT = 3
C
C     =================================================================
C     SUB-CHECK 1 -- each fatal code triggers a FATAL MESAGE in-band.
C     For every code: clear the capture cells, drive the dispatcher,
C     then require (a) a fatal MESAGE was issued (NCALL>=1 and NO<0)
C     and (b) the fatal code lies in 9001..9999 (IABS of NO).  The
C     TMTOGO stub keeps the dispatcher off its -50 time-fatal branch,
C     so the ONLY captured fatal is the unmapped/in-range-fatal one.
C     =================================================================
      DO 100 I = 1, 6
         K      = KODES(I)
         NCALL  = 0
         LASTNO = 0
         CALL DISPTBL (K)
         IAB = IABS(LASTNO)
         IF (.NOT. (NCALL .GE. 1 .AND. LASTNO .LT. 0)) THEN
            OK = .FALSE.
            WRITE (3,9100) K
         ELSE IF (IAB .LT. ILOW .OR. IAB .GT. IHIGH) THEN
            OK = .FALSE.
            WRITE (3,9101) K, LASTNO
         END IF
  100 CONTINUE
C
C     =================================================================
C     SUB-CHECK 2 -- reserved no-op is NOT fatal (negative control).
C     MODX 25 is a RESERVED no-op slot (a valid CONTINUE in the
C     dispatcher), so driving it must NOT capture any fatal MESAGE.
C     This guards against a dispatcher that over-eagerly treats a
C     reserved slot as unmapped.
C     =================================================================
      NCALL  = 0
      LASTNO = 0
      CALL DISPTBL (25)
      IF (NCALL .GE. 1 .AND. LASTNO .LT. 0) THEN
         OK = .FALSE.
         WRITE (3,9102)
      END IF
C
C     ---- verdict (single line, unit 3 only) -----------------------
C     The failure token 'FAIL:' is written ONLY in the .NOT. OK
C     branch; it appears nowhere else in this file.
      WRITE (3,'(A)') ' TDSUNM UNMAPPED-FATAL SUITE COMPLETE'
      IF (OK) THEN
         WRITE (3,'(A)') 'PASS: TDSUNM'
      ELSE
         WRITE (3,'(A)') 'FAIL: TDSUNM'
      END IF
      CLOSE (3)
C
C     ---- informational formats (no failure token) -----------------
 9100 FORMAT (' NO FATAL CAPTURED MODX=', I6)
 9101 FORMAT (' FATAL OUT OF BAND MODX=', I6, ' NO=', I8)
 9102 FORMAT (' RESERVED SLOT FATAL MODX=25')
C
      STOP
      END
C=====================================================================
C     Driver-local stub: TMTOGO (exact legacy signature).
C     mis/tmtogo.f is  SUBROUTINE TMTOGO (TOGO); INTEGER TOGO.  This
C     stub returns a large POSITIVE budget so the dispatcher's
C     IF (KTIME .LE. 0) time-fatal guard is NOT taken -- the only
C     fatal the test captures is the unmapped/in-range-fatal one.
C=====================================================================
      SUBROUTINE TMTOGO (TOGO)
      INTEGER TOGO
      TOGO = 1000000
      RETURN
      END
C=====================================================================
C     Driver-local stub: MESAGE (exact legacy signature).
C     mis/mesage.f is  SUBROUTINE MESAGE (NO,PARM,NAME)  with
C     INTEGER PARM,NAME(2); there NO .LE. 0 is the FATAL path that
C     normally terminates the run.  This stub instead CAPTURES NO into
C     COMMON /TMESG/ (and counts the call) and RETURNs, so the test
C     can observe that the fatal path was taken WITHOUT aborting.
C     NAME is declared NAME(2) to accept the legacy 2-word name arg.
C=====================================================================
      SUBROUTINE MESAGE (NO,PARM,NAME)
      INTEGER NO, PARM, NAME(2)
      COMMON /TMESG/  LASTNO, NCALL
      NCALL  = NCALL + 1
      LASTNO = NO
      RETURN
      END
