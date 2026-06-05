      SUBROUTINE DIAGCTL (IDIAG)
C=====================================================================
C     modern/diag/diagctl.f
C---------------------------------------------------------------------
C     MODERNIZATION DIAGNOSTIC CONTROL -- reads the NASTRAN_* env
C     toggles via GETENV and sets the IDIAG bitmask once; default
C     (no toggle set) = APR.95 (IDIAG = 0, all diagnostics silent).
C=====================================================================
C
C     SIGNATURE (FROZEN -- do not change):
C         SUBROUTINE DIAGCTL (IDIAG)
C
C     ARGUMENT:
C         INTEGER IDIAG -- OUTPUT.  Bitmask encoding which NASTRAN_*
C                          toggles are set; 0 when none are set.  The
C                          caller passes an INTEGER variable to receive
C                          the value.
C
C     CONFIGURATION TOGGLES AND THEIR IDIAG BIT VALUES
C     (names fixed by AAP 0.6.4; a toggle contributes its bit when it
C      is set to a non-blank value -- the bin/nastrn.f GETENV idiom: an
C      unset variable comes back blank, so blank/unset => disabled):
C
C         NASTRAN_LEGACY_INIT        bit value 1
C         NASTRAN_INIT_VALIDATE      bit value 2
C         NASTRAN_DISPATCH_VALIDATE  bit value 4
C         NASTRAN_DISPATCH_LOG       bit value 8
C
C     IDIAG = sum of the bit values of the toggles that are set:
C         (none set)  => IDIAG =  0  (silent / APR.95 default)
C         all four    => IDIAG = 15  (every consumer enabled)
C     Consumers decode their own bit AFTER the master guard:
C     e.g. IAND(IDIAG,8).NE.0 (or MOD(IDIAG/8,2).NE.0) tests bit 8.
C     IAND/RSHIFT are available under Sun f77 (cf. mis/xsem00.f).
C     DIAGCTL only BUILDS the mask; decoding is done by the consumers.
C
C     GUARD-EXEMPT SETTER (deliberate exception):
C         DIAGCTL MUST NOT begin with  IF (IDIAG .EQ. 0) RETURN.  It is
C         the routine that COMPUTES IDIAG, so guarding on the value it
C         is about to set would make it never run.  The
C         IF(IDIAG.EQ.0)RETURN guard belongs to the emitters/validators
C         (diaglog.f, initval.f, stateval.f, dispval.f) -- not here
C         (AAP 0.6.4).
C
C     NO GLOBAL STATE / NO I/O:
C         This routine touches NO global state.  It contains NO COMMON,
C         NO EQUIVALENCE, NO INCLUDE; it reads the environment into a
C         local CHARACTER*80 receiver and writes only the IDIAG output
C         argument (AAP 0.5.3 zero-new-COMMON; 0.7.2).  It performs NO
C         WRITE/PRINT and opens NO unit -- diagnostic output is the job
C         of diaglog.f on logical unit 3.
C
C     DEFAULT SAFETY & ROLLBACK:
C         With no toggle set IDIAG = 0, every guarded modern/ routine
C         short-circuits; the run is bit-identical to the unmodified
C         APR.95 solver.  Rollback is a configuration change (unset
C         or flip a NASTRAN_* variable) with NO recompilation (AAP
C         0.7.4).  Operators set these toggles in the bin/nastran csh
C         wrapper's inline env list -- the "env NAME=val ... " block
C         that precedes nastrn.exe, next to LOGNM=$probname.log (the
C         logical-unit-3 log file), e.g.:
C             NASTRAN_DISPATCH_LOG=1 nastrn.exe < deck.inp > deck.out
C
C     CALLERS MUST INVOKE:  CALL DIAGCTL (IDIAG)
C         -> IDIAG = 0 in a clean environment (no NASTRAN_* set)
C         -> IDIAG bitmask non-zero when one or more toggles are set
C     The sibling unit driver test/diag/tdgctl.f calls CALL DIAGCTL
C     (IDIAG) and asserts IDIAG .EQ. 0 in a clean environment
C     (consistent with test/diag/tdgctl.ref DEFAULT_IDIAG 0).  DIAGCTL
C     does NOT call DIAGLOG and has no compile-time dependency on it.
C
C     DESIGN DECISION / MAINTAINER FLAG:
C         IDIAG is returned as an OUTPUT ARGUMENT (not stored in a
C         COMMON block).  This is REQUIRED to honor "zero new COMMON"
C         (AAP 0.5.3, 0.7.2): IDIAG is not in any of the nine *.COM
C         headers, and creating a new COMMON for it is forbidden.  Thus
C         the AAP phrase "IDIAG is set once by DIAGCTL" is realized as:
C         DIAGCTL is the single authority that computes the env->IDIAG
C         mapping; each subsystem obtains IDIAG by calling DIAGCTL once
C         at its entry (or receives it by argument) and threads it to
C         its guarded routines.
C         FLAG: if a process-wide single-evaluation global is later
C         desired, add a one-line /MODDIAG/ block via a modern
C         INCLUDE header -- DEFERRED to honor "zero new COMMON" and
C         the "exactly two .f files" scope of modern/diag/.
C
C     REFERENCE PROVENANCE:
C         bin/nastrn.f -- GETENV idiom (VALUE=' ' at L31; CALL GETENV
C                         (name,VALUE) at L33); LOUT=3 at L45.
C         bin/nastran  -- operator toggle placement: inline env vars
C                         before nastrn.exe; LOGNM=$probname.log (unit
C                         3 log).
C
C     Fixed-form FORTRAN 77; compiled by Sun f77 -fast -dn into
C     bin/nastlib.a via an updated bin/linknas (build wiring is done by
C     the bin/ agent, not in this file).
C=====================================================================
      INTEGER       IDIAG
      CHARACTER*80  VALUE
C
C     DIAGCTL IS THE SETTER -- NO  IF (IDIAG .EQ. 0) RETURN  HERE.
C     Start from a deterministic zero so a clean environment yields
C     IDIAG = 0 (APR.95 default) regardless of host GETENV behavior.
      IDIAG = 0
C
C     NASTRAN_LEGACY_INIT -> bit value 1
      VALUE = ' '
      CALL GETENV ( 'NASTRAN_LEGACY_INIT', VALUE )
      IF (VALUE .NE. ' ') IDIAG = IDIAG + 1
C
C     NASTRAN_INIT_VALIDATE -> bit value 2
      VALUE = ' '
      CALL GETENV ( 'NASTRAN_INIT_VALIDATE', VALUE )
      IF (VALUE .NE. ' ') IDIAG = IDIAG + 2
C
C     NASTRAN_DISPATCH_VALIDATE -> bit value 4
      VALUE = ' '
      CALL GETENV ( 'NASTRAN_DISPATCH_VALIDATE', VALUE )
      IF (VALUE .NE. ' ') IDIAG = IDIAG + 4
C
C     NASTRAN_DISPATCH_LOG -> bit value 8
      VALUE = ' '
      CALL GETENV ( 'NASTRAN_DISPATCH_LOG', VALUE )
      IF (VALUE .NE. ' ') IDIAG = IDIAG + 8
C
      RETURN
      END
