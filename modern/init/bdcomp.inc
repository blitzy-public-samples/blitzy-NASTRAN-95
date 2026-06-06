C     bdcomp.inc - bitwise compare the 72 R-set COMMON blocks against
C     BDGOLD.  Increments NDIV once per diverging 32-bit word, so a
C     single corrupted word forces NDIV >= 1 (no false pass).  Emits
C     ONE 9101 diagnostic per diverging block via the standard
C     DIAGLOG(IDIAG,ICODE,NVAL,MSG) writer: NVAL = first diverging
C     word offset within the block, MSG = 'BD <blockname>'.
C     BITPOS (64 words)
      IBAD = 0
      DO 8001 IBD = 1, 64
      IF (KB0001(IBD) .NE. BDGOLD(IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8001  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD BITPOS')
C     BLANK (100 words)
      IBAD = 0
      DO 8002 IBD = 1, 100
      IF (KB0002(IBD) .NE. BDGOLD(64+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8002  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD BLANK')
C     CHAR94 (240 words)
      IBAD = 0
      DO 8003 IBD = 1, 240
      IF (KB0003(IBD) .NE. BDGOLD(164+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8003  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD CHAR94')
C     CHRDRW (761 words)
      IBAD = 0
      DO 8004 IBD = 1, 761
      IF (KB0004(IBD) .NE. BDGOLD(404+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8004  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD CHRDRW')
C     CLSTRS (530 words)
      IBAD = 0
      DO 8005 IBD = 1, 530
      IF (KB0005(IBD) .NE. BDGOLD(1165+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8005  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD CLSTRS')
C     DPDCOM (142 words)
      IBAD = 0
      DO 8006 IBD = 1, 142
      IF (KB0006(IBD) .NE. BDGOLD(1695+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8006  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD DPDCOM')
C     DRWAXS (12 words)
      IBAD = 0
      DO 8007 IBD = 1, 12
      IF (KB0007(IBD) .NE. BDGOLD(1837+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8007  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD DRWAXS')
C     EXIO2F (107 words)
      IBAD = 0
      DO 8008 IBD = 1, 107
      IF (KB0008(IBD) .NE. BDGOLD(1849+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8008  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD EXIO2F')
C     EXIO2P (141 words)
      IBAD = 0
      DO 8009 IBD = 1, 141
      IF (KB0009(IBD) .NE. BDGOLD(1956+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8009  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD EXIO2P')
C     FLBFIL (20 words)
      IBAD = 0
      DO 8010 IBD = 1, 20
      IF (KB0010(IBD) .NE. BDGOLD(2097+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8010  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD FLBFIL')
C     GIVN (150 words)
      IBAD = 0
      DO 8011 IBD = 1, 150
      IF (KB0011(IBD) .NE. BDGOLD(2117+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8011  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD GIVN')
C     GP3COM (357 words)
      IBAD = 0
      DO 8012 IBD = 1, 357
      IF (KB0012(IBD) .NE. BDGOLD(2267+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8012  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD GP3COM')
C     GPTA1 (2153 words)
      IBAD = 0
      DO 8013 IBD = 1, 2153
      IF (KB0013(IBD) .NE. BDGOLD(2624+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8013  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD GPTA1')
C     IFP3CM (266 words)
      IBAD = 0
      DO 8014 IBD = 1, 266
      IF (KB0014(IBD) .NE. BDGOLD(4777+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8014  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD IFP3CM')
C     IFPX0 (21 words)
      IBAD = 0
      DO 8015 IBD = 1, 21
      IF (KB0015(IBD) .NE. BDGOLD(5043+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8015  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD IFPX0')
C     IFPX1 (1117 words)
      IBAD = 0
      DO 8016 IBD = 1, 1117
      IF (KB0016(IBD) .NE. BDGOLD(5064+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8016  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD IFPX1')
C     IFPX2 (740 words)
      IBAD = 0
      DO 8017 IBD = 1, 740
      IF (KB0017(IBD) .NE. BDGOLD(6181+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8017  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD IFPX2')
C     IFPX3 (740 words)
      IBAD = 0
      DO 8018 IBD = 1, 740
      IF (KB0018(IBD) .NE. BDGOLD(6921+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8018  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD IFPX3')
C     IFPX4 (740 words)
      IBAD = 0
      DO 8019 IBD = 1, 740
      IF (KB0019(IBD) .NE. BDGOLD(7661+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8019  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD IFPX4')
C     IFPX5 (740 words)
      IBAD = 0
      DO 8020 IBD = 1, 740
      IF (KB0020(IBD) .NE. BDGOLD(8401+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8020  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD IFPX5')
C     IFPX6 (740 words)
      IBAD = 0
      DO 8021 IBD = 1, 740
      IF (KB0021(IBD) .NE. BDGOLD(9141+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8021  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD IFPX6')
C     IFPX7 (1469 words)
      IBAD = 0
      DO 8022 IBD = 1, 1469
      IF (KB0022(IBD) .NE. BDGOLD(9881+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8022  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD IFPX7')
C     INVPWX (44 words)
      IBAD = 0
      DO 8023 IBD = 1, 44
      IF (KB0023(IBD) .NE. BDGOLD(11350+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8023  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD INVPWX')
C     ITEMDT (176 words)
      IBAD = 0
      DO 8024 IBD = 1, 176
      IF (KB0024(IBD) .NE. BDGOLD(11394+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8024  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD ITEMDT')
C     MSGX (162 words)
      IBAD = 0
      DO 8025 IBD = 1, 162
      IF (KB0025(IBD) .NE. BDGOLD(11570+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8025  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD MSGX')
C     NAMES (19 words)
      IBAD = 0
      DO 8026 IBD = 1, 19
      IF (KB0026(IBD) .NE. BDGOLD(11732+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8026  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD NAMES')
C     NTIME (24 words)
      IBAD = 0
      DO 8027 IBD = 1, 24
      IF (KB0027(IBD) .NE. BDGOLD(11751+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8027  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD NTIME')
C     OFPB1 (600 words)
      IBAD = 0
      DO 8028 IBD = 1, 600
      IF (KB0028(IBD) .NE. BDGOLD(11775+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8028  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD OFPB1')
C     OFPB2 (1200 words)
      IBAD = 0
      DO 8029 IBD = 1, 1200
      IF (KB0029(IBD) .NE. BDGOLD(12375+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8029  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD OFPB2')
C     OFPB3 (600 words)
      IBAD = 0
      DO 8030 IBD = 1, 600
      IF (KB0030(IBD) .NE. BDGOLD(13575+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8030  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD OFPB3')
C     OFPB3S (600 words)
      IBAD = 0
      DO 8031 IBD = 1, 600
      IF (KB0031(IBD) .NE. BDGOLD(14175+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8031  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD OFPB3S')
C     OFPB4 (1200 words)
      IBAD = 0
      DO 8032 IBD = 1, 1200
      IF (KB0032(IBD) .NE. BDGOLD(14775+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8032  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD OFPB4')
C     OFPB5 (600 words)
      IBAD = 0
      DO 8033 IBD = 1, 600
      IF (KB0033(IBD) .NE. BDGOLD(15975+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8033  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD OFPB5')
C     OFPB6 (1200 words)
      IBAD = 0
      DO 8034 IBD = 1, 1200
      IF (KB0034(IBD) .NE. BDGOLD(16575+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8034  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD OFPB6')
C     OFPB7 (600 words)
      IBAD = 0
      DO 8035 IBD = 1, 600
      IF (KB0035(IBD) .NE. BDGOLD(17775+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8035  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD OFPB7')
C     OFPB7S (600 words)
      IBAD = 0
      DO 8036 IBD = 1, 600
      IF (KB0036(IBD) .NE. BDGOLD(18375+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8036  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD OFPB7S')
C     OFPB8 (1200 words)
      IBAD = 0
      DO 8037 IBD = 1, 1200
      IF (KB0037(IBD) .NE. BDGOLD(18975+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8037  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD OFPB8')
C     OFPB9 (480 words)
      IBAD = 0
      DO 8038 IBD = 1, 480
      IF (KB0038(IBD) .NE. BDGOLD(20175+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8038  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD OFPB9')
C     OFPBD1 (4290 words)
      IBAD = 0
      DO 8039 IBD = 1, 4290
      IF (KB0039(IBD) .NE. BDGOLD(20655+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8039  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD OFPBD1')
C     OFPBD5 (564 words)
      IBAD = 0
      DO 8040 IBD = 1, 564
      IF (KB0040(IBD) .NE. BDGOLD(24945+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8040  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD OFPBD5')
C     OFSN1 (66 words)
      IBAD = 0
      DO 8041 IBD = 1, 66
      IF (KB0041(IBD) .NE. BDGOLD(25509+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8041  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD OFSN1')
C     OFSS1 (30 words)
      IBAD = 0
      DO 8042 IBD = 1, 30
      IF (KB0042(IBD) .NE. BDGOLD(25575+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8042  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD OFSS1')
C     OSCENT (200 words)
      IBAD = 0
      DO 8043 IBD = 1, 200
      IF (KB0043(IBD) .NE. BDGOLD(25605+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8043  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD OSCENT')
C     OUTPUT (224 words)
      IBAD = 0
      DO 8044 IBD = 1, 224
      IF (KB0044(IBD) .NE. BDGOLD(25805+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8044  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD OUTPUT')
C     PLA42C (150 words)
      IBAD = 0
      DO 8045 IBD = 1, 150
      IF (KB0045(IBD) .NE. BDGOLD(26029+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8045  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD PLA42C')
C     PLTDAT (92 words)
      IBAD = 0
      DO 8046 IBD = 1, 92
      IF (KB0046(IBD) .NE. BDGOLD(26179+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8046  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD PLTDAT')
C     PLTSCR (51 words)
      IBAD = 0
      DO 8047 IBD = 1, 51
      IF (KB0047(IBD) .NE. BDGOLD(26271+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8047  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD PLTSCR')
C     REGEAN (42 words)
      IBAD = 0
      DO 8048 IBD = 1, 42
      IF (KB0048(IBD) .NE. BDGOLD(26322+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8048  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD REGEAN')
C     SDR2X1 (17 words)
      IBAD = 0
      DO 8049 IBD = 1, 17
      IF (KB0049(IBD) .NE. BDGOLD(26364+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8049  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD SDR2X1')
C     SDR2X2 (32 words)
      IBAD = 0
      DO 8050 IBD = 1, 32
      IF (KB0050(IBD) .NE. BDGOLD(26381+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8050  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD SDR2X2')
C     SDR2X4 (112 words)
      IBAD = 0
      DO 8051 IBD = 1, 112
      IF (KB0051(IBD) .NE. BDGOLD(26413+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8051  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD SDR2X4')
C     SMA1CL (223 words)
      IBAD = 0
      DO 8052 IBD = 1, 223
      IF (KB0052(IBD) .NE. BDGOLD(26525+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8052  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD SMA1CL')
C     SMA1IO (36 words)
      IBAD = 0
      DO 8053 IBD = 1, 36
      IF (KB0053(IBD) .NE. BDGOLD(26748+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8053  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD SMA1IO')
C     SMA2CL (223 words)
      IBAD = 0
      DO 8054 IBD = 1, 223
      IF (KB0054(IBD) .NE. BDGOLD(26784+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8054  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD SMA2CL')
C     SMA2IO (36 words)
      IBAD = 0
      DO 8055 IBD = 1, 36
      IF (KB0055(IBD) .NE. BDGOLD(27007+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8055  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD SMA2IO')
C     SOFCOM (27 words)
      IBAD = 0
      DO 8056 IBD = 1, 27
      IF (KB0056(IBD) .NE. BDGOLD(27043+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8056  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD SOFCOM')
C     SYMBLS (41 words)
      IBAD = 0
      DO 8057 IBD = 1, 41
      IF (KB0057(IBD) .NE. BDGOLD(27070+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8057  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD SYMBLS')
C     TA1ACM (90 words)
      IBAD = 0
      DO 8058 IBD = 1, 90
      IF (KB0058(IBD) .NE. BDGOLD(27111+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8058  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD TA1ACM')
C     TABFTX (1344 words)
      IBAD = 0
      DO 8059 IBD = 1, 1344
      IF (KB0059(IBD) .NE. BDGOLD(27201+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8059  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD TABFTX')
C     TYPE (16 words)
      IBAD = 0
      DO 8060 IBD = 1, 16
      IF (KB0060(IBD) .NE. BDGOLD(28545+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8060  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD TYPE')
C     VDRCOM (101 words)
      IBAD = 0
      DO 8061 IBD = 1, 101
      IF (KB0061(IBD) .NE. BDGOLD(28561+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8061  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD VDRCOM')
C     XCEITB (42 words)
      IBAD = 0
      DO 8062 IBD = 1, 42
      IF (KB0062(IBD) .NE. BDGOLD(28662+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8062  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD XCEITB')
C     XDPL (243 words)
      IBAD = 0
      DO 8063 IBD = 1, 243
      IF (KB0063(IBD) .NE. BDGOLD(28704+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8063  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD XDPL')
C     XFIAT (1103 words)
      IBAD = 0
      DO 8064 IBD = 1, 1103
      IF (KB0064(IBD) .NE. BDGOLD(28947+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8064  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD XFIAT')
C     XFIST (114 words)
      IBAD = 0
      DO 8065 IBD = 1, 114
      IF (KB0065(IBD) .NE. BDGOLD(30050+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8065  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD XFIST')
C     XLINK (222 words)
      IBAD = 0
      DO 8066 IBD = 1, 222
      IF (KB0066(IBD) .NE. BDGOLD(30164+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8066  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD XLINK')
C     XMDMSK (10 words)
      IBAD = 0
      DO 8067 IBD = 1, 10
      IF (KB0067(IBD) .NE. BDGOLD(30386+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8067  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD XMDMSK')
C     XMSSG (40 words)
      IBAD = 0
      DO 8068 IBD = 1, 40
      IF (KB0068(IBD) .NE. BDGOLD(30396+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8068  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD XMSSG')
C     XPFIST (1 words)
      IBAD = 0
      DO 8069 IBD = 1, 1
      IF (KB0069(IBD) .NE. BDGOLD(30436+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8069  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD XPFIST')
C     XREADX (43 words)
      IBAD = 0
      DO 8070 IBD = 1, 43
      IF (KB0070(IBD) .NE. BDGOLD(30437+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8070  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD XREADX')
C     XVPS (600 words)
      IBAD = 0
      DO 8071 IBD = 1, 600
      IF (KB0071(IBD) .NE. BDGOLD(30480+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8071  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD XVPS')
C     XXPARM (236 words)
      IBAD = 0
      DO 8072 IBD = 1, 236
      IF (KB0072(IBD) .NE. BDGOLD(31080+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8072  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD XXPARM')
C     SEM (33 words) -- PARTIAL: validate word 1 (MASK) and words 4-33
C     (NAME); skip BTSTRP-owned words 2,3 (not reproduced by blkinit.f),
C     matching the bdcopy.inc copy mask exactly.
      IBAD = 0
      IF (KB0073(1) .NE. BDGOLD(31317)) THEN
        NDIV = NDIV + 1
        IBAD = 1
      END IF
      DO 8073 IBD = 4, 33
      IF (KB0073(IBD) .NE. BDGOLD(31316+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8073  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD SEM')
C     TWO (33 words) -- PARTIAL: validate words 2-32 (powers of two);
C     skip BTSTRP-owned words 1,33, matching the bdcopy.inc copy mask.
      IBAD = 0
      DO 8074 IBD = 2, 32
      IF (KB0074(IBD) .NE. BDGOLD(31349+IBD)) THEN
        NDIV = NDIV + 1
        IF (IBAD .EQ. 0) IBAD = IBD
      END IF
8074  CONTINUE
      IF (IBAD .NE. 0)
     &   CALL DIAGLOG (IDIAG, 9101, IBAD, 'BD TWO')
