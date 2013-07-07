%% -*- erlang-indent-level: 2 -*-
%%------------------------------------------------------------------------------

%%====================================================================
%% Prefixes
%%====================================================================

%% concolic_symbolic
-define(SYMBOLIC_PREFIX, '__s').

%% concolic_encdec, concolic_eval, concolic_tserver
-define(DEPTH_PREFIX, '__conc_depth').

%% concolic_json
-define(UNBOUND_VAR, '__any').

%% concolic_eval
-define(FUNCTION_PREFIX, '__func').
-define(CONCOLIC_PREFIX_MSG, '__concm').
-define(CONCOLIC_PREFIX_PDICT, '__concp').

%%====================================================================
%% Flags
%%====================================================================

%% concolic_encdec
-define(LOGGING_FLAG, ok).  %% Enables logging

%% concolic_analyzer
%-define(PRINT_TRACE, ok).  %% Pretty Prints all traces
-define(DELETE_TRACE, ok).  %% Deletes execution traces

%% coordinator
%-define(PRINT_ANALYSIS, ok). %% Prints an execution analysis