C=====================================================================
C     test/state/tstval.f
C---------------------------------------------------------------------
C     PROGRAM TSTVAL -- NASTRAN-95 modernization unit-test driver.
C
C     PURPOSE
C        Validate STATE-CONSISTENCY CHECKING (test/state/ suite,
C        coverage area 2) of the modern global-state encapsulation
C        layer:  after a known-good (CONSISTENT) global state is
C        established through the modern/state/stateacc.f SET accessors,
C        the state-consistency validator modern/state/stateval.f must
C        report the state as CONSISTENT (zero divergences).  By
C        construction this driver is ALSO the living proof of coverage
C        area 3 ("zero re-declaration evidence"): it reaches global
C        state ONLY through accessor CALLs and holds NO literal shared
C        block declaration and NO storage-association whatsoever.
C
C     ROUTINE UNDER TEST   modern/state/stateval.f
C        SUBROUTINE STATEVAL (IDIAG, IST) -- reads the encapsulated
C        cells through the stateacc.f GET accessors, checks coherence
C        invariants (codes 9101-9106), and sets IST = the divergence
C        count (0 => state consistent).  It is resolved from
C        bin/nastlib.a at link time; this driver never defines it.
C        modern/state/stateacc.f supplies the SET accessors used here
C        to establish the consistent state (also from bin/nastlib.a).
C
C     CROSS-AGENT INTERFACE  (assumed -> RECONCILED to the real source)
C        modern/state/ was authored in the SAME build phase.  The
C        ORIGINAL assumed validator contract was  CALL STVAL(IST)  with
C        IST = 0 when consistent.  The REAL, shipped contract in
C        modern/state/stateval.f is
C            CALL STATEVAL (IDIAG, IST)
C        whose FIRST executable statement is the guard
C            IF (IDIAG .EQ. 0) RETURN
C        so a caller MUST pass a NON-ZERO IDIAG to activate the checks;
C        with IDIAG = 0 the validator is a no-op (the APR.95 zero-
C        overhead default) and would leave the poisoned IST untouched.
C        This driver therefore passes IDIAG = 2 (non-zero) and asserts
C        the validator actively sets IST = 0.  The SET accessors were
C        reconciled to single-INTEGER-argument SUBROUTINEs
C            CALL SETxxx (IVAL).
C        If the real names/signatures ever change, update the CALLs;
C        the "establish consistent state -> assert consistent" logic
C        is unchanged.
C
C     ZERO literal shared-block / ZERO aliasing  (the defining
C        test/state rule -- stricter than the sibling test/dispatch &
C        test/diag suites).  It mirrors the modern/state encapsulation
C        rule: new code reaches global state ONLY via an existing
C        *.COM header, never a re-declared shared block.  This driver
C        goes further and uses NO header INCLUDE either -- it reaches
C        global state ONLY via the accessor CALLs, so it is a clean
C        witness of the zero-re-declaration property it exists to test.
C        Because the /LOGOUT/ log-unit block is forbidden here, the
C        verdict is written to the LITERAL log unit 3 (NASTRAN's log
C        unit -- the bootstrap sets LOUT = 3 in bin/nastrn.f right after
C        CALL DBMINT) -- the same destination without any shared block.
C
C     IDIAG / DIAGNOSTICS NOTE
C        Run via test/run_units.csh with NO NASTRAN_* toggle set.  The
C        non-zero IDIAG is supplied LOCALLY here purely to drive the
C        validator's checks; it is NOT read from the environment.  When
C        IST = 0, STATEVAL emits one informational record (code 9100)
C        through DIAGLOG to unit 3; that record carries no failure
C        token and does not affect the grep contract below.
C
C     HAPPY-PATH ONLY
C        Negative/error-path testing would need to capture the
C        validator's divergence emission (a MESAGE/DIAGLOG record) via
C        a stub backed by a shared block, which this suite's zero-block
C        rule forbids.  Asserting that a known-good state validates as
C        CONSISTENT fully covers the stated requirement; negative
C        testing is intentionally deferred to a later phase.
C
C     OUTPUT CONTRACT
C        Exactly one verdict to the log unit (logical unit 3):
C        'PASS: TSTVAL' on success, else the failure verdict.  The
C        literal failure token appears ONLY on the genuine failure path
C        -- test/run_units.csh greps captured output for it and exits
C        non-zero on a match -- so it is in NO comment/banner/info line.
C
C     DELIVERABLE ONLY -- NOT EXECUTED BY BLITZY.  Compiled and run
C        later in the developer's Solaris environment (csh + Sun f77):
C        f77 -fast -dn -o tstval.exe test/state/tstval.f bin/nastlib.a
C        A SINGLE self-contained PROGRAM unit that NEVER defines any
C        accessor or the validator (all resolved from bin/nastlib.a).
C
C     SEED VALUES are kept identical to the SEED_* lines in
C        test/state/tstval.ref (consistency coupling); EXPECT_STATUS 0.
C=====================================================================
      PROGRAM TSTVAL
C
C     ---- declarations (NO shared block, NO aliasing, NO INCLUDE) --
      CHARACTER*80    LOG
      LOGICAL         OK
      INTEGER         IST, IDIAG
C     Known-good consistent-state seeds (one per cell STATEVAL reads),
C     values identical to the SEED_* lines of test/state/tstval.ref.
      INTEGER         LCWV, LWDV, NWDV, DBLNV, NBKV, MBKV, NOUV, NBPV
C
      OK    = .TRUE.
C     Non-zero IDIAG activates the validator (bypasses its guard
C     IF (IDIAG .EQ. 0) RETURN); 2 mirrors the schema example.
      IDIAG = 2
C
C     ---- consistent-state seed values (sync: tstval.ref) -----------
C     /DSIO/ (mds/DSIOF.COM): LCW, LWORDS, NWORDS
      LCWV  = 1024
      LWDV  = 2048
      NWDV  = 2048
C     /DBM/  (mds/DSIOF.COM): IDBLEN, NBLOCK, MAXBLK
      DBLNV = 4096
      NBKV  = 64
      MBKV  = 64
C     /SYSTEM/ (mis/SMCOMX.COM): NOUT, NBPW
      NOUV  = 6
      NBPV  = 32
C
C     ---- unit-3 (log) wiring -- mirror bin/nastrn.f ----------------
C     Read the log-file name from LOGNM (set per driver by
C     test/run_units.csh); fall back to a fixed name when unset so the
C     driver also runs standalone.  Open it on the LITERAL unit 3.
      LOG = ' '
      CALL GETENV ('LOGNM', LOG)
      IF (LOG .EQ. ' ') LOG = 'tstval.log'
      OPEN (3, FILE=LOG, STATUS='UNKNOWN')
C
C     Truncate the log on the LITERAL unit 3 after open so no stale
C     record from a prior run survives into this run's verdict.
      REWIND (3)
      ENDFILE (3)
      REWIND (3)
C
C     =================================================================
C     SUB-CHECK 1 -- ESTABLISH A KNOWN-GOOD CONSISTENT STATE.
C     Write a coherent, in-range, non-degenerate value to every cell
C     the validator inspects, exclusively through the stateacc.f SET
C     accessors (no shared block).  The matched capacities
C     (NWORDS <= LWORDS, NBLOCK <= MAXBLK) and the positive unit/word
C     sizes satisfy STATEVAL's invariants 9101-9106, so a correct
C     validator must report IST = 0.
C     =================================================================
      CALL SETLCW  (LCWV)
      CALL SETLWRD (LWDV)
      CALL SETNWRD (NWDV)
      CALL SETDBLN (DBLNV)
      CALL SETNBLK (NBKV)
      CALL SETMBLK (MBKV)
      CALL SETNOUT (NOUV)
      CALL SETNBPW (NBPV)
C
C     =================================================================
C     SUB-CHECK 2 -- VALIDATOR REPORTS CONSISTENT (PRIMARY ASSERTION).
C     Poison IST to a non-zero sentinel so a no-op CALL cannot pass by
C     accident, then require STATEVAL to actively set IST = 0.
C     =================================================================
      IST = -1
      CALL STATEVAL (IDIAG, IST)
      IF (IST .NE. 0) THEN
         OK = .FALSE.
         WRITE (3,9001) IST
      END IF
C
C     =================================================================
C     SUB-CHECK 3 -- VERDICT IS STABLE UNDER AN ACCESSOR ROUND-TRIP.
C     Re-establish the identical consistent state through the SET
C     accessors, poison IST to a different sentinel, and require the
C     validator to again report IST = 0 -- showing the verdict is
C     stable and the accessor writes did not perturb consistency.
C     =================================================================
      CALL SETLCW  (LCWV)
      CALL SETLWRD (LWDV)
      CALL SETNWRD (NWDV)
      CALL SETDBLN (DBLNV)
      CALL SETNBLK (NBKV)
      CALL SETMBLK (MBKV)
      CALL SETNOUT (NOUV)
      CALL SETNBPW (NBPV)
C
      IST = -2
      CALL STATEVAL (IDIAG, IST)
      IF (IST .NE. 0) THEN
         OK = .FALSE.
         WRITE (3,9002) IST
      END IF
C
C     ---- verdict (single line, unit 3 only) ------------------------
C     The failure token is written ONLY in the .NOT. OK branch; it
C     appears nowhere else in this file.
      WRITE (3,'(A)') ' TSTVAL STATE-CONSISTENCY SUITE COMPLETE'
      IF (OK) THEN
         WRITE (3,'(A)') 'PASS: TSTVAL'
      ELSE
         WRITE (3,'(A)') 'FAIL: TSTVAL'
      END IF
      CLOSE (3)
C
C     ---- informational status formats (no failure token) -----------
 9001 FORMAT (' SUB-CHECK 2 STATEVAL STATUS (EXPECTED 0) = ', I12)
 9002 FORMAT (' SUB-CHECK 3 STATEVAL STATUS (EXPECTED 0) = ', I12)
C
      STOP
      END
