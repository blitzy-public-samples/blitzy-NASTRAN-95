C=====================================================================
C     modern/state/stateval.f
C---------------------------------------------------------------------
C     MODERNIZATION STATE-CONSISTENCY VALIDATOR
C
C     Modernization state-consistency validator over the encapsulated
C     global state; reads via stateacc.f GET accessors; guard-clause
C     zero overhead; reports to unit 3 with codes 9100-9199.
C
C     This is the validator counterpart to the accessor/facade layer
C     modern/state/stateacc.f and the second (and last) .f file in
C     modern/state/.  Pattern realized: TEMPLATE METHOD validator
C     (setup -> compare -> report) + GUARD CLAUSE (zero overhead when
C     diagnostics are disabled), consistent with the sibling validators
C     modern/init/initval.f and modern/dispatch/dispval.f.
C=====================================================================
C
C     SIGNATURE (FROZEN cross-agent contract -- do NOT change):
C         SUBROUTINE STATEVAL (IDIAG, IST)
C
C     ARGUMENTS:
C         INTEGER IDIAG -- INPUT.  Diagnostics-enable bitmask produced
C                 by modern/diag/diagctl.f (CALL DIAGCTL(IDIAG)); 0 =>
C                 disabled.  Used by the mandatory guard clause below
C                 and threaded unchanged into DIAGLOG.
C         INTEGER IST   -- OUTPUT.  Divergence count: 0 => state is
C                 consistent; > 0 => number of consistency violations
C                 detected.  IST is set ONLY when IDIAG .NE. 0; when
C                 IDIAG = 0 STATEVAL is a no-op and does NOT touch IST
C                 (the APR.95 / zero-overhead default path).
C
C     CALLER / TEST CALL FORM (published contract):
C         CALL STATEVAL (IDIAG, IST)
C     Because the guard returns immediately when IDIAG = 0, a caller
C     that wants a meaningful verdict MUST pass a non-zero IDIAG (for
C     example IDIAG = 2).  The sibling driver test/state/tstval.f
C     establishes a consistent state via the stateacc.f SET accessors,
C     poisons IST to a non-zero sentinel, then CALLs STATEVAL with a
C     non-zero IDIAG and asserts IST .EQ. 0 -- STATEVAL actively
C     setting IST = 0 is what proves consistency.  (tstval.ref was
C     drafted against a guessed CALL STVAL(IST); THIS file is the
C     source of truth -- reconcile to CALL STATEVAL(IDIAG,IST).)
C
C     GUARD CLAUSE  IF (IDIAG .EQ. 0) RETURN  IS THE FIRST EXECUTABLE
C     STATEMENT (AAP 0.6.4 / 0.7.2).  Nothing executable -- not even
C     IST = 0 -- precedes it, so an unconfigured (APR.95) run incurs
C     provably zero overhead.  This is the single most-checked success
C     criterion in the whole modern/ tree.
C
C     NO COMMON / NO EQUIVALENCE / NO INCLUDE -- global state is reached
C     ONLY via the stateacc.f GET accessors (AAP 0.5.3 zero-new-COMMON;
C     0.7.2).  Every value arrives in a local INTEGER via an accessor
C     CALL; IDIAG and IST are arguments.  Reading through the accessors
C     (rather than INCLUDEing headers) also keeps STATEVAL free of the
C     /DSNAME/ (DSNAMES vs MDSNAM) and /ZZZZZZ/ (IBASE vs MEM) header-
C     layout conflicts entirely.  Verifiable by inspection.
C
C     ALL REPORTING via CALL DIAGLOG (IDIAG, ICODE, NVAL, MSG), with
C     ICODE in the 9100-9199 sub-band (subset of the permitted
C     9001-9999 band that is unassigned in um/MSSG.TXT; that registry
C     file is NOT edited).  STATEVAL never WRITE/PRINTs, never OPENs a
C     unit, and never calls MESAGE: normal divergences are non-fatal
C     and MESAGE would write to NOUT, not unit 3.  DIAGLOG itself
C     re-applies the guard and writes to logical unit 3 only.
C
C     INVARIANTS CHECKED (representative, defensible coherence relations
C     on the encapsulated cells -- a used count must not exceed its
C     capacity; unit numbers, word sizes and lengths must be sane;
C     maintainers may extend the set).  They are satisfied by the
C     known-good seed in test/state/tstval.ref (NWORDS=LWORDS=2048,
C     NBLOCK=MAXBLK=64, NOUT=6, NBPW=32, LCW=1024, IDBLEN=4096), so a
C     consistent state yields IST = 0:
C         9101  NWORDS must not exceed LWORDS    (NWD  .GT. LWD)
C         9102  NBLOCK must not exceed MAXBLK    (NBK  .GT. MBK)
C         9103  NOUT (print unit) must be > 0    (NOU  .LE. 0)
C         9104  NBPW (bits/word) must be > 0     (NBP  .LE. 0)
C         9105  LCW must be non-negative         (LCWV .LT. 0)
C         9106  IDBLEN (DB length) non-negative  (DBLN .LT. 0)
C         9100  summary: state consistent        (IST  .EQ. 0)
C         9199  summary: divergences found       (IST  .GT. 0)
C
C     PROVENANCE:
C         Validates modern/state/stateacc.f via its GET accessors
C         (GETLCW, GETLWRD, GETNWRD, GETNBLK, GETMBLK, GETNOUT,
C         GETNBPW, GETDBLN).  Reporting via modern/diag/diaglog.f.
C         Cell semantics: /DSIO/ LWORDS,NWORDS,LCW and /DBM/
C         NBLOCK,MAXBLK,IDBLEN are capacity/usage counters in
C         mds/DSIOF.COM; /SYSTEM/ NOUT (word 2) is the print-output
C         unit and NBPW (bits/word) come from mis/SMCOMX.COM.  STATEVAL
C         itself INCLUDEs none of these -- the accessors own the
C         headers.
C
C     KEY INSIGHT: IDIAG is an ARGUMENT across the whole modern tree
C     (it is in none of the nine *.COM headers, so it cannot be a
C     COMMON cell without violating zero-new-COMMON); STATEVAL receives
C     IDIAG and threads it to DIAGLOG.  A validator that guards on
C     IDIAG is active only when diagnostics are enabled; in the default
C     run it is a no-op with provably zero overhead -- exactly the
C     rollback / default-safety guarantee of the refactor.
C
C     Fixed-form FORTRAN 77; compiled by Sun/Solaris f77 -fast -dn into
C     bin/nastlib.a via an updated bin/linknas (build wiring is owned
C     by the bin/ agent; this file does not edit any build file).
C=====================================================================
      SUBROUTINE STATEVAL (IDIAG, IST)
C
C     Dummy arguments: IDIAG (INPUT bitmask) and IST (OUTPUT count).
      INTEGER IDIAG, IST
C
C     Local INTEGER receivers for the encapsulated cells under test.
C     Each is filled by a stateacc.f GET accessor CALL below; none is a
C     COMMON variable.  LCWV=/DSIO/ LCW, LWD=/DSIO/ LWORDS,
C     NWD=/DSIO/ NWORDS, NBK=/DBM/ NBLOCK, MBK=/DBM/ MAXBLK,
C     NOU=/SYSTEM/ NOUT, NBP=/SYSTEM/ NBPW, DBLN=/DBM/ IDBLEN.
      INTEGER LCWV, LWD, NWD, NBK, MBK, NOU, NBP, DBLN
C
C     -----------------------------------------------------------------
C     GUARD CLAUSE -- FIRST EXECUTABLE STATEMENT (MANDATORY, AAP
C     0.6.4/0.7.2).  Zero overhead when diagnostics are disabled
C     (IDIAG = 0 => APR.95 default).  Nothing executable, not even
C     IST = 0, may precede this line.
C     -----------------------------------------------------------------
      IF (IDIAG .EQ. 0) RETURN
C
C     -----------------------------------------------------------------
C     SETUP -- initialize the verdict only AFTER the guard has passed.
C     -----------------------------------------------------------------
      IST = 0
C
C     -----------------------------------------------------------------
C     READ -- obtain each cell strictly through the stateacc.f GET
C     accessors (no raw COMMON, no INCLUDE).
C     -----------------------------------------------------------------
      CALL GETLCW  (LCWV)
      CALL GETLWRD (LWD)
      CALL GETNWRD (NWD)
      CALL GETNBLK (NBK)
      CALL GETMBLK (MBK)
      CALL GETNOUT (NOU)
      CALL GETNBPW (NBP)
      CALL GETDBLN (DBLN)
C
C     -----------------------------------------------------------------
C     COMPARE -- check the coherence invariants.  Each violation
C     contributes independently to IST and emits exactly one DIAGLOG
C     record (NVAL = the offending live value).
C     -----------------------------------------------------------------
C     9101: used word count must not exceed allocated word capacity.
      IF (NWD .GT. LWD) THEN
         IST = IST + 1
         CALL DIAGLOG (IDIAG, 9101, NWD, 'STATEVAL NWORDS GT LWORDS')
      END IF
C     9102: used block count must not exceed maximum block capacity.
      IF (NBK .GT. MBK) THEN
         IST = IST + 1
         CALL DIAGLOG (IDIAG, 9102, NBK, 'STATEVAL NBLOCK GT MAXBLK')
      END IF
C     9103: the print-output unit number must be strictly positive.
      IF (NOU .LE. 0) THEN
         IST = IST + 1
         CALL DIAGLOG (IDIAG, 9103, NOU, 'STATEVAL NOUT NOT POSITIVE')
      END IF
C     9104: the machine word size (bits/word) must be strictly
C     positive.
      IF (NBP .LE. 0) THEN
         IST = IST + 1
         CALL DIAGLOG (IDIAG, 9104, NBP, 'STATEVAL NBPW NOT POSITIVE')
      END IF
C     9105: the current-word pointer LCW must be non-negative.
      IF (LCWV .LT. 0) THEN
         IST = IST + 1
         CALL DIAGLOG (IDIAG, 9105, LCWV, 'STATEVAL LCW NEGATIVE')
      END IF
C     9106: the database length must be non-negative.
      IF (DBLN .LT. 0) THEN
         IST = IST + 1
         CALL DIAGLOG (IDIAG, 9106, DBLN, 'STATEVAL IDBLEN NEGATIVE')
      END IF
C
C     -----------------------------------------------------------------
C     REPORT -- one summary record carrying the final verdict.  IST = 0
C     means every invariant held (state consistent).
C     -----------------------------------------------------------------
      IF (IST .EQ. 0) THEN
         CALL DIAGLOG (IDIAG, 9100, 0, 'STATEVAL STATE CONSISTENT')
      ELSE
         CALL DIAGLOG (IDIAG, 9199, IST, 'STATEVAL DIVERGENCES FOUND')
      END IF
C
      RETURN
      END
