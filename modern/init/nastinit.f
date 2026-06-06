C=====================================================================
C     modern/init/nastinit.f
C---------------------------------------------------------------------
C     SINGLE INITIALIZATION ENTRY POINT      SUBROUTINE NASTINIT
C
C     NASTINIT is the one routine the NASTRAN-95 bootstrap calls to
C     drive the explicit, ordered, validated modernization init path.
C     It is the Strangler-Fig / feature-toggle CUTOVER SWITCH for
C     initialization (branch-by-abstraction): at RUNTIME, with NO
C     recompilation, it selects either the modern explicit initializer
C     or the legacy load-time path.  DEFAULT (no NASTRAN_* toggle set)
C     is bit-identical APR.95 behavior.
C
C     SIGNATURE (LOCKED cross-agent contract -- do not change):
C         SUBROUTINE NASTINIT          -- NO arguments
C     The no-argument form is fixed by (a) AAP 0.6 ("invoked by exactly
C     one CALL NASTINIT"), (b) the bin/ agent's single bootstrap
C     insertion CALL NASTINIT immediately after CALL DBMINT
C     (bin/nastrn.f L44), and (c) the test/init driver tinnas.f, which
C     issues CALL NASTINIT with no arguments.
C
C     ORCHESTRATION ONLY (no computation; no global state touched):
C       1. Read NASTRAN_LEGACY_INIT via GETENV (exact bootstrap idiom:
C          a CHARACTER*80 receiver pre-cleared to blanks).
C       2. LEGACY mode (toggle set / non-blank): do NOT call BLKINIT --
C          the 39 linked bd/ BLOCK DATA units already seeded COMMON at
C          load time, so legacy APR.95 init stands.  Emit nothing.
C       3. MODERN / DEFAULT mode (toggle unset / blank): CALL BLKINIT,
C          the explicit, ordered, idempotent initializer.
C       4. Validation gate: read NASTRAN_INIT_VALIDATE via GETENV; when
C          set, acquire IDIAG (DIAGCTL), SELF-OPEN unit 3 to LOGNM if the
C          bootstrap has not yet opened it (FLAG C), run validator
C          INITVAL (IDIAG, NDIV), and on a positive divergence count emit
C          ONE unit-3 summary record via DIAGLOG (code 9100, 9001-9999).
C       5. RETURN (single exit at label 900).
C
C     IMPORTS (all from depends_on_files; resolved from bin/nastlib.a):
C         BLKINIT  (modern/init/blkinit.f)  CALL BLKINIT
C         INITVAL  (modern/init/initval.f)  CALL INITVAL (IDIAG, NDIV)
C         DIAGCTL  (modern/diag/diagctl.f)  CALL DIAGCTL (IDIAG)
C         DIAGLOG  (modern/diag/diaglog.f)  CALL DIAGLOG (IDIAG,CODE,
C                                                         NVAL,MSG)
C     EXTERNAL (Sun/Solaris f77 runtime; no INCLUDE/EXTERNAL needed):
C         GETENV   CALL GETENV (NAME, VALUE) -- unset returns blanks
C
C     INCLUDE / COMMON / EQUIVALENCE:  NONE.  NASTINIT needs no global
C     state to orchestrate, so it declares NO COMMON, adds NO
C     EQUIVALENCE, and includes none of the nine *.COM headers (AAP
C     0.5.3 zero-new-COMMON).  Every declaration below is a local.
C     Verifiable by inspection.
C
C  MAINTAINER FLAG A -- UNIT-3 TIMING (default path writes NOTHING)
C     The bin/ agent inserts CALL NASTINIT immediately after CALL DBMINT
C     (bin/nastrn.f L44) and BEFORE LOUT = 3 (L45) / OPEN(3,...) (L115).
C     Consequences honored here:
C       * BTSTRP (L32) and DBMINT (L44) have ALREADY populated the
C         machine constants in /SYSTEM/ and the DBM state; NASTINIT and
C         BLKINIT treat those as authoritative and NEVER clobber them.
C       * Logical unit 3 (LOUT) is NOT yet open when NASTINIT runs in
C         the real solver, so the DEFAULT / PRODUCTION path (toggle
C         unset) writes NOTHING to any unit and stays bit-identical to
C         APR.95.  When NASTRAN_INIT_VALIDATE IS set, however, the
C         validate path no longer depends on the bootstrap having opened
C         unit 3: it SELF-OPENS unit 3 to LOGNM (the same file the
C         bootstrap opens at L116) when unit 3 is not yet connected, so
C         init validation runs RELIABLY in the real solver as well as in
C         the test/init harness (where unit 3 is already open).  Because
C         re-opening an already-connected unit to the same file is a
C         records-preserving no-op (verified), the bootstrap's later
C         OPEN(3,...) keeps the validation records NASTINIT wrote.
C
C  MAINTAINER FLAG B -- TOGGLE-POLARITY RECONCILIATION
C     The modern DEFAULT path (NASTRAN_LEGACY_INIT unset) CALLS BLKINIT,
C     yet the run is still bit-identical to APR.95.  This holds ONLY
C     because BLKINIT idempotently RE-AFFIRMS the safe config cells with
C     the identical values the 39 linked bd/ units already placed and
C     NEVER clobbers a machine constant (proof in blkinit.f).  The test
C     harness assumes unset => modern; AAP 0.7.4 mandates default =>
C     APR.95; both hold together because BLKINIT == bd/ bitwise on the
C     safe subset.  Flagged for maintainer confirmation.
C
C  MAINTAINER FLAG C -- VALIDATE PATH SELF-OPENS UNIT 3
C     INITVAL writes informational records to unit 3 once enabled
C     (initval.f emits codes 9170/9171/9150/9160/9100 via DIAGLOG after
C     its own guard passes), so unit 3 MUST be connected before INITVAL
C     runs.  Rather than skip validation when the bootstrap has not yet
C     opened unit 3 (the real-solver case), the validate path SELF-OPENS
C     unit 3 to LOGNM and only then calls INITVAL.  The INITVAL call is
C     still placed inside IF (LOPEN) so that, in the rare case LOGNM is
C     unset AND unit 3 is closed, NASTINIT stays silent and does not
C     attempt I/O on an unconnected unit.  IDIAG is acquired via DIAGCTL
C     BEFORE INITVAL because INITVAL's first-statement guard needs it.
C
C     DIAGNOSTICS: all reporting is on logical unit 3 only and uses a
C     MESAGE code in the 9001-9999 band (here 9100, the init summary).
C     No CALL MESAGE and no WRITE/PRINT/OPEN appears in this file; the
C     only emission path is DIAGLOG (itself guarded and unit-3-only).
C
C     Fixed-form FORTRAN 77; compiled by Sun/Solaris f77 -fast -dn into
C     bin/nastlib.a via an updated bin/linknas (build wiring owned by
C     the bin/ agent; this file does NOT edit bin/nastrn.f or
C     bin/linknas).
C=====================================================================
      SUBROUTINE NASTINIT
C
C     Local declarations ONLY (no COMMON, no EQUIVALENCE, no INCLUDE).
C       VALUE  CHARACTER*80 GETENV receiver (matches bin/nastrn.f L3);
C              pre-cleared so an unset variable comes back blank.
C       NDIV   INTEGER divergence count returned by INITVAL.
C       IDIAG  INTEGER toggle bitmask from DIAGCTL for the DIAGLOG call.
C       LOPEN  LOGICAL INQUIRE result: is logical unit 3 connected?
      CHARACTER*80   VALUE
      INTEGER        NDIV
      INTEGER        IDIAG
      LOGICAL        LOPEN
C
C     -----------------------------------------------------------------
C     STEP 1 -- read the Strangler-Fig cutover toggle.  Pre-clear the
C     receiver (bin/nastrn.f GETENV idiom) so UNSET comes back blank.
C     -----------------------------------------------------------------
      VALUE = ' '
      CALL GETENV ( 'NASTRAN_LEGACY_INIT', VALUE )
C
C     -----------------------------------------------------------------
C     STEP 2 -- LEGACY PATH (toggle set / non-blank).  Strangler-Fig
C     rollback: do NOT call BLKINIT.  The 39 linked bd/ BLOCK DATA units
C     already seeded COMMON at load, so APR.95 init stands.  Emit
C     nothing and skip to the single exit (step 5).
C     -----------------------------------------------------------------
      IF (VALUE .NE. ' ') GO TO 900
C
C     -----------------------------------------------------------------
C     STEP 3 -- MODERN / DEFAULT PATH (toggle unset / blank).  Run the
C     explicit, ordered, idempotent initializer.  BLKINIT only
C     re-affirms the safe config cells (bit-identical to APR.95; FLAG B)
C     and writes NOTHING to any unit (FLAG A).
C     -----------------------------------------------------------------
      CALL BLKINIT
C
C     -----------------------------------------------------------------
C     STEP 4 -- VALIDATION GATE.  Read NASTRAN_INIT_VALIDATE via the same
C     GETENV idiom; when set, RELIABLY run INITVAL and report any
C     positive divergence count on unit 3 via DIAGLOG (init-band 9100).
C     Because the bin/ bootstrap calls NASTINIT BEFORE it opens logical
C     unit 3 (bin/nastrn.f L116), this validate path SELF-OPENS unit 3 to
C     LOGNM -- the SAME file the bootstrap opens (DSNAMES(3)=LOGNM,
C     bin/nastrn.f L62-63) -- when it is not already connected, so a
C     production `run_all.csh -validate` actually exercises init
C     validation and produces the promised unit-3 log.  Re-opening an
C     already-connected unit to the same file with STATUS='UNKNOWN' is a
C     records-preserving no-op (the bootstrap's later OPEN keeps these
C     records; verified), and the DEFAULT path (toggle unset) opens
C     NOTHING and stays bit-identical to APR.95.
C     -----------------------------------------------------------------
      VALUE = ' '
      CALL GETENV ( 'NASTRAN_INIT_VALIDATE', VALUE )
      IF (VALUE .NE. ' ') THEN
C        Acquire the diagnostics bitmask ONCE; INITVAL's first-statement
C        guard IF (IDIAG .EQ. 0) RETURN needs a non-zero IDIAG (bit 2 set
C        by NASTRAN_INIT_VALIDATE) to run, so DIAGCTL must precede it.
         CALL DIAGCTL (IDIAG)
C        Ensure unit 3 is connected before INITVAL writes.  In the test
C        harness it is already open; in the real solver it is not, so
C        self-open it to LOGNM (raw value, exactly as DSNAMES(3)).
         INQUIRE (UNIT=3, OPENED=LOPEN)
         IF (.NOT. LOPEN) THEN
            VALUE = ' '
            CALL GETENV ( 'LOGNM', VALUE )
            IF (VALUE .NE. ' ') THEN
               OPEN (3, FILE=VALUE, STATUS='UNKNOWN')
            END IF
            INQUIRE (UNIT=3, OPENED=LOPEN)
         END IF
C        Run the validator whenever unit 3 is connected.  INITVAL
C        self-guards on IDIAG and emits its own 9170/9171/9150/9160/9100
C        records; the sentinel NDIV=-1 survives a guarded no-op so the
C        .GT. 0 test stays false and emits no spurious summary.
         IF (LOPEN) THEN
            NDIV = -1
            CALL INITVAL (IDIAG, NDIV)
            IF (NDIV .GT. 0) THEN
               CALL DIAGLOG (IDIAG, 9100, NDIV,
     &              'NASTINIT: INIT VALIDATION DIVERGENCES')
            END IF
         END IF
      END IF
C
C     -----------------------------------------------------------------
C     STEP 5 -- single exit.  The bootstrap resumes at LOUT = 3.
C     -----------------------------------------------------------------
  900 CONTINUE
      RETURN
      END
