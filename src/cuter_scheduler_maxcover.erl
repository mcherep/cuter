%% -*- erlang-indent-level: 2 -*-
%%------------------------------------------------------------------------------
-module(cuter_scheduler_maxcover).
-behaviour(gen_server).

-export([ %% external API
          start/4, stop/1,
          request_input/1, store_execution/3, request_operation/1, solver_reply/2,
          %% gen_server callbacks
          init/1, terminate/2, code_change/3, handle_info/2, handle_call/3, handle_cast/2]).

-include("include/cuter_macros.hrl").

-export_type([handle/0, operationId/0]).

-type visited() :: boolean().
-type operationId() :: integer().
-type item() :: {visited(), operationId(), cuter_cerl:tagID(), handle()}.
-type inputs_queue_item() :: {operationId(), cuter:input()}.
-type inputs_queue() :: queue:queue(inputs_queue_item()).
-type handle() :: nonempty_string().

-record(info, {
  dataDir   :: file:filename(),
  mappings  :: [cuter_symbolic:mapping()],
  traceFile :: file:filename()
}).
-type execution_info() :: #info{}.
-type execution_info_tab() :: dict:dict(handle(), execution_info()).

-type from()  :: {pid(), reference()}.

%% Server's state
%% ---------------
%%
%% codeServer :: pid()
%%   The main CodeServer.
%% depth :: cuter:depth()
%%   Maximum number of branches to log per process.
%% erroneous :: cuter:erroneous_inputs()
%%   A list of all the inputs that led to a runtime error.
%% firstOperation :: dict:dict(handle(), operationId())
%%   The first operation that will be considered to be reversed
%%   for each concolic execution.
%% infoTab :: execution_info_tab()
%%   The information of each concolic execution.
%% inputsQueue :: inputs_queue()
%%   A queue for all the generated inputs that wait to be executed.
%%   Used for the seed inputs (for now).
%% python :: file:filename()
%%   The path to the python script that will invoke the solver.
%% running :: dict:dict(handle(), cuter:input())
%%   The currently running concolic executions and their inputs.
%%  tagsQueue :: cuter_minheap:minheap()
%%   The heap with all the constraints/tags that await to be reversed.
%%  visitedTags :: cuter_cerl:visited_tags()
%%   The visited tags of the concolic executions.

-record(st, {
  codeServer      :: pid(),
  depth           :: cuter:depth(),
  erroneous       :: cuter:erroneous_inputs(),
  firstOperation  :: dict:dict(handle(), operationId()),
  infoTab         :: execution_info_tab(),
  inputsQueue     :: inputs_queue(),
  python          :: file:filename(),
  running         :: dict:dict(handle(), cuter:input()),
  solving         :: dict:dict(pid(), operationId()),
  tagsQueue       :: cuter_minheap:minheap(),
  visitedTags     :: cuter_cerl:visited_tags()}).
-type state() :: #st{}.

%% ----------------------------------------------------------------------------
%% External API
%% ----------------------------------------------------------------------------

%% Starts the Scheduler.
-spec start(file:filename(), integer(), cuter:input(), pid()) -> pid().
start(Python, Depth, SeedInput, CodeServer) ->
  case gen_server:start_link(?MODULE, [Python, Depth, SeedInput, CodeServer], []) of
    {ok, Scheduler} -> Scheduler;
    {error, R} -> exit({scheduler_start, R})
  end.

%% Stops the Scheduler.
-spec stop(pid()) -> cuter:erroneous_inputs().
stop(Scheduler) ->
  gen_server:call(Scheduler, stop).

%% Requests a new input to execute.
-spec request_input(pid()) -> {handle(), cuter:input()} | empty | try_later.
request_input(Scheduler) ->
  gen_server:call(Scheduler, request_input, infinity).

%% Stores the information of an execution.
-spec store_execution(pid(), handle(), cuter_analyzer:info()) -> ok.
store_execution(Scheduler, Handle, Info) ->
  gen_server:call(Scheduler, {store_execution, Handle, Info}, infinity).

-spec request_operation(pid()) -> cuter_solver:solver_input() | try_later.
request_operation(Scheduler) ->
  gen_server:call(Scheduler, request_operation, infinity).

-spec solver_reply(pid(), cuter_solver:solver_result()) -> ok.
solver_reply(Scheduler, Result) ->
  gen_server:call(Scheduler, {solver_reply, Result}, infinity).

%% ----------------------------------------------------------------------------
%% gen_server callbacks (Server Implementation)
%% ----------------------------------------------------------------------------

%% init/1
-type init_arg() :: [file:filename() | integer() | cuter:input() | pid(), ...].
-spec init(init_arg()) -> {ok, state()}.
init([Python, Depth, SeedInput, CodeServer]) ->
  _ = set_execution_counter(0),
  TagsQueue = cuter_minheap:new(fun erlang:'<'/2),
  InpQueue = queue:in({1, SeedInput}, queue:new()),
  {ok, #st{ codeServer = CodeServer
          , infoTab = dict:new()
          , python = Python
          , depth = Depth
          , visitedTags = gb_sets:new()
          , running = dict:new()
          , firstOperation = dict:new()
          , erroneous = []
          , inputsQueue = InpQueue
          , solving = dict:new()
          , tagsQueue = TagsQueue}}.

%% terminate/2
-spec terminate(any(), state()) -> ok.
terminate(_Reason, #st{tagsQueue = TQ}) ->
  cuter_minheap:delete(TQ),
  %% TODO clear dirs
  ok.

%% code_change/3
-spec code_change(any(), state(), any()) -> {ok, state()}.
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.  % No change planned.

%% handle_info/2
-spec handle_info(any(), state()) -> {noreply, state()}.
handle_info(_Msg, State) ->
  {noreply, State}.

%% handle_call/3
-spec handle_call(request_input, from(), state()) -> {reply, (empty | try_later | {handle(), cuter:input()}), state()}
               ; ({store_execution, handle(), cuter_analyzer:info()}, from(), state()) -> {reply, ok, state()}
               ; ({solver_reply, cuter_solver:solver_result()}, from(), state()) -> {reply, ok, state()}
               ; (request_operation, from(), state()) -> {reply, cuter_solver:solver_input() | try_later, state()}
               ; (stop, from(), state()) -> {stop, normal, cuter:erroneous_inputs(), state()}.

%% Ask for a new input to execute.
handle_call(request_input, _From, S=#st{running = Running, firstOperation = FirstOperation, inputsQueue = InputsQueue, tagsQueue = TagsQueue,
                                        solving = Solving}) ->
  %% Check the queue for inputs that wait to be executed.
  case queue:out(InputsQueue) of
    %% Empty queue.
    {empty, InputsQueue} ->
      case dict:is_empty(Running) andalso cuter_minheap:is_empty(TagsQueue) andalso dict:is_empty(Solving) of
        true  -> {reply, empty, S};     % There are no active executions, so the queues will remain empty.
        false -> {reply, try_later, S}  % There are active executions, so the queues may later have some entries.
      end;
    %% Retrieved an input.
    {{value, {OperationAllowed, Input}}, RemainingQueue} ->
      Handle = fresh_execution_handle(),
      {reply, {Handle, Input}, S#st{ running = dict:store(Handle, Input, Running)
                                   , firstOperation = dict:store(Handle, OperationAllowed, FirstOperation)
                                   , inputsQueue = RemainingQueue}}
  end;

%% Store the information of a concolic execution.
handle_call({store_execution, Handle, Info}, _From, S=#st{tagsQueue = TQ, infoTab = AllInfo, visitedTags = Vs, depth = Depth,
                                                          running = Rn, firstOperation = FOp, erroneous = Err, codeServer = CServer}) ->
  %% Generate the information of the execution.
  I = #info{ dataDir = cuter_analyzer:dir_of_info(Info)
           , mappings = cuter_analyzer:mappings_of_info(Info)
           , traceFile = cuter_analyzer:traceFile_of_info(Info)},
  %% Get the input & update the erroneous inputs, if necessary.
  Input = dict:fetch(Handle, Rn),
  NErr = update_erroneous(cuter_analyzer:runtimeError_of_info(Info), Input, Err),
  %% Update the visited tags.
  Visited = gb_sets:union(Vs, cuter_codeserver:get_visited_tags(CServer)),
  %% Update the queue.
  N = dict:fetch(Handle, FOp),
  Rvs = cuter_analyzer:reversible_of_info(Info),
  Items = generate_queue_items(Rvs, Handle, Visited, N, Depth),
  lists:foreach(fun(Item) -> cuter_minheap:insert(Item, TQ) end, Items),
  {reply, ok, S#st{ infoTab = dict:store(Handle, I, AllInfo)
                  , visitedTags = Visited
                  , running = dict:erase(Handle, Rn)  % Remove the handle from the running set
                  , firstOperation = dict:erase(Handle, FOp)
                  , erroneous = NErr}};

%% Report the result of an SMT solving.
handle_call({solver_reply, Reply}, {Who, _Ref}, S=#st{solving = Solving, inputsQueue = InputsQueue}) ->
  case Reply of
    %% The model could not be satisfied.
    error ->
      {reply, ok, S#st{solving = dict:erase(Who, Solving)}};
    %% The modal was satisfied and a new input was generated.
    {ok, Input} ->
      OperationId = dict:fetch(Who, Solving),
      {reply, ok, S#st{ inputsQueue = queue:in({OperationId+1, Input}, InputsQueue)  % Queue the input
                      , solving = dict:erase(Who, Solving)}}
  end;

%% Request an operation to reverse.
handle_call(request_operation, {Who, _Ref}, S=#st{tagsQueue = TagsQueue, infoTab = Info, visitedTags = Visited, python = Python, solving = Solving}) ->
  case locate_next_reversible(TagsQueue, Visited) of
    %% The queue is empty.
    empty -> {reply, try_later, S};
    %% Located an operation to reverse.
    {ok, OperationId, Handle} ->
      ExecInfo = dict:fetch(Handle, Info),
      Reply = {Python, ExecInfo#info.mappings, ExecInfo#info.traceFile, OperationId},
      {reply, Reply, S#st{solving = dict:store(Who, OperationId, Solving)}}
  end;

%% Stops the server.
handle_call(stop, _From, S=#st{erroneous = Err}) ->
  {stop, normal, lists:reverse(Err), S}.

%% handle_cast/2
-spec handle_cast(any(), state()) -> {noreply, state()}.
handle_cast(_Msg, State) ->
  {noreply, State}.

%% ----------------------------------------------------------------------------
%% Functions for tags
%% ----------------------------------------------------------------------------

%% Each item in the heap is in the form {Visited, OperationId, TagId, Handle}
%% where Visited     : if the tag has already been visited during an execution
%%       OperationId : the cardinality of the constraint in the path vertex
%%       TagId       : the Id of the tag that will be visited
%%       Handle      : the unique identifier of the concolic execution

-spec locate_next_reversible(cuter_minheap:minheap(), cuter_cerl:visited_tags()) -> {ok, integer(), handle()} | empty.
locate_next_reversible(Queue, Visited) ->
  locate_next_reversible(Queue, Visited, cuter_minheap:heap_size(Queue)).

-spec locate_next_reversible(cuter_minheap:minheap(), cuter_cerl:visited_tags(), integer()) -> {ok, integer(), handle()} | empty.
locate_next_reversible(Queue, Visited, M) ->
  case cuter_minheap:take_min(Queue) of
    {error, empty_heap} -> empty;
    {true, N, _TagID, Handle} -> {ok, N, Handle};
    {false, N, TagID, Handle} ->
      %% Check if the tag is actually visited
      case gb_sets:is_element(TagID, Visited) of
        %% If it's not visited, then return it.
        false -> {ok, N, Handle};
        %% else, put it back in the heap.
        true  ->
          case M of
            0 -> {ok, N, Handle};  % Have seen all the entries at least once (possible redundant)
            _ ->
              cuter_minheap:insert({true, N, TagID, Handle}, Queue),
              locate_next_reversible(Queue, Visited, M-1)
          end
      end
  end.

-spec generate_queue_items(cuter_analyzer:reversible_with_tags(), handle(), cuter_cerl:visited_tags(), operationId(), cuter:depth()) -> [item()].
generate_queue_items(Rvs, Handle, Visited, N, Depth) ->
  generate_queue_items(Rvs, Handle, Visited, N, Depth, []).

-spec generate_queue_items(cuter_analyzer:reversible_with_tags(), handle(), cuter_cerl:visited_tags(), operationId(), cuter:depth(), [item()]) -> [item()].
generate_queue_items([], _Handle, _Visited, _N, _Depth, Acc) ->
  lists:reverse(Acc);
generate_queue_items([R|Rs], Handle, Visited, N, Depth, Acc) ->
  case maybe_item(R, Handle, Visited, N) of
    false -> generate_queue_items(Rs, Handle, Visited, N, Depth, Acc);
    {ok, Item} -> generate_queue_items(Rs, Handle, Visited, N, Depth, [Item|Acc])
  end.

-spec maybe_item(cuter_analyzer:reversible_with_tag(), handle(), cuter_cerl:visited_tags(), operationId()) -> {ok, item()} | false.
maybe_item({Id, TagID}, Handle, Visited, N) ->
  case Id < N of
    true  -> false;
    false -> {ok, {gb_sets:is_element(TagID, Visited), Id, TagID, Handle}}
  end.

%% ----------------------------------------------------------------------------
%% Generate handles for executions
%% ----------------------------------------------------------------------------

-spec set_execution_counter(integer()) -> integer() | undefined.
set_execution_counter(N) ->
  put(?EXECUTION_COUNTER_PREFIX, N).

-spec fresh_execution_handle() -> handle().
fresh_execution_handle() ->
  N = get(?EXECUTION_COUNTER_PREFIX) + 1,
  put(?EXECUTION_COUNTER_PREFIX, N),
  "exec" ++ integer_to_list(N).

%% ----------------------------------------------------------------------------
%% Erroneous inputs
%% ----------------------------------------------------------------------------

-spec update_erroneous(boolean(), cuter:input(), cuter:erroneous_inputs()) -> cuter:erroneous_inputs().
update_erroneous(false, _Input, Erroneous) -> Erroneous;
update_erroneous(true, Input, Erroneous) -> [Input | Erroneous].
