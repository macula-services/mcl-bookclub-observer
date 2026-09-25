%% @doc OTP application entry.
%%
%% mcl_om:boot/1 wires the mesh, the realm identity, capabilities, health
%% AND the mesh subscriptions this service declares (subscriptions/0), then
%% starts this service. STORELESS: no store_id/0 or data_dir/0 callback, so
%% no reckon-db is started -- this service owns no event store and never
%% dispatches a command.
-module(mcl_bookclub_observer_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_Type, _Args) -> mcl_om:boot(mcl_bookclub_observer_service).

stop(_State) -> ok.
