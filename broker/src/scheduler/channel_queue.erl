-module(channel_queue).
-export([start_link/1, enqueue/1, dispatch/1]).

-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-define(QUEUE(ChannelId), {global, {channel, ChannelId}}).
-include("db.hrl").

-record(state, {self, active = true, channel, current_calls = 0, max_calls, queued_calls}).

start_link(Channel = #channel{id = Id}) ->
  gen_server:start_link(?QUEUE(Id), ?MODULE, Channel, []).

%% Enqueue a new ready call. The queue will immediatelly dispatch to broker unless it's busy
enqueue(QueuedCall = #queued_call{channel_id = ChannelId}) ->
  gen_server:cast(?QUEUE(ChannelId), {enqueue, QueuedCall}).

%% Notify the queue that it can now dispatch ready calls to the broker
dispatch(ChannelId) ->
  gen_server:cast(?QUEUE(ChannelId), dispatch).

%% @private
init(Channel) ->
  {ok, #state{self = ?QUEUE(Channel#channel.id), channel = Channel, max_calls = Channel:limit(), queued_calls = queue:new()}}.

%% @private
handle_call(_Request, _From, State) ->
  {reply, {error, unknown_call}, State}.

%% @private
handle_cast({enqueue, QueuedCall}, State = #state{queued_calls = Queue}) ->
  Queue2 = queue:in(QueuedCall, Queue),
  {noreply, do_dispatch(State#state{queued_calls = Queue2})};

handle_cast(dispatch, State) ->
  {noreply, do_dispatch(State)};

handle_cast(_Msg, State) ->
  {noreply, State}.

%% @private
handle_info(_Info, State) ->
  {noreply, State}.

%% @private
terminate(_Reason, _State) ->
  ok.

%% @private
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

do_dispatch(State = #state{active = false}) -> State;
do_dispatch(State = #state{current_calls = C, max_calls = M}) when C >= M -> State;
do_dispatch(State = #state{current_calls = C, queued_calls = Q}) ->
  case queue:out(Q) of
    {empty, _} -> State;
    {{value, Call}, Q2} ->
      io:format("Dispatching ~p~n", [Call]),
      broker:dispatch(State#state.channel, Call),
      do_dispatch(State#state{current_calls = C + 1, queued_calls = Q2})
  end.

