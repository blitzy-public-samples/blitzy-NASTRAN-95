C=====================================================================
C     test/state/tstacc.f
C---------------------------------------------------------------------
C     PROGRAM TSTACC -- NASTRAN-95 modernization unit-test driver.
C
C     PURPOSE
C        Validate GET/SET ROUND-TRIP CORRECTNESS (test/state/ suite,
C        coverage area 1) of the modern global-state accessor/facade
C        layer modern/state/stateacc.f:  a value written through a SET
C        accessor must read back IDENTICALLY through the paired GET
C        accessor, for each legacy shared cell the modern components
C        reference.  By construction this driver is ALSO the living
C        proof of coverage area 3 ("zero re-declaration evidence"):
C        it reaches global state ONLY through accessor CALLs and holds
C        NO literal shared-block decl and no storage-association.
C
C     ROUTINE UNDER TEST   modern/state/stateacc.f
C        Paired GET/SET accessor SUBROUTINEs (one pair per wrapped
C        shared cell), each declared via a pull-in of the relevant
C        *.COM header INSIDE stateacc.f -- not here.  This driver only
C        CALLs them; they are resolved from bin/nastlib.a at link time.
C
C     CROSS-AGENT ASSUMED INTERFACE  (reconcile with the real source)
C        modern/state/stateacc.f is authored in the SAME build phase.
C        The names/signatures below were reconciled against the real
C        stateacc.f: each is a single-INTEGER-argument SUBROUTINE of
C        the form  CALL SETxxx(IVAL) / CALL GETxxx(IVAL):
C           /DSIO/   LCW    <-> SETLCW  / GETLCW
C           /DSIO/   LWORDS <-> SETLWRD / GETLWRD
C           /DSIO/   NWORDS <-> SETNWRD / GETNWRD
C           /DSIO/   MAXDSN <-> SETMDSN / GETMDSN
C           /DBM/    IDBLEN <-> SETDBLN / GETDBLN
C           /DBM/    LENOPC <-> SETLNOP / GETLNOP
C           /DBM/    NBLOCK <-> SETNBLK / GETNBLK
C           /SYSTEM/ NOUT   <-> SETNOUT / GETNOUT
C           /SYSTEM/ NBPW   <-> SETNBPW / GETNBPW
C           /SMCOMX/ NCOL   <-> SETNCOL / GETNCOL
C        If the real signatures ever differ, update the CALLs; the
C        round-trip assertion logic is unchanged.
C
C     ZERO literal shared-block / ZERO aliasing (defining test/state
C        rule -- stricter than the sibling test/dispatch & test/diag
C        suites).  It mirrors the modern/state encapsulation rule: new
C        code reaches global state ONLY via an existing header, never a
C        re-declared shared block.  This driver goes further and uses NO
C        header pull-in either -- it reaches global state ONLY via the
C        accessor CALLs, so it is a clean witness of the zero-re-
C        declaration property it is testing.  Because the LOUT
C        log-unit block is forbidden here, the verdict is written to the
C        LITERAL log unit 3 (NASTRAN's log unit -- the bootstrap sets
C        LOUT = 3 in bin/nastrn.f right after CALL DBMINT) -- the
C        identical destination without any shared block.
C
C     CLEAN-ENVIRONMENT NOTE
C        Run via test/run_units.csh with NO NASTRAN_* toggle set, so any
C        diagnostics layer reachable from the accessors has IDIAG = 0
C        and is guard-clause silent; this driver therefore does not
C        depend on the LOUT log-unit cell being initialized.
C
C     HAPPY-PATH ONLY
C        Negative/error-path testing would need a MESAGE/DIAGLOG capture
C        stub backed by a shared block, which this suite's zero-block
C        rule forbids; the round-trip + cross-wiring checks below fully
C        cover the stated requirement.  Negative testing is
C        intentionally deferred to a later phase.
C
C     OUTPUT CONTRACT
C        Exactly one verdict to the log unit (logical unit 3):
C        'PASS: TSTACC' on success, else the failure verdict.  The
C        literal failure token appears ONLY on the genuine failure path
C        -- test/run_units.csh greps captured output for it and exits
C        non-zero on a match -- so it is in NO comment/banner/info line.
C
C     DELIVERABLE ONLY -- NOT EXECUTED BY BLITZY.  Compiled and run
C        later in the developer's Solaris environment (csh + Sun f77):
C        f77 -fast -dn -o tstacc.exe test/state/tstacc.f bin/nastlib.a
C        The accessors come from bin/nastlib.a; this is a SINGLE self-
C        contained PROGRAM unit and NEVER defines any accessor.
C
C     SENTINELS are kept identical to the KEY VALUE lines in
C        test/state/tstacc.ref (consistency coupling).
C=====================================================================
      PROGRAM TSTACC
C
C     ---- declarations (NO shared block, NO aliasing) --------------
      CHARACTER*80    LOG
      CHARACTER*6     VNAME(10)
      LOGICAL         OK
      INTEGER         SENT(10), GOT(10), K
C
C     Ten distinct integer sentinels, one per wrapped cell, in the
C     SAME order as test/state/tstacc.ref.  Distinct values expose a
C     cross-wired accessor (set one cell, read another).
      DATA SENT / 12345, -32109, 77001, 4242, 424242,
     &            -55055, 60601, 31337, 909090, -70701 /
C
C     Human-readable cell labels for informational mismatch lines
C     (<= 6 chars; plain text, NOT shared-block references).
      DATA VNAME / 'LCW   ', 'LWORDS', 'NWORDS', 'MAXDSN', 'IDBLEN',
     &             'LENOPC', 'NBLOCK', 'NOUT  ', 'NBPW  ', 'NCOL  ' /
C
      OK = .TRUE.
C
C     ---- unit-3 (log) wiring -- mirror bin/nastrn.f ----------------
C     Read the log-file name from LOGNM (set per driver by
C     test/run_units.csh); fall back to a fixed name when unset so the
C     driver also runs standalone.  Open it on the LITERAL unit 3.  The
C     blank-then-GETENV receiver idiom matches bin/nastrn.f.
      LOG = ' '
      CALL GETENV ('LOGNM', LOG)
      IF (LOG .EQ. ' ') LOG = 'tstacc.log'
      OPEN (3, FILE=LOG, STATUS='UNKNOWN')
C
C     Truncate the log on the LITERAL unit 3 after open so no stale
C     record from a prior run survives into this run's verdict (mirrors
C     the tdggrd.f fresh-log idiom).  Writes are sequential, no rewind.
      REWIND (3)
      ENDFILE (3)
      REWIND (3)
C
C     =================================================================
C     SUB-CHECK 1A -- PER-PAIR GET/SET ROUND-TRIP (the binding test).
C     For each accessor pair: write its sentinel through SET, read it
C     back through GET, and require exact equality.  This is exactly
C     the tstacc.ref contract  CALL set(V); CALL get(OUT); OUT .EQ. V.
C     =================================================================
      CALL SETLCW  (SENT(1))
      CALL GETLCW  (GOT(1))
      CALL SETLWRD (SENT(2))
      CALL GETLWRD (GOT(2))
      CALL SETNWRD (SENT(3))
      CALL GETNWRD (GOT(3))
      CALL SETMDSN (SENT(4))
      CALL GETMDSN (GOT(4))
      CALL SETDBLN (SENT(5))
      CALL GETDBLN (GOT(5))
      CALL SETLNOP (SENT(6))
      CALL GETLNOP (GOT(6))
      CALL SETNBLK (SENT(7))
      CALL GETNBLK (GOT(7))
      CALL SETNOUT (SENT(8))
      CALL GETNOUT (GOT(8))
      CALL SETNBPW (SENT(9))
      CALL GETNBPW (GOT(9))
      CALL SETNCOL (SENT(10))
      CALL GETNCOL (GOT(10))
C
      DO 100 K = 1, 10
         IF (GOT(K) .NE. SENT(K)) THEN
            OK = .FALSE.
            WRITE (3,9100) VNAME(K), SENT(K), GOT(K)
         END IF
  100 CONTINUE
C
C     =================================================================
C     SUB-CHECK 1B -- CROSS-WIRING GUARD (set ALL, then get ALL).
C     Writing every cell BEFORE reading any cell exposes a pair wired
C     to the wrong (shared) cell: the shared cell holds the last
C     writer's value, so an earlier cell reads back wrong.  This is the
C     no-header substitute for a direct shared peek and is strictly
C     stronger than 1A for detecting cross-wired accessors.
C     =================================================================
      DO 110 K = 1, 10
         GOT(K) = 0
  110 CONTINUE
C
      CALL SETLCW  (SENT(1))
      CALL SETLWRD (SENT(2))
      CALL SETNWRD (SENT(3))
      CALL SETMDSN (SENT(4))
      CALL SETDBLN (SENT(5))
      CALL SETLNOP (SENT(6))
      CALL SETNBLK (SENT(7))
      CALL SETNOUT (SENT(8))
      CALL SETNBPW (SENT(9))
      CALL SETNCOL (SENT(10))
C
      CALL GETLCW  (GOT(1))
      CALL GETLWRD (GOT(2))
      CALL GETNWRD (GOT(3))
      CALL GETMDSN (GOT(4))
      CALL GETDBLN (GOT(5))
      CALL GETLNOP (GOT(6))
      CALL GETNBLK (GOT(7))
      CALL GETNOUT (GOT(8))
      CALL GETNBPW (GOT(9))
      CALL GETNCOL (GOT(10))
C
      DO 120 K = 1, 10
         IF (GOT(K) .NE. SENT(K)) THEN
            OK = .FALSE.
            WRITE (3,9101) VNAME(K), SENT(K), GOT(K)
         END IF
  120 CONTINUE
C
C     ---- verdict (single line, unit 3 only) ------------------------
C     The failure token is written ONLY in the .NOT. OK branch; it
C     appears nowhere else in this file.
      WRITE (3,'(A)') ' TSTACC GET/SET ROUND-TRIP SUITE COMPLETE'
      IF (OK) THEN
         WRITE (3,'(A)') 'PASS: TSTACC'
      ELSE
         WRITE (3,'(A)') 'FAIL: TSTACC'
      END IF
      CLOSE (3)
C
C     ---- informational mismatch formats (no failure token) ---------
 9100 FORMAT (' RT  MISMATCH ', A6, ' SET=', I12, ' GET=', I12)
 9101 FORMAT (' XW  MISMATCH ', A6, ' SET=', I12, ' GET=', I12)
C
      STOP
      END
