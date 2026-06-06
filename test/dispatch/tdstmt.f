C=====================================================================
C     test/dispatch/tdstmt.f
C---------------------------------------------------------------------
C     PROGRAM TDSTMT -- NASTRAN-95 modernization unit-test driver.
C
C     PURPOSE
C        Validate TMTOGO(KTIME) PLACEMENT (test/dispatch/ suite,
C        coverage area 3): the modern dispatcher
C        modern/dispatch/disptbl.f must perform EXACTLY ONE
C        pre-dispatch  CALL TMTOGO (KTIME)  per dispatch invocation,
C        mirroring the SINGLE legacy time check in mis/xsem00.f
C        (250 CALL TMTOGO (KTIME), just before the dispatch ladder
C        at label 1000).  This driver counts the calls via a local
C        TMTOGO override and asserts the count is exactly one.
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
C        with INTEGER MODX passed as the sole argument; the dispatcher
C        performs exactly one pre-dispatch CALL TMTOGO (KTIME) and
C        then routes MODX to its target.  RECONCILED: the real
C        modern/dispatch/disptbl.f is  SUBROUTINE DISPTBL (MODX)  --
C        a single INTEGER argument, exactly as assumed; it issues one
C        CALL TMTOGO (KTIME) then IF (KTIME .LE. 0) CALL MESAGE
C        (-50,0,..) before its IF / ELSE-IF dispatch chain.  No extra
C        arguments exist, so no reconciliation change is needed.
C
C     LINK-OVERRIDE TECHNIQUE  (central -- intentional and standard)
C        This driver PROVIDES its own TMTOGO (after the program END,
C        in this same file) to COUNT invocations.  With the standard
C        Unix link
C           f77 -fast -dn -o tdstmt.exe test/dispatch/tdstmt.f
C           bin/nastlib.a
C        the command-line object (this driver) resolves TMTOGO BEFORE
C        the archive, so the archive member mis/tmtogo.o is NOT pulled
C        (no duplicate-symbol error).  DISPTBL (unresolved) IS pulled
C        from bin/nastlib.a and its internal CALL TMTOGO binds to this
C        counting stub.  DISPTBL's MESAGE reference and its ~188
C        module EXTERNALs are resolved from the archive but are NEVER
C        executed on the reserved no-op path (MODX 25/36) tested here.
C        FALLBACK: should a stricter Solaris linker object to the
C        override, compile this stub into a separate object and place
C        it BEFORE bin/nastlib.a on the link line (the same precedence
C        rule yields the identical effect).
C
C     /SYSTEM/ AVOIDANCE
C        KTIME nominally originates from /SYSTEM/ (declared in
C        mis/SMCOMX.COM per the AAP discrepancy flag; the /SYSTEM/
C        overlay differs across xsem00.f / tmtogo.f / SMCOMX.COM /
C        mesage.f / nastrn.f).  This driver deliberately does NOT
C        declare /SYSTEM/: the TMTOGO stub fills the passed TOGO /
C        KTIME argument directly with a large POSITIVE value, so the
C        dispatcher's time-budget guard (IF (KTIME .LE. 0) ...) is NOT
C        taken and cannot perturb the TMTOGO count or reach MESAGE.
C
C     TEST CODES  (hardcoded; mirrored in test/dispatch/tdstmt.ref)
C        NOOP_MODX           25   reserved no-op CONTINUE slot
C        ALT_NOOP_MODX       36   second reserved no-op slot
C        EXPECT_TMTOGO_CALLS  1   exactly one pre-dispatch call
C
C     OUTPUT CONTRACT
C        Exactly one verdict to the log unit (logical unit 3 / LOUT):
C        'PASS: TDSTMT' on success, else 'FAIL: TDSTMT'.  The literal
C        failure token appears ONLY on the genuine failure branch --
C        test/run_units.csh greps captured output for 'FAIL:' and
C        exits non-zero on a match -- so it is in NO banner/info line.
C
C     DELIVERABLE ONLY -- NOT EXECUTED BY BLITZY.  Compiled and run
C        later in the developer's Solaris environment (csh + Sun f77).
C        SINGLE self-contained file: exactly one PROGRAM plus the
C        local TMTOGO stub; it never defines DISPTBL.  Fixed-form
C        FORTRAN 77 only (Sun f77 -fast -dn).
C=====================================================================
      PROGRAM TDSTMT
C
C     ---- declarations ---------------------------------------------
      CHARACTER*80    LOG
      LOGICAL         OK
C     NTMG is the shared invocation counter: the TMTOGO stub (below,
C     after the program END) INCREMENTS it; this program RESETS and
C     READS it through COMMON /TMCNT/.  LOUT is the NASTRAN log-unit
C     cell, set to 3 exactly as the bin/nastrn.f bootstrap does.  No
C     /SYSTEM/ and no re-declared dispatcher COMMON appear anywhere in
C     this driver.
      INTEGER         NTMG, LOUT
      COMMON /LOGOUT/ LOUT
      COMMON /TMCNT/  NTMG
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
      IF (LOG .EQ. ' ') LOG = 'tdstmt.log'
      OPEN (3, FILE=LOG, STATUS='UNKNOWN')
      LOUT = 3
C     STATUS='UNKNOWN' does not truncate an existing file and the runner
C     does not pre-remove a per-run log, so a stale prior log (including
C     a stale FAIL:) could remain.  Truncate unit 3 to zero length the
C     way test/diag/tdggrd.f does: REWIND then ENDFILE truncates; the
C     second REWIND repositions at the now-empty start.  All driver
C     writes below are sequential from the start, so the log then holds
C     exactly this run's records, ending at the verdict.
      REWIND (3)
      ENDFILE (3)
      REWIND (3)
C
C     =================================================================
C     SUB-CHECK 1 (PRIMARY) -- exactly one pre-dispatch TMTOGO for a
C     no-op dispatch.  Reset the shared counter, drive the dispatcher
C     with the RESERVED no-op MODX 25 (a CONTINUE slot: no module
C     subroutine executes), then require the counter to read EXACTLY
C     one.  NTMG=0 would mean the mandatory time check was OMITTED (a
C     regression); NTMG>1 would mean TMTOGO was called MORE than once
C     (violating the single pre-dispatch contract).
C     =================================================================
      NTMG = 0
      CALL DISPTBL (25)
      IF (NTMG .NE. 1) THEN
         OK = .FALSE.
         WRITE (3,9100) NTMG
      END IF
C
C     =================================================================
C     SUB-CHECK 2 -- idempotent single-call across a repeated dispatch.
C     Drive a SECOND reserved no-op MODX (36) from a fresh counter and
C     again require exactly one TMTOGO call.  This shows each dispatch
C     invocation performs exactly one pre-dispatch time check (not an
C     accumulating or a skipped one).
C     =================================================================
      NTMG = 0
      CALL DISPTBL (36)
      IF (NTMG .NE. 1) THEN
         OK = .FALSE.
         WRITE (3,9101) NTMG
      END IF
C
C     ---- verdict (single line, unit 3 only) -----------------------
C     The failure token 'FAIL:' is written ONLY in the .NOT. OK
C     branch; it appears nowhere else in this file.
      WRITE (3,'(A)') ' TDSTMT TMTOGO-PLACEMENT SUITE COMPLETE'
      IF (OK) THEN
         WRITE (3,'(A)') 'PASS: TDSTMT'
      ELSE
         WRITE (3,'(A)') 'FAIL: TDSTMT'
      END IF
      CLOSE (3)
C
C     ---- informational formats (NO failure token) -----------------
 9100 FORMAT (' TMTOGO CALLS MODX=25 GOT=', I6, ' EXP=1')
 9101 FORMAT (' TMTOGO CALLS MODX=36 GOT=', I6, ' EXP=1')
C
      STOP
      END
C=====================================================================
C     Driver-local stub: TMTOGO (EXACT legacy signature).
C     mis/tmtogo.f is  SUBROUTINE TMTOGO (TOGO); INTEGER TOGO.  This
C     stub COUNTS each invocation in COMMON /TMCNT/ NTMG and returns a
C     large POSITIVE budget so the dispatcher's IF (KTIME .LE. 0)
C     time-fatal guard is NOT taken -- keeping the dispatcher on its
C     normal path so the only effect this test observes is the single
C     pre-dispatch TMTOGO call it counts.
C=====================================================================
      SUBROUTINE TMTOGO (TOGO)
      INTEGER TOGO
      COMMON /TMCNT/ NTMG
      NTMG = NTMG + 1
      TOGO = 1000000
      RETURN
      END
