C=====================================================================
C     test/dispatch/tdscnt.f
C---------------------------------------------------------------------
C     PROGRAM TDSCNT -- NASTRAN-95 modernization unit-test driver.
C
C     PURPOSE
C        Validate the ENTRY-COUNT success criterion (test/dispatch/
C        suite, coverage area 1):  the modern OSCAR dispatcher must
C        account for EVERY catalogued MODX code with no gaps, no
C        duplicates, and no in-range unmapped codes.  Concretely, the
C        dispatch validator modern/dispatch/dispval.f must report an
C        ENTRY COUNT equal to the catalogued MODX count of 217, with
C        ZERO duplicate codes and ZERO in-range unmapped codes.  This
C        is the executable form of the AAP success criterion: "the
C        dispatcher's entry count equals the catalogued MODX count
C        with zero omissions."
C
C     ROUTINE UNDER TEST   modern/dispatch/dispval.f
C        OSCAR dispatch-table validator.  This driver only CALLs
C        DISPVAL; DISPVAL (and its companion classifier DSPMAP) are
C        resolved from bin/nastlib.a at link time and are NEVER
C        defined in this file.  Counting the catalogued entries is a
C        NON-EXECUTING catalog query: DISPVAL enumerates the MODX
C        table as DATA and never CALLs any dispatched module, so no
C        solver code runs and no global state is touched.
C
C     CROSS-AGENT INTERFACE  (ASSUMED at authoring -> RECONCILED)
C        modern/dispatch/dispval.f is authored by the dispatch agent
C        in the SAME build phase.  The interface ASSUMED by the
C        original task was
C           CALL DISPVAL (NENT, NDUP, NUNMAP, IST)
C        RECONCILED against the real source: the authoritative
C        signature is
C           SUBROUTINE DISPVAL (IDIAG, NENT, NDUP, NUNMAP, IST)
C        i.e. IDIAG is the LEADING argument (matching the project-wide
C        convention that IDIAG is ALWAYS an argument and NEVER a
C        COMMON cell; cf. the sibling STATEVAL(IDIAG,IST)).  DISPVAL
C        begins with the mandatory guard  IF (IDIAG .EQ. 0) RETURN ,
C        so when IDIAG = 0 it returns leaving the OUTPUT arguments
C        UNDEFINED.  A caller that wants results MUST therefore pass a
C        NON-ZERO IDIAG.  This driver passes IDIAG = 4 (the
C        NASTRAN_DISPATCH_VALIDATE bit), exactly as prescribed by the
C        dispval.f header, so the full enumeration runs and the four
C        OUTPUT counters are defined.  ARGUMENTS:
C           IDIAG  (INPUT)  diagnostic bitmask; 4 = DISPATCH_VALIDATE.
C           NENT   (OUTPUT) count of catalogued dispatch entries
C                           (mapped + reserved + in-range fatal); = 217.
C           NDUP   (OUTPUT) count of duplicate MODX codes; = 0.
C           NUNMAP (OUTPUT) count of in-range MODX with no disposition
C                           (gap detector); = 0.
C           IST    (OUTPUT) overall status: 0 = OK, non-zero = failure.
C
C     NON-EXECUTING / NO STUBS
C        Unlike the sibling drivers tdstmt.f and tdsunm.f -- which
C        drive DISPTBL and therefore supply local TMTOGO / MESAGE
C        stubs to count or capture calls -- this driver needs NO
C        stubs.  DISPVAL never calls TMTOGO, and its only fatal
C        MESAGE (-9301 on a genuine in-range gap, IKIND = 3) cannot
C        fire for the complete 1..217 table, so DISPVAL never aborts.
C        tdscnt.f therefore links the REAL mis/mesage.o safely and is
C        a SINGLE self-contained PROGRAM unit with nothing after END.
C        DISPVAL routes its summary through DIAGLOG to logical unit 3
C        (codes 9300/9302/9303/9304/9399); none of that text contains
C        the literal failure token, so it cannot trip the runner grep.
C
C     EXPECTED VALUES  (hardcoded; mirrored in test/dispatch/tdscnt.ref)
C        Per the validated catalog extracted from the FROZEN
C        mis/xsem00.f dispatch ladder [L200 MODX extraction; ladder at
C        label 1000]:
C           NEXP   = 217   total catalogued MODX slots (each 1..217
C                          appears exactly once).
C           NDUPEX = 0     expected duplicate codes.
C           NUNMEX = 0     expected in-range unmapped codes.
C        DOCUMENTARY SUB-COUNTS (also in tdscnt.ref; NOT asserted here
C        because the real DISPVAL signature does NOT expose them):
C           193 CALL slots, 188 distinct subroutines (XCEI shared by
C           MODX 5,6,7,11,12,13), 21 RESERVED no-op CONTINUE slots,
C           3 in-range FATAL slots {1,2,4}.  193 + 21 + 3 = 217.
C        If a future DISPVAL revision also returns these sub-counts,
C        they should be asserted against the constants above; until
C        then Sub-checks 1 and 2 are the binding criteria.
C
C     OUTPUT CONTRACT
C        Exactly one verdict to the log unit (logical unit 3 / LOUT):
C        'PASS: TDSCNT' on success, else 'FAIL: TDSCNT'.  The literal
C        failure token appears ONLY on the genuine failure branch --
C        test/run_units.csh greps captured output for 'FAIL:' and
C        exits non-zero on a match -- so it is in NO banner/info line.
C
C     DELIVERABLE ONLY -- NOT EXECUTED BY BLITZY.  Compiled and run
C        later in the developer's Solaris environment (csh + Sun f77)
C        via  f77 -fast -dn -o <exe> test/dispatch/tdscnt.f
C        bin/nastlib.a .  Fixed-form FORTRAN 77 only (Sun f77
C        -fast -dn).  Mirrors the bin/nastrn.f unit-3 / log wiring.
C=====================================================================
      PROGRAM TDSCNT
C
C     ---- declarations ---------------------------------------------
      CHARACTER*80    LOG
      LOGICAL         OK
C     IDIAG is the LEADING DISPVAL argument (NOT a COMMON cell); the
C     four counters NENT/NDUP/NUNMAP/IST are its OUTPUTs.  NEXP/NDUPEX/
C     NUNMEX are the hardcoded expected constants (cited from the
C     mis/xsem00.f catalog; kept in sync with test/dispatch/tdscnt.ref).
      INTEGER         IDIAG, NENT, NDUP, NUNMAP, IST
      INTEGER         NEXP, NDUPEX, NUNMEX
C     LOUT is the NASTRAN log-unit cell, set to 3 exactly as the
C     bin/nastrn.f bootstrap does.  No /SYSTEM/ and no re-declared
C     dispatcher COMMON appear anywhere in this driver.
      INTEGER         LOUT
      COMMON /LOGOUT/ LOUT
C     Expected catalog counts (FROZEN mis/xsem00.f): TOTAL = 217,
C     duplicates = 0, in-range unmapped = 0.
      DATA            NEXP /217/, NDUPEX /0/, NUNMEX /0/
C
      OK = .TRUE.
C
C     ---- unit-3 (log) wiring -- mirror bin/nastrn.f ---------------
C     Read the log-file name from LOGNM (set per driver by
C     test/run_units.csh); fall back to a fixed name when unset so the
C     driver also runs standalone.  Open it on the LITERAL unit 3 and
C     record the unit in /LOGOUT/ LOUT exactly as the bootstrap does.
      LOG = ' '
      CALL GETENV ('LOGNM', LOG)
      IF (LOG .EQ. ' ') LOG = 'tdscnt.log'
      OPEN (3, FILE=LOG, STATUS='UNKNOWN')
      LOUT = 3
C
C     DISPVAL guard requires a NON-ZERO IDIAG or it returns leaving the
C     OUTPUT counters undefined; 4 = the NASTRAN_DISPATCH_VALIDATE bit
C     (and bit8/verbose is NOT set, so enumeration is silent).
      IDIAG = 4
C
C     =================================================================
C     SUB-CHECK 1 (PRIMARY) -- entry count equals the catalog count.
C     Run the validator once and require the enumerated entry count to
C     equal the catalogued MODX count (217).  A mismatch means the
C     modern dispatcher omitted or over-counted slots relative to the
C     FROZEN mis/xsem00.f ladder.
C     =================================================================
      CALL DISPVAL (IDIAG, NENT, NDUP, NUNMAP, IST)
      IF (NENT .NE. NEXP) THEN
         OK = .FALSE.
         WRITE (3,9100) NENT, NEXP
      END IF
C
C     =================================================================
C     SUB-CHECK 2 (PRIMARY) -- zero duplicates and zero unmapped.
C     The catalogue must contain no duplicate MODX codes and no
C     in-range code without a disposition; the validator's overall
C     status (IST) must also report OK (0).  Any non-zero value clears
C     OK and emits an informational line (no failure token).
C     =================================================================
      IF (NDUP .NE. NDUPEX) THEN
         OK = .FALSE.
         WRITE (3,9101) NDUP, NDUPEX
      END IF
      IF (NUNMAP .NE. NUNMEX) THEN
         OK = .FALSE.
         WRITE (3,9102) NUNMAP, NUNMEX
      END IF
      IF (IST .NE. 0) THEN
         OK = .FALSE.
         WRITE (3,9103) IST
      END IF
C
C     SUB-CHECK 3 (documented, not asserted) -- the documentary sub-
C     counts (193 CALL / 188 DISTINCT / 21 RESERVED / 3 FATAL, summing
C     to 217) are catalogued in test/dispatch/tdscnt.ref but are NOT
C     returned by the real DISPVAL(IDIAG,NENT,NDUP,NUNMAP,IST), so they
C     cannot be asserted here.  Sub-checks 1 and 2 are the binding
C     criteria; the sub-counts remain a documented cross-reference.
C
C     ---- verdict (single line, unit 3 only) -----------------------
C     The failure token 'FAIL:' is written ONLY in the .NOT. OK
C     branch; it appears nowhere else in this file.
      WRITE (3,'(A)') ' TDSCNT ENTRY-COUNT SUITE COMPLETE'
      IF (OK) THEN
         WRITE (3,'(A)') 'PASS: TDSCNT'
      ELSE
         WRITE (3,'(A)') 'FAIL: TDSCNT'
      END IF
      CLOSE (3)
C
C     ---- informational formats (NO failure token) -----------------
 9100 FORMAT (' ENTRY COUNT GOT=', I6, ' EXP=', I6)
 9101 FORMAT (' DUP COUNT GOT=', I6, ' EXP=', I6)
 9102 FORMAT (' UNMAPPED GOT=', I6, ' EXP=', I6)
 9103 FORMAT (' STATUS IST=', I6, ' EXP=0')
C
      STOP
      END
