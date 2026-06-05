C=====================================================================
C     modern/state/stateacc.f
C---------------------------------------------------------------------
C     MODERNIZATION GLOBAL-STATE ACCESSOR / FACADE LAYER
C
C     Accessor/facade GET/SET layer over the existing nine *.COM
C     COMMON headers; the single mediation point for all modern
C     reads and updates of the subset of legacy global state
C     referenced by the new modernization components.  ZERO new COMMON
C     and ZERO new storage-association (aliasing) statements -- every
C     COMMON variable is reached only through an INCLUDE of the
C     appropriate *.COM header.
C=====================================================================
C
C     COMPLIANCE STATEMENT (verifiable by inspection):
C       * Every COMMON variable is reached ONLY through an INCLUDEd
C         *.COM header -- there is NO literal COMMON statement and NO
C         storage-association (aliasing) statement anywhere in this
C         file.
C       * Exactly ONE header is INCLUDEd per program unit.  Headers are
C         NEVER combined in a single unit because two block names are
C         declared with conflicting layouts across headers:
C           - /DSNAME/ = DSNAMES(89)*80 in NASNAMES.COM, but
C                        MDSNAM(89)*80  in DSIOF.COM (the SAME memory
C                        under two names); GROUP C uses ONLY the
C                        NASNAMES.COM/DSNAMES view and never wraps
C                        MDSNAM (it would be a redundant alias).
C           - /ZZZZZZ/ = IBASE(700000) in XNSTRN.COM, but MEM(10) in
C                        ZZZZZZ.COM (neither is wrapped here).
C         The conflict matters only WITHIN a single scoping unit, so
C         placing the three header groups in one file is safe -- no
C         unit INCLUDEs more than one header.
C       * Each accessor wraps its cell EXACTLY as declared in the
C         header it INCLUDEs (exact name, type and dimensionality).
C       * Accessors are pure store/fetch: NO WRITE/PRINT/OPEN, NO
C         CALL MESAGE, NO guard clause, NO EXTERNAL/SAVE.  (The
C         IF (IDIAG .EQ. 0) RETURN guard belongs to the validators and
C         loggers -- diaglog.f, initval.f, stateval.f, dispval.f --
C         NOT to these accessors.)
C
C     /SYSTEM/ LAYOUT NOTE (NBPW word position -- RESOLVED):
C       The /SYSTEM/ accessors rely on the SMCOMX.COM /SYSTEM/ layout
C       (ISYSBF,NOUT,DUM1(37),NBPW,DUM2(14),ISPREC).  /SYSTEM/ appears
C       in only this one of the nine headers.  NBPW is word 40 here,
C       and the ARRAY-AWARE bd/semdbd.f layout ALSO puts NBPW at word
C       40; the "word 38" figure is only a NAIVE all-scalar miscount,
C       not the canonical layout (corroborated by the mds/btstrp.f
C       EQUIVALENCE (B(40),NBPW)), so the two layouts AGREE.  Words 1
C       (ISYSBF) and 2 (NOUT) are consistent across every NASTRAN
C       /SYSTEM/ declaration and are SAFE.  KTIME is NOT a named
C       /SYSTEM/ cell here; the dispatcher obtains it via CALL
C       TMTOGO(KTIME).  A pure SET-then-GET round-trip is correct
C       because it reads back the very cell it wrote within the SMCOMX
C       layout.
C
C     GETLOG NAME-COLLISION FLAG (maintainer note):
C       The accessor GETLOG shares its name with the Unix/GNU library
C       routine getlog (getlogin).  The name is RETAINED VERBATIM per
C       the published contract.  Under Sun f77 (production) CALL GETLOG
C       binds to this accessor; under gfortran (validation) GETLOG is
C       an intrinsic, so callers must declare EXTERNAL GETLOG.  See the
C       full note at SUBROUTINE GETLOG below.  SETLOG is unaffected.

C
C     SCOPE DISCIPLINE (deliberate omissions, AAP 0.4.2):
C       /GINOX/, /PAKBLK/, /ZZZZZZ/ and /MMACOM/ are intentionally NOT
C       wrapped -- no modern component references them.  They remain
C       available "as needed" for a future modernization phase.
C
C     GET/SET -> COMMON-block.cell MAPPING (the published contract that
C     modern/state/stateval.f and the test/state/ drivers reconcile to;
C     names are <= 7 chars and accepted by Sun f77):
C
C       GROUP A -- INCLUDE 'DSIOF.COM' (22 routines, all INTEGER)
C         GETLCW  / SETLCW   <-> /DSIO/   LCW
C         GETLWRD / SETLWRD  <-> /DSIO/   LWORDS
C         GETNWRD / SETNWRD  <-> /DSIO/   NWORDS
C         GETMDSN / SETMDSN  <-> /DSIO/   MAXDSN
C         GETNBUF / SETNBUF  <-> /DSIO/   NBUFF
C         GETDBLN / SETDBLN  <-> /DBM/    IDBLEN
C         GETDBAD / SETDBAD  <-> /DBM/    IDBADR
C         GETNBLK / SETNBLK  <-> /DBM/    NBLOCK
C         GETMBLK / SETMBLK  <-> /DBM/    MAXBLK
C         GETLNOP / SETLNOP  <-> /DBM/    LENOPC
C         GETFCB  / SETFCB   <-> /FCB/    FCB(I,J)    args (I,J,IVAL)
C
C       GROUP B -- INCLUDE 'SMCOMX.COM' (10 routines, all INTEGER)
C         GETSBUF / SETSBUF  <-> /SYSTEM/ ISYSBF   (word 1,  SAFE)
C         GETNOUT / SETNOUT  <-> /SYSTEM/ NOUT     (word 2,  SAFE)
C         GETNBPW / SETNBPW  <-> /SYSTEM/ NBPW     (word 40, FLAG)
C         GETNCOL / SETNCOL  <-> /SMCOMX/ NCOL
C         GETIERR / SETIERR  <-> /SMCOMX/ IERROR
C
C       GROUP C -- INCLUDE 'NASNAMES.COM' (8 routines, all CHARACTER)
C         GETDSN  / SETDSN   <-> /DSNAME/ DSNAMES(I) *80  args (I,NAME)
C         GETLOG  / SETLOG   <-> /DOSNAM/ LOG      *72
C         GETINP  / SETINP   <-> /DOSNAM/ INPUT    *72
C         GETOUT  / SETOUT   <-> /DOSNAM/ OUTPUT   *72
C
C       Total = 22 (A) + 10 (B) + 8 (C) = 40 program units.
C
C     PROVENANCE:
C       bin/NASNAMES.COM / mds/NASNAMES.COM (verified identical) --
C         /DOSNAM/ (15 x CHARACTER*72), /DSNAME/ DSNAMES(89)*80.
C       mds/DSIOF.COM  -- /DSIO/, /DBM/ (INTEGER), /FCB/ FCB(17,89).
C       mis/SMCOMX.COM -- /SMCOMX/ (NCOL,IERROR,...), /SYSTEM/ layout.
C       Layout context: bd/semdbd.f (canonical /SYSTEM/), mis/tmtogo.f
C         (KTIME via TMTOGO), bin/nastrn.f (fixed-form column style and
C         the INCLUDE 'NASNAMES.COM' bare-filename idiom).
C
C     These accessors are used ONLY by new code; legacy routines keep
C     their own COMMON declarations untouched (the refactor does not
C     require legacy adoption).
C
C     Fixed-form FORTRAN 77; compiled by Sun f77 -fast -dn into
C     bin/nastlib.a via an updated bin/linknas (the build wiring is
C     done by the bin/ agent, not in this file).
C=====================================================================
C
C---------------------------------------------------------------------
C     GROUP A -- INCLUDE 'DSIOF.COM'  (/DSIO/, /DBM/, /FCB/)  22 units
C---------------------------------------------------------------------
C
      SUBROUTINE GETLCW (IVAL)
C     GET accessor for /DSIO/ LCW (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      IVAL = LCW
      RETURN
      END
C
      SUBROUTINE SETLCW (IVAL)
C     SET accessor for /DSIO/ LCW (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      LCW = IVAL
      RETURN
      END
C
      SUBROUTINE GETLWRD (IVAL)
C     GET accessor for /DSIO/ LWORDS (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      IVAL = LWORDS
      RETURN
      END
C
      SUBROUTINE SETLWRD (IVAL)
C     SET accessor for /DSIO/ LWORDS (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      LWORDS = IVAL
      RETURN
      END
C
      SUBROUTINE GETNWRD (IVAL)
C     GET accessor for /DSIO/ NWORDS (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      IVAL = NWORDS
      RETURN
      END
C
      SUBROUTINE SETNWRD (IVAL)
C     SET accessor for /DSIO/ NWORDS (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      NWORDS = IVAL
      RETURN
      END
C
      SUBROUTINE GETMDSN (IVAL)
C     GET accessor for /DSIO/ MAXDSN (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      IVAL = MAXDSN
      RETURN
      END
C
      SUBROUTINE SETMDSN (IVAL)
C     SET accessor for /DSIO/ MAXDSN (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      MAXDSN = IVAL
      RETURN
      END
C
      SUBROUTINE GETNBUF (IVAL)
C     GET accessor for /DSIO/ NBUFF (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      IVAL = NBUFF
      RETURN
      END
C
      SUBROUTINE SETNBUF (IVAL)
C     SET accessor for /DSIO/ NBUFF (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      NBUFF = IVAL
      RETURN
      END
C
      SUBROUTINE GETDBLN (IVAL)
C     GET accessor for /DBM/ IDBLEN (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      IVAL = IDBLEN
      RETURN
      END
C
      SUBROUTINE SETDBLN (IVAL)
C     SET accessor for /DBM/ IDBLEN (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      IDBLEN = IVAL
      RETURN
      END
C
      SUBROUTINE GETDBAD (IVAL)
C     GET accessor for /DBM/ IDBADR (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      IVAL = IDBADR
      RETURN
      END
C
      SUBROUTINE SETDBAD (IVAL)
C     SET accessor for /DBM/ IDBADR (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      IDBADR = IVAL
      RETURN
      END
C
      SUBROUTINE GETNBLK (IVAL)
C     GET accessor for /DBM/ NBLOCK (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      IVAL = NBLOCK
      RETURN
      END
C
      SUBROUTINE SETNBLK (IVAL)
C     SET accessor for /DBM/ NBLOCK (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      NBLOCK = IVAL
      RETURN
      END
C
      SUBROUTINE GETMBLK (IVAL)
C     GET accessor for /DBM/ MAXBLK (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      IVAL = MAXBLK
      RETURN
      END
C
      SUBROUTINE SETMBLK (IVAL)
C     SET accessor for /DBM/ MAXBLK (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      MAXBLK = IVAL
      RETURN
      END
C
      SUBROUTINE GETLNOP (IVAL)
C     GET accessor for /DBM/ LENOPC (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      IVAL = LENOPC
      RETURN
      END
C
      SUBROUTINE SETLNOP (IVAL)
C     SET accessor for /DBM/ LENOPC (mds/DSIOF.COM). INTEGER.
      INCLUDE 'DSIOF.COM'
      INTEGER IVAL
      LENOPC = IVAL
      RETURN
      END
C
      SUBROUTINE GETFCB (I, J, IVAL)
C     GET accessor for /FCB/ FCB(I,J) (mds/DSIOF.COM). INTEGER.
C     Caller ensures 1<=I<=17, 1<=J<=89 (no bounds check, matches
C     legacy). FCB is declared INTEGER FCB(17,89) in the header.
      INCLUDE 'DSIOF.COM'
      INTEGER I, J, IVAL
      IVAL = FCB(I,J)
      RETURN
      END
C
      SUBROUTINE SETFCB (I, J, IVAL)
C     SET accessor for /FCB/ FCB(I,J) (mds/DSIOF.COM). INTEGER.
C     Caller ensures 1<=I<=17, 1<=J<=89 (no bounds check, matches
C     legacy).
      INCLUDE 'DSIOF.COM'
      INTEGER I, J, IVAL
      FCB(I,J) = IVAL
      RETURN
      END
C
C---------------------------------------------------------------------
C     GROUP B -- INCLUDE 'SMCOMX.COM'  (/SYSTEM/, /SMCOMX/)  10 units
C---------------------------------------------------------------------
C
      SUBROUTINE GETSBUF (IVAL)
C     GET accessor for /SYSTEM/ ISYSBF (mis/SMCOMX.COM). INTEGER.
C     Relies on the SMCOMX.COM /SYSTEM/ layout
C     (ISYSBF,NOUT,DUM1(37),NBPW,DUM2(14),ISPREC). /SYSTEM/ appears in
C     only this one of the nine headers. ISYSBF is word 1, consistent
C     across all NASTRAN /SYSTEM/ layouts (SAFE). KTIME is NOT a named
C     /SYSTEM/ cell here -- the dispatcher obtains it via
C     CALL TMTOGO(KTIME).
      INCLUDE 'SMCOMX.COM'
      INTEGER IVAL
      IVAL = ISYSBF
      RETURN
      END
C
      SUBROUTINE SETSBUF (IVAL)
C     SET accessor for /SYSTEM/ ISYSBF (mis/SMCOMX.COM). INTEGER.
C     Relies on the SMCOMX.COM /SYSTEM/ layout
C     (ISYSBF,NOUT,DUM1(37),NBPW,DUM2(14),ISPREC). /SYSTEM/ appears in
C     only this one of the nine headers. ISYSBF is word 1, consistent
C     across all NASTRAN /SYSTEM/ layouts (SAFE). KTIME is NOT a named
C     /SYSTEM/ cell here -- the dispatcher obtains it via
C     CALL TMTOGO(KTIME).
      INCLUDE 'SMCOMX.COM'
      INTEGER IVAL
      ISYSBF = IVAL
      RETURN
      END
C
      SUBROUTINE GETNOUT (IVAL)
C     GET accessor for /SYSTEM/ NOUT (mis/SMCOMX.COM). INTEGER.
C     Relies on the SMCOMX.COM /SYSTEM/ layout
C     (ISYSBF,NOUT,DUM1(37),NBPW,DUM2(14),ISPREC). /SYSTEM/ appears in
C     only this one of the nine headers. NOUT is word 2 (print-output
C     unit), consistent across all NASTRAN /SYSTEM/ layouts (SAFE).
C     KTIME is NOT a named /SYSTEM/ cell here -- the dispatcher obtains
C     it via CALL TMTOGO(KTIME).
      INCLUDE 'SMCOMX.COM'
      INTEGER IVAL
      IVAL = NOUT
      RETURN
      END
C
      SUBROUTINE SETNOUT (IVAL)
C     SET accessor for /SYSTEM/ NOUT (mis/SMCOMX.COM). INTEGER.
C     Relies on the SMCOMX.COM /SYSTEM/ layout
C     (ISYSBF,NOUT,DUM1(37),NBPW,DUM2(14),ISPREC). /SYSTEM/ appears in
C     only this one of the nine headers. NOUT is word 2 (print-output
C     unit), consistent across all NASTRAN /SYSTEM/ layouts (SAFE).
C     KTIME is NOT a named /SYSTEM/ cell here -- the dispatcher obtains
C     it via CALL TMTOGO(KTIME).
      INCLUDE 'SMCOMX.COM'
      INTEGER IVAL
      NOUT = IVAL
      RETURN
      END
C
      SUBROUTINE GETNBPW (IVAL)
C     GET accessor for /SYSTEM/ NBPW (mis/SMCOMX.COM). INTEGER.
C     Relies on the SMCOMX.COM /SYSTEM/ layout
C     (ISYSBF,NOUT,DUM1(37),NBPW,DUM2(14),ISPREC). /SYSTEM/ appears in
C     only this one of the nine headers; NBPW is word 40 here, and the
C     ARRAY-AWARE bd/semdbd.f layout ALSO places NBPW at word 40 (the
C     "word 38" figure is only a NAIVE all-scalar miscount, not the
C     canonical layout; corroborated by mds/btstrp.f EQUIVALENCE
C     (B(40),NBPW)). KTIME is NOT a named /SYSTEM/ cell here -- the
C     dispatcher obtains it via CALL TMTOGO(KTIME).
      INCLUDE 'SMCOMX.COM'
      INTEGER IVAL
      IVAL = NBPW
      RETURN
      END
C
      SUBROUTINE SETNBPW (IVAL)
C     SET accessor for /SYSTEM/ NBPW (mis/SMCOMX.COM). INTEGER.
C     Relies on the SMCOMX.COM /SYSTEM/ layout
C     (ISYSBF,NOUT,DUM1(37),NBPW,DUM2(14),ISPREC). /SYSTEM/ appears in
C     only this one of the nine headers; NBPW is word 40 here, and the
C     ARRAY-AWARE bd/semdbd.f layout ALSO places NBPW at word 40 (the
C     "word 38" figure is only a NAIVE all-scalar miscount, not the
C     canonical layout; corroborated by mds/btstrp.f EQUIVALENCE
C     (B(40),NBPW)). KTIME is NOT a named /SYSTEM/ cell here -- the
C     dispatcher obtains it via CALL TMTOGO(KTIME).
      INCLUDE 'SMCOMX.COM'
      INTEGER IVAL
      NBPW = IVAL
      RETURN
      END
C
      SUBROUTINE GETNCOL (IVAL)
C     GET accessor for /SMCOMX/ NCOL (mis/SMCOMX.COM). INTEGER.
      INCLUDE 'SMCOMX.COM'
      INTEGER IVAL
      IVAL = NCOL
      RETURN
      END
C
      SUBROUTINE SETNCOL (IVAL)
C     SET accessor for /SMCOMX/ NCOL (mis/SMCOMX.COM). INTEGER.
      INCLUDE 'SMCOMX.COM'
      INTEGER IVAL
      NCOL = IVAL
      RETURN
      END
C
      SUBROUTINE GETIERR (IVAL)
C     GET accessor for /SMCOMX/ IERROR (mis/SMCOMX.COM). INTEGER.
      INCLUDE 'SMCOMX.COM'
      INTEGER IVAL
      IVAL = IERROR
      RETURN
      END
C
      SUBROUTINE SETIERR (IVAL)
C     SET accessor for /SMCOMX/ IERROR (mis/SMCOMX.COM). INTEGER.
      INCLUDE 'SMCOMX.COM'
      INTEGER IVAL
      IERROR = IVAL
      RETURN
      END
C

C---------------------------------------------------------------------
C     GROUP C -- INCLUDE 'NASNAMES.COM'  (/DSNAME/, /DOSNAM/)  8 units
C     CHARACTER accessors: dummy NAME is CHARACTER*(*); F77 blank-pads
C     or truncates on assignment as usual.
C---------------------------------------------------------------------
C
      SUBROUTINE GETDSN (I, NAME)
C     GET accessor for /DSNAME/ DSNAMES(I) (NASNAMES.COM). CHARACTER*80.
C     Caller ensures 1<=I<=89. Uses the NASNAMES.COM/DSNAMES view of
C     /DSNAME/ (the same memory is named MDSNAM in DSIOF.COM; that
C     alias is deliberately NOT wrapped to avoid a two-header unit).
      INCLUDE 'NASNAMES.COM'
      INTEGER       I
      CHARACTER*(*) NAME
      NAME = DSNAMES(I)
      RETURN
      END
C
      SUBROUTINE SETDSN (I, NAME)
C     SET accessor for /DSNAME/ DSNAMES(I) (NASNAMES.COM). CHARACTER*80.
C     Caller ensures 1<=I<=89.
      INCLUDE 'NASNAMES.COM'
      INTEGER       I
      CHARACTER*(*) NAME
      DSNAMES(I) = NAME
      RETURN
      END
C
      SUBROUTINE GETLOG (NAME)
C     GET accessor for /DOSNAM/ LOG (NASNAMES.COM). CHARACTER*72.
C     LOG is a /DOSNAM/ CHARACTER variable here; the COMMON declaration
C     from the header shadows the LOG intrinsic inside this unit,
C     exactly as in the legacy routines.
C
C     NAME-COLLISION FLAG (maintainer note, verified by validation):
C       The subroutine name GETLOG coincides with the Unix/GNU library
C       routine getlog (getlogin -- returns the user login name).  The
C       accessor name is RETAINED VERBATIM per the published contract
C       (the export schema and the test/state drivers expect GETLOG).
C       The DEFINITION below is correct and was proven by a SET/GET
C       round-trip.  Caller-side binding differs by compiler:
C         * Sun f77 (production target): getlog is a libF77 routine
C           resolved AFTER the user objects named on the bin/linknas
C           link line, so CALL GETLOG binds to THIS accessor.
C         * gfortran (the Linux validation stand-in): GETLOG is a
C           recognized intrinsic, so a caller must declare
C           EXTERNAL GETLOG to bind to this accessor instead of the
C           intrinsic.  SETLOG has no such collision.
      INCLUDE 'NASNAMES.COM'
      CHARACTER*(*) NAME
      NAME = LOG
      RETURN
      END
C
      SUBROUTINE SETLOG (NAME)
C     SET accessor for /DOSNAM/ LOG (NASNAMES.COM). CHARACTER*72.
C     LOG is a /DOSNAM/ CHARACTER variable here; the COMMON declaration
C     from the header shadows the LOG intrinsic inside this unit.
      INCLUDE 'NASNAMES.COM'
      CHARACTER*(*) NAME
      LOG = NAME
      RETURN
      END
C
      SUBROUTINE GETINP (NAME)
C     GET accessor for /DOSNAM/ INPUT (NASNAMES.COM). CHARACTER*72.
      INCLUDE 'NASNAMES.COM'
      CHARACTER*(*) NAME
      NAME = INPUT
      RETURN
      END
C
      SUBROUTINE SETINP (NAME)
C     SET accessor for /DOSNAM/ INPUT (NASNAMES.COM). CHARACTER*72.
      INCLUDE 'NASNAMES.COM'
      CHARACTER*(*) NAME
      INPUT = NAME
      RETURN
      END
C
      SUBROUTINE GETOUT (NAME)
C     GET accessor for /DOSNAM/ OUTPUT (NASNAMES.COM). CHARACTER*72.
      INCLUDE 'NASNAMES.COM'
      CHARACTER*(*) NAME
      NAME = OUTPUT
      RETURN
      END
C
      SUBROUTINE SETOUT (NAME)
C     SET accessor for /DOSNAM/ OUTPUT (NASNAMES.COM). CHARACTER*72.
      INCLUDE 'NASNAMES.COM'
      CHARACTER*(*) NAME
      OUTPUT = NAME
      RETURN
      END

