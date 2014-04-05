%% -*- erlang-indent-level: 2 -*-
%%------------------------------------------------------------------------------
-module(cuter_mock).

-export([simulate_behaviour/3]).

-include("cuter_macros.hrl").

%% BIFs I found during testing, may be more out there
%% Returns bif if an MFA is an Erlang BIF
-spec simulate_behaviour(module(), atom(), non_neg_integer()) -> bif | {ok, mfa()}.

%% Module erlang
simulate_behaviour(erlang, abs, 1)->
  {ok, {cuter_erlang, abs, 1}};
simulate_behaviour(erlang, element, 2)->
  {ok, {cuter_erlang, element, 2}};
simulate_behaviour(erlang, length, 1)->
  {ok, {cuter_erlang, length, 1}};
simulate_behaviour(erlang, make_tuple, 2)->
  {ok, {cuter_erlang, make_tuple, 2}};
simulate_behaviour(erlang, max, 2)->
  {ok, {cuter_erlang, max, 2}};
simulate_behaviour(erlang, min, 2)->
  {ok, {cuter_erlang, min, 2}};

simulate_behaviour(erlang, _F, _A) -> bif;
%% Module beam_asm 
%% XXX Not BIF but with unsupported primops
simulate_behaviour(beam_asm, _F, _A) -> bif;
%% Module beam_lib
%% XXX Not BIF but with unsupported primops
simulate_behaviour(beam_lib, _F, _A) -> bif;
%% Module binary
simulate_behaviour(binary, compile_pattern, 1) -> bif;
simulate_behaviour(binary, match, 2) -> bif;
simulate_behaviour(binary, match, 3) -> bif;
simulate_behaviour(binary, matches, 2) -> bif;
simulate_behaviour(binary, matches, 3) -> bif;
simulate_behaviour(binary, longest_common_prefix, 1) -> bif;
simulate_behaviour(binary, longest_common_suffix, 1) -> bif;
simulate_behaviour(binary, first, 1) -> bif;
simulate_behaviour(binary, last, 1) -> bif;
simulate_behaviour(binary, at, 2) -> bif;
simulate_behaviour(binary, part, 2) -> bif;
simulate_behaviour(binary, part, 3) -> bif;
simulate_behaviour(binary, bin_to_list, 1) -> bif;
simulate_behaviour(binary, bin_to_list, 2) -> bif;
simulate_behaviour(binary, bin_to_list, 3) -> bif;
simulate_behaviour(binary, list_to_bin, 1) -> bif;
simulate_behaviour(binary, copy, 1) -> bif;
simulate_behaviour(binary, copy, 2) -> bif;
simulate_behaviour(binary, referenced_byte_size, 1) -> bif;
simulate_behaviour(binary, decode_unsigned, 1) -> bif;
simulate_behaviour(binary, decode_unsigned, 2) -> bif;
%% Module epp
%% XXX Not BIF but with unsupported primops
simulate_behaviour(epp, _F, _A) -> bif;
%% Module ets
simulate_behaviour(ets, all, 0) -> bif;
simulate_behaviour(ets, new, 2) -> bif;
simulate_behaviour(ets, delete, 1) -> bif;
simulate_behaviour(ets, delete, 2) -> bif;
simulate_behaviour(ets, first, 1) -> bif;
simulate_behaviour(ets, info, 1) -> bif;
simulate_behaviour(ets, info, 2) -> bif;
simulate_behaviour(ets, safe_fixtable, 2) -> bif;
simulate_behaviour(ets, lookup, 2) -> bif;
simulate_behaviour(ets, lookup_element, 3) -> bif;
simulate_behaviour(ets, insert, 2) -> bif;
simulate_behaviour(ets, is_compiles_ms, 1) -> bif;
simulate_behaviour(ets, last, 1) -> bif;
simulate_behaviour(ets, member, 2) -> bif;
simulate_behaviour(ets, next, 2) -> bif;
simulate_behaviour(ets, prev, 2) -> bif;
simulate_behaviour(ets, rename, 2) -> bif;
simulate_behaviour(ets, slot, 2) -> bif;
simulate_behaviour(ets, match, 1) -> bif;
simulate_behaviour(ets, match, 2) -> bif;
simulate_behaviour(ets, match, 3) -> bif;
simulate_behaviour(ets, match_object, 1) -> bif;
simulate_behaviour(ets, match_object, 2) -> bif;
simulate_behaviour(ets, match_object, 3) -> bif;
simulate_behaviour(ets, match_spec_compile, 1) -> bif;
simulate_behaviour(ets, match_spec_run_r, 3) -> bif;
simulate_behaviour(ets, select, 1) -> bif;
simulate_behaviour(ets, select, 2) -> bif;
simulate_behaviour(ets, select, 3) -> bif;
simulate_behaviour(ets, select_count, 2) -> bif;
simulate_behaviour(ets, select_reverse, 1) -> bif;
simulate_behaviour(ets, select_reverse, 2) -> bif;
simulate_behaviour(ets, select_reverse, 3) -> bif;
simulate_behaviour(ets, select_delete, 2) -> bif;
simulate_behaviour(ets, setopts, 2) -> bif;
simulate_behaviour(ets, update_counter, 3) -> bif;
simulate_behaviour(ets, update_element, 3) -> bif;
%% Module file
simulate_behaviour(file, native_name_encoding, 0) -> bif;
%% Module lists
simulate_behaviour(lists, member, 2)  -> bif;
simulate_behaviour(lists, reverse, 2) -> bif;
simulate_behaviour(lists, keymember, 3) -> bif;
simulate_behaviour(lists, keysearch, 3) -> bif;
simulate_behaviour(lists, keyfind, 3) -> bif;
%% Module math
simulate_behaviour(math, pi, 0) -> {ok, {math, pi, 0}};
simulate_behaviour(math, _F, _A) -> bif;
%% Module net_kernel
simulate_behaviour(net_kernel, dflag_unicode_io, 1) -> bif;
%% Module os
simulate_behaviour(os, getenv, 0) -> bif;
simulate_behaviour(os, getenv, 1) -> bif;
simulate_behaviour(os, getpid, 0) -> bif;
simulate_behaviour(os, putenv, 2) -> bif;
simulate_behaviour(os, timestamp, 0) -> bif;
%% Rest MFAs are not BIFs
simulate_behaviour(M, F, A) -> {ok, {M, F, A}}.