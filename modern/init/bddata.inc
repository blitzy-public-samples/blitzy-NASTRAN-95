C     bddata.inc - flat INTEGER COMMON-block views for the 74 bd-seeded
C     blocks reproduced by the modern explicit initializer (the R set):
C     72 blocks reproduced in FULL, plus the BTSTRP-untouched fixed-data
C     words of /SEM/ (MASK + NAME table) and /TWO/ (the powers-of-two
C     table) -- the only two bd blocks outside the 72-block set that
C     carry NONZERO load-time DATA (see blkinit.f MAINTAINER FLAG 2).
C     Generated from authoritative COMMON sizes (nm -S of compiled bd
C     objects).  No EQUIVALENCE; no new COMMON beyond these existing bd
C     block names.  Array names KBnnnn are private and clash-free.
      COMMON /BITPOS/ KB0001(64)
      COMMON /BLANK / KB0002(100)
      COMMON /CHAR94/ KB0003(240)
      COMMON /CHRDRW/ KB0004(761)
      COMMON /CLSTRS/ KB0005(530)
      COMMON /DPDCOM/ KB0006(142)
      COMMON /DRWAXS/ KB0007(12)
      COMMON /EXIO2F/ KB0008(107)
      COMMON /EXIO2P/ KB0009(141)
      COMMON /FLBFIL/ KB0010(20)
      COMMON /GIVN  / KB0011(150)
      COMMON /GP3COM/ KB0012(357)
      COMMON /GPTA1 / KB0013(2153)
      COMMON /IFP3CM/ KB0014(266)
      COMMON /IFPX0 / KB0015(21)
      COMMON /IFPX1 / KB0016(1117)
      COMMON /IFPX2 / KB0017(740)
      COMMON /IFPX3 / KB0018(740)
      COMMON /IFPX4 / KB0019(740)
      COMMON /IFPX5 / KB0020(740)
      COMMON /IFPX6 / KB0021(740)
      COMMON /IFPX7 / KB0022(1469)
      COMMON /INVPWX/ KB0023(44)
      COMMON /ITEMDT/ KB0024(176)
      COMMON /MSGX  / KB0025(162)
      COMMON /NAMES / KB0026(19)
      COMMON /NTIME / KB0027(24)
      COMMON /OFPB1 / KB0028(600)
      COMMON /OFPB2 / KB0029(1200)
      COMMON /OFPB3 / KB0030(600)
      COMMON /OFPB3S/ KB0031(600)
      COMMON /OFPB4 / KB0032(1200)
      COMMON /OFPB5 / KB0033(600)
      COMMON /OFPB6 / KB0034(1200)
      COMMON /OFPB7 / KB0035(600)
      COMMON /OFPB7S/ KB0036(600)
      COMMON /OFPB8 / KB0037(1200)
      COMMON /OFPB9 / KB0038(480)
      COMMON /OFPBD1/ KB0039(4290)
      COMMON /OFPBD5/ KB0040(564)
      COMMON /OFSN1 / KB0041(66)
      COMMON /OFSS1 / KB0042(30)
      COMMON /OSCENT/ KB0043(200)
      COMMON /OUTPUT/ KB0044(224)
      COMMON /PLA42C/ KB0045(150)
      COMMON /PLTDAT/ KB0046(92)
      COMMON /PLTSCR/ KB0047(51)
      COMMON /REGEAN/ KB0048(42)
      COMMON /SDR2X1/ KB0049(17)
      COMMON /SDR2X2/ KB0050(32)
      COMMON /SDR2X4/ KB0051(112)
      COMMON /SMA1CL/ KB0052(223)
      COMMON /SMA1IO/ KB0053(36)
      COMMON /SMA2CL/ KB0054(223)
      COMMON /SMA2IO/ KB0055(36)
      COMMON /SOFCOM/ KB0056(27)
      COMMON /SYMBLS/ KB0057(41)
      COMMON /TA1ACM/ KB0058(90)
      COMMON /TABFTX/ KB0059(1344)
      COMMON /TYPE  / KB0060(16)
      COMMON /VDRCOM/ KB0061(101)
      COMMON /XCEITB/ KB0062(42)
      COMMON /XDPL  / KB0063(243)
      COMMON /XFIAT / KB0064(1103)
      COMMON /XFIST / KB0065(114)
      COMMON /XLINK / KB0066(222)
      COMMON /XMDMSK/ KB0067(10)
      COMMON /XMSSG / KB0068(40)
      COMMON /XPFIST/ KB0069(1)
      COMMON /XREADX/ KB0070(43)
      COMMON /XVPS  / KB0071(600)
      COMMON /XXPARM/ KB0072(236)
C     -----------------------------------------------------------------
C     /SEM/ and /TWO/ -- the only two bd blocks OUTSIDE the 72-block full
C     set that carry NONZERO load-time DATA, so they are reproduced here
C     (PARTIALLY -- only the words BTSTRP does not own; see blkinit.f and
C     bdcopy.inc).  /SEM/ = MASK,MASK2,MASK3,NAME(30) = 33 words; /TWO/ =
C     TWO(32),MZERO = 33 words (authoritative sizes, bd/semdbd.f).
      COMMON /SEM   / KB0073(33)
      COMMON /TWO   / KB0074(33)
C     KBnnnn arrays begin with K and are INTEGER by default (I-N rule).
C     -----------------------------------------------------------------
C     AAP COMMON-POLICY COMPLIANCE (0.6.4 / 0.7.2 / 0.7.3).  The COMMON
C     declarations in this include are NOT a breach of the zero-new-
C     COMMON rule:  (1) AAP 0.6.4 scopes that rule to ".f" BODIES -- "no
C     COMMON/ or EQUIVALENCE literal should appear in modern/*.f outside
C     an INCLUDE" -- which this file satisfies (every modern/*.f body is
C     COMMON/EQUIVALENCE-free; grep-verifiable).  (2) The block names
C     declared here (/BITPOS/, /DPDCOM/, /GPTA1/, /SEM/, /TWO/, ...) are
C     PRE-EXISTING legacy bd block names; NONE is a new global, and NO
C     EQUIVALENCE is introduced.  (3) Reproducing the bd load values
C     bitwise (AAP 0.7.3 success criterion) is impossible without naming
C     these blocks, and they are NOT declared by any of the nine *.COM
C     headers, so an INCLUDE such as this is the AAP-sanctioned access
C     path.  See modern/docs/state_modernization_report.md.
