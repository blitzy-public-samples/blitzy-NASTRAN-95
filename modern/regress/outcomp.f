      SUBROUTINE OUTCOMP (LUTST, LUREF, LULOG, NDIFF, IRET)
C=====================================================================
C     modern/regress/outcomp.f
C---------------------------------------------------------------------
C     FIELD-BY-FIELD OFP (Output File Processor) OUTPUT COMPARATOR.
C     Realizes the A3 = Candidate 2 decision (AAP 0.6.3): the golden-
C     master / characterization comparator that proves the modern/
C     abstraction layer preserves exact APR.95 solver behavior
C     (AAP 0.2.1, 0.3.1, 0.7.1, 0.7.3).
C=====================================================================
C
C     PURPOSE
C         Compare two already-open NASTRAN OFP (line-printer) text
C         streams -- a CANDIDATE and a GOLDEN MASTER from demoout/ --
C         skipping the inherently volatile lines, then comparing the
C         remaining content FIELD BY FIELD:
C           * floating-point fields : 6-significant-figure RELATIVE
C                                      tolerance (RTOL = 1.0D-6).
C           * integer and text      : EXACT / bitwise identity.
C         Returns a difference count (NDIFF) and a status code (IRET).
C         It does NOT decide PASS/FAIL and never calls EXIT; the
C         caller PROGRAM REGVAL owns the verdict.
C
C     LOCKED PUBLIC INTERFACE (regval.f and test/* depend on it)
C         SUBROUTINE OUTCOMP (LUTST, LUREF, LULOG, NDIFF, IRET)
C         LUTST (INTEGER, in)  logical unit of the CANDIDATE file,
C                              ALREADY OPENed by the caller.
C         LUREF (INTEGER, in)  logical unit of the GOLDEN MASTER file,
C                              ALREADY OPENed by the caller.
C         LULOG (INTEGER, in)  logical unit for the human-readable
C                              difference report.  The caller passes 6
C                              (stdout) so run_all.csh captures it via
C                              >>& $RUNLOG.  ALL report lines go here.
C         NDIFF (INTEGER, out) total count of field/line differences;
C                              0 => the two outputs match.
C         IRET  (INTEGER, out) 0 = completed normally; 1 = an I/O or
C                              format error occurred (e.g. a hard read
C                              error on the embedded-binary file
C                              demoout/t01231a.out).  Caller treats
C                              IRET .NE. 0 as a failure.
C
C     VOLATILE LINES SKIPPED (handled in NXTCMP)
C         * per-page header carrying volatile DATE + PAGE n, matched
C           by the signature 'SOLARIS NASTRAN' (e.g. "... SUN SOLARIS
C           NASTRAN / MAY 17, 95 / PAGE n").  Does NOT match the
C           static banner line 'SOLARIS VERSION'.
C         * final timing tail (3 lines): 'DATE:', 'END TIME',
C           'WALL CLOCK'.
C         * the entire cover/banner preceding the first page header.
C         * lines blank after the column-1 carriage control is gone.
C
C     SELF-CONTAINED -- NO COMMON, NO EQUIVALENCE, NO INCLUDE.  All
C     data arrives through arguments or is local; the nine *.COM
C     headers are NOT included.  Verifiable by inspection (AAP 0.5.3).
C
C     READS THE TWO STREAMS READ-ONLY.  This routine never OPENs or
C     CLOSEs any unit (the caller owns open/close) and never writes
C     to unit 3; every report line is written to LULOG.
C
C     NO GUARD CLAUSE.  This is explicitly-invoked standalone infra-
C     structure that must run unconditionally when called; it does
C     NOT take IDIAG.  The folder guard-clause rule (IF (IDIAG.EQ.0)
C     RETURN) applies only to IDIAG-gated diagnostic routines, not to
C     this comparator.
C
C     NEVER EMITS A VERDICT TOKEN (the words FAIL or PASS followed by
C     a colon).  Those verdict tokens are reserved for PROGRAM REGVAL;
C     this routine reports differences with wording such as MISMATCH /
C     DIFFERS so a grep for the failure verdict over the run log counts
C     only true per-deck verdicts.  On a clean match it writes ZERO
C     detail lines and returns NDIFF = 0.
C
C     PROGRAM UNITS IN THIS FILE (fixed-form FORTRAN 77; compiled by
C     Sun f77 -fast -dn into bin/nastlib.a; also gfortran-clean):
C         OUTCOMP -- this comparator driver.
C         NXTCMP  -- advance one stream to its next comparable line.
C         ICLASS  -- classify a token: 0=TEXT, 1=INTEGER, 2=REAL.
C     The tokenizer and the real-token parse are inlined in OUTCOMP.
C=====================================================================
C     STRICT FORTRAN 77 -- every name in this program unit is
C     EXPLICITLY typed below; no IMPLICIT NONE (an F90 feature) is used
C     and no name relies on implicit typing (AAP 0.7.2: no non-F77
C     dialect features).
C     --- dummy arguments ---
      INTEGER          LUTST, LUREF, LULOG, NDIFF, IRET
C     --- relative floating-point tolerance: 6 significant figures ---
      DOUBLE PRECISION RTOL
      PARAMETER       (RTOL = 1.0D-6)
C     --- token-table capacity (OFP lines hold a few dozen tokens) ---
      INTEGER          MAXTOK
      PARAMETER       (MAXTOK = 140)
C     --- per-stream comparable-line buffers and their lengths ---
      CHARACTER*255    CONTT, CONTR
      INTEGER          LCT, LCR
C     --- per-stream header-seen flags and end/error status ---
      LOGICAL          HEADST, HEADSR
      INTEGER          IEOFT, IEOFR, IERRT, IERRR
C     --- token start/end column tables for each stream ---
      INTEGER          IST(MAXTOK), IET(MAXTOK)
      INTEGER          ISR(MAXTOK), IER(MAXTOK)
      INTEGER          NT, NR
C     --- real parse values and tolerance work variables ---
      DOUBLE PRECISION VT, VR, DIFF, DEN
      INTEGER          JOST, JOSR
C     --- token classes, lengths and a per-token difference flag ---
      INTEGER          ICA, ICB, LA, LB, IDIF
C     --- loop counters and the comparable-line counter ---
      INTEGER          K, I, NLINE
C     --- ICLASS is an INTEGER function defined later in this file ---
      INTEGER          ICLASS
      INTRINSIC        ABS, MAX
C
C=====================================================================
C     INITIALIZE
C=====================================================================
      NDIFF  = 0
      IRET   = 0
      NLINE  = 0
      HEADST = .FALSE.
      HEADSR = .FALSE.
C
C=====================================================================
C     MAIN LOOP -- pull one comparable line from EACH stream, compare.
C=====================================================================
  100 CONTINUE
      CALL NXTCMP (LUTST, HEADST, IEOFT, IERRT, CONTT, LCT)
      CALL NXTCMP (LUREF, HEADSR, IEOFR, IERRR, CONTR, LCR)
C
C     --- hard read error on either stream -> fail and stop ---
      IF (IERRT .NE. 0 .OR. IERRR .NE. 0) THEN
         IRET = 1
         WRITE (LULOG, 9010)
         GO TO 800
      END IF
C
C     --- both streams exhausted -> normal completion ---
      IF (IEOFT .EQ. 1 .AND. IEOFR .EQ. 1) GO TO 800
C
C     --- exactly one stream ended early -> line-count mismatch ---
      IF (IEOFT .EQ. 1 .OR. IEOFR .EQ. 1) THEN
         NDIFF = NDIFF + 1
         WRITE (LULOG, 9020) NLINE
         IF (IEOFT .EQ. 0) THEN
C           --- candidate is longer: drain it, counting each line ---
  110       CONTINUE
            CALL NXTCMP (LUTST, HEADST, IEOFT, IERRT, CONTT, LCT)
            IF (IERRT .NE. 0) THEN
               IRET = 1
               WRITE (LULOG, 9010)
               GO TO 800
            END IF
            IF (IEOFT .EQ. 1) GO TO 800
            NDIFF = NDIFF + 1
            WRITE (LULOG, 9025) NLINE
            GO TO 110
         ELSE
C           --- golden master is longer: drain, counting each line ---
  120       CONTINUE
            CALL NXTCMP (LUREF, HEADSR, IEOFR, IERRR, CONTR, LCR)
            IF (IERRR .NE. 0) THEN
               IRET = 1
               WRITE (LULOG, 9010)
               GO TO 800
            END IF
            IF (IEOFR .EQ. 1) GO TO 800
            NDIFF = NDIFF + 1
            WRITE (LULOG, 9025) NLINE
            GO TO 120
         END IF
      END IF
C
C     --- both streams returned a comparable content line ---
      NLINE = NLINE + 1
C
C=====================================================================
C     TOKENIZE the candidate line CONTT(1:LCT) -> IST/IET, count NT.
C     Split on runs of blanks: skip blanks; mark the token start at
C     the first non-blank; advance to the next blank to mark the end.
C=====================================================================
      NT = 0
      I  = 1
  130 CONTINUE
      IF (I .GT. LCT) GO TO 150
      IF (CONTT(I:I) .EQ. ' ') THEN
         I = I + 1
         GO TO 130
      END IF
      NT = NT + 1
      IF (NT .GT. MAXTOK) THEN
         NDIFF = NDIFF + 1
         WRITE (LULOG, 9040) NLINE
         GO TO 100
      END IF
      IST(NT) = I
  140 CONTINUE
      I = I + 1
      IF (I .LE. LCT) THEN
         IF (CONTT(I:I) .NE. ' ') GO TO 140
      END IF
      IET(NT) = I - 1
      GO TO 130
  150 CONTINUE
C
C     --- TOKENIZE the golden-master line CONTR(1:LCR) -> ISR/IER ---
      NR = 0
      I  = 1
  160 CONTINUE
      IF (I .GT. LCR) GO TO 180
      IF (CONTR(I:I) .EQ. ' ') THEN
         I = I + 1
         GO TO 160
      END IF
      NR = NR + 1
      IF (NR .GT. MAXTOK) THEN
         NDIFF = NDIFF + 1
         WRITE (LULOG, 9040) NLINE
         GO TO 100
      END IF
      ISR(NR) = I
  170 CONTINUE
      I = I + 1
      IF (I .LE. LCR) THEN
         IF (CONTR(I:I) .NE. ' ') GO TO 170
      END IF
      IER(NR) = I - 1
      GO TO 160
  180 CONTINUE
C
C     --- token-count mismatch -> one difference, report, next line ---
      IF (NT .NE. NR) THEN
         NDIFF = NDIFF + 1
         WRITE (LULOG, 9030) NLINE, NT, NR
         WRITE (LULOG, 9031) CONTT(1:LCT)
         WRITE (LULOG, 9032) CONTR(1:LCR)
         GO TO 100
      END IF
C
C=====================================================================
C     PER-TOKEN COMPARISON -- the heart of the field-by-field rule.
C=====================================================================
      DO 200 K = 1, NT
         LA = IET(K) - IST(K) + 1
         LB = IER(K) - ISR(K) + 1
         ICA = ICLASS (CONTT(IST(K):IET(K)), LA)
         ICB = ICLASS (CONTR(ISR(K):IER(K)), LB)
         IF (ICA .EQ. 2 .AND. ICB .EQ. 2) THEN
C           --- both REAL: parse and apply the relative tolerance ---
            READ (CONTT(IST(K):IET(K)), *, IOSTAT=JOST) VT
            READ (CONTR(ISR(K):IER(K)), *, IOSTAT=JOSR) VR
            IF (JOST .NE. 0 .OR. JOSR .NE. 0) THEN
C              --- a parse failed (abutting/malformed token): fall
C              --- back to a SAFE exact-text comparison.  In a bit-
C              --- identical run the same f77 + FORMAT prints byte-
C              --- identical text, so this cannot raise a false fail.
               IDIF = 0
               IF (LA .NE. LB) THEN
                  IDIF = 1
               ELSE IF (CONTT(IST(K):IET(K)) .NE.
     &                  CONTR(ISR(K):IER(K))) THEN
                  IDIF = 1
               END IF
               IF (IDIF .EQ. 1) THEN
                  NDIFF = NDIFF + 1
                  WRITE (LULOG, 9060) NLINE, K
                  WRITE (LULOG, 9061) CONTT(IST(K):IET(K))
                  WRITE (LULOG, 9062) CONTR(ISR(K):IER(K))
               END IF
            ELSE
C              --- both parsed: 6-sig-fig RELATIVE tolerance.  DEN is
C              --- never negative; divide only when DEN > 0 so a pair
C              --- of exact zeros (DEN = 0) is a match with no divide.
               DIFF = ABS (VT - VR)
               DEN  = MAX (ABS(VT), ABS(VR))
               IF (DEN .GT. 0.0D0) THEN
                  IF (DIFF / DEN .GT. RTOL) THEN
                     NDIFF = NDIFF + 1
                     WRITE (LULOG, 9050) NLINE, K, VT, VR
                  END IF
               END IF
            END IF
         ELSE
C           --- INTEGER, TEXT, or mixed classes: EXACT comparison.
C           --- This realizes "integer fields bitwise identical" and
C           --- the same for text; a token that is INTEGER in one
C           --- stream but REAL in the other compares unequal.
            IDIF = 0
            IF (LA .NE. LB) THEN
               IDIF = 1
            ELSE IF (CONTT(IST(K):IET(K)) .NE.
     &               CONTR(ISR(K):IER(K))) THEN
               IDIF = 1
            END IF
            IF (IDIF .EQ. 1) THEN
               NDIFF = NDIFF + 1
               WRITE (LULOG, 9060) NLINE, K
               WRITE (LULOG, 9061) CONTT(IST(K):IET(K))
               WRITE (LULOG, 9062) CONTR(ISR(K):IER(K))
            END IF
         END IF
  200 CONTINUE
      GO TO 100
C
  800 CONTINUE
      RETURN
C
C=====================================================================
C     REPORT FORMATS.  NONE contains a verdict token (the words FAIL
C     or PASS followed by a colon); those belong to PROGRAM REGVAL.
C     The leading blank in each is line-printer carriage control.
C=====================================================================
 9010 FORMAT (' OUTCOMP: I/O ERROR READING OUTPUT STREAM')
 9020 FORMAT (' OUTCOMP: LINE COUNT MISMATCH AFTER COMPARABLE LINE ',
     &        I8, ' (ONE STREAM ENDED EARLY)')
 9025 FORMAT (' OUTCOMP: EXTRA COMPARABLE LINE IN LONGER STREAM ',
     &        '(AFTER LINE ', I8, ')')
 9030 FORMAT (' OUTCOMP: TOKEN COUNT DIFFERS AT LINE ', I8,
     &        ' :', I4, ' VS ', I4)
 9031 FORMAT ('   CAND: ', A)
 9032 FORMAT ('   GOLD: ', A)
 9040 FORMAT (' OUTCOMP: TOKEN OVERFLOW (EXCEEDS MAXTOK) AT LINE ',
     &        I8)
 9050 FORMAT (' OUTCOMP: REAL FIELD DIFFERS AT LINE ', I8,
     &        ' FIELD ', I4, ' : ', 1PE16.8, ' VS ', 1PE16.8)
 9060 FORMAT (' OUTCOMP: FIELD MISMATCH AT LINE ', I8, ' FIELD ', I4)
 9061 FORMAT ('   CAND TOKEN: [', A, ']')
 9062 FORMAT ('   GOLD TOKEN: [', A, ']')
      END
      SUBROUTINE NXTCMP (LU, HEADSN, IEOF, IERR, CONT, LCONT)
C=====================================================================
C     modern/regress/outcomp.f :: NXTCMP
C---------------------------------------------------------------------
C     Advance ONE OFP stream to its next COMPARABLE content line,
C     skipping all volatile and structurally-irrelevant records.
C
C     ARGUMENTS
C         LU     (INTEGER, in)        logical unit to read (open).
C         HEADSN (LOGICAL, in/out)    per-stream "first page header
C                                     seen" flag.  The caller sets it
C                                     .FALSE. once before the loop and
C                                     passes the SAME variable on every
C                                     call so the state persists;
C                                     NXTCMP sets it .TRUE. on the
C                                     first page header.  Everything
C                                     before that header is cover/
C                                     banner and is skipped.
C         IEOF   (INTEGER, out)       1 at end-of-file OR after a hard
C                                     read error; 0 when a comparable
C                                     line is returned.
C         IERR   (INTEGER, out)       1 ONLY on a hard read error
C                                     (IOSTAT .GT. 0); 0 otherwise.
C         CONT   (CHARACTER*(*), out) the comparable line with its
C                                     column-1 carriage-control
C                                     character removed (BUF(2:256)).
C         LCONT  (INTEGER, out)       last non-blank column of CONT;
C                                     the routine never returns a line
C                                     whose LCONT is 0 (blank lines
C                                     are skipped).
C
C     VOLATILE SIGNATURES SKIPPED
C         'SOLARIS NASTRAN'     -> per-page header (also sets HEADSN).
C         'DATE:'               -> final timing tail.
C         'END TIME'            -> final timing tail.
C         'WALL CLOCK'          -> final timing tail.
C         'MACHINE' AND 'BY '   -> tape-provenance line naming the
C                                  MACHINE that wrote a tape (INPUTT5/
C                                  OUTPUT5).  The machine name is
C                                  environment-specific (NUL padding in
C                                  the shipped demoout/t01231a.out), so
C                                  the whole line is volatile; the
C                                  signature is machine-name-INDEPENDENT
C                                  so it skips symmetrically in both
C                                  streams and does NOT match the
C                                  legitimate 'ON 32-BIT WORD MACHINE'
C                                  warning (which has no 'BY ').
C     Text line-ending residue -- a trailing CR (13) or LF (10) left in
C     the record by a CRLF-terminated file -- is replaced by a blank so
C     such files compare cleanly.  An embedded NUL (0) is likewise
C     normalized to a blank (recording HADNUL): the only NULs in the 132
C     shipped golden masters are the four-byte machine-name padding on
C     the volatile tape-provenance lines above, which are skipped whole,
C     so the all-132 regression gate can pass.  ANY OTHER control byte
C     (ICHAR .LT. 32), AND a NUL that survives every volatile skip, marks
C     the record as embedded binary / non-text: NXTCMP sets IERR = 1 and
C     IEOF = 1 and returns, so OUTCOMP reports IRET = 1.
C
C     SELF-CONTAINED -- NO COMMON, NO EQUIVALENCE, NO INCLUDE.
C=====================================================================
C     STRICT FORTRAN 77 -- all names explicitly typed; no IMPLICIT NONE
C     (an F90 feature) is used (AAP 0.7.2: no non-F77 dialect features).
      INTEGER       LU, IEOF, IERR, LCONT
      LOGICAL       HEADSN, HADNUL
      CHARACTER*(*) CONT
      CHARACTER*256 BUF
      INTEGER       IOS, I, IC
      INTRINSIC     INDEX, ICHAR, CHAR, LEN
C
      IEOF = 0
      IERR = 0
C
   10 CONTINUE
      READ (LU, '(A)', IOSTAT=IOS) BUF
      IF (IOS .LT. 0) THEN
C        --- end-of-file ---
         IEOF = 1
         RETURN
      ELSE IF (IOS .GT. 0) THEN
C        --- hard read error (e.g. an embedded-binary output file) ---
         IERR = 1
         IEOF = 1
         RETURN
      END IF
C
C     --- scan for control bytes.  Normalize the expected text
C     --- line-ending residue CR (13) / LF (10) to a blank, and ALSO
C     --- normalize an embedded NUL (0) to a blank while recording
C     --- HADNUL.  The shipped golden master demoout/t01231a.out carries
C     --- 20 NUL bytes -- four-byte machine-name padding on five VOLATILE
C     --- tape-provenance lines ("... WRITTEN BY <nul-name> MACHINE ...")
C     --- written by INPUTT5/OUTPUT5; those whole lines are skipped as
C     --- volatile just below (the MACHINE+'BY ' signature), so the NUL
C     --- padding never reaches a comparison.  EVERY OTHER control byte
C     --- (ICHAR .LT. 32) remains embedded binary: flag a hard error so
C     --- OUTCOMP returns IRET = 1 rather than silently comparing binary
C     --- as blanks.  A NUL that survives every volatile skip is also
C     --- treated as binary by the HADNUL guard below.
      HADNUL = .FALSE.
      DO 20 I = 1, 256
         IC = ICHAR(BUF(I:I))
         IF (IC .LT. 32) THEN
            IF (IC .EQ. 13 .OR. IC .EQ. 10) THEN
               BUF(I:I) = CHAR(32)
            ELSE IF (IC .EQ. 0) THEN
               BUF(I:I) = CHAR(32)
               HADNUL   = .TRUE.
            ELSE
               IERR = 1
               IEOF = 1
               RETURN
            END IF
         END IF
   20 CONTINUE
C
C     --- volatile per-page header: carries a volatile DATE and PAGE
C     --- n.  'SOLARIS NASTRAN' matches the page header only, NOT the
C     --- static 'SOLARIS VERSION' banner.  Mark the header as seen.
      IF (INDEX(BUF, 'SOLARIS NASTRAN') .GT. 0) THEN
         HEADSN = .TRUE.
         GO TO 10
      END IF
C
C     --- volatile final timing tail (3 lines) ---
      IF (INDEX(BUF, 'DATE:')      .GT. 0) GO TO 10
      IF (INDEX(BUF, 'END TIME')   .GT. 0) GO TO 10
      IF (INDEX(BUF, 'WALL CLOCK') .GT. 0) GO TO 10
C
C     --- volatile tape-provenance lines: INPUTT5/OUTPUT5 emit the name
C     --- of the MACHINE that wrote the tape, e.g.
C     ---   "... WRITTEN BY <machine-name> MACHINE ..."  and
C     ---   "(BY <machine-name> MACHINE, ... RECORDS)".
C     --- The machine name is environment-specific (NUL padding in the
C     --- shipped demoout/t01231a.out, a real name on a fresh run), so
C     --- the whole line is volatile and skipped SYMMETRICALLY in both
C     --- streams via a machine-name-INDEPENDENT signature: the line
C     --- contains BOTH 'MACHINE' and 'BY '.  This matches exactly the
C     --- five tape-provenance lines across all 132 golden masters and
C     --- does NOT match the legitimate, non-volatile
C     --- '... ON 32-BIT WORD MACHINE' warning (which has no 'BY ').
      IF (INDEX(BUF, 'MACHINE') .GT. 0 .AND.
     &    INDEX(BUF, 'BY ')     .GT. 0) GO TO 10
C
C     --- skip the cover/banner preceding the first page header ---
      IF (.NOT. HEADSN) GO TO 10
C
C     --- residual-binary guard: a NUL that was normalized above but did
C     --- NOT belong to a recognized volatile line is unexpected binary
C     --- content; treat it as a hard error (IRET = 1) exactly as before,
C     --- so genuine embedded-binary output is never silently compared.
      IF (HADNUL) THEN
         IERR = 1
         IEOF = 1
         RETURN
      END IF
C
C     --- strip the column-1 carriage-control character ('1','0',
C     --- ' ','+') by taking columns 2..256 as the comparable text ---
      CONT = BUF(2:256)
C
C     --- find the last non-blank column; skip a blank-after-strip
C     --- line (it carries no comparable tokens) ---
      LCONT = 0
      DO 30 I = LEN(CONT), 1, -1
         IF (CONT(I:I) .NE. ' ') THEN
            LCONT = I
            GO TO 40
         END IF
   30 CONTINUE
   40 CONTINUE
      IF (LCONT .EQ. 0) GO TO 10
C
      IEOF = 0
      RETURN
      END
      INTEGER FUNCTION ICLASS (STR, L)
C=====================================================================
C     modern/regress/outcomp.f :: ICLASS
C---------------------------------------------------------------------
C     Classify a whitespace-delimited token.
C         RETURNS 0 = TEXT, 1 = INTEGER, 2 = REAL.
C
C     A token is numeric (INTEGER or REAL) IFF every character is in
C     the set { 0-9 + - . E e D d } AND at least one character is a
C     digit 0-9.  Among numeric tokens it is REAL when any character
C     is one of { . E e D d } (a decimal point or an E/D exponent
C     marker), otherwise INTEGER.  Anything else is TEXT.
C
C     Examples: 11, 162 -> INTEGER;  6.326195E-04, -5.312650E-04,
C     1.27579471D+02, 0.00000000D+00, 0.0 -> REAL;  G, OUGV2, POINT,
C     TYPE, ID. (has a letter), 163, (trailing comma) -> TEXT.
C
C     ARGUMENTS
C         STR (CHARACTER*(*), in) the token text (only STR(1:L) read).
C         L   (INTEGER, in)       the token length in characters.
C
C     SELF-CONTAINED -- NO COMMON, NO EQUIVALENCE, NO INCLUDE.
C=====================================================================
C     STRICT FORTRAN 77 -- all names explicitly typed; no IMPLICIT NONE
C     (an F90 feature) is used (AAP 0.7.2: no non-F77 dialect features).
      CHARACTER*(*) STR
      INTEGER       L
      INTEGER       I, ND
      LOGICAL       ISREAL
      CHARACTER*1   C
C
      ICLASS = 0
      IF (L .LE. 0) RETURN
      ND     = 0
      ISREAL = .FALSE.
C
      DO 10 I = 1, L
         C = STR(I:I)
         IF (C .GE. '0' .AND. C .LE. '9') THEN
            ND = ND + 1
         ELSE IF (C .EQ. '+' .OR. C .EQ. '-') THEN
C           --- a leading/exponent sign is permitted ---
            CONTINUE
         ELSE IF (C .EQ. '.' .OR. C .EQ. 'E' .OR. C .EQ. 'e' .OR.
     &            C .EQ. 'D' .OR. C .EQ. 'd') THEN
C           --- a decimal point or E/D exponent marker => REAL ---
            ISREAL = .TRUE.
         ELSE
C           --- any other character forces the token to TEXT ---
            ICLASS = 0
            RETURN
         END IF
   10 CONTINUE
C
      IF (ND .EQ. 0) THEN
         ICLASS = 0
      ELSE IF (ISREAL) THEN
         ICLASS = 2
      ELSE
         ICLASS = 1
      END IF
      RETURN
      END
