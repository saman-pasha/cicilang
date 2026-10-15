%% test/why.pl -- WHERE A BUILD GAVE UP (0.144; on cocolog 1.11.4's why since 0.146), read from cocolog's
%% library(flow/debug), run by test/why.sh.
%%
%% A build that fails says where it gave up only as well as its refusal does: `not lowered yet:
%% item(function(pick, block/1))' names the function, not the clause; `the check or the lowering
%% failed without saying why' names nothing. library(flow/debug) runs the build twice, each time in
%% a child of its own -- a probe at full speed learns at which inference the run ends, and a replay
%% at full speed to there records the last inferences: every call, its arguments, the clauses it
%% tried and how it ended. The build is made to END AT ITS FIRST ERROR ('$ccl_why', which the driver
%% reads): an error the compiler raises is not caught by the driver, so the run ends with the
%% compiler's own exception (dr_catch/3), and an error the driver says after a failure is thrown
%% there (dr_why_stop/3).
%%
%%   cw_main(+Top, +Base, +Window)
%%       Top is the program test/why.sh writes -- library(cicilang) and cw_goal, the build of the
%%       command's arguments with '$ccl_why' set. Base.svg, Base.xml and Base.txt are the
%%       debugger's (Base.txt: the run, a call a line). Printed: how the run ended; THE ERROR'S
%%       PATH, the calls the exception ended from the window's top down to the raise
%%       (flow_why_raised/3); and WHAT THE RAISE ANSWERED -- a failed call that tried no clause
%%       just before the raise, in the raising call's own body: a refusal's deciding test, a
%%       builtin as often as not (cpp_not_abstract/1 refuses where `nb_getval('$cpp_base_ctor',
%%       yes)' fails); else the last call that failed having tried a clause before the raise, from
%%       the deepest body outwards, and down the path that got furthest (flow_why_furthest/2: at
%%       each failed call the clause whose body got the most calls done, past an explicit fail).
%%
%% EVERY CALL IS THE PROGRAM'S OWN here (own(all)): the chart is of Top, whose calls into the
%% compiler are library calls, and the compiler is the program being debugged. 0.144 wrote this
%% by hand -- a panel on every recorded call, the raising call found as the last one an exception
%% ended, its failed sibling, an explicit fail stepped past -- and cocolog 1.11.4 took each of
%% them in. The one rule kept here is the first above: 1.11.4's answered failure is a call that
%% TRIED A CLAUSE, and the builtin that decided a refusal tried none, so it was passed over for an
%% older failure further out (abstract.cpp: an array-type test of the declaration).

:- use_module(library(flow/debug)).

cw_main(Top, Base, Window) :-
    flow_debug(cw_goal, Base, [source(Top), window(Window), txt(true), text(160), own(all)], Run),
    Run = run(How, At, _, window(From, To), Calls, _, _, _),
    length(Calls, NC),
    format("-- the build under library(flow/debug): ~q at inference ~w; inferences ~w to ~w recorded, ~w calls~n",
           [How, At, From, To, NC]),
    (   flow_why_raised(Run, raised(Chain, Answered), [own(all)])
    ->  format("-- the error was raised through (the window's top first):~n", []),
        forall(member(E, Chain), cw_print(E)),
        (   last(Chain, ended(R, _, _, _)), cw_test_before(Calls, R, F)
        ->  format("-- the test the raise answered, a failed call just before it that tried no clause:~n", []),
            flow_why_call(Run, F, W, [own(all)]),
            cw_print(W)
        ;   Answered == none
        ->  format("-- no failure before it in the recorded window: test/why.sh with WHY_WINDOW larger~n", [])
        ;   format("-- the failure it answered, down the path that got furthest:~n", []),
            flow_why_furthest([Answered], Path),
            forall(member(St, Path), cw_print(St))
        )
    ;   format("-- the run did not raise; where its last failure got furthest:~n", []),
        flow_why(Run, Whys, [own(all)]),
        flow_why_furthest(Whys, Path),
        forall(member(St, Path), cw_print(St))
    ),
    format("-- every call of the window, a line each: ~w.txt; the run over its chart: ~w.svg and ~w.xml~n", [Base, Base, Base]).

%% the last call that failed before the raising call R in the body R was made in, if it tried no clause:
%% fail/0 and false/0 never, they are how a body says no
cw_test_before(Calls, R, F) :-
    memberchk(call(R, _, _, P, _, _, _, _, _, _), Calls),
    findall(S-Cl, ( member(call(S, Name/Ar, _, P, _, _, Cl, _, _, fail), Calls), S < R,
                    \+ ( Ar =:= 0, memberchk(Name, [fail, false]) ) ),
            Fs),
    last(Fs, F-[]).

cw_print(ended(S, P, In, Fate)) :- !,
    cw_goal_text(P, In, G), format("   ~w ~w: ~w~n", [S, G, Fate]).
cw_print(step(S, P, In, K, Done, Tried)) :- !,
    cw_goal_text(P, In, G),
    format("   ~w ~w: failed in clause ~w (the furthest of ~w tried, ~w of its calls done)~n", [S, G, K, Tried, Done]).
cw_print(failed(S, P, In)) :- !,
    cw_goal_text(P, In, G), format("   ~w ~w: failed~n", [S, G]).
cw_print(nohead(S, P, In)) :- !,
    cw_goal_text(P, In, G), format("   ~w ~w: failed, no clause's head unified~n", [S, G]).
cw_print(why(S, P, In, [])) :- !,
    cw_goal_text(P, In, G), format("   ~w ~w: failed, no clause's head unified~n", [S, G]).
cw_print(why(S, P, In, _)) :- !,
    cw_goal_text(P, In, G), format("   ~w ~w: failed~n", [S, G]).
cw_print(X) :-
    format("   ~q~n", [X]).

%% the goal as it was called, its arguments as the window wrote them: each its text, or cut(Text, Length) for one
%% cut short
cw_goal_text(Name/_, In, G) :-
    (   In == [] -> format(atom(G), '~q', [Name])
    ;   cw_arg_texts(In, Ts), atomic_list_concat(Ts, ', ', AT), format(atom(G), '~q(~w)', [Name, AT])
    ).

cw_arg_texts([], []).
cw_arg_texts([A|As], [T|Ts]) :-
    (   atomic(A) -> T = A
    ;   A = cut(T0, L) -> format(atom(T), '~w...[~w]', [T0, L])
    ;   format(atom(T), '~q', [A])
    ),
    cw_arg_texts(As, Ts).
