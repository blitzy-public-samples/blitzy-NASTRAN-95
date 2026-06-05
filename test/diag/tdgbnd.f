C=====================================================================
C     test/diag/tdgbnd.f
C---------------------------------------------------------------------
C     PROGRAM TDGBND -- NASTRAN-95 modernization unit-test driver.
C
C     PURPOSE
C        Validate the MESSAGE-CODE BAND contract of the modern runtime-
C        diagnostics layer (test/diag/ suite, coverage area 2):  every
C        NEW diagnostic / MESAGE code must lie in 9001-9999, the band
C        that is UNASSIGNED in um/MSSG.TXT (highest registered id 8015).
C        This driver is the executable assertion of that rule.
C
C     ROUTINE UNDER TEST   modern/diag/diaglog.f
C        SUBROUTINE DIAGLOG (IDIAG, ICODE, NVAL, MSG) -- formatted
C        diagnostic writer to logical unit 3 ONLY, gated by the guard
C        clause  IF (IDIAG .EQ. 0) RETURN.  An in-band code yields one
C        record:  ' *** MODERN DIAGNOSTIC ', I6, 1X, A, 1X, '(VALUE=',
C        I12, ')'  -- the numeric code is embedded after 'DIAGNOSTIC'.
C
C     REFERENCE SOURCES
C        um/MSSG.TXT   message-registry band evidence (max id = 8015).
C        bin/nastrn.f  unit-3 / LOGNM wiring idiom (LOUT=3; OPEN(3,..));
C                      internal list-directed read READ(VALUE,*).
C        mis/mesage.f  legacy MESAGE writes to NOUT (~unit 6); the
C                      modern writer instead targets unit 3 -- contrast.
C
C     DELIVERABLE ONLY -- NOT EXECUTED BY BLITZY.  Compiled and run
C     later in the developer's Solaris environment (csh + Sun f77):
C        f77 -fast -dn -o tdgbnd.exe test/diag/tdgbnd.f bin/nastlib.a
C     DIAGLOG is provided by bin/nastlib.a; this file is a SINGLE self-
C     contained PROGRAM unit and NEVER defines DIAGLOG or DIAGCTL.
C
C     OUTPUT CONTRACT
C        Exactly one verdict is written to the LOG unit (logical unit 3
C        / LOUT):  'PASS: TDGBND' on success, or 'FAIL: TDGBND' on any
C        failure.  The literal FAIL token is emitted ONLY on a real
C        failure path -- test/run_units.csh greps it and exits non-zero
C        on a match.  The verdict goes to unit 3 only, never stdout.
C
C     CROSS-CONSISTENCY
C        Band bounds and representative codes MUST match
C        test/diag/tdgbnd.ref (BAND_LOW 9001, BAND_HIGH 9999,
C        LEGACY_MAX_ID 8015, SAMPLE_CODES 9001 9500 9999).
C
C     Fixed-form FORTRAN 77 (Sun f77 -fast -dn).  No F90+, no third-
C     party libraries.
C=====================================================================
      PROGRAM TDGBND
C
C     ---- declarations -----------------------------------------------
      CHARACTER*80    LOG
      CHARACTER*132   LINE
      LOGICAL         OK
      INTEGER         ILOW, IHIGH, ICODE, KODE, NVAL
      INTEGER         I, IP
      INTEGER         IDIAG
      INTEGER         SAMPLE(3)
C
C     LOUT mirrors the bin/nastrn.f log-unit cell (the modern/ "no new
C     COMMON" rule does NOT apply to test/ drivers).  It holds the log
C     unit number (3); the driver writes its verdict to it.
      COMMON /LOGOUT/ LOUT
      INTEGER         LOUT
C
C     Message-code band bounds.  Sourced from um/MSSG.TXT analysis: the
C     highest registered message id is 8015 and a full registry scan
C     finds NO id in 9001-9999, so that band is reserved for new modern
C     diagnostics.  These MUST stay in step with test/diag/tdgbnd.ref.
      DATA ILOW, IHIGH /9001, 9999/
C
      OK = .TRUE.
C
C     ---- unit-3 (log) wiring -- mirror bin/nastrn.f -----------------
C     Read the log-file name from LOGNM (set per driver by
C     test/run_units.csh); fall back to a fixed name when unset so the
C     driver also runs standalone.  Open it on unit 3 and record LOUT=3
C     as the single diagnostic / verdict sink.
      LOUT = 3
      LOG  = ' '
      CALL GETENV ('LOGNM', LOG)
      IF (LOG .EQ. ' ') LOG = 'tdgbnd.log'
      OPEN (LOUT, FILE=LOG, STATUS='UNKNOWN')
C
C     =================================================================
C     SUB-CHECK 1 -- band definition is sane (static contract guard).
C     The bounds are constants, but asserting them documents and guards
C     the band contract against future regressions: the band must start
C     STRICTLY above the highest legacy id (no collision with
C     um/MSSG.TXT), be non-empty, and stay within 9999.
C     =================================================================
      IF (ILOW  .LE. 8015 ) OK = .FALSE.
      IF (ILOW  .GT. IHIGH) OK = .FALSE.
      IF (IHIGH .GT. 9999 ) OK = .FALSE.
C
C     =================================================================
C     SUB-CHECK 2 (PRIMARY) -- DIAGLOG accepts and emits representative
C     IN-BAND codes on unit 3.  Enable diagnostics by setting a LOCAL
C     IDIAG non-zero (DIAGLOG takes IDIAG as an argument; IDIAG = 0 is
C     the disabled/guard-return path, IDIAG = 8 the enabled path -- see
C     modern/diag/diaglog.f).  For each representative code:
C        (a) REWIND unit 3, CALL DIAGLOG, REWIND, READ the record back;
C        (b) assert a record WAS produced (in-band code accepted);
C        (c) the record embeds the numeric code after the word
C            DIAGNOSTIC -- parse it (list-directed internal read, the
C            same idiom as bin/nastrn.f READ(VALUE,*)) and assert it is
C            in-band AND equals the code passed (preserved, not
C            clamped).  A parse miss is NON-FATAL: the presence check
C            alone still binds (per the agent prompt).
C     =================================================================
      IDIAG = 8
      NVAL  = 0
      SAMPLE(1) = ILOW
      SAMPLE(2) = 9500
      SAMPLE(3) = IHIGH
C
      DO 30 I = 1, 3
         ICODE = SAMPLE(I)
C        Clear the capture region, emit one diagnostic, read it back.
         REWIND (LOUT)
         CALL DIAGLOG (IDIAG, ICODE, NVAL, 'TDGBND BAND CHECK')
         REWIND (LOUT)
         LINE = ' '
         READ (LOUT, '(A)', END=20) LINE
         GO TO 25
C        No record for an in-band, diagnostics-enabled call -> failure.
   20    OK = .FALSE.
         GO TO 30
C        A record was produced.  Locate the embedded code (it follows
C        the word DIAGNOSTIC) and parse it.  ERR/END => parse miss,
C        which is non-fatal: presence already established acceptance.
   25    IP = INDEX (LINE, 'DIAGNOSTIC')
         IF (IP .LE. 0) GO TO 30
         KODE = -1
         READ (LINE(IP+10:), *, ERR=30, END=30) KODE
         IF (KODE .LT. ILOW .OR. KODE .GT. IHIGH) OK = .FALSE.
         IF (KODE .NE. ICODE) OK = .FALSE.
   30 CONTINUE
C
C     ---- verdict (single line, unit 3 only) -------------------------
C     Rewind so the log holds exactly the verdict the harness greps.
      REWIND (LOUT)
      IF (OK) THEN
         WRITE (LOUT, '(A)') 'PASS: TDGBND'
      ELSE
         WRITE (LOUT, '(A)') 'FAIL: TDGBND'
      END IF
      CLOSE (LOUT)
      STOP
      END
