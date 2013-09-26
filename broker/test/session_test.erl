-module(session_test).
-include_lib("eunit/include/eunit.hrl").
-include("session.hrl").
-include("db.hrl").

-record(state, {session_id, session, resume_ptr, pbx_pid, flow_pid}).

notify_status_on_completed_ok_test() ->
  Project = #project{status_callback_url = <<"http://foo.com">>},
  Session = #session{address = <<"123">>, call_log = {call_log_srv}, project = Project},
  meck:new(call_log_srv, [stub_all]),
  meck:expect(call_log_srv, id, 1, 1),
  meck:new(httpc),

  RequestParams = [get, {"http://foo.com/?CallSid=1&CallStatus=completed&From=123", []}, '_', [{full_result, false}]],
  meck:expect(httpc, request, RequestParams, ok),
  session:in_progress({completed, ok}, #state{session = Session}),

  meck:wait(httpc, request, RequestParams, 1000),
  meck:unload().

notify_status_on_completed_ok_with_callback_params_test() ->
  Project = #project{status_callback_url = <<"http://foo.com">>},
  Session = #session{address = <<"123">>, call_log = {call_log_srv}, project = Project, callback_params = [{"foo", "1"}]},
  meck:new(call_log_srv, [stub_all]),
  meck:expect(call_log_srv, id, 1, 1),
  meck:new(httpc),

  RequestParams = [get, {"http://foo.com/?CallSid=1&CallStatus=completed&From=123&foo=1", []}, '_', [{full_result, false}]],
  meck:expect(httpc, request, RequestParams, ok),
  session:in_progress({completed, ok}, #state{session = Session}),

  meck:wait(httpc, request, RequestParams, 1000),
  meck:unload().