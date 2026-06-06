#!/bin/csh
#=======================================================================
# test/run_units.csh
#
# Top-level UNIT-test runner for the NASTRAN-95 modernization
# regression-safety infrastructure (AAP 0.2.1, 0.3.1, 0.7.5).
#
# WHAT IT DOES
#   Builds and runs every unit-test driver across the four modernization
#   unit suites -- test/init, test/state, test/dispatch, test/diag --
#   captures each driver's "PASS: <name>" / "FAIL: <name>" output, greps
#   the aggregated log for the literal token "FAIL:", and EXITS NON-ZERO
#   if ANY driver fails OR if ANY build/link/run step fails.  It exits 0
#   ONLY when every driver was built, run, and reported PASS.
#
#   This is the unit-level counterpart of test/regress/run_all.csh (the
#   integration / golden-master harness).  Together they form the
#   regression-safety net proving the modern/ abstraction layer preserves
#   exact APR.95 solver behavior.
#
# DELIVERABLE -- NOT EXECUTED BY BLITZY
#   This script is a deliverable to be run later in the developer's
#   Solaris environment (csh + Sun f77).  It is NOT executed during the
#   refactor: it references f77 and bin/nastlib.a, which exist only in
#   the Solaris build environment after bin/linknas has run.
#
# CONVENTIONS (patterned on bin/nastran and bin/linknas)
#   * "#!/bin/csh" shebang and "unalias rm" mirror bin/nastran.
#   * Each driver is a standalone PROGRAM linked individually against
#     bin/nastlib.a with the EXACT compiler flags "-fast -dn" taken from
#     bin/linknas (f77 -fast -dn -o <exe> <objs> nastlib.a).  Drivers are
#     NOT co-linked into nastrn.exe -- each becomes its own test exe.
#   * Drivers write PASS:/FAIL: to the log unit (unit 3 / LOUT).  Because
#     the drivers link nastlib.a, they honor the same unit-3 wiring the
#     solver uses; as in bin/nastran (LOGNM=$ft03 -> unit 3) this runner
#     sets LOGNM so a standalone driver's unit-3 output is captured to a
#     file, and it ALSO captures stdout+stderr -- so PASS:/FAIL: is
#     collected wherever the suite's driver convention places it.  The
#     exact unit-3 wiring is each suite child agent's choice; the runner
#     captures both sinks to remain robust and reusable.
#
# USAGE
#   ./test/run_units.csh             (run from the repository root, or)
#   cd test ; ./run_units.csh        (run from the test/ directory)
#   setenv NASTROOT /path/to/nast95  (optional: override the repo root)
#
# EXIT STATUS
#   0   every expected suite was present with >=1 driver, and ALL
#       drivers built, ran, and reported PASS (>=1 driver discovered)
#   1   one or more drivers reported FAIL; a build/run step failed; an
#       expected suite directory was missing; a suite contained no *.f
#       drivers; or no drivers were discovered at all
#=======================================================================

unalias rm

# Let an unmatched "*.f" glob expand to the literal pattern instead of
# aborting with csh "No match." -- the empty-suite guard below then uses
# a -e test on the first element to detect a suite with no drivers.
set nonomatch

#-----------------------------------------------------------------------
# Phase A -- configuration (override-friendly; reusable across phases)
#-----------------------------------------------------------------------

# Repository root.  Honor a pre-set environment value if present;
# otherwise derive it from this script's own location.  This script
# lives at <root>/test/run_units.csh, so the directory holding it is
# <root>/test and its parent is the repository root.
if ( $?NASTROOT == 0 ) then
   set scriptdir = $0:h
   if ( "$scriptdir" == "$0" ) then
      # $0 carried no directory component (invoked as a bare name from
      # within test/); the repository root is the parent of the cwd.
      set NASTROOT = ..
   else
      set NASTROOT = $scriptdir/..
   endif
endif

set NASTLIB = $NASTROOT/bin/nastlib.a    # archive each driver links against
set FFLAGS  = "-fast -dn"                 # EXACT flags from bin/linknas
set TESTDIR = $NASTROOT/test
set SUITES  = ( init state dispatch diag )  # four unit suites, csh word list

# Work / results area for per-driver executables, per-driver logs, and
# the aggregated run log that the final FAIL: grep is applied to.
set RESULTS = $TESTDIR/results
if ( ! -d $RESULTS ) then
   mkdir $RESULTS
endif

# Failure accumulator for build/run errors (driver-reported FAIL: lines
# are detected separately by the Phase C grep).  Summary counters.
@ nfail  = 0
@ ndrv   = 0
@ nbuilt = 0
@ nrun   = 0

# Aggregated log.  Truncate any previous run, then write a header so the
# file always exists before the Phase C grep is applied.
set RUNLOG = $RESULTS/run_units.log
if ( -e $RUNLOG ) then
   rm $RUNLOG
endif
echo "=== NASTRAN-95 modernization unit-test run ==="  >  $RUNLOG
echo "NASTROOT = $NASTROOT"                             >> $RUNLOG
echo "NASTLIB  = $NASTLIB"                              >> $RUNLOG
echo "FFLAGS   = $FFLAGS"                               >> $RUNLOG
echo "suites   = $SUITES"                               >> $RUNLOG
echo ""                                                 >> $RUNLOG

echo "NASTRAN-95 modernization unit-test runner"
echo "  repository root : $NASTROOT"
echo "  test archive    : $NASTLIB"
echo "  run log         : $RUNLOG"
echo ""

# A missing archive is not fatal at config time (a developer might build
# drivers differently), but it almost certainly means the link step will
# fail, so record a clear NOTICE for diagnosis.
if ( ! -e $NASTLIB ) then
   echo "NOTICE: archive $NASTLIB not found - driver links will likely fail" >> $RUNLOG
   echo "NOTICE: archive $NASTLIB not found - driver links will likely fail"
endif

#-----------------------------------------------------------------------
# Phase B -- per-suite build & run
#-----------------------------------------------------------------------
foreach suite ( $SUITES )

   set suitedir = $TESTDIR/$suite
   echo "---- suite: $suite ($suitedir) ----" >> $RUNLOG

   # Guard: an EXPECTED suite directory is absent (e.g. a partial /
   # phased checkout).  A missing expected suite is a FAILURE for final
   # validation -- emit a FAIL: token AND count it so the run exits
   # non-zero; never silently pass (Binding Rule R14 / AAP 0.7.5).
   if ( ! -d $suitedir ) then
      echo "FAIL: suite directory $suitedir not found" >> $RUNLOG
      echo "FAIL: suite directory $suitedir not found"
      @ nfail++
      continue
   endif

   # Discover drivers by glob (never hardcode names -- keeps the runner
   # reusable across future modernization phases).  With nonomatch an
   # empty suite yields the literal pattern as the single list element,
   # so a -e test on the first element detects "no real .f drivers".
   # An expected suite with no drivers is a FAILURE (Binding Rule R14):
   # emit a FAIL: token AND count it so the run exits non-zero.
   set drivers = ( $suitedir/*.f )
   if ( ! -e "$drivers[1]" ) then
      echo "FAIL: no *.f unit drivers in $suitedir" >> $RUNLOG
      echo "FAIL: no *.f unit drivers in $suitedir"
      @ nfail++
      continue
   endif

   foreach src ( $drivers )
      @ ndrv++
      set base = $src:t:r                        # tail without .f extension
      set exe  = $RESULTS/${suite}_${base}.exe
      set dlog = $RESULTS/${suite}_${base}.log   # LOGNM target (unit 3)
      set dout = $RESULTS/${suite}_${base}.out   # stdout + stderr capture

      # ---- Build: link the standalone driver against nastlib.a using
      #      the exact bin/linknas idiom (f77 -fast -dn ... nastlib.a).
      #      A build/link failure counts as a failure -> non-zero exit. ----
      echo "BUILD $suite/$base : f77 $FFLAGS -o $exe $src $NASTLIB" >> $RUNLOG
      f77 $FFLAGS -o $exe $src $NASTLIB >>& $RUNLOG
      if ( $status != 0 ) then
         echo "FAIL: build $suite/$base" >> $RUNLOG
         echo "FAIL: build $suite/$base"
         @ nfail++
         continue
      endif
      @ nbuilt++

      # ---- Fresh logs: remove any per-driver log/out from a PRIOR run
      #      BEFORE executing.  A driver opens unit 3 with
      #      STATUS='UNKNOWN', which does NOT truncate an existing file,
      #      so a stale record (including a stale FAIL: line) could
      #      otherwise survive into this run and be copied into $RUNLOG.
      #      Removing them here guarantees a clean capture regardless of
      #      whether an individual driver self-truncates ("rm" was
      #      unaliased above so this is non-interactive; -f ignores a
      #      missing file). ----
      rm -f $dlog $dout
      # ---- Run: execute the driver.  As in bin/nastran, map the log
      #      unit (unit 3) to a file via LOGNM, and ALSO capture
      #      stdout+stderr, so PASS:/FAIL: is collected wherever the
      #      driver writes it.  ALSO export TDSREF=<suitedir>/<base>.ref:
      #      a driver that resolves its reference data by environment
      #      (e.g. dispatch/tdsmap) then finds the correct .ref no matter
      #      which directory the runner was launched from (./test or the
      #      repository root).  $suitedir is derived from NASTROOT, so the
      #      path is cwd-independent.  Harmless for drivers that ignore
      #      TDSREF.  Capture $status immediately. ----
      # ---- Per-suite run environment.  The init suite's validator
      #      INITVAL begins with the mandatory guard IF (IDIAG .EQ. 0)
      #      RETURN; without NASTRAN_INIT_VALIDATE=1 (DIAGCTL sets IDIAG
      #      bit 2) that guard early-returns, the init drivers keep their
      #      999999 sentinel, and they correctly report FAIL.  So the
      #      runner MUST enable init validation for the init suite.  It is
      #      scoped to the init suite ONLY -- setting it globally would
      #      change the diag suite's DIAGCTL bitmask expectations (the
      #      diag .ref files encode the bitmask) and spuriously fail them.
      #      (Resolves the "init validation env not set" finding; honors
      #      Binding Rule R14 / AAP 0.7.5.) ----
      #      NOTE (csh status capture): $status MUST be read on the line
      #      immediately AFTER the command, INSIDE each branch.  In csh the
      #      "endif" of an if/else block resets $status to 0, so a single
      #      "set rc = $status" placed AFTER the endif would always capture
      #      0 and silently swallow a non-zero driver exit (a crashed driver
      #      that never wrote a FAIL: token) -- a false PASS that violates
      #      Binding Rule R14 / AAP 0.7.5.  Capturing rc within each branch
      #      preserves the real driver exit status.
      if ( "$suite" == "init" ) then
         env NASTRAN_INIT_VALIDATE=1 LOGNM=$dlog TDSREF=$suitedir/${base}.ref $exe >& $dout
         set rc = $status
      else
         env LOGNM=$dlog TDSREF=$suitedir/${base}.ref $exe >& $dout
         set rc = $status
      endif
      @ nrun++

      if ( -e $dlog ) then
         cat $dlog >> $RUNLOG
      endif
      cat $dout >> $RUNLOG

      if ( $rc != 0 ) then
         echo "FAIL: run $suite/$base (exit $rc)" >> $RUNLOG
         echo "FAIL: run $suite/$base (exit $rc)"
         @ nfail++
      endif
   end
end

# Belt-and-suspenders: if NOT A SINGLE driver was discovered across all
# suites, this run proves nothing and MUST NOT report success.  Count it
# as a failure so the exit status is non-zero (Binding Rule R14).
if ( $ndrv == 0 ) then
   echo "FAIL: no unit drivers discovered in any suite" >> $RUNLOG
   echo "FAIL: no unit drivers discovered in any suite"
   @ nfail++
endif

#-----------------------------------------------------------------------
# Phase C -- aggregate, grep, report, exit
#-----------------------------------------------------------------------
# Count driver-reported results in the aggregated log.  grep -c prints a
# count; in csh backticks it never aborts the script on a no-match (it
# yields "0"), so this is safe even when there are no failures.
set nfg   = `grep -c "FAIL:" $RUNLOG`
set npass = `grep -c "PASS:" $RUNLOG`

echo ""
echo "================ UNIT TEST SUMMARY ================"
echo "  drivers discovered : $ndrv"
echo "  drivers built      : $nbuilt"
echo "  drivers run        : $nrun"
echo "  PASS: lines        : $npass"
echo "  FAIL: lines        : $nfg"
echo "  build/run errors   : $nfail"
echo "  aggregated log     : $RUNLOG"
echo "=================================================="

# Echo the offending lines for quick triage (harmless when none match).
grep -i "FAIL:" $RUNLOG

# THE contract: exit non-zero if ANY FAIL: token was logged (driver
# failures) OR ANY build/run error was counted; exit 0 only otherwise.
if ( $nfg > 0 || $nfail > 0 ) then
   echo ""
   echo "**** UNIT TESTS FAILED ****"
   exit 1
endif

echo ""
echo "**** ALL UNIT TESTS PASSED ****"
exit 0
