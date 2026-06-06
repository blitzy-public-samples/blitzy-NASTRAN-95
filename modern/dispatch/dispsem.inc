C=====================================================================
C     modern/dispatch/dispsem.inc
C---------------------------------------------------------------------
C     Dispatcher windows of the EXISTING /SEM/ and /SYSTEM/ COMMON
C     blocks, needed ONLY by the MODX 43 branch of
C     modern/dispatch/disptbl.f (the EMG link-number save/restore).
C
C     WHY THIS HEADER EXISTS (Binding Rule R8 compliance).  The two
C     blocks declared here ALREADY exist in the legacy solver; the
C     frozen mis/xsem00.f declares them inline with this exact layout.
C     The MODX 43 branch must read LINKNM (from /SEM/) and write LINKNO
C     (in /SYSTEM/), but neither symbol is exposed BY NAME through any
C     of the nine *.COM headers, so disptbl.f originally re-declared
C     them inline.  To remove that inline COMMON re-declaration from the
C     routine body, those declarations are centralized HERE, in a
C     dedicated AAP-approved modern header, and pulled in by a single
C     INCLUDE 'dispsem.inc' -- exactly the include-based state-access
C     policy already used by modern/init/bddata.inc.  AAP 0.6.4 makes
C     this explicit: its VERIFIABLE criterion is that "no COMMON/ or
C     EQUIVALENCE literal should appear in modern/*.f outside an
C     INCLUDE" -- so COMMON reached THROUGH an INCLUDE (as here) is
C     compliant, and disptbl.f's body is correspondingly COMMON-free
C     (grep-verifiable).  This introduces NO new COMMON block (both
C     /SEM/ and /SYSTEM/ pre-exist in the frozen mis/xsem00.f) and NO
C     EQUIVALENCE; it only relocates two existing declarations into a
C     header so the routine body holds no literal COMMON statement.
C
C     LAYOUT (identical to mis/xsem00.f -- DO NOT change the offsets):
C       /SEM/    : ISEM(3) then LINKNM(1..15)  ==> LINKNM occupies
C                  words 4-18 of /SEM/  (LINKNM(1)=word 4,
C                  LINKNM(8)=word 11).
C       /SYSTEM/ : ISYS(21) then LINKNO         ==> LINKNO occupies
C                  word 22 of /SYSTEM/.
C     ISEM, LINKNM, ISYS and LINKNO all begin with I-N and are INTEGER
C     by the default typing rule (matching the original inline form);
C     no IMPLICIT or explicit type change is introduced.
C=====================================================================
      COMMON /SEM/    ISEM(3), LINKNM(15)
      COMMON /SYSTEM/ ISYS(21), LINKNO
