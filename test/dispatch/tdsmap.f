C=====================================================================
C     test/dispatch/tdsmap.f
C---------------------------------------------------------------------
C     PROGRAM TDSMAP -- NASTRAN-95 modernization unit-test driver.
C
C     PURPOSE
C        Validate DECISION EQUIVALENCE (test/dispatch/ suite, coverage
C        area 2):  for EVERY OSCAR operation code MODX = 1..217 the
C        modern table-driven dispatcher must resolve to the SAME target
C        entry-point as the legacy cascading computed-GO TO ladder in
C        the FROZEN mis/xsem00.f [L262-L761].  The legacy mapping is
C        supplied as the golden catalog test/dispatch/tdsmap.ref (217
C        data lines), transcribed read-only from that ladder.  This
C        driver loads the catalog and, for each MODX, compares the
C        modern dispatcher's catalogued target against the golden one.
C
C     ROUTINES UNDER TEST   modern/dispatch/disptbl.f (DISPTBL)
C                           modern/dispatch/dispval.f (DSPMAP)
C        DISPTBL is the table-driven OSCAR module dispatcher (the
C        System-Under-Test).  It is NOT called here: invoking
C        DISPTBL(MODX) would EXECUTE a real dispatched module with side
C        effects, defeating test isolation.  Instead this driver uses
C        the NON-EXECUTING data-twin classifier DSPMAP, which mirrors
C        DISPTBL's IF/ELSE-IF table as pure data and returns each
C        MODX's catalogued target WITHOUT executing any module.  Both
C        DISPTBL and DSPMAP are resolved from bin/nastlib.a at link
C        time and are NEVER defined in this file.
C
C     CROSS-AGENT INTERFACE  (ASSUMED at authoring -> RECONCILED)
C        modern/dispatch/ is authored by the dispatch agent in the SAME
C        build phase.  The interface ASSUMED by the original task was a
C        dry-run lookup  CALL DSPMAP (MODX, NAME, IST)  with status
C        sentinels and a 'RESERVED' token for no-op slots.  RECONCILED
C        against the real modern/dispatch/dispval.f, the authoritative
C        signature is
C           SUBROUTINE DSPMAP (MODX, NAME, IKIND)
C        with arguments:
C           MODX  (INTEGER,    INPUT)  operation code (1..217 here).
C           NAME  (CHARACTER*8,OUTPUT) catalogued target token, left-
C                 justified blank-padded: a module subroutine name
C                 (e.g. 'XCHK    '), or 'CONTINUE' for a reserved no-op
C                 slot, or 'FATAL   ' for an in-range fatal slot.
C           IKIND (INTEGER,    OUTPUT) slot-kind code:
C                 0 = mapped subroutine,  1 = reserved CONTINUE no-op,
C                 2 = in-range FATAL {MODX 1,2,4}, -1 = out-of-range,
C                 3 = in-range gap (defensive; never for the complete
C                 1..217 table).
C        SENTINEL AGREEMENT (reconciled): the no-op token is 'CONTINUE'
C        (NOT the originally-assumed 'RESERVED') and the fatal token is
C        'FATAL'; both EXACTLY match the tokens in tdsmap.ref, so the
C        comparison is a direct 8-character equality.  DSPMAP performs
C        NO module CALL and touches NO global state -- a pure lookup.
C        If a future dispatch revision renames the lookup or changes a
C        sentinel, reconcile the CALL and the token derivation below.
C
C     GOLDEN CATALOG  test/dispatch/tdsmap.ref  (read-only ground truth)
C        Lines beginning with '#' and blank lines are ignored.  Each
C        data line is  "<MODX> <TARGET>"  (an integer 1..217 then one
C        token: a subroutine name, or CONTINUE, or FATAL).  Any line
C        whose first field is not an integer in 1..217 is skipped (so
C        documentary KEY VALUE lines do no harm).  The catalog holds
C        TOTAL=217, CALL=193 (DISTINCT=188; XCEI shared by MODX
C        5,6,7,11,12,13), RESERVED=21 CONTINUE slots, FATAL=3 {1,2,4}.
C
C     CATALOG PATH RESOLUTION
C        run_units.csh does not guarantee the cwd.  The catalog path is
C        resolved robustly: (1) GETENV('TDSREF') if non-blank, else
C        (2) 'test/dispatch/tdsmap.ref' (repo-root cwd), else
C        (3) 'dispatch/tdsmap.ref' (cwd = test, the documented
C        'cd test ; ./run_units.csh' invocation), else
C        (4) 'tdsmap.ref' (suite-dir cwd).  run_units.csh also exports
C        TDSREF=<suite>/<base>.ref so candidate (1) resolves from any
C        cwd.  A developer may likewise set TDSREF when running from
C        another directory.  If none of the candidates opens, that is a
C        genuine failure.
C
C     OUTPUT CONTRACT
C        Exactly one verdict to the log unit (logical unit 3 / LOUT):
C        the success line 'PASS: TDSMAP', or on failure a line whose
C        first token is the four-letter failure word plus a colon and
C        ' TDSMAP'.  That failure token (letters F,A,I,L then a colon)
C        is emitted ONLY on a genuine failure path and appears in NO
C        banner, success, or informational line -- test/run_units.csh
C        greps the captured run output for it and exits non-zero on a
C        match.  All driver output goes to unit 3 only (mirrors the
C        bin/nastrn.f unit-3 / log wiring); stdout (unit 6) is never
C        used as the verdict channel and no new output unit is opened.
C
C     DELIVERABLE ONLY -- NOT EXECUTED BY BLITZY.  Compiled and run
C        later in the developer's Solaris environment (csh + Sun f77)
C        via  f77 -fast -dn -o <exe> test/dispatch/tdsmap.f
C        bin/nastlib.a .  This is a SINGLE self-contained PROGRAM unit
C        with nothing after END; it never defines DISPTBL, DISPVAL or
C        DSPMAP.  Fixed-form FORTRAN 77 only (Sun f77 -fast -dn);
C        every identifier <= 6 characters, every line <= 72 columns.
C=====================================================================
      PROGRAM TDSMAP
C
C     ---- declarations ---------------------------------------------
C     LOG  : log-file name from LOGNM (unit-3 target).
C     BUF  : one raw catalog record (read then parsed internally).
C     RPATH: resolved catalog path (TDSREF or a relative fallback).
C     GREF : golden MODX->token catalog; GREF(MODX) blank until seen.
C     DNAME: token returned by the DSPMAP lookup for a given MODX.
C     DTOK : dispatcher token derived from DNAME/IKIND for comparison.
C     CTOK : token field parsed from a catalog data line.
C     SEEN : per-MODX "present in catalog" flags (gap/dup detector).
C     OK   : overall verdict accumulator (.TRUE. until any failure).
C     NMIS : count of per-MODX decision mismatches (informational).
C     IKIND: DSPMAP slot-kind code (see header).
C     LOUT : NASTRAN log-unit cell, set to 3 as the bootstrap does.
      CHARACTER*80    LOG, BUF, RPATH
      CHARACTER*8     GREF(217), DNAME, DTOK, CTOK
      LOGICAL         OK, SEEN(217)
      INTEGER         MODX, IMODX, IKIND, NMIS, I, LOUT
      COMMON /LOGOUT/ LOUT
C
C     ---- initialize accumulators and the catalog arrays -----------
      OK   = .TRUE.
      NMIS = 0
      DO 100 I = 1, 217
         GREF(I) = ' '
         SEEN(I) = .FALSE.
  100 CONTINUE
C
C     ---- unit-3 (log) wiring -- mirror bin/nastrn.f ---------------
C     Read the log-file name from LOGNM (set per driver by
C     test/run_units.csh); fall back to a fixed name when unset so the
C     driver also runs standalone.  Open it on the LITERAL unit 3 and
C     record the unit in /LOGOUT/ LOUT exactly as the bootstrap does.
      LOG = ' '
      CALL GETENV ('LOGNM', LOG)
      IF (LOG .EQ. ' ') LOG = 'tdsmap.log'
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
C     ---- resolve and open the golden catalog ----------------------
C     Candidate 1: TDSREF (if set non-blank).  On a blank value or an
C     open error, fall through to candidate 2, then candidate 3.
      RPATH = ' '
      CALL GETENV ('TDSREF', RPATH)
      IF (RPATH .EQ. ' ') GO TO 200
      OPEN (8, FILE=RPATH, STATUS='OLD', ERR=200)
      GO TO 250
C     Candidate 2: repo-root-relative path (cwd = repository root).
  200 RPATH = 'test/dispatch/tdsmap.ref'
      OPEN (8, FILE=RPATH, STATUS='OLD', ERR=205)
      GO TO 250
C     Candidate 3: test-dir-relative path (cwd = test, the documented
C     'cd test ; ./run_units.csh' invocation).  From test/ the repo-root
C     path becomes test/test/dispatch/tdsmap.ref and the bare name
C     test/tdsmap.ref -- so this candidate is required.
  205 RPATH = 'dispatch/tdsmap.ref'
      OPEN (8, FILE=RPATH, STATUS='OLD', ERR=210)
      GO TO 250
C     Candidate 4: suite-dir-relative path (cwd = test/dispatch).
  210 RPATH = 'tdsmap.ref'
      OPEN (8, FILE=RPATH, STATUS='OLD', ERR=220)
      GO TO 250
C     No candidate opened -- a genuine failure (cannot load catalog).
C     Emit the single failure verdict to unit 3 and stop.
  220 WRITE (3,'(A)') ' CANNOT OPEN GOLDEN CATALOG TDSMAP.REF'
      WRITE (3,'(A)') 'FAIL: TDSMAP'
      CLOSE (3)
      STOP
  250 CONTINUE
C
C     ---- parse the catalog ----------------------------------------
C     Read each record; skip comment ('#' in column 1) and blank
C     lines.  A list-directed internal read pulls an integer MODX and
C     an unquoted token; a malformed line (e.g. a documentary KEY
C     VALUE line) errors on the read and is skipped.  Codes outside
C     1..217 are ignored; a repeated code is a catalog error.
  300 READ (8, '(A80)', END=390) BUF
      IF (BUF(1:1) .EQ. '#') GO TO 300
      IF (BUF .EQ. ' ')      GO TO 300
      READ (BUF, *, ERR=300) IMODX, CTOK
      IF (IMODX .LT. 1 .OR. IMODX .GT. 217) GO TO 300
      IF (SEEN(IMODX)) THEN
         OK   = .FALSE.
         NMIS = NMIS + 1
         WRITE (3,9001) IMODX
         GO TO 300
      END IF
      GREF(IMODX) = CTOK
      SEEN(IMODX) = .TRUE.
      GO TO 300
  390 CLOSE (8)
C
C     ---- completeness check ---------------------------------------
C     Every MODX in 1..217 must appear exactly once.  A gap means the
C     golden catalog is incomplete -- a genuine failure.
      DO 400 I = 1, 217
         IF (.NOT. SEEN(I)) THEN
            OK = .FALSE.
            WRITE (3,9002) I
         END IF
  400 CONTINUE
C
C     ---- decision-equivalence compare loop ------------------------
C     Only compare when the catalog loaded completely; otherwise the
C     verdict is already a failure and comparing against blank entries
C     would add redundant noise.  For each MODX the NON-EXECUTING
C     DSPMAP lookup yields the dispatcher's catalogued token and kind;
C     DTOK is derived to match the .ref token convention, then
C     compared for exact 8-character equality with the golden token.
      IF (OK) THEN
         DO 500 MODX = 1, 217
            CALL DSPMAP (MODX, DNAME, IKIND)
C           For the complete 1..217 catalog IKIND is 0/1/2 and DNAME
C           already holds the catalog token ('XCHK    ', 'CONTINUE',
C           'FATAL   ', ...).  IKIND = -1 (out-of-range) or 3 (in-range
C           gap) is anomalous and is forced to a non-matching token so
C           the comparison records a mismatch.
            IF (IKIND .EQ. -1 .OR. IKIND .EQ. 3) THEN
               DTOK = '????????'
            ELSE
               DTOK = DNAME
            END IF
            IF (DTOK .NE. GREF(MODX)) THEN
               NMIS = NMIS + 1
               OK   = .FALSE.
               WRITE (3,9003) MODX, GREF(MODX), DTOK
            END IF
  500    CONTINUE
      END IF
C
C     ---- verdict (single line, unit 3 only) -----------------------
C     The failure token is written ONLY in the .NOT. OK branch; it
C     appears nowhere else in this file.
      WRITE (3,'(A)') ' TDSMAP DECISION-EQUIVALENCE SUITE COMPLETE'
      WRITE (3,9004) NMIS
      IF (OK) THEN
         WRITE (3,'(A)') 'PASS: TDSMAP'
      ELSE
         WRITE (3,'(A)') 'FAIL: TDSMAP'
      END IF
      CLOSE (3)
C
C     ---- informational formats (NO failure token) -----------------
 9001 FORMAT (' DUPLICATE MODX IN CATALOG=', I6)
 9002 FORMAT (' MISSING MODX IN CATALOG=', I6)
 9003 FORMAT (' MISMATCH MODX=', I4, ' REF=', A8, ' GOT=', A8)
 9004 FORMAT (' MISMATCHES=', I6)
C
      STOP
      END
