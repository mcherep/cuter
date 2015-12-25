#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys, getopt, os
import subprocess as subp

def main(argv):
  shortOpts = "d:p:s:vrw:cl"
  longOpts = [
    "depth=", "pollers=", "solvers=", "whitelist=",
    "verbose", "fully-verbose", "disable-pmatch", "recompile",
    "coverage", "run-libs", "help"]
  try:
    optlist, remainder = getopt.gnu_getopt(argv, shortOpts, longOpts)
    # Ensure that there are enough arguments.
    if len(remainder) < 3:
      usage()
      sys.exit(1)
    # Export ERL_LIBS.
    erl_libs = os.getenv("ERL_LIBS")
    if erl_libs != None:
      os.environ["ERL_LIBS"] = getDirectory() + ":" + erl_libs
    else:
      os.environ["ERL_LIBS"] = getDirectory()
    # Read the arguments.
    module, fun, args = remainder[0], remainder[1], remainder[2]
    # Set the default options.
    depth = 25
    pollers = 1
    solvers = 1
    whitelist = None
    recompileModule = False
    runLibs = False
    # Parse the given options.
    runOpts = []
    for opt, arg in optlist:
      if opt == "-d":
        depth = int(arg)
      elif opt in ("-p", "--pollers"):
        pollers = int(arg)
      elif opt in ("-s", "--solvers"):
        solvers = int(arg)
      elif opt in ("-w", "--whitelist"):
        whitelist = arg
      elif opt in ("-v", "--verbose"):
        runOpts.append("verbose_execution_info")
      elif opt in ("-c", "--coverage"):
        runOpts.append("coverage")
      elif opt in ("-r", "--recompile"):
        recompileModule = True
      elif opt in ("-l", "--run-libs"):
        runLibs = True
      elif opt == "--fully-verbose":
        runOpts.append("fully_verbose_execution_info")
      elif opt == "--disable-pmatch":
        runOpts.append("disable_pmatch")
      elif opt == "--help":
        usage()
        sys.exit(0)

    runOpts.append("{{number_of_pollers, {}}}".format(pollers))
    runOpts.append("{{number_of_solvers, {}}}".format(solvers))
    if whitelist != None:
      runOpts.append("{{whitelist, '{}'}}".format(whitelist))

    cmd = "erl -noshell -eval \"cuter:run({}, {}, {}, {}, [{}])\" -s init stop".format(
      module, fun, args, depth, ",".join(runOpts))
    if runLibs:
      sys.exit(runCuter(cmd))
    else:
      compiledStatus, log = compileModule(module, recompileModule)
      if compiledStatus == 0:
        sys.exit(runCuter(cmd))
      else:
        print log
        sys.exit(1)
  except Exception as e:
    print "Fatal Error:", e
    sys.exit(1)

def getDirectory():
  return os.path.dirname(os.path.realpath(__file__))

def compileModule(module, again = False):
  exists = os.path.isfile(module + ".beam")
  if again or not exists:
    erl = module + ".erl"
    if not os.path.isfile(erl):
      return 1, "Cannot locate {} ...  ".format(erl)
    print "Compiling {} ...".format(erl),
    p = subp.Popen(["erlc", "+debug_info", erl], stdout=subp.PIPE, stderr=subp.PIPE)
    out, err = p.communicate()
    print "OK" if p.returncode == 0 else "ERROR"
    return p.returncode, "\n".join([out.strip(), err.strip()]).strip()
  return 0, ""

def runCuter(cmd):
  return subp.call(cmd, shell=True)

def usage():
  print "Usage: cuter M F '[A1,...,An]' [ options ]"
  print "PARAMETERS"
  print "	M				The module."
  print "	F				The function."
  print "	'[A1,...,An]'			The arguments of the MFA given as a list."
  print "OPTIONS"
  print "	-d D, --depth=D			The depth limit D of the search."
  print "	-p N, --pollers=N		Use N pollers."
  print "	-s N, --solvers=N		Use N solvers."
  print "	-w File, --whitelist=File	Path of the file with the whitelisted MFAs."
  print "					Write one line ending with a dor for each MFA."
  print "	-v, --verbose			Request a verbose execution."
  print "	-r, --recompile			Recompile the module under test."
  print "	-c, --coverage			Calculate the coverage achieved."
  print "	-l, --run-libs			The tested MFA is already loaded, so do not look"
  print "					for the .erl file in the current directory."
  print "	--fully-verbose			Request a fully verbose execution (for debugging)."
  print "	--disable-pmatch		Disable the pattern matching compilation."
  print "	--help				Display this information."

if __name__ == "__main__":
  main(sys.argv[1:])
