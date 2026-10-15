%% test/why.pl -- WHERE A BUILD GAVE UP (0.144; on cocolog 1.11.10's why since 0.148), read from cocolog's
%% library(flow/debug), run by test/why.sh.
%%
%% A build that fails says where it gave up only as well as its refusal does: `not lowered yet:
%% item(function(pick, block/1))' names the function, not the clause; `the check or the lowering
%% failed without saying why' names nothing. library(flow/debug) runs the build twice, each time in
%% a child of its own -- a probe at full speed learns at which inference the run ends, and a replay
%% at full speed to there records the last inferences: every call, its arguments, the clauses it
%% tried and how it ended. The build is made to END AT ITS FIRST ERROR ('$ccl_why', which the
%% driver reads): the driver throws after it reports an error (dr_why_stop/3), so the recording
%% ends where the compiler gave up.
%%
%%   cw_main(+Top, +Base, +Window, +Keep)
%%       Top is the program test/why.sh writes -- library(cicilang) and cw_goal, the build of the
%%       command's arguments with '$ccl_why' set. Printed, from flow_why_raised/3: how the run
%%       ended; THE ERROR'S PATH, the calls the exception ended from the window's top down to the
%%       raise; THE BRANCH IT WAS RAISED IN (chose(C)), the call whose if-then-else or
%%       disjunction took the branch that raised, and every condition that choice ran, builtins
%%       included -- abstract.cpp's refusal is then(2) of cpp_not_abstract('Shape'), after
%%       `nb_current('$cpp_base_ctor', yes)' failed and `cpp_abstract_class('Shape')' held, the
%%       test 0.144 found by hand; and THE FAILURE IT ANSWERED, a condition that
%%       failed having tried a clause, down the path that got furthest (flow_why_furthest/2). An
%%       error raised in a catch/3's recovery is followed by the error that catch took, raised
%%       further down, explained the same way (caught(K)): the compiler's own catches that restore
%%       a state and throw again (cpp_stmt/3, cpp_method_body_/5) are levels of one path. Keep is
%%       true under WHY_KEEP: Base.txt, Base.svg and Base.xml are written; else none is
%%       (svg(false), xml(false): the window costs its matching alone).
%%
%% Two things the debugger needs of test/why.sh. THE COMPILER'S FILES, named in the top file in a
%% block the engine skips (`:- if(fail).'): the debugger reads the clauses an exception ended from
%% the program's files as the source's directives load them, and library(cicilang) is a compiled
%% module whose Prolog half's files it does not reach -- without them it finds no branch and no
%% catch, and its answered failure is an older one further out (abstract.cpp: an array-type test of
%% the declaration). And THE DRIVER'S dr_catch/3 STAYS: caught(K) names a catch/3 whose call the
%% window recorded, and the driver's report sites are entered when the build starts, long before the
%% window -- measured at 0.148 over the driver of 0.144 (catch/3 at its sites), no case found the
%% compiler's error, and each took 30 s and 740 to 750 MB where it takes 12 s and 300 MB. 0.146's
%% own rule here, a failed call that tried no clause just before the raise, is gone: chose(C) names
%% the conditions of the branch, builtins included.

:- use_module(library(flow/debug)).

cw_main(Top, Base, Window, Keep) :-
    (   Keep == true -> Docs = [txt(true)] ; Docs = [svg(false), xml(false)] ),
    flow_debug(cw_goal, Base, [source(Top), window(Window), text(160), own(all)|Docs], Run),
    Run = run(How, At, _, window(From, To), Calls, _, _, _),
    length(Calls, NC),
    format("-- the build under library(flow/debug): ~q at inference ~w; inferences ~w to ~w recorded, ~w calls~n",
           [How, At, From, To, NC]),
    (   flow_why_raised(Run, Raised, [own(all), chose(C), caught(K)])
    ->  format("-- the error was raised through (the window's top first):~n", []),
        cw_raised(Raised, C, K)
    ;   format("-- the run did not raise; where its last failure got furthest:~n", []),
        flow_why(Run, Whys, [own(all)]),
        flow_why_furthest(Whys, Path),
        forall(member(St, Path), cw_print(St))
    ),
    (   Keep == true
    ->  format("-- every call of the window, a line each: ~w.txt; the run over its chart: ~w.svg and ~w.xml~n",
               [Base, Base, Base])
    ;   true
    ).

%% a raise: its path; where it was raised in a catch's recovery -- a rethrow, a report that stops the run -- the
%% error that catch took, raised further down, the same way; at the bottom, the branch a choice took to the raise
%% and the failure it answered
cw_raised(raised(Chain, Answered), C, K) :-
    forall(member(E, Chain), cw_print(E)),
    (   K = caught(KS, KP, KIn, _, Raised1, C1, K1)
    ->  cw_goal_text(KP, KIn, KG),
        format("-- in the recovery of the catch/3 in ~w ~w; the error that catch took was raised through:~n", [KS, KG]),
        cw_raised(Raised1, C1, K1)
    ;   (   C = chose(S, P, In, _, Branch, Conds)
        ->  cw_goal_text(P, In, G),
            format("-- the branch it was raised in: ~w of ~w ~w, after the conditions:~n", [Branch, S, G]),
            forall(member(W, Conds), cw_print(W))
        ;   true
        ),
        (   Answered \== none
        ->  format("-- the failure it answered, down the path that got furthest:~n", []),
            flow_why_furthest([Answered], Path),
            forall(member(St, Path), cw_print(St))
        ;   C == none
        ->  format("-- no failure before it in the recorded window: test/why.sh with WHY_WINDOW larger~n", [])
        ;   true
        )
    ).

cw_print(ended(S, P, In, Fate)) :- !,
    cw_goal_text(P, In, G), format("   ~w ~w: ~w~n", [S, G, Fate]).
cw_print(exited(S, P, In, _)) :- !,
    cw_goal_text(P, In, G), format("   ~w ~w: held~n", [S, G]).
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
