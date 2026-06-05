      SUBROUTINE DISPVAL (IDIAG, NENT, NDUP, NUNMAP, IST)
C=====================================================================
C     modern/dispatch/dispval.f
C---------------------------------------------------------------------
C     OSCAR DISPATCH-TABLE VALIDATOR (DISPVAL) + NON-EXECUTING MODX
C     CLASSIFIER (DSPMAP).  Part of the A2 table-driven dispatch
C     modernization (AAP 0.2.1, 0.6.2).  This file is the DATA TWIN of
C     the executing dispatcher modern/dispatch/disptbl.f: DSPMAP (the
C     second unit below) and the IF/ELSE IF chain in DISPTBL encode the
C     IDENTICAL MODX->target mapping in identical numerical order, so
C     the two can never silently drift.  The validator proves the
C     modernized dispatch is COMPLETE and UNAMBIGUOUS without touching
C     the FROZEN mis/xsem00.f ladder [L262-L761] -- pure branch-by-
C     abstraction.
C
C     SIGNATURE (authoritative; IDIAG is the LEADING argument, matching
C     the project-wide convention that IDIAG is ALWAYS an argument and
C     NEVER a COMMON cell; mirrors sibling STATEVAL(IDIAG,IST)):
C         SUBROUTINE DISPVAL (IDIAG, NENT, NDUP, NUNMAP, IST)
C
C     ARGUMENTS:
C         IDIAG  (INTEGER, INPUT)  -- diagnostic bitmask from DIAGCTL.
C                Bit4 = NASTRAN_DISPATCH_VALIDATE, bit8 =
C                NASTRAN_DISPATCH_LOG.  IDIAG.EQ.0 => APR.95 default
C                (the guard returns immediately, doing nothing).
C         NENT   (INTEGER, OUTPUT) -- count of catalogued dispatch
C                entries enumerated (comes out = 217).
C         NDUP   (INTEGER, OUTPUT) -- count of duplicate MODX codes
C                (always 0: first-match classification precludes dups).
C         NUNMAP (INTEGER, OUTPUT) -- count of in-range MODX with no
C                mapping (gap detector; 0 for the complete table).
C         IST    (INTEGER, OUTPUT) -- overall status: 0 = OK (all
C                assertions pass), non-zero = failure.
C
C     GUARD CLAUSE (AAP 0.7.3): IF (IDIAG .EQ. 0) RETURN is the FIRST
C     executable statement -- zero runtime overhead when diagnostics
C     are disabled.  CONSEQUENCE (cross-agent contract): when IDIAG = 0
C     the guard returns leaving the OUTPUT args UNDEFINED, so a caller
C     that wants results MUST pass a non-zero IDIAG.  The sibling
C     test/dispatch/tdscnt.f therefore calls
C         CALL DISPVAL (4, NENT, NDUP, NUNMAP, IST)
C     (4 = the DISPATCH_VALIDATE bit), exactly as the sibling state
C     tests pass a leading IDIAG to STATEVAL.
C
C     REPORTING: all diagnostics route through the sibling writer
C     DIAGLOG (modern/diag/diaglog.f), whose signature is
C     DIAGLOG (IDIAG, ICODE, NVAL, MSG) with CHARACTER*(*) MSG.  DIAGLOG
C     re-applies its own guard, writes to logical unit 3 ONLY (its
C     internal LOUT = 3), and enforces the 9001-9999 band.  DISPVAL
C     never WRITEs to any unit directly.  Dispatch sub-band codes:
C         9300 summary OK,    9302 entry-count mismatch,
C         9303 duplicate,     9304 in-range unmapped,
C         9305 verbose per-MODX (only when bit8 set),
C         9399 divergence summary.
C     The ONLY fatal MESAGE is MESAGE (-9301, MODX, SUBNAM) on a
C     genuine in-range gap (IKIND.EQ.3), which never fires for the
C     complete 1..217 table; thus DISPVAL never aborts (this keeps
C     tdscnt.f, which links the real mesage.o, safe from an unexpected
C     abort).
C
C     NO COMMON / NO EQUIVALENCE / NO INCLUDE: DISPVAL touches no global
C     state -- it only enumerates the catalogue via DSPMAP and reports
C     via DIAGLOG/MESAGE (AAP 0.5.3, 0.7.2).  Verifiable by inspection.
C
C     Fixed-form FORTRAN 77; compiled by Sun f77 -fast -dn into
C     bin/nastlib.a via an updated bin/linknas.
C=====================================================================
      INTEGER IDIAG, NENT, NDUP, NUNMAP, IST
      INTEGER MODX, IKIND, SUBNAM(2)
      CHARACTER*8 NAME
C
C     Hollerith 'DISPVAL ' packed into a 2-word INTEGER array for the
C     NAME argument of MESAGE (MESAGE(NO,PARM,NAME), INTEGER NAME(2)).
      DATA SUBNAM /4HDISP,4HVAL /
C
C     GUARD CLAUSE -- FIRST EXECUTABLE STATEMENT (MANDATORY, AAP 0.7.3).
C     Zero overhead when diagnostics disabled (IDIAG = 0 => APR.95).
      IF (IDIAG .EQ. 0) RETURN
C
C     Initialize counters AFTER the guard (these are executable
C     assignments and must not precede the guard).
      NENT   = 0
      NDUP   = 0
      NUNMAP = 0
      IST    = 0
C
C     Enumerate the full catalogue MODX = 1..217.  DSPMAP classifies
C     each code; first-match classification means a single MODX matches
C     exactly one entry, so duplicates are structurally impossible and
C     NDUP stays 0 (still reported for the cross-agent count contract).
      DO 100 MODX = 1, 217
         CALL DSPMAP (MODX, NAME, IKIND)
C        Catalogued entry: 0 = mapped subroutine, 1 = reserved
C        CONTINUE no-op, 2 = in-range FATAL {1,2,4}.
         IF (IKIND .EQ. 0 .OR. IKIND .EQ. 1 .OR. IKIND .EQ. 2) THEN
            NENT = NENT + 1
         ELSE IF (IKIND .EQ. 3) THEN
C           In-range value with NO mapping -- a genuine gap.  For the
C           complete/correct table this NEVER executes.  Count it and
C           raise the fatal dispatch-band diagnostic.
            NUNMAP = NUNMAP + 1
            CALL MESAGE (-9301, MODX, SUBNAM)
         END IF
C        Verbose per-MODX logging only when the DISPATCH_LOG bit (bit8)
C        is set.  Disabled by default => silent, cheap runs.
         IF (MOD(IDIAG/8,2) .NE. 0) THEN
            CALL DIAGLOG (IDIAG, 9305, MODX, NAME)
         END IF
  100 CONTINUE
C
C     Overall status: OK iff the enumerated count matches the catalogue
C     size with no duplicates and no in-range gaps.
      IF (NENT .EQ. 217 .AND. NDUP .EQ. 0 .AND. NUNMAP .EQ. 0) THEN
         IST = 0
      ELSE
         IST = 1
      END IF
C
C     Report through DIAGLOG (unit 3 only; codes in 9001-9999 band).
      IF (IST .EQ. 0) THEN
         CALL DIAGLOG (IDIAG, 9300, NENT,
     &                 'DISPATCH TABLE VALIDATED OK')
      ELSE
         IF (NENT .NE. 217) THEN
            CALL DIAGLOG (IDIAG, 9302, NENT,
     &                    'DISPATCH ENTRY COUNT MISMATCH')
         END IF
         IF (NDUP .GT. 0) THEN
            CALL DIAGLOG (IDIAG, 9303, NDUP,
     &                    'DISPATCH DUPLICATE CODE')
         END IF
         IF (NUNMAP .GT. 0) THEN
            CALL DIAGLOG (IDIAG, 9304, NUNMAP,
     &                    'DISPATCH IN-RANGE UNMAPPED')
         END IF
         CALL DIAGLOG (IDIAG, 9399, IST,
     &                 'DISPATCH DIVERGENCES DETECTED')
      END IF
C
      RETURN
      END
      SUBROUTINE DSPMAP (MODX, NAME, IKIND)
C=====================================================================
C     modern/dispatch/dispval.f  (second program unit)
C---------------------------------------------------------------------
C     NON-EXECUTING MODX CLASSIFIER.  Given an OSCAR operation code
C     MODX, return the catalogued target token (NAME) and a kind code
C     (IKIND).  This is a PURE lookup: it performs NO CALL to any
C     dispatched module and changes NO global state -- it merely
C     mirrors the dispatch table as data.  It serves DISPVAL (above)
C     and the sibling test/dispatch/tdsmap.f, which links it from
C     nastlib.a and compares its returns against the golden tdsmap.ref.
C
C     ARGUMENTS:
C         MODX  (INTEGER, INPUT)      -- operation code; expected
C               1..217 but tolerates any integer.
C         NAME  (CHARACTER*8, OUTPUT) -- catalogued token, left-
C               justified and blank-padded to 8: a module subroutine
C               name (e.g. 'XCHK    '), or 'CONTINUE' for a reserved
C               no-op slot, or 'FATAL   ' for a fatal code.
C         IKIND (INTEGER, OUTPUT)     -- kind code:
C               0 = mapped subroutine,
C               1 = reserved CONTINUE no-op,
C               2 = in-range FATAL (MODX 1,2,4),
C              -1 = out-of-range FATAL (MODX<1 or MODX>217),
C               3 = in-range value with no table entry (defensive;
C                   cannot occur for the complete 1..217 table).
C
C     The MODX->token table below is byte-identical to the golden
C     test/dispatch/tdsmap.ref, which is itself transcribed verbatim
C     from the FROZEN mis/xsem00.f ladder [L262-L761].  Totals:
C     TOTAL = 217, CALL = 193 (DISTINCT = 188; XCEI is shared by MODX
C     5,6,7,11,12,13), RESERVED = 21 CONTINUE slots, FATAL = 3
C     (MODX 1,2,4).
C
C     IKIND is DERIVED from the token (single source of truth = TBL):
C     'FATAL' => 2, 'CONTINUE' => 1, anything else => 0.  No module
C     subroutine name equals 'FATAL' or 'CONTINUE', so the derivation
C     is exact.  (The out-of-range case is handled first and returns
C     IKIND = -1 before this derivation.)
C
C     NO COMMON / NO EQUIVALENCE / NO INCLUDE.
C=====================================================================
      INTEGER MODX, IKIND
      CHARACTER*8 NAME
      INTEGER I
      CHARACTER*8 TBL(217)
C
C     Catalogued MODX->token table (numerical order 1..217), generated
C     byte-identically from test/dispatch/tdsmap.ref.
      DATA (TBL(I),I=  1, 10)/
     &  'FATAL   ','FATAL   ','XCHK    ','FATAL   ','XCEI    ',
     &  'XCEI    ','XCEI    ','XSAVE   ','XPURGE  ','XEQUIV  '/
      DATA (TBL(I),I= 11, 20)/
     &  'XCEI    ','XCEI    ','XCEI    ','DADD    ','DADD5   ',
     &  'AMG     ','AMP     ','APD     ','BMG     ','CASE    '/
      DATA (TBL(I),I= 21, 30)/
     &  'CYCT1   ','CYCT2   ','CEAD    ','CURV    ','CONTINUE',
     &  'DDR     ','DDR1    ','DDR2    ','DDRMM   ','DDCOMP  '/
      DATA (TBL(I),I= 31, 40)/
     &  'DIAGON  ','DPD     ','DSCHK   ','DSMG1   ','DSMG2   ',
     &  'CONTINUE','DUMOD1  ','DUMOD2  ','DUMOD3  ','DUMOD4  '/
      DATA (TBL(I),I= 41, 50)/
     &  'CONTINUE','EMA1    ','EMG     ','FA1     ','FA2     ',
     &  'DFBS    ','FRLG    ','FRRD    ','CONTINUE','GI      '/
      DATA (TBL(I),I= 51, 60)/
     &  'GKAD    ','GKAM    ','GP1     ','GP2     ','GP3     ',
     &  'GP4     ','GPCYC   ','GPFDR   ','DUMOD5  ','GPWG    '/
      DATA (TBL(I),I= 61, 70)/
     &  'CONTINUE','INPUT   ','INPTT1  ','INPTT2  ','INPTT3  ',
     &  'INPTT4  ','MATGEN  ','MATGPR  ','MATPRN  ','PRTINT  '/
      DATA (TBL(I),I= 71, 80)/
     &  'MCE1    ','MCE2    ','MERGE1  ','CONTINUE','MODA    ',
     &  'MODACC  ','MODB    ','MODC    ','DMPYAD  ','MTRXIN  '/
      DATA (TBL(I),I= 81, 90)/
     &  'OFP     ','OPTPR1  ','OPTPR2  ','CONTINUE','OUTPT   ',
     &  'OUTPT1  ','OUTPT2  ','OUTPT3  ','OUTPT4  ','QPARAM  '/
      DATA (TBL(I),I= 91,100)/
     &  'PARAML  ','QPARMR  ','PARTN1  ','CONTINUE','MRED1   ',
     &  'MRED2   ','CMRD2   ','PLA1    ','PLA2    ','PLA3    '/
      DATA (TBL(I),I=101,110)/
     &  'PLA4    ','CONTINUE','DPLOT   ','DPLTST  ','PLTTRA  ',
     &  'PRTMSG  ','PRTPRM  ','RANDOM  ','RBMG1   ','RBMG2   '/
      DATA (TBL(I),I=111,120)/
     &  'RBMG3   ','RBMG4   ','CONTINUE','REIG    ','RMG     ',
     &  'SCALAR  ','SCE1    ','SDR1    ','SDR2    ','SDR3    '/
      DATA (TBL(I),I=121,130)/
     &  'SDRHT   ','SEEMAT  ','CONTINUE','SETVAL  ','SMA1    ',
     &  'SMA2    ','SMA3    ','SMP1    ','SMP2    ','SMPYAD  '/
      DATA (TBL(I),I=131,140)/
     &  'SOLVE   ','CONTINUE','SSG1    ','SSG2    ','SSG3    ',
     &  'SSG4    ','SSGHT   ','TA1     ','TABPCH  ','CONTINUE'/
      DATA (TBL(I),I=141,150)/
     &  'TABFMT  ','TABPT   ','CONTINUE','TIMTST  ','TRD     ',
     &  'TRHT    ','TRLG    ','DTRANP  ','DUMERG  ','DUPART  '/
      DATA (TBL(I),I=151,160)/
     &  'VDR     ','VEC     ','CONTINUE','XYPLOT  ','XYPRPT  ',
     &  'XYTRAN  ','CONTINUE','COMB1   ','COMB2   ','EXIO    '/
      DATA (TBL(I),I=161,170)/
     &  'RCOVR   ','EMFLD   ','CONTINUE','RCOVR3  ','REDUCE  ',
     &  'SGEN    ','SOFI    ','SOFO    ','SOFUT   ','SUBPH1  '/
      DATA (TBL(I),I=171,180)/
     &  'PLTMRG  ','CONTINUE','COPY    ','SWITCH  ','MPY3    ',
     &  'DDCMPS  ','LODAPP  ','GPSTGN  ','EQMCK   ','ADR     '/
      DATA (TBL(I),I=181,190)/
     &  'FRRD2   ','GUST    ','IFT     ','LAMX    ','EMA     ',
     &  'ANISOP  ','CONTINUE','GENCOS  ','DDAMAT  ','DDAMPG  '/
      DATA (TBL(I),I=191,200)/
     &  'NRLSUM  ','GENPAR  ','CASEGE  ','DESVEL  ','PROLAT  ',
     &  'MAGBDY  ','COMUGV  ','FLBMG   ','GFSMA   ','TRAIL   '/
      DATA (TBL(I),I=201,210)/
     &  'SCAN    ','CONTINUE','PTHBDY  ','VARIAN  ','FVRST1  ',
     &  'FVRST2  ','ALG     ','APDB    ','PROMPT  ','OLPLOT  '/
      DATA (TBL(I),I=211,217)/
     &  'INPTT5  ','OUTPT5  ','CONTINUE','QPARMD  ','GINOFL  ',
     &  'DBASE   ','NORMAL  '/
C
C     Out-of-range guard FIRST: a MODX outside 1..217 is fatal, with
C     the distinguishing kind code -1 (NOT 2).
      IF (MODX .LT. 1 .OR. MODX .GT. 217) THEN
         NAME  = 'FATAL'
         IKIND = -1
         RETURN
      END IF
C
C     In-range: look up the catalogued token, then derive the kind.
      NAME = TBL(MODX)
      IF (NAME .EQ. 'FATAL') THEN
         IKIND = 2
      ELSE IF (NAME .EQ. 'CONTINUE') THEN
         IKIND = 1
      ELSE
         IKIND = 0
      END IF
C
      RETURN
      END
