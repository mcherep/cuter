.PHONY: clean distclean all

###----------------------------------------------------------------------
### Orientation information
###----------------------------------------------------------------------

TOP  = $(PWD)
SRC  = src
EBIN = ebin
SUITE_SRC = testsuite/src
SUITE_EBIN = testsuite/ebin
ERLC = erlc

###----------------------------------------------------------------------
### Flags
###----------------------------------------------------------------------

WARNS = +warn_exported_vars +warn_unused_import +warn_missing_spec #+warn_untyped_record
ERLC_FLAGS = +debug_info $(WARNS)

SRC_MODULES = \
	bin_lib \
	concolic \
	concolic_cserver \
	concolic_encdec \
	concolic_eval \
	concolic_lib \
	concolic_load \
	concolic_symbolic \
	concolic_tserver \
	coordinator

SUITE_MODULES = \
	bang \
	big \
	demo \
	ehb \
	ets_test \
	genstress \
	mbrot \
	parallel \
	pcmark \
	ran \
	serialmsg \
	timer_wheel

UTEST_MODULES = \
	coordinator_tests

###----------------------------------------------------------------------
### Targets
###----------------------------------------------------------------------

TARGETS = \
	concolic_target \
	utest_target

ERL_DIRS = \
	src \
	utest \
	testsuite/src

vpath %.erl $(ERL_DIRS)

default: $(TARGETS) dialyzer

fast: concolic_target

all: default test

concolic_target: $(SRC_MODULES:%=$(EBIN)/%.beam)

utest_target: $(UTEST_MODULES:%=$(EBIN)/%.beam) suite

suite: $(SUITE_MODULES:%=$(SUITE_EBIN)/%.beam)

$(EBIN)/bin_lib.beam: $(SRC)/bin_lib.erl
	$(ERLC) $(ERLC_FLAGS) -o $(EBIN) $<

$(EBIN)/%.beam: %.erl
	$(ERLC) +native $(ERLC_FLAGS) -o $(EBIN) $<

$(SUITE_EBIN)/%.beam : %.erl
	$(ERLC) -o $(SUITE_EBIN) $<

test: $(TARGETS)
	@(./runtests.rb)

dialyzer: $(TARGETS)
	dialyzer -n -Wunmatched_returns $(EBIN)/*.beam

clean:
	$(RM) $(EBIN)/*.beam

distclean: clean
	$(RM) $(SUITE_EBIN)/*.beam

