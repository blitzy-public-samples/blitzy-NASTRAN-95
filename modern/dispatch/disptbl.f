      SUBROUTINE DISPTBL (MODX)
C=====================================================================
C     modern/dispatch/disptbl.f
C---------------------------------------------------------------------
C     TABLE-DRIVEN OSCAR MODULE DISPATCHER  (A2 modernization,
C     Candidate 1: direct IF / ELSE IF chain on MODX).
C
C     Modernized, maintainable replacement for the 22-stage cascading
C     computed-GO TO ladder in the FROZEN mis/xsem00.f [L262-L761].
C     This is a COEXISTENCE (branch-by-abstraction) deliverable: the
C     legacy ladder is NOT edited and the live cutover (replacing it
C     with CALL DISPTBL(MODX)) is DEFERRED.  DISPTBL is a faithful
C     functional twin so that a future cutover preserves bit-for-bit
C     results and module execution order.  It is exercised only by the
C     sibling test/dispatch/*.f unit drivers.
C
C     SIGNATURE (FROZEN -- do not change):
C         SUBROUTINE DISPTBL (MODX)
C
C     ARGUMENT:
C         INTEGER MODX -- OSCAR operation code in 1..217 (INPUT).
C                 MODX is the SOLE argument and is treated READ-ONLY:
C                 it is NEVER reassigned.  The legacy ladder mutated a
C                 local copy (MODX = MODX - 10) to index its computed
C                 GO TO blocks; this dispatcher tests MODX directly
C                 with IF (MODX .EQ. n), so no decrement is needed.
C                 MODX is extracted ONCE by the frozen xsem00.f at
C                 L182 (MODX = RSHIFT(INOSCR(3),16)) and passed in;
C                 DISPTBL never reads INOSCR and never re-extracts it.
C
C     DISPATCH CONTRACT (catalog == test/dispatch/tdsmap.ref, which is
C     byte-identical to the frozen ladder):
C         TOTAL  = 217 MODX codes (1..217)
C         CALL   = 193 dispatched slots (188 distinct subroutines;
C                  XCEI is shared by MODX 5,6,7,11,12,13)
C         RESVD  =  21 reserved no-op CONTINUE slots
C         FATAL  =   3 in-range slots (MODX 1,2,4) that fall through
C                  to the ELSE (unmapped) handler, plus any MODX that
C                  is out of the 1..217 range.
C
C     PRESERVED BEHAVIOR:
C       * The public CALL interface of every dispatched module is
C         preserved EXACTLY -- each branch is a bare argument-less
C         CALL <SUB>, identical to the legacy ladder.
C       * Exactly ONE pre-dispatch CALL TMTOGO (KTIME) time check,
C         mirroring xsem00.f L196 (250 CALL TMTOGO (KTIME)).
C       * Fatal-on-unmapped behavior is preserved (legacy GO TO 940).
C
C     MAINTAINER FLAGS (see modern/docs/dispatch_modernization_report):
C       (1) The pre-dispatch guard is simplified to
C           IF (KTIME .LE. 0) CALL MESAGE (-50, 0, SUBNAM).  The legacy
C           qualifier '.AND. WORDB(2).NE.EXIT' is omitted because the
C           MODX-only interface has no WORDB, and EXIT is handled by
C           the executive BEFORE the ladder is reached, so the test is
C           always true at the dispatch point -- behaviorally
C           equivalent.  The NAME argument is SUBNAM ('DISPTBL ')
C           rather than the module BCD name WORDB(2): a cosmetic
C           message-identification difference.  -50 is the EXISTING
C           legacy INSUFFICIENT-TIME code (preserved, NOT a new code).
C       (2) The unmapped/out-of-range path uses CALL MESAGE
C           (-9301, MODX, SUBNAM).  -9301 is fatal (negative) with
C           IABS = 9301 in the unassigned 9001-9999 band (dispatch
C           sub-band 9300-9399), per AAP 0.7.2.  The legacy -37/-50
C           codes are deliberately NOT reused for this path.
C       (3) The MODX 43 branch references LINKNM (/SEM/) and LINKNO
C           (/SYSTEM/), neither of which is exposed by name in the
C           nine *.COM headers.  Per NASTRAN's per-routine COMMON
C           convention (and the AAP's explicit allowance) minimal
C           inline WINDOWS of these two EXISTING blocks are declared
C           below, positioned to match xsem00.f exactly (LINKNM at
C           words 4-18 of /SEM/, LINKNO at word 22 of /SYSTEM/).  They
C           are used ONLY by the MODX 43 branch and overlay storage
C           that TMTOGO and others view differently -- intentional
C           NASTRAN overlay convention, flagged for confirmation.  No
C           EQUIVALENCE and no new COMMON block are introduced.
C
C     This routine carries ZERO diagnostic overhead: no IDIAG, no
C     guard clause, no DIAGLOG, no WRITE.  Validation and logging live
C     in modern/dispatch/dispval.f and modern/diag/diaglog.f.
C=====================================================================
      INTEGER MODX, KTIME, SUBNAM(2)
C
C     Minimal inline windows of the EXISTING /SEM/ and /SYSTEM/ blocks
C     (MODX 43 only).  ISEM(3) places LINKNM(1..15) at /SEM/ words
C     4-18 (so LINKNM(8)=word 11, LINKNM(1)=word 4); ISYS(21) places
C     LINKNO at /SYSTEM/ word 22 -- identical to mis/xsem00.f.
      COMMON /SEM/    ISEM(3), LINKNM(15)
      COMMON /SYSTEM/ ISYS(21), LINKNO
C
C     Hollerith 'DISPTBL ' packed into a 2-word INTEGER array for the
C     NAME argument of MESAGE (MESAGE(NO,PARM,NAME), INTEGER NAME(2)).
      DATA SUBNAM /4HDISP,4HTBL /
C
C     Single pre-dispatch wall-clock time check (mirror xsem00.f
C     L196-L197).  Exactly ONE CALL TMTOGO in the whole routine.
      CALL TMTOGO (KTIME)
      IF (KTIME .LE. 0) CALL MESAGE (-50, 0, SUBNAM)
C
C     Table-driven dispatch: one branch per catalogued MODX, in
C     strict numerical order.  MODX 1,2,4 have no branch and fall to
C     the ELSE (fatal), as do any out-of-range codes.
      IF (MODX .EQ. 3) THEN
         CALL XCHK
      ELSE IF (MODX .EQ. 5) THEN
         CALL XCEI
      ELSE IF (MODX .EQ. 6) THEN
         CALL XCEI
      ELSE IF (MODX .EQ. 7) THEN
         CALL XCEI
      ELSE IF (MODX .EQ. 8) THEN
         CALL XSAVE
      ELSE IF (MODX .EQ. 9) THEN
         CALL XPURGE
      ELSE IF (MODX .EQ. 10) THEN
         CALL XEQUIV
      ELSE IF (MODX .EQ. 11) THEN
         CALL XCEI
      ELSE IF (MODX .EQ. 12) THEN
         CALL XCEI
      ELSE IF (MODX .EQ. 13) THEN
         CALL XCEI
      ELSE IF (MODX .EQ. 14) THEN
         CALL DADD
      ELSE IF (MODX .EQ. 15) THEN
         CALL DADD5
      ELSE IF (MODX .EQ. 16) THEN
         CALL AMG
      ELSE IF (MODX .EQ. 17) THEN
         CALL AMP
      ELSE IF (MODX .EQ. 18) THEN
         CALL APD
      ELSE IF (MODX .EQ. 19) THEN
         CALL BMG
      ELSE IF (MODX .EQ. 20) THEN
         CALL CASE
      ELSE IF (MODX .EQ. 21) THEN
         CALL CYCT1
      ELSE IF (MODX .EQ. 22) THEN
         CALL CYCT2
      ELSE IF (MODX .EQ. 23) THEN
         CALL CEAD
      ELSE IF (MODX .EQ. 24) THEN
         CALL CURV
      ELSE IF (MODX .EQ. 25) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 26) THEN
         CALL DDR
      ELSE IF (MODX .EQ. 27) THEN
         CALL DDR1
      ELSE IF (MODX .EQ. 28) THEN
         CALL DDR2
      ELSE IF (MODX .EQ. 29) THEN
         CALL DDRMM
      ELSE IF (MODX .EQ. 30) THEN
         CALL DDCOMP
      ELSE IF (MODX .EQ. 31) THEN
         CALL DIAGON
      ELSE IF (MODX .EQ. 32) THEN
         CALL DPD
      ELSE IF (MODX .EQ. 33) THEN
         CALL DSCHK
      ELSE IF (MODX .EQ. 34) THEN
         CALL DSMG1
      ELSE IF (MODX .EQ. 35) THEN
         CALL DSMG2
      ELSE IF (MODX .EQ. 36) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 37) THEN
         CALL DUMOD1
      ELSE IF (MODX .EQ. 38) THEN
         CALL DUMOD2
      ELSE IF (MODX .EQ. 39) THEN
         CALL DUMOD3
      ELSE IF (MODX .EQ. 40) THEN
         CALL DUMOD4
      ELSE IF (MODX .EQ. 41) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 42) THEN
         CALL EMA1
      ELSE IF (MODX .EQ. 43) THEN
         LINKNO = LINKNM(8)
         CALL EMG
         LINKNO = LINKNM(1)
      ELSE IF (MODX .EQ. 44) THEN
         CALL FA1
      ELSE IF (MODX .EQ. 45) THEN
         CALL FA2
      ELSE IF (MODX .EQ. 46) THEN
         CALL DFBS
      ELSE IF (MODX .EQ. 47) THEN
         CALL FRLG
      ELSE IF (MODX .EQ. 48) THEN
         CALL FRRD
      ELSE IF (MODX .EQ. 49) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 50) THEN
         CALL GI
      ELSE IF (MODX .EQ. 51) THEN
         CALL GKAD
      ELSE IF (MODX .EQ. 52) THEN
         CALL GKAM
      ELSE IF (MODX .EQ. 53) THEN
         CALL GP1
      ELSE IF (MODX .EQ. 54) THEN
         CALL GP2
      ELSE IF (MODX .EQ. 55) THEN
         CALL GP3
      ELSE IF (MODX .EQ. 56) THEN
         CALL GP4
      ELSE IF (MODX .EQ. 57) THEN
         CALL GPCYC
      ELSE IF (MODX .EQ. 58) THEN
         CALL GPFDR
      ELSE IF (MODX .EQ. 59) THEN
         CALL DUMOD5
      ELSE IF (MODX .EQ. 60) THEN
         CALL GPWG
      ELSE IF (MODX .EQ. 61) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 62) THEN
         CALL INPUT
      ELSE IF (MODX .EQ. 63) THEN
         CALL INPTT1
      ELSE IF (MODX .EQ. 64) THEN
         CALL INPTT2
      ELSE IF (MODX .EQ. 65) THEN
         CALL INPTT3
      ELSE IF (MODX .EQ. 66) THEN
         CALL INPTT4
      ELSE IF (MODX .EQ. 67) THEN
         CALL MATGEN
      ELSE IF (MODX .EQ. 68) THEN
         CALL MATGPR
      ELSE IF (MODX .EQ. 69) THEN
         CALL MATPRN
      ELSE IF (MODX .EQ. 70) THEN
         CALL PRTINT
      ELSE IF (MODX .EQ. 71) THEN
         CALL MCE1
      ELSE IF (MODX .EQ. 72) THEN
         CALL MCE2
      ELSE IF (MODX .EQ. 73) THEN
         CALL MERGE1
      ELSE IF (MODX .EQ. 74) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 75) THEN
         CALL MODA
      ELSE IF (MODX .EQ. 76) THEN
         CALL MODACC
      ELSE IF (MODX .EQ. 77) THEN
         CALL MODB
      ELSE IF (MODX .EQ. 78) THEN
         CALL MODC
      ELSE IF (MODX .EQ. 79) THEN
         CALL DMPYAD
      ELSE IF (MODX .EQ. 80) THEN
         CALL MTRXIN
      ELSE IF (MODX .EQ. 81) THEN
         CALL OFP
      ELSE IF (MODX .EQ. 82) THEN
         CALL OPTPR1
      ELSE IF (MODX .EQ. 83) THEN
         CALL OPTPR2
      ELSE IF (MODX .EQ. 84) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 85) THEN
         CALL OUTPT
      ELSE IF (MODX .EQ. 86) THEN
         CALL OUTPT1
      ELSE IF (MODX .EQ. 87) THEN
         CALL OUTPT2
      ELSE IF (MODX .EQ. 88) THEN
         CALL OUTPT3
      ELSE IF (MODX .EQ. 89) THEN
         CALL OUTPT4
      ELSE IF (MODX .EQ. 90) THEN
         CALL QPARAM
      ELSE IF (MODX .EQ. 91) THEN
         CALL PARAML
      ELSE IF (MODX .EQ. 92) THEN
         CALL QPARMR
      ELSE IF (MODX .EQ. 93) THEN
         CALL PARTN1
      ELSE IF (MODX .EQ. 94) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 95) THEN
         CALL MRED1
      ELSE IF (MODX .EQ. 96) THEN
         CALL MRED2
      ELSE IF (MODX .EQ. 97) THEN
         CALL CMRD2
      ELSE IF (MODX .EQ. 98) THEN
         CALL PLA1
      ELSE IF (MODX .EQ. 99) THEN
         CALL PLA2
      ELSE IF (MODX .EQ. 100) THEN
         CALL PLA3
      ELSE IF (MODX .EQ. 101) THEN
         CALL PLA4
      ELSE IF (MODX .EQ. 102) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 103) THEN
         CALL DPLOT
      ELSE IF (MODX .EQ. 104) THEN
         CALL DPLTST
      ELSE IF (MODX .EQ. 105) THEN
         CALL PLTTRA
      ELSE IF (MODX .EQ. 106) THEN
         CALL PRTMSG
      ELSE IF (MODX .EQ. 107) THEN
         CALL PRTPRM
      ELSE IF (MODX .EQ. 108) THEN
         CALL RANDOM
      ELSE IF (MODX .EQ. 109) THEN
         CALL RBMG1
      ELSE IF (MODX .EQ. 110) THEN
         CALL RBMG2
      ELSE IF (MODX .EQ. 111) THEN
         CALL RBMG3
      ELSE IF (MODX .EQ. 112) THEN
         CALL RBMG4
      ELSE IF (MODX .EQ. 113) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 114) THEN
         CALL REIG
      ELSE IF (MODX .EQ. 115) THEN
         CALL RMG
      ELSE IF (MODX .EQ. 116) THEN
         CALL SCALAR
      ELSE IF (MODX .EQ. 117) THEN
         CALL SCE1
      ELSE IF (MODX .EQ. 118) THEN
         CALL SDR1
      ELSE IF (MODX .EQ. 119) THEN
         CALL SDR2
      ELSE IF (MODX .EQ. 120) THEN
         CALL SDR3
      ELSE IF (MODX .EQ. 121) THEN
         CALL SDRHT
      ELSE IF (MODX .EQ. 122) THEN
         CALL SEEMAT
      ELSE IF (MODX .EQ. 123) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 124) THEN
         CALL SETVAL
      ELSE IF (MODX .EQ. 125) THEN
         CALL SMA1
      ELSE IF (MODX .EQ. 126) THEN
         CALL SMA2
      ELSE IF (MODX .EQ. 127) THEN
         CALL SMA3
      ELSE IF (MODX .EQ. 128) THEN
         CALL SMP1
      ELSE IF (MODX .EQ. 129) THEN
         CALL SMP2
      ELSE IF (MODX .EQ. 130) THEN
         CALL SMPYAD
      ELSE IF (MODX .EQ. 131) THEN
         CALL SOLVE
      ELSE IF (MODX .EQ. 132) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 133) THEN
         CALL SSG1
      ELSE IF (MODX .EQ. 134) THEN
         CALL SSG2
      ELSE IF (MODX .EQ. 135) THEN
         CALL SSG3
      ELSE IF (MODX .EQ. 136) THEN
         CALL SSG4
      ELSE IF (MODX .EQ. 137) THEN
         CALL SSGHT
      ELSE IF (MODX .EQ. 138) THEN
         CALL TA1
      ELSE IF (MODX .EQ. 139) THEN
         CALL TABPCH
      ELSE IF (MODX .EQ. 140) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 141) THEN
         CALL TABFMT
      ELSE IF (MODX .EQ. 142) THEN
         CALL TABPT
      ELSE IF (MODX .EQ. 143) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 144) THEN
         CALL TIMTST
      ELSE IF (MODX .EQ. 145) THEN
         CALL TRD
      ELSE IF (MODX .EQ. 146) THEN
         CALL TRHT
      ELSE IF (MODX .EQ. 147) THEN
         CALL TRLG
      ELSE IF (MODX .EQ. 148) THEN
         CALL DTRANP
      ELSE IF (MODX .EQ. 149) THEN
         CALL DUMERG
      ELSE IF (MODX .EQ. 150) THEN
         CALL DUPART
      ELSE IF (MODX .EQ. 151) THEN
         CALL VDR
      ELSE IF (MODX .EQ. 152) THEN
         CALL VEC
      ELSE IF (MODX .EQ. 153) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 154) THEN
         CALL XYPLOT
      ELSE IF (MODX .EQ. 155) THEN
         CALL XYPRPT
      ELSE IF (MODX .EQ. 156) THEN
         CALL XYTRAN
      ELSE IF (MODX .EQ. 157) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 158) THEN
         CALL COMB1
      ELSE IF (MODX .EQ. 159) THEN
         CALL COMB2
      ELSE IF (MODX .EQ. 160) THEN
         CALL EXIO
      ELSE IF (MODX .EQ. 161) THEN
         CALL RCOVR
      ELSE IF (MODX .EQ. 162) THEN
         CALL EMFLD
      ELSE IF (MODX .EQ. 163) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 164) THEN
         CALL RCOVR3
      ELSE IF (MODX .EQ. 165) THEN
         CALL REDUCE
      ELSE IF (MODX .EQ. 166) THEN
         CALL SGEN
      ELSE IF (MODX .EQ. 167) THEN
         CALL SOFI
      ELSE IF (MODX .EQ. 168) THEN
         CALL SOFO
      ELSE IF (MODX .EQ. 169) THEN
         CALL SOFUT
      ELSE IF (MODX .EQ. 170) THEN
         CALL SUBPH1
      ELSE IF (MODX .EQ. 171) THEN
         CALL PLTMRG
      ELSE IF (MODX .EQ. 172) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 173) THEN
         CALL COPY
      ELSE IF (MODX .EQ. 174) THEN
         CALL SWITCH
      ELSE IF (MODX .EQ. 175) THEN
         CALL MPY3
      ELSE IF (MODX .EQ. 176) THEN
         CALL DDCMPS
      ELSE IF (MODX .EQ. 177) THEN
         CALL LODAPP
      ELSE IF (MODX .EQ. 178) THEN
         CALL GPSTGN
      ELSE IF (MODX .EQ. 179) THEN
         CALL EQMCK
      ELSE IF (MODX .EQ. 180) THEN
         CALL ADR
      ELSE IF (MODX .EQ. 181) THEN
         CALL FRRD2
      ELSE IF (MODX .EQ. 182) THEN
         CALL GUST
      ELSE IF (MODX .EQ. 183) THEN
         CALL IFT
      ELSE IF (MODX .EQ. 184) THEN
         CALL LAMX
      ELSE IF (MODX .EQ. 185) THEN
         CALL EMA
      ELSE IF (MODX .EQ. 186) THEN
         CALL ANISOP
      ELSE IF (MODX .EQ. 187) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 188) THEN
         CALL GENCOS
      ELSE IF (MODX .EQ. 189) THEN
         CALL DDAMAT
      ELSE IF (MODX .EQ. 190) THEN
         CALL DDAMPG
      ELSE IF (MODX .EQ. 191) THEN
         CALL NRLSUM
      ELSE IF (MODX .EQ. 192) THEN
         CALL GENPAR
      ELSE IF (MODX .EQ. 193) THEN
         CALL CASEGE
      ELSE IF (MODX .EQ. 194) THEN
         CALL DESVEL
      ELSE IF (MODX .EQ. 195) THEN
         CALL PROLAT
      ELSE IF (MODX .EQ. 196) THEN
         CALL MAGBDY
      ELSE IF (MODX .EQ. 197) THEN
         CALL COMUGV
      ELSE IF (MODX .EQ. 198) THEN
         CALL FLBMG
      ELSE IF (MODX .EQ. 199) THEN
         CALL GFSMA
      ELSE IF (MODX .EQ. 200) THEN
         CALL TRAIL
      ELSE IF (MODX .EQ. 201) THEN
         CALL SCAN
      ELSE IF (MODX .EQ. 202) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 203) THEN
         CALL PTHBDY
      ELSE IF (MODX .EQ. 204) THEN
         CALL VARIAN
      ELSE IF (MODX .EQ. 205) THEN
         CALL FVRST1
      ELSE IF (MODX .EQ. 206) THEN
         CALL FVRST2
      ELSE IF (MODX .EQ. 207) THEN
         CALL ALG
      ELSE IF (MODX .EQ. 208) THEN
         CALL APDB
      ELSE IF (MODX .EQ. 209) THEN
         CALL PROMPT
      ELSE IF (MODX .EQ. 210) THEN
         CALL OLPLOT
      ELSE IF (MODX .EQ. 211) THEN
         CALL INPTT5
      ELSE IF (MODX .EQ. 212) THEN
         CALL OUTPT5
      ELSE IF (MODX .EQ. 213) THEN
         CONTINUE
      ELSE IF (MODX .EQ. 214) THEN
         CALL QPARMD
      ELSE IF (MODX .EQ. 215) THEN
         CALL GINOFL
      ELSE IF (MODX .EQ. 216) THEN
         CALL DBASE
      ELSE IF (MODX .EQ. 217) THEN
         CALL NORMAL
      ELSE
         CALL MESAGE (-9301, MODX, SUBNAM)
      END IF
      RETURN
      END
