      SUBROUTINE DIAGLOG (IDIAG, ICODE, NVAL, MSG)
C=====================================================================
C     modern/diag/diaglog.f
C---------------------------------------------------------------------
C     MODERNIZATION RUNTIME-DIAGNOSTICS FORMATTED WRITER -- logical
C     unit 3 only; codes 9001-9999; guard-clause zero overhead.
C=====================================================================
C
C     SIGNATURE (FROZEN -- do not change):
C         SUBROUTINE DIAGLOG (IDIAG, ICODE, NVAL, MSG)
C
C     ARGUMENTS (all INPUT; nothing is modified, nothing returned):
C         INTEGER       IDIAG -- master diagnostics-enable flag from
C                       DIAGCTL (0 => disabled).  Used ONLY by the
C                       guard clause below.
C         INTEGER       ICODE -- diagnostic message code; callers MUST
C                       pass a value in the 9001-9999 band.
C         INTEGER       NVAL  -- general-purpose integer payload to
C                       print (a count, a MODX value, a divergence
C                       index, ...).  Callers pass 0 when unused.
C         CHARACTER*(*) MSG   -- short caller-supplied text label.
C                       Assumed-length F77 dummy.
C
C     GUARD CLAUSE  IF (IDIAG .EQ. 0) RETURN  IS THE FIRST EXECUTABLE
C     STATEMENT (AAP 0.6.4 / 0.7.2).  When IDIAG = 0 (the default, no
C     NASTRAN_* toggle set) the routine returns immediately and does
C     no I/O -- provably zero overhead, bit-identical to APR.95.
C
C     WRITES ONLY TO LOGICAL UNIT 3 (LOUT).  Never stdout, never the
C     legacy print unit NOUT, never a new unit (AAP 0.7.2).  Unit 3 is
C     the NASTRAN log: the bootstrap sets LOUT = 3 (bin/nastrn.f L45)
C     and opens it (OPEN(3,...) at bin/nastrn.f L115); standalone test
C     drivers open it themselves.  DIAGLOG therefore ASSUMES unit 3 is
C     already connected and never opens or closes it.
C
C     LOUT IS A LOCAL PARAMETER (= 3), NOT a COMMON variable.  The cell
C     /LOGOUT/ LOUT is declared only inline in bin/nastrn.f (L10) and
C     is absent from every one of the nine *.COM headers, so it cannot
C     be reached by INCLUDE; re-declaring it as a COMMON is forbidden.
C     A local PARAMETER is not a COMMON and is fully compliant.
C
C     DIAGNOSTIC CODES are confined to the 9001-9999 band, which is
C     unassigned in um/MSSG.TXT (highest registered id = 8015; the
C     registry ends at line 6042 with no id in 9001-9999).  The file
C     um/MSSG.TXT is NOT edited; new codes are EMITTED here, never
C     registered.  A defensive band check (label 110) tags any
C     out-of-band code on unit 3 AND remaps the emitted code to the
C     in-band sentinel 9999, so an out-of-band value is NEVER written
C     as a diagnostic code (Binding Rule R5); it never aborts and never
C     escapes to any other unit.
C
C     NO COMMON / NO EQUIVALENCE / NO INCLUDE -- this routine touches
C     NO global state: IDIAG, ICODE, NVAL and MSG all arrive as
C     arguments and LOUT is a local PARAMETER (AAP 0.5.3 zero-new-
C     COMMON; 0.7.2).  This is verifiable by inspection.
C
C     DIAGLOG DOES NOT CALL MESAGE.  Legacy MESAGE (mis/mesage.f) writes
C     to NOUT (/SYSTEM/ cell 2), not unit 3, so routing normal logging
C     through it would violate "unit 3 only".  DIAGLOG is a pure
C     unit-3 writer.
C
C     FATAL CONVENTION (performed by the DETECTING routine, e.g. DISPTBL
C     for an unmapped MODX), NOT by DIAGLOG:
C        CALL MESAGE (-ICODE, IPARM, NAME)   ! ICODE in 9001..9999
C     where MESAGE has signature MESAGE(NO,PARM,NAME), INTEGER PARM,
C     NAME(2), and a negative NO terminates the run (see mis/mesage.f;
C     cf. CALL MESAGE(-61,0,0) at bin/nastrn.f L39).
C
C     DESIGN DECISION / MAINTAINER FLAG:
C         IDIAG is PASSED AS AN ARGUMENT (not stored in a COMMON block).
C         This is REQUIRED to honor "zero new COMMON / no literal
C         COMMON/... in modern/*.f except via an included header" (AAP
C         0.5.3, 0.7.2): IDIAG is not present in any of the nine *.COM
C         headers, and creating a new COMMON for it is forbidden.  Thus
C         the AAP phrase "IDIAG is set once by DIAGCTL" is realized as:
C         DIAGCTL is the single authority that computes the env->IDIAG
C         mapping; callers obtain IDIAG from it and pass it down (here,
C         into DIAGLOG).
C         FLAG: if a true process-wide single-evaluation global is later
C         desired, it can be added as a one-line /MODDIAG/ block via a
C         dedicated modern INCLUDE header -- DEFERRED here to honor
C         "zero new COMMON" and the "exactly two .f files" scope of
C         modern/diag/.
C
C     COORDINATION -- CALLERS MUST INVOKE:
C         CALL DIAGLOG (IDIAG, ICODE, NVAL, MSG)
C       e.g.  CALL DIAGLOG (IDIAG, 9001, NCNT, 'DISPATCH ENTRY COUNT')
C     TEST DRIVERS (test/diag/tdglog.f, tdggrd.f, tdgbnd.f): declare a
C     LOCAL  INTEGER IDIAG  and set it directly:
C         IDIAG = 0  -> disabled path (guard returns; zero unit-3 recs)
C         IDIAG = 8  -> enabled  path (record written to unit 3)
C     DIAGLOG does NOT decode individual toggle bits; the master guard
C     IF (IDIAG .EQ. 0) RETURN is the only gate it applies.  Per-toggle
C     gating (e.g. log dispatch only when NASTRAN_DISPATCH_LOG is set)
C     is the CALLER's responsibility before it calls DIAGLOG.  DIAGLOG
C     does not call DIAGCTL and has no compile-time dependency on it;
C     they communicate only through the IDIAG value the caller threads.
C
C     REFERENCE PROVENANCE:
C         bin/nastrn.f -- LOUT = 3 (L45); OPEN(3,...) (L115); fatal
C                         CALL MESAGE(-61,0,0) (L39).
C         mis/mesage.f -- MESAGE(NO,PARM,NAME) -> NOUT; negative NO is
C                         fatal (CALL PEXIT).
C         um/MSSG.TXT  -- band evidence: highest id 8015; 9001-9999
C                         free.
C
C     Fixed-form FORTRAN 77; compiled by Sun f77 -fast -dn into
C     bin/nastlib.a via an updated bin/linknas (build wiring is done by
C     the bin/ agent, not in this file).
C=====================================================================
      INTEGER       IDIAG, ICODE, NVAL
      CHARACTER*(*) MSG
      INTEGER       LOUT
      PARAMETER   ( LOUT = 3 )
      INTEGER       JCODE
C
C     GUARD CLAUSE -- FIRST EXECUTABLE STATEMENT (MANDATORY).  Zero
C     overhead when diagnostics are disabled (IDIAG = 0 => APR.95).
      IF (IDIAG .EQ. 0) RETURN
C
C     DEFENSIVE BAND CHECK -- a code outside 9001-9999 violates the
C     contract.  Tag the offending value on unit 3 (only) AND remap the
C     emitted code to the in-band sentinel 9999 so the core record below
C     can NEVER carry an out-of-band diagnostic code (Binding Rule R5:
C     codes confined to 9001-9999).  Do NOT abort and do NOT escape to
C     any other unit.  ICODE (an INPUT argument) is left unmodified; the
C     local JCODE carries the in-band code actually written.
      JCODE = ICODE
      IF (ICODE .LT. 9001 .OR. ICODE .GT. 9999) THEN
         WRITE (LOUT, 110) ICODE
         JCODE = 9999
      END IF
  110 FORMAT (' *** MODERN DIAG OUT-OF-BAND CODE = ', I10)
C
C     CORE ACTION -- write one formatted diagnostic record to unit 3
C     using the in-band JCODE (NEVER the possibly-invalid ICODE).
C     The leading blank in the format is line-printer carriage control.
      WRITE (LOUT, 100) JCODE, MSG, NVAL
  100 FORMAT (' *** MODERN DIAGNOSTIC ', I6, 1X, A, 1X,
     &        '(VALUE=', I12, ')')
C
      RETURN
      END
