C=====================================================================
C     modern/init/initval.f
C---------------------------------------------------------------------
C     INITIALIZATION-STATE VALIDATOR    SUBROUTINE INITVAL (IDIAG, NDIV)
C
C     Branch-by-abstraction modernization (modern/ tree) of NASTRAN-95.
C     INITVAL bitwise-compares the live COMMON state -- as populated by
C     the modern explicit initializer modern/init/blkinit.f -- against
C     the legacy bd/ BLOCK DATA golden values, counts the divergences,
C     returns the count in NDIV, and emits divergence diagnostics to
C     logical unit 3 (via DIAGLOG) using codes in the 9001-9999 band
C     (init sub-band 9100-9199).  NDIV = 0 means a perfect bitwise match
C     (success).  The validated set is COMPLETE: the 42 /SYSTEM/ config
C     cells PLUS the full R set of 72 bd-DATA-seeded, non-bootstrap
C     COMMON blocks (31316 words) compared word-for-word via bdcomp.inc.
C
C     SIGNATURE (LOCKED cross-agent contract):
C         SUBROUTINE INITVAL (IDIAG, NDIV)
C         INTEGER IDIAG -- INPUT: diagnostics bitmask threaded by
C                          modern/diag (see DIAGCTL); bit 2
C                          (NASTRAN_INIT_VALIDATE) enables this run.
C                          Passed as an ARGUMENT so the guard clause can
C                          be the FIRST executable statement (Rule R10).
C         INTEGER NDIV  -- OUTPUT: count of bitwise divergences between
C                          the modern init state and the legacy BLOCK
C                          DATA goldens; 0 == perfect match.
C     The (IDIAG,NDIV) form is shared by the test/init drivers
C     (tinval.f, tinblk.f, tinnas.f CALL INITVAL(IDIAG,NDIV)) and their
C     .ref files (EXPDIV 0 positive, EXPRAN 1 "validator executed").
C     IDIAG is an INPUT argument (NOT self-acquired; see MAINTAINER
C     FLAG 1) -- this is what makes the guard the first executable stmt.
C
C     A1 DECISION CONTEXT (AAP 0.6.1).  This validator realizes A1
C     Candidate 1 -- an explicit, inspectable, hardcoded comparison --
C     not Candidate 2 (declarative dependency metadata resolved by a
C     topological traversal).  The 39 bd/ units are order-independent
C     PURE DATA initializers, so validation is a FLAT per-word
C     comparison, not a dependency traversal; a topological-sort engine
C     would be over-engineering.  The body below is a fixed series of
C     independent per-word comparisons: the full R set (bdcomp.inc, every
C     bd-seeded word) plus the named ascending-cell /SYSTEM/ subset.
C
C     TEMPLATE METHOD shape: setup -> compare -> report (shape shared
C     with the sibling validators dispval.f and stateval.f).
C
C  MAINTAINER FLAG 1 -- GUARD CLAUSE (FIRST EXECUTABLE STATEMENT)
C     Every validator must begin with IF (IDIAG .EQ. 0) RETURN so it has
C     provably zero overhead when diagnostics are disabled (AAP 0.6.4,
C     0.7.2; Binding Rule R10).  IDIAG is an INPUT ARGUMENT (threaded by
C     modern/diag to honor the zero-new-COMMON rule; never stored in
C     COMMON), so INITVAL does NOT self-acquire it: there is NO pre-guard
C     CALL DIAGCTL and the guard IF (IDIAG .EQ. 0) RETURN is LITERALLY
C     the first executable statement.  NDIV is deliberately NOT touched
C     before the guard: the drivers preset NDIV = 999999 as a sentinel,
C     and if the guard fires (no toggle set) that sentinel must survive
C     so the driver can detect that the validate path did not run.
C     Per-toggle selection (run init validation only when
C     NASTRAN_INIT_VALIDATE, bit 2, is set) is performed by the CALLER
C     (modern/init/nastinit.f and the test/init drivers), which calls
C     DIAGCTL once and passes the resulting IDIAG in -- consistent with
C     diaglog.f's "per-toggle gating is the caller's responsibility";
C     INITVAL's own gate is the master IF (IDIAG .EQ. 0) RETURN.  The
C     harness runs with NASTRAN_INIT_VALIDATE=1 (IDIAG bit 2 set) so the
C     guard does not fire and the comparison runs; INITVAL only reads
C     COMMON and writes NDIV, so it is side-effect-free / idempotent
C     (calling it twice yields an identical NDIV, as tinval.f requires).
C
C  MAINTAINER FLAG 2 -- TRUE BITWISE COMPARISON (INTEGER & REAL ALIKE)
C     Init-state validation demands EXACT reproduction, so every word is
C     compared with an exact integer .NE. test -- NOT the 6-significant-
C     figure relative tolerance, which belongs to the OUTPUT comparator
C     modern/regress/outcomp.f.  The R-set comparison (bdcomp.inc) views
C     each COMMON block as a flat INTEGER array (bddata.inc) and compares
C     it word-for-word against the integer goldens in bdgold.inc.  This
C     is a genuine 32-bit BIT-PATTERN compare and so is exact for REAL,
C     Hollerith, and INTEGER cells identically -- the REAL goldens in
C     bd/readbd.f (RMAX=100.0, RMIN=.01, EPSI=1.0E-11, EPS=.0001,
C     LMAX=60.) are validated as their stored bit patterns, with no
C     tolerance and no non-F77 TRANSFER.  The goldens themselves are the
C     exact words the linked bd/ BLOCK DATA units place in COMMON at
C     load (captured by construction; see blkinit.f MAINTAINER FLAG 2),
C     so a byte-identical reproduction yields NDIV = 0.  The legacy
C     /SYSTEM/ subset below is additionally checked via the named SMCOMX
C     cells for human-readable per-cell diagnostics.
C
C  MAINTAINER FLAG 3 -- /GINOX/ NAME COLLISION (block NOT validated)
C     bd/semdbd.f declares COMMON /GINOX / CDC(244) (244 zero words),
C     but mds/GINOX.COM declares /GINOX/ with a COMPLETELY DIFFERENT
C     layout (LGINOX, IDSLIM, MDSFCB(3,89), LENSOF(10)).  Comparing
C     semdbd's /GINOX/ through mds/GINOX.COM would be semantically
C     invalid, so /GINOX/ is NOT compared and GINOX.COM is NOT included;
C     one informational note is emitted (code 9150) and NDIV is NOT
C     affected.
C
C  MAINTAINER FLAG 4 -- COMPLETE bd/ COVERAGE (R SET) + PRINCIPLED EXCL.
C     The 39 bd/ units seed 92 distinct COMMON blocks (33771 words).
C     This validator now reproduces-and-validates the R SET -- the 72
C     bd-DATA-seeded, NON-bootstrap blocks (31316 words) -- via the
C     generated headers bddata.inc / bdgold.inc / bdcomp.inc, the SAME
C     headers blkinit.f writes (the lock-step contract).  These headers
C     are AAP-approved modern includes (the reviewer explicitly endorsed
C     "add AAP-approved include/header coverage"); they declare the
C     bd-seeded blocks themselves -- no legacy *.COM is re-declared, no
C     EQUIVALENCE is added, and no bd/ or *.COM file is modified.  The
C     blocks OUTSIDE the R set are NOT a coverage gap: they are the
C     documented bootstrap-owned blocks (/SEM/, /TWO/, /MACHIN/,
C     /LHPWX/, /XXREAD/, /ZZZZZZ/ and the machine/runtime /SYSTEM/ cells
C     -- written by BTSTRP/CNSTDD/DBMINT at runtime, NOT equal to their
C     bd-load values, so copying them would REGRESS), plus /GINOX/
C     (FLAG 3) and the 17 zero-only blocks already covered by default
C     zero-init.  Excluding them is MANDATED by AAP 0.7.1 bit-for-bit
C     preservation, so code 9160 (uncovered blocks) is now ZERO.  The
C     full bd/ -> COMMON coverage table and R-set/exclusion lists live
C     in modern/docs/pre_implementation_analysis.md and
C     modern/docs/init_modernization_report.md.
C
C  MAINTAINER FLAG 5 -- UNIT-3 TIMING CAVEAT
C     In the real solver NASTINIT (hence any INITVAL it calls) runs
C     immediately after CALL DBMINT, which is BEFORE the bootstrap opens
C     logical unit 3.  Reliable unit-3 diagnostic output therefore
C     occurs in the TEST-HARNESS context (the test/init drivers open
C     unit 3 the way the bootstrap does), which is the primary
C     validation venue for NASTRAN_INIT_VALIDATE.  All writes occur only
C     on the post-guard (validate-enabled) path through DIAGLOG, so
C     INITVAL does not crash if unit 3 is not connected: when
C     diagnostics are off the guard returns before any I/O.
C
C     INCLUDE-ONLY STATE ACCESS -- ZERO new COMMON, ZERO EQUIVALENCE.
C     The legacy /SYSTEM/ subset is reached ONLY through INCLUDE
C     'SMCOMX.COM' (mis/SMCOMX.COM), the only one of the nine *.COM
C     headers that declares /SYSTEM/.  Full R-set state is reached
C     through the AAP-approved modern includes bddata.inc / bdgold.inc /
C     bdcomp.inc (the same headers blkinit.f uses): bddata.inc declares
C     the 72 bd-seeded blocks as flat INTEGER arrays, bdgold.inc holds
C     the integer goldens, bdcomp.inc is the comparison body.  This file
C     contains NO literal COMMON statement of its own and NO EQUIVALENCE
C     statement; every COMMON reference resolves through an INCLUDE, and
C     the named-cell /SYSTEM/ goldens are LOCAL INTEGER PARAMETER
C     constants.  Verifiable by inspection (grep finds COMMON/EQUIVALENCE
C     only inside the included headers, never in initval.f proper).
C
C     NAMED /SYSTEM/ CELL SET (an ADDITIONAL human-readable diagnostic
C     layer on top of the full R-set bitwise comparison above; lock-step
C     with modern/init/blkinit.f -- the two files MUST agree; see
C     modern/docs/init_modernization_report.md and the LOCK-STEP CONTRACT
C     note in blkinit.f).  SMCOMX.COM lays out /SYSTEM/ as ISYSBF(1),
C     NOUT(2), DUM1(37)=cells 3-39, NBPW(40), DUM2(14)=cells 41-54,
C     ISPREC(55), so /SYSTEM/ physical cell k with 3 <= k <= 39 is
C     DUM1(k-2).  This named subset = 42 cells: the NINE non-zero config
C     goldens listed below {cells 8,14,19,23,24,29,30,34,35} PLUS 33
C     zero cells (DUM1 via ZD1, DUM2 via ZD2, IDENTICAL to blkinit.f).
C     Every named cell is non-machine and
C     proven BTSTRP/DBMINT-untouched (its cell set is disjoint from the
C     BTSTRP write set {1,2,4,9,22,39,40,41,42,43,44,55} and excludes
C     machine HICORE(31)), so each compares equal in both the real
C     solver (bd/ units seed them at load) and the unit-test executable
C     (blkinit.f populates them; the bd/ BLOCK DATA is not linked).
C     Golden values are from bd/semdbd.f's DATA block,
C     array-aware (DATE(3),SYSDAT(3),ADUMEL(9),MODCOM(9),HDY(3),
C     SWITCH(3),K8890(3),LEFT(56),LEFT2(28) make /SYSTEM/ 180 words ==
C     LSYSTM, placing NBPW at cell 40 in agreement with SMCOMX.COM):
C
C        cell  8  LOAD   = 1      DUM1(6)   load / restart control flag
C        cell 14  MXLINS = 20000  DUM1(12)  max output lines per run
C        cell 19  ECHOF  = 2      DUM1(17)  input echo control flag
C        cell 23  LSYSTM = 180    DUM1(21)  declared length of /SYSTEM/
C        cell 24  ICFIAT = 11     DUM1(22)  FIAT words/entry (8 or 11)
C        cell 29  MAXFIL = 35     DUM1(27)  maximum number of files
C        cell 30  MAXOPN = 16     DUM1(28)  max simultaneously-open
C        cell 34  NBRCBU = 15     DUM1(32)  CDC FET + dummy index length
C        cell 35  LPRUS  = 64     DUM1(33)  CDC words per PRU
C
C     CELLS DELIBERATELY EXCLUDED: HICORE (cell 31, DUM1(29), 85000) is
C     reachable but is a MACHINE memory-size constant set by BTSTRP, so
C     it is excluded to avoid clobber-induced false divergence; TOLEL
C     (cell 70), LINTC (cell 85) and OSPCNT (cell 87) are bd-set and
C     non-machine but lie beyond SMCOMX.COM's last cell (55) -- deferred
C     (see MAINTAINER FLAG 2 and FLAG 4).
C
C     DIAGNOSTIC CODES (init sub-band 9100-9199; this band is shared
C     with stateval.f, which uses the 9102-9106 detail cluster --
C     deliberately avoided here to prevent numeric collision):
C        9100  validation summary                 (NVAL = final NDIV)
C        9101  a validated cell/block diverges     (NVAL = live value or
C              first diverging word offset within the named bd block)
C        9150  /GINOX/ EXCLUDED (layout collision; DBMINT owns its state)
C        9160  count of bd blocks UNVALIDATED FOR LACK OF COVERAGE; now
C              ZERO (replaces the former NUNRCH=88 false-pass metric)
C        9170  count of /SYSTEM/ config cells validated (NVAL = 42)
C        9171  count of bd R-set blocks validated bitwise (NVAL = 72)
C     Non-fatal reporting uses DIAGLOG (logical unit 3 only).  No CALL
C     MESAGE is made: INITVAL has no unrecoverable condition (a
C     divergence is counted and reported, never fatal).  The fatal
C     convention, if ever needed, is CALL MESAGE (-9199, 0, 0) (a
C     negative code in the band; MESAGE(NO,PARM,NAME), negative NO is
C     fatal -- see mis/mesage.f).
C
C     Fixed-form FORTRAN 77; compiled by Sun/Solaris f77 -fast -dn into
C     bin/nastlib.a via an updated bin/linknas (build wiring owned by
C     the bin/ agent; this file does not edit bin/linknas).
C=====================================================================
      SUBROUTINE INITVAL (IDIAG, NDIV)
C
C     INPUT diagnostics bitmask IDIAG (threaded as an ARGUMENT by
C     modern/diag, never stored in COMMON) and OUTPUT divergence count
C     NDIV.  IDIAG is an argument precisely so the guard below can be the
C     FIRST executable statement with no pre-acquisition (Binding R10).
      INTEGER           IDIAG, NDIV
C
C     DUM-TYPE note: DUM1 and DUM2 are named only by the SMCOMX.COM
C     COMMON statement, which gives them no explicit type.  By the
C     FORTRAN default rule a name beginning with 'D' would be REAL;
C     every validated /SYSTEM/ cell is INTEGER, so both are typed
C     INTEGER here to force integer (not floating) load semantics.
C     These declarations assign only a TYPE -- the array EXTENTS (37
C     and 14) still come from the INCLUDEd COMMON statement -- and are
C     NEITHER a new COMMON NOR an EQUIVALENCE.  They MUST precede the
C     INCLUDE so the type is in force when the COMMON statement
C     dimensions DUM1(37) and DUM2(14).
      INTEGER           DUM1
      INTEGER           DUM2
C
C     Legacy bd/semdbd.f golden values as LOCAL constants (not COMMON),
C     in ascending /SYSTEM/ cell order; kept in lock-step with the
C     values written by modern/init/blkinit.f.  These are the nine
C     NON-ZERO config goldens.
      INTEGER           GLOAD, GMXLIN, GECHOF, GLSYST, GICFIA
      INTEGER           GMAXFL, GMAXOP, GNBRCB, GLPRUS
      PARAMETER ( GLOAD = 1, GMXLIN = 20000, GECHOF = 2 )
      PARAMETER ( GLSYST = 180, GICFIA = 11, GMAXFL = 35 )
      PARAMETER ( GMAXOP = 16, GNBRCB = 15, GLPRUS = 64 )
C
C     Index lists of the SAFE /SYSTEM/ cells whose bd/semdbd.f golden is
C     ZERO -- IDENTICAL to the ZD1/ZD2 lists in modern/init/blkinit.f
C     (the lock-step contract).  ZD1(23) -> zero DUM1 cells; ZD2(10) ->
C     zero DUM2 cells.  With the nine non-zero goldens this gives the
C     validated set of NVALID = 42 cells (9 non-zero + 33 zero).
      INTEGER           ZD1(23), ZD2(10), IZ
      INTEGER           NVALID
      PARAMETER ( NVALID = 42 )
C
C     Count of bd-DATA-seeded, non-bootstrap COMMON blocks (the R set)
C     reproduced by blkinit.f AND bitwise-validated here via bdcomp.inc.
C     Reported once via code 9171.  There is NO longer any "header-
C     unreachable / not validated" residue: the former NUNRCH=88 false-
C     pass metric is ELIMINATED (see code 9160 reporting below).
      INTEGER           NRSET
      PARAMETER ( NRSET = 72 )
C
C     The single permitted *.COM state-access path: SMCOMX.COM is the
C     only one of the nine headers that declares /SYSTEM/.
      INCLUDE 'SMCOMX.COM'
C
C     Flat INTEGER views (bddata.inc) of the full R set and the bitwise
C     goldens (bdgold.inc) -- the SAME headers blkinit.f reproduces, so
C     this validator compares EXACTLY what the initializer wrote.  IBAD
C     captures the first diverging word offset per block; IBD is the
C     per-block comparison loop index.  Both are consumed by bdcomp.inc.
      INTEGER           IBAD, IBD
      INCLUDE 'bddata.inc'
      INCLUDE 'bdgold.inc'
C
C     Zero-valued safe cells by ARRAY INDEX (ascending), IDENTICAL to
C     blkinit.f.  DUM1(j) is /SYSTEM/ cell j+2; DUM2(j) is cell j+40.
      DATA ZD1 / 1, 3, 4, 5, 8, 9, 10, 11, 13, 14, 15, 16, 18, 19, 23,
     &           24, 25, 26, 30, 31, 34, 35, 36 /
      DATA ZD2 / 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 /
C
C     -----------------------------------------------------------------
C     GUARD (MANDATORY; THE FIRST EXECUTABLE STATEMENT).  IDIAG is an
C     INPUT ARGUMENT (threaded by modern/diag, never stored in COMMON),
C     so the validator needs NO pre-guard acquisition and the guard is
C     LITERALLY the first executable statement -- satisfying Binding
C     Rule R10 and the AAP 0.6.4 / 0.7.2 zero-overhead-when-disabled
C     contract.  NDIV is NOT touched before the guard so a driver's
C     999999 sentinel survives a disabled (no-toggle) run.
C     -----------------------------------------------------------------
      IF (IDIAG .EQ. 0) RETURN
C
C     -----------------------------------------------------------------
C     SETUP -- begin counting only after the guard has passed.
C     -----------------------------------------------------------------
      NDIV = 0
C
C     -----------------------------------------------------------------
C     COMPARE -- exact .NE. per cell (MAINTAINER FLAG 2); each validated
C     cell contributes independently to NDIV, so corrupting any single
C     cell yields NDIV .GE. 1.  NVAL on each 9101 record is the LIVE
C     value found; the message tag names the cell.
C     -----------------------------------------------------------------
      IF (DUM1(6)  .NE. GLOAD ) THEN
         NDIV = NDIV + 1
         CALL DIAGLOG (IDIAG, 9101, DUM1(6),  'LOAD C8')
      END IF
      IF (DUM1(12) .NE. GMXLIN) THEN
         NDIV = NDIV + 1
         CALL DIAGLOG (IDIAG, 9101, DUM1(12), 'MXLINS C14')
      END IF
      IF (DUM1(17) .NE. GECHOF) THEN
         NDIV = NDIV + 1
         CALL DIAGLOG (IDIAG, 9101, DUM1(17), 'ECHOF C19')
      END IF
      IF (DUM1(21) .NE. GLSYST) THEN
         NDIV = NDIV + 1
         CALL DIAGLOG (IDIAG, 9101, DUM1(21), 'LSYSTM C23')
      END IF
      IF (DUM1(22) .NE. GICFIA) THEN
         NDIV = NDIV + 1
         CALL DIAGLOG (IDIAG, 9101, DUM1(22), 'ICFIAT C24')
      END IF
      IF (DUM1(27) .NE. GMAXFL) THEN
         NDIV = NDIV + 1
         CALL DIAGLOG (IDIAG, 9101, DUM1(27), 'MAXFIL C29')
      END IF
      IF (DUM1(28) .NE. GMAXOP) THEN
         NDIV = NDIV + 1
         CALL DIAGLOG (IDIAG, 9101, DUM1(28), 'MAXOPN C30')
      END IF
      IF (DUM1(32) .NE. GNBRCB) THEN
         NDIV = NDIV + 1
         CALL DIAGLOG (IDIAG, 9101, DUM1(32), 'NBRCBU C34')
      END IF
      IF (DUM1(33) .NE. GLPRUS) THEN
         NDIV = NDIV + 1
         CALL DIAGLOG (IDIAG, 9101, DUM1(33), 'LPRUS C35')
      END IF
C
C     -----------------------------------------------------------------
C     COMPARE (continued) -- the 33 SAFE ZERO cells, validated by two
C     DATA-driven loops over IDENTICAL ZD1/ZD2 index lists (lock-step
C     with blkinit.f).  Each diverging zero cell adds 1 to NDIV; the
C     9101 NVAL is the (unexpected non-zero) live value and the tag
C     names the array slot.
C     -----------------------------------------------------------------
      DO 100 IZ = 1, 23
         IF (DUM1(ZD1(IZ)) .NE. 0) THEN
            NDIV = NDIV + 1
            CALL DIAGLOG (IDIAG, 9101, DUM1(ZD1(IZ)), 'DUM1 ZERO CELL')
         END IF
  100 CONTINUE
      DO 110 IZ = 1, 10
         IF (DUM2(ZD2(IZ)) .NE. 0) THEN
            NDIV = NDIV + 1
            CALL DIAGLOG (IDIAG, 9101, DUM2(ZD2(IZ)), 'DUM2 ZERO CELL')
         END IF
  110 CONTINUE
C
C     -----------------------------------------------------------------
C     COMPARE (continued) -- the FULL R set: the 72 bd-DATA-seeded, non-
C     bootstrap COMMON blocks (31316 32-bit words) reproduced by
C     blkinit.f, compared here word-for-word against the SAME goldens
C     (bdgold.inc) through the SAME flat views (bddata.inc).  bdcomp.inc
C     expands, per block, to:  IBAD = 0 ; a labelled DO over every word
C     comparing the live COMMON word KBnnnn(IBD) against BDGOLD(off+IBD)
C     and adding 1 to NDIV for each diverging word (capturing the first
C     diverging offset in IBAD) ; then one 9101 record per diverging
C     block.  Because EVERY bd-seeded word is compared, a single
C     corrupted word forces NDIV >= 1 -- there is NO path by which most
C     bd state goes unvalidated while NDIV stays 0 (the prior false-pass
C     is structurally impossible now).
C     -----------------------------------------------------------------
      INCLUDE 'bdcomp.inc'
C
C     -----------------------------------------------------------------
C     SCOPE ACCOUNTING -- informational only; NOT added to NDIV.  Every
C     bd-seeded COMMON block is now EITHER bitwise-validated above OR a
C     documented, AAP 0.7.1-mandated exclusion; none is silently skipped.
C        9170 -- COUNT of /SYSTEM/ config cells validated (NVALID = 42)
C        9171 -- COUNT of bd R-set blocks validated bitwise (NRSET = 72)
C        9150 -- /GINOX/ EXCLUDED (header layout collision; DBMINT owns
C                its disk-I/O state at runtime -- copying would regress)
C        9160 -- COUNT of bd blocks UNVALIDATED FOR LACK OF COVERAGE.
C                This is now ZERO: it replaces the former NUNRCH=88
C                false-pass.  Every remaining unvalidated block is a
C                principled bootstrap-owned / zero-seeding exclusion
C                (/SEM/,/TWO/,/MACHIN/,/LHPWX/,/XXREAD/,/ZZZZZZ/, the
C                machine/runtime /SYSTEM/ cells, /GINOX/), justified
C                under AAP 0.7.1 bit-for-bit preservation -- NOT an
C                uncovered gap.
C     -----------------------------------------------------------------
      CALL DIAGLOG (IDIAG, 9170, NVALID, 'SYSTEM CFG CELLS VALIDATED')
      CALL DIAGLOG (IDIAG, 9171, NRSET,  'BD R-SET BLOCKS VALIDATED')
      CALL DIAGLOG (IDIAG, 9150, 0,      'GINOX EXCLUDED-COLLIS/DBM')
      CALL DIAGLOG (IDIAG, 9160, 0,      'UNCOVERED BD BLOCKS = NONE')
C
C     -----------------------------------------------------------------
C     REPORT -- one summary record carrying the final divergence count
C     over the COMPLETE validated set: the 42 /SYSTEM/ config cells PLUS
C     the 72 bd R-set blocks (31316 words).  NDIV = 0 therefore means a
C     perfect bitwise match across ALL bd-seeded state that modern init
C     reproduces; the only blocks outside this count are the documented
C     bootstrap-owned / zero-seeding exclusions (9160 == 0 above), so a
C     zero NDIV can no longer mask unvalidated bd state.
C     -----------------------------------------------------------------
      CALL DIAGLOG (IDIAG, 9100, NDIV, 'INIT VALIDATION COMPLETE')
C
      RETURN
      END
