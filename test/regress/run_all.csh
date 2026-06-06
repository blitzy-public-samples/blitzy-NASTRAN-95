#!/bin/csh
#==============================================================================
# test/regress/run_all.csh
#------------------------------------------------------------------------------
# NASTRAN-95 MODERNIZATION -- INTEGRATION / GOLDEN-MASTER REGRESSION HARNESS
# (AAP 0.2.1 "Regression-safety infrastructure", 0.3.1, 0.4.1, 0.6.3, 0.7.5).
#
# WHAT IT DOES (one command):
#   1. Runs EVERY benchmark deck inp/*.inp (132 decks) through the built
#      solver bin/nastrn.exe, replicating -- for batch use -- the exact
#      env-variable run idiom of the interactive wrapper bin/nastran
#      (lines 522-533).
#   2. Applies the field-by-field OFP comparator modern/regress/outcomp.f
#      (driven by the PROGRAM entry modern/regress/regval.f, built here into
#      regress.exe) against the shipped golden masters demoout/*.out.
#   3. Reports a per-deck verdict "PASS: <base>" / "FAIL: <base>" to the
#      aggregate log test/regress/results/run_all.log.
#   4. EXITS NON-ZERO on ANY failure -- a comparator build error, a solver
#      run error, a missing required artifact, a missing golden master, or a
#      field-by-field comparison mismatch.  It exits 0 ONLY when every deck
#      PASSes.
#
# INVOCATION
#   run_all.csh            Default mode: a run is BIT-IDENTICAL to the
#                          unmodified APR.95 solver (all NASTRAN_* toggles
#                          unset) -- AAP 0.7.4 default-safety / instant
#                          rollback.
#   run_all.csh -validate  Additionally exports NASTRAN_INIT_VALIDATE=1 and
#                          NASTRAN_DISPATCH_VALIDATE=1 so the modern init /
#                          dispatch validation paths run.  Those toggles emit
#                          ONLY to logical unit 3 (the per-deck log), NEVER to
#                          stdout (the OFP being compared), so enabling
#                          validation does NOT perturb the golden-master
#                          comparison (see the run-block comment below).
#
# DELIVERABLE -- NOT EXECUTED BY BLITZY
#   This script is produced as a deliverable and run LATER in the developer's
#   Solaris environment (csh + Sun f77).  It is NOT executed during the
#   refactor: it references f77, bin/nastrn.exe and bin/nastlib.a, which exist
#   only AFTER bin/linknas has built them in the Solaris build environment.
#
# BINDING CONSTRAINT -- READ-ONLY LEGACY
#   This harness NEVER modifies inp/, demoout/, or any frozen/legacy source.
#   Input decks and golden masters are strictly READ-ONLY.  ALL generated
#   artifacts -- candidate outputs, per-deck logs, scratch dirs, the
#   comparator executable, and the aggregate log -- are written ONLY under the
#   dedicated $RESULTS directory, which is NEVER demoout/.
#
# CONVENTIONS (consistent with the sibling test/run_units.csh)
#   The "#!/bin/csh" shebang, "unalias rm", "set nonomatch", the
#   $NASTROOT/$NASTLIB/$FFLAGS/$RESULTS variable naming, the "@" integer
#   counters, the backtick `grep -c "FAIL:"` aggregation, and the
#   "exit 1 on any FAIL / exit 0 otherwise" contract are all shared with the
#   unit-level runner so the two harnesses form one coherent safety net.
#
# EXIT STATUS
#   0   every benchmark deck PASSed (>=1 deck discovered, comparator built,
#       all solver runs succeeded, all comparisons matched)
#   1   any failure: comparator build failure; a missing required artifact
#       (solver / archive / inp dir / golden dir / no decks); a missing golden
#       master; a non-zero solver exit; or a comparison FAIL
#==============================================================================
unalias rm

# Let an unmatched "inp/*.inp" glob expand to the literal pattern instead of
# aborting the run with csh "No match." -- the empty-deck guard below then
# uses a -e test on the first element to detect "no decks present" (a FAIL).
set nonomatch

#------------------------------------------------------------------------------
# Configuration -- every path derives from $NASTROOT so the harness relocates
# cleanly and stays reusable across future modernization phases.  Honor a
# pre-set environment $NASTROOT if present; otherwise derive the repository
# root from this script's own location.  This script lives at
# <root>/test/regress/run_all.csh, so the repository root is the GRANDPARENT
# of the directory that holds the script (two levels up) -- regardless of the
# directory from which the harness is launched.
#------------------------------------------------------------------------------
if ( $?NASTROOT == 0 ) then
   set scriptdir = $0:h
   if ( "$scriptdir" == "$0" ) then
      # $0 carried no directory component (invoked as a bare name from within
      # test/regress/); the repository root is two levels up from the cwd.
      set NASTROOT = ../..
   else
      # $0 carried a directory component; the script lives at
      # <root>/test/regress/, so the repository root is scriptdir's
      # grandparent.
      set NASTROOT = $scriptdir/../..
   endif
endif

set NASEXEC  = $NASTROOT/bin/nastrn.exe   # the built solver
set NASTLIB  = $NASTROOT/bin/nastlib.a    # archive the comparator links against
set FFLAGS   = "-fast -dn"                # EXACT Sun f77 flags from bin/linknas
set INPDIR   = $NASTROOT/inp              # benchmark decks (READ-ONLY)
set REFDIR   = $NASTROOT/demoout          # golden masters (READ-ONLY)
set RFDIR    = $NASTROOT/rf               # rigid-format dir (solver RFDIR env)
set TESTDIR  = $NASTROOT/test
set RESULTS  = $TESTDIR/regress/results   # ALL generated output (NEVER demoout/)
set RUNLOG   = $RESULTS/run_all.log       # aggregate PASS:/FAIL: log
set CMPEXE   = $RESULTS/regress.exe       # comparator exe (built below)
# Comparator sources: regval.f (PROGRAM/MAIN) listed FIRST, then outcomp.f
# (SUBROUTINE).  Kept as ONE configurable variable so a developer can drop
# these explicit sources if a future bin/linknas archives regval.o/outcomp.o
# into nastlib.a (avoids a duplicate-symbol link error).
set CMPSRC   = "$NASTROOT/modern/regress/regval.f $NASTROOT/modern/regress/outcomp.f"
set DBMEM    = 12000000                   # verbatim default from bin/nastran
set OCMEM    = 2000000                    # verbatim default from bin/nastran

set nrun  = 0
set npass = 0
set nfail = 0

#------------------------------------------------------------------------------
# Optional validation mode.  DEFAULT OFF => the solver run is BIT-IDENTICAL to
# the unmodified APR.95 solver (AAP 0.7.4 default-safety / instant rollback).
# With "-validate", the modern init/dispatch validation paths are enabled.
# CRITICAL: the NASTRAN_*_VALIDATE toggles emit ONLY to logical unit 3 (the
# per-deck log, mapped via LOGNM below) -- NEVER to stdout (the OFP under
# comparison) -- so enabling validation does NOT perturb the golden-master
# comparison.  The five integration decks are what exercise these paths.
# Guard the $argv[1] read so a zero-argument invocation is safe (no
# "Subscript out of range").
#------------------------------------------------------------------------------
set VALIDATE = 0
if ( $#argv > 0 ) then
   if ( "$argv[1]" == "-validate" ) set VALIDATE = 1
endif
set TOGGLES = ""
if ( $VALIDATE != 0 ) set TOGGLES = "NASTRAN_INIT_VALIDATE=1 NASTRAN_DISPATCH_VALIDATE=1"

#------------------------------------------------------------------------------
# Pre-flight: create $RESULTS (NEVER demoout/) and reset the aggregate log,
# then FAIL FAST with a non-zero exit if any required artifact is absent.
# Each failure is written to BOTH the terminal and the log (via "|& tee -a")
# so it is immediately visible AND greppable by the final FAIL: count.
#------------------------------------------------------------------------------
if ( ! -d $RESULTS ) mkdir -p $RESULTS
if ( -e $RUNLOG ) rm -f $RUNLOG
touch $RUNLOG

if ( ! -x $NASEXEC ) then
   echo "FAIL: missing-solver $NASEXEC" |& tee -a $RUNLOG
   echo "REGRESSION FAILED"
   exit 1
endif
if ( ! -e $NASTLIB ) then
   echo "FAIL: missing-archive $NASTLIB" |& tee -a $RUNLOG
   echo "REGRESSION FAILED"
   exit 1
endif
if ( ! -d $INPDIR ) then
   echo "FAIL: missing-inpdir $INPDIR" |& tee -a $RUNLOG
   echo "REGRESSION FAILED"
   exit 1
endif
if ( ! -d $REFDIR ) then
   echo "FAIL: missing-refdir $REFDIR" |& tee -a $RUNLOG
   echo "REGRESSION FAILED"
   exit 1
endif

#------------------------------------------------------------------------------
# Build the field-by-field comparator regress.exe using the EXACT bin/linknas
# f77 idiom: "f77 -fast -dn -o <exe> <objs> nastlib.a".
#
# COMPARATOR INVOCATION CONTRACT (owned by modern/regress/):
#   regval.f is the PROGRAM (MAIN) entry.  It takes TWO path arguments -- the
#   CANDIDATE output ($out) THEN the GOLDEN master ($ref) -- opens both
#   READ-ONLY, calls SUBROUTINE OUTCOMP to compare them field by field, prints
#   a PASS:/FAIL: verdict to stdout, and EXITS NON-ZERO on mismatch
#   (CALL EXIT(1); CALL EXIT(2) only for an argument-count usage error).  The
#   harness treats the PROCESS EXIT STATUS as the PRIMARY pass/fail signal and
#   ALSO redirects the comparator's stdout into $RUNLOG for the final grep.
#------------------------------------------------------------------------------
echo "Building comparator: f77 $FFLAGS -o $CMPEXE $CMPSRC $NASTLIB" >> $RUNLOG
f77 $FFLAGS -o $CMPEXE $CMPSRC $NASTLIB >>& $RUNLOG
if ( $status != 0 ) then
   echo "FAIL: build comparator (see $RUNLOG)" |& tee -a $RUNLOG
   echo "REGRESSION FAILED"
   exit 1
endif

#------------------------------------------------------------------------------
# Main loop: run every benchmark deck and compare its output to the golden
# master.  With "set nonomatch" above, an empty inp/ yields the literal glob
# as a single element, so the -e guard detects "no decks" (a FAIL: an empty
# regression proves nothing and must NOT report success).
#------------------------------------------------------------------------------
set decks = ( $INPDIR/*.inp )
if ( ! -e "$decks[1]" ) then
   echo "FAIL: no-decks $INPDIR" |& tee -a $RUNLOG
   echo "REGRESSION FAILED"
   exit 1
endif

foreach deck ( $decks )
   set base = $deck:t:r              # tail (strip dir) then root (strip .inp)
   set ref  = $REFDIR/$base.out      # golden master (READ-ONLY)
   set out  = $RESULTS/$base.out     # candidate output (under $RESULTS)
   set log  = $RESULTS/$base.log     # per-deck log == logical unit 3
   set scr  = $RESULTS/scr_$base     # per-deck scratch (solver DIRCTY)

   # A missing golden master is a FAILURE, never a silent skip.
   if ( ! -e $ref ) then
      echo "FAIL: missing-golden $base" >> $RUNLOG
      @ nfail++
      continue
   endif
   @ nrun++

   # Fresh per-deck scratch directory (maps to the solver's DIRCTY).
   if ( -d $scr ) rm -r $scr
   mkdir $scr

   # Run the solver with the EXACT env-variable idiom replicated from the
   # interactive wrapper bin/nastran (lines 522-533), adapted for batch use:
   #   * LOGNM=$log   -> NASTRAN log == logical unit 3, so ALL diagnostics and
   #                     any -validate toggle output land in $log, NOT in $out.
   #   * DIRCTY=$scr  -> per-deck scratch directory.
   #   * RFDIR=$RFDIR -> rigid-format directory.
   #   * DBMEM/OCMEM  -> the same memory sizes under which demoout/ was made.
   #   * stdin  < $deck is the input deck; stdout > $out is the candidate OFP.
   #   * $TOGGLES expands to nothing when unset (no empty-arg error), or
   #     word-splits into two VAR=value tokens for env when -validate is given.
   # DO NOT invoke bin/nastran itself (it is the INTERACTIVE wrapper); this is
   # its non-interactive batch analog -- replicate the env block, call $NASEXEC.
   env NPTPNM=$RESULTS/$base.nptp PLTNM=none DICTNM=$RESULTS/$base.dic PUNCHNM=none \
       FTN11=none FTN12=none DIRCTY=$scr \
       LOGNM=$log OPTPNM=none RFDIR=$RFDIR \
       FTN13=none SOF1=none SOF2=none \
       FTN14=none FTN17=none FTN18=none FTN19=none FTN20=none \
       FTN15=none FTN16=none FTN21=none FTN22=none FTN23=none \
       DBMEM=$DBMEM OCMEM=$OCMEM $TOGGLES \
       $NASEXEC < $deck > $out
   set runstat = $status            # capture IMMEDIATELY ($status is volatile)

   # Remove the scratch dir regardless of outcome (keeps $RESULTS tidy).
   if ( -d $scr ) rm -r $scr

   if ( $runstat != 0 ) then
      echo "FAIL: run $base (solver exit $runstat)" >> $RUNLOG
      @ nfail++
      continue
   endif

   # Compare candidate vs golden.  ALL comparison logic lives in
   # modern/regress/outcomp.f -- the harness does NOT parse output itself:
   #   * skip volatile lines: the per-page header
   #     "1 ... / 95 SUN SOLARIS NASTRAN / MAY 17, 95 / PAGE n",
   #     " DATE: ...", " END TIME: ...", " TOTAL WALL CLOCK TIME ... SEC.",
   #     and the column-1 carriage-control characters;
   #   * 6-significant-figure RELATIVE tolerance on floating-point fields;
   #   * BITWISE identity on integer fields.
   # The harness keys ONLY on the comparator's process exit status
   # (0 => match, non-zero => mismatch).
   $CMPEXE $out $ref >>& $RUNLOG
   set cmpstat = $status
   if ( $cmpstat == 0 ) then
      echo "PASS: $base" >> $RUNLOG
      @ npass++
   else
      echo "FAIL: $base" >> $RUNLOG
      @ nfail++
   endif
end

#------------------------------------------------------------------------------
# Aggregate, report, and exit.  "grep -c" counts FAIL: lines; in csh backticks
# it never aborts on a no-match (it yields "0"), so this is safe even with zero
# failures.  csh has NO "$(...)" -- command substitution uses backticks.
#------------------------------------------------------------------------------
set hits = `grep -c "FAIL:" $RUNLOG`

echo ""
echo "================ REGRESSION SUMMARY ================"
echo "  decks run         : $nrun"
echo "  PASS              : $npass"
echo "  FAIL              : $nfail"
echo "  FAIL: hits in log : $hits"
echo "  log               : $RUNLOG"
echo "==================================================="

# Echo the offending lines for quick triage (harmless when none match).
grep -i "FAIL:" $RUNLOG

# THE binding contract: exit non-zero if EITHER the greppable FAIL: count is
# positive OR the running nfail counter is positive; exit 0 ONLY when BOTH are
# zero (every deck PASSed).
if ( $hits > 0 || $nfail > 0 ) then
   echo "REGRESSION FAILED"
   exit 1
endif
echo "ALL REGRESSION TESTS PASSED"
exit 0
