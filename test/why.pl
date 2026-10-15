%% test/why.pl -- WHERE A BUILD GAVE UP (0.144), read from cocolog's library(flow/debug), run by test/why.sh.
%%
%% A build that fails says where it gave up only as well as its refusal does: `not lowered yet:
%% item(function(pick, block/1))' names the function, not the clause; `the check or the lowering
%% failed without saying why' names nothing. library(flow/debug) runs the build twice, each time in
%% a child of its own -- a probe at full speed learns at which inference the run ends, and a replay
%% at full speed to there records the last inferences: every call, its arguments, the clauses it
%% tried and how it ended. The build is made to END AT ITS FIRST ERROR ('$ccl_why', which
%% dr_error/3 reads), so the recording holds the code that failed.
%%
%%   cw_main(+Top, +Base, +Window)
%%       Top is the program test/why.sh writes -- library(cicilang) and cw_goal, the build of the
%%       command's arguments with '$ccl_why' set. Base.svg, Base.xml and Base.txt are the
%%       debugger's (Base.txt: the run, a call a line). Printed: how the run ended; the calls
%%       an error was RAISED through, from the window's top down; and the FAILURE it answered,
%%       down the path that got furthest -- at each failed call the clause whose body got the
%%       most calls done (cocolog's flow_why_furthest/2), and its last call that did not exit.
%%
%% EVERY CALL IS THE PROGRAM'S OWN here: cocolog's why tree takes a call with a panel on the
%% chart for the program's own, and the chart is of Top, whose calls into the compiler are
%% library calls. The compiler is the program being debugged, so each recorded call is given a
%% panel before the tree is made.

:- use_module(library(flow/debug)).

cw_main(Top, Base, Window) :-
    flow_debug(cw_goal, Base, [source(Top), window(Window), txt(true), text(160)], Run),
    Run = run(How, At, _, window(From, To), Calls0, _, _, _),
    length(Calls0, NC),
    format("-- the build under library(flow/debug): ~q at inference ~w; inferences ~w to ~w recorded, ~w calls~n",
           [How, At, From, To, NC]),
    cw_own_all(Calls0, Calls),
    cw_index(Calls, ByS, Kids),
    (   cw_report_start(Calls, E) -> true ; E = none ),
    (   cw_raiser(Calls, E, R)
    ->  cw_ancestors(R, ByS, Up),
        format("-- the error was raised through (the window's top first):~n", []),
        forall(member(S, Up), cw_print_call(ByS, S, '   '))
    ;   R = none
    ),
    (   R == none -> From0 = E ; From0 = R ),
    (   From0 \== none, cw_failure(From0, ByS, Kids, F)
    ->  format("-- what failed before it, down the path that got furthest:~n", []),
        cw_furthest(F, ByS, Kids)
    ;   format("-- no failure before it in the recorded window: test/why.sh with WHY_WINDOW larger~n", [])
    ),
    format("-- every call of the window, a line each: ~w.txt; the run over its chart: ~w.svg and ~w.xml~n", [Base, Base, Base]).

%% a panel for every call: cocolog's tree then takes each as the program's own
cw_own_all([], []).
cw_own_all([call(S, P, D, Par, Box, _, Cl, In, Out, Fate)|Cs], [call(S, P, D, Par, Box, own, Cl, In, Out, Fate)|Os]) :-
    cw_own_all(Cs, Os).

%% the calls by their inference, and each call's calls in the order made
cw_index(Calls, ByS, Kids) :-
    findall(S-C, ( member(C, Calls), arg(1, C, S) ), SC),
    list_to_assoc(SC, ByS),
    findall(P-S, member(call(S, _, _, P, _, _, _, _, _, _), Calls), PS0),
    keysort(PS0, PS),
    flow_dbg_why_kids(PS, Kids).

%% where the driver began to say the error: its first dr_report/2 or dr_error/3
cw_report_start(Calls, S) :-
    member(call(S, P, _, _, _, _, _, _, _, _), Calls),
    memberchk(P, [dr_report/2, dr_error/3]), !.

%% the call that raised the error the driver says: the last call an exception ended before the report
cw_raiser(Calls, E, R) :-
    findall(S, ( member(call(S, _, _, _, _, _, _, _, _, Fate), Calls),
                 memberchk(Fate, [raised, unwound]),
                 ( E == none -> true ; S < E ) ),
            Ss),
    Ss \== [],
    max_list(Ss, R).

%% a call and the calls it was made in that the window saw, the outermost first
cw_ancestors(S, ByS, Up) :-
    cw_up(S, ByS, [], Up).
cw_up(0, _, Acc, Acc) :- !.
cw_up(S, ByS, Acc, Up) :-
    (   get_assoc(S, ByS, call(_, _, _, P, _, _, _, _, _, _)) -> cw_up(P, ByS, [S|Acc], Up) ; Up = Acc ).

%% what failed before an error: among the calls the raising call's own clause made before it (or the report's), the
%% last that failed -- a refusal's deciding test, a builtin as often as not (cpp_not_abstract/1 refuses where
%% `nb_getval('$cpp_base_ctor', yes)' fails), and the failed item or phase that ir_fail/1 answers; none there, the
%% same a call further up, where only a call that tried a clause counts (a failed test up there is another decision).
%% fail/0 and false/0 never: they are how a body says no
cw_failure(S, ByS, Kids, F) :-
    cw_failure(S, ByS, Kids, own, F).

cw_failure(S, ByS, Kids, Level, F) :-
    get_assoc(S, ByS, call(_, _, _, P, _, _, _, _, _, _)),
    (   get_assoc(P, Kids, Sibs) -> true ; Sibs = [] ),
    (   cw_last_failed_before(Sibs, S, ByS, Level, F0)
    ->  F = F0
    ;   P =\= 0, cw_failure(P, ByS, Kids, up, F)
    ).

cw_last_failed_before(Sibs, S, ByS, Level, F) :-
    reverse(Sibs, Rev),
    member(F, Rev),
    F < S,
    get_assoc(F, ByS, call(_, Name/Ar, _, _, _, _, Cl, _, _, fail)),
    \+ ( Ar =:= 0, memberchk(Name, [fail, false]) ),
    ( Level == own -> true ; Cl \== [] ), !.

%% the furthest path of a failed call, over cocolog's why tree of it: at each failed call the clause whose body got
%% the most calls done, then the most inferences spent, then the earlier (flow_why_furthest/2's order), and down into
%% the call it failed at -- its last call that did not exit, but for an explicit fail/0 or false/0, which is how a
%% body says no: then the last call before it that failed after trying a clause (`( Cond -> ... ; trace, fail )',
%% where flow_why_furthest/2 ends at the `fail')
cw_furthest(F, ByS, Kids) :-
    flow_dbg_why_node(F, ByS, Kids, W),
    cw_path(W, ByS, Kids, Path),
    (   Path == [] -> cw_print_call(ByS, F, '   ') ; true ),
    forall(member(Step, Path), cw_print_step(ByS, Step)).

cw_path(why(S, P, In, Tries), ByS, Kids, Path) :- !,
    length(Tries, NT),
    findall(o(ND, NSpan, K)-Gs,
            ( member(entered(K, Gs), Tries),
              findall(x, member(exited(_, _, _, _), Gs), Xs), length(Xs, Done),
              cw_span(Gs, Span), ND is -Done, NSpan is -Span ),
            Os),
    (   Os == [], get_assoc(S, Kids, Ks), cw_last_failed_kid(Ks, ByS, K0)   % a goal handed to it failed: forall/2, call/N
    ->  Path = [inside(S, P, In)|Rest],
        flow_dbg_why_node(K0, ByS, Kids, KW),
        cw_path(KW, ByS, Kids, Rest)
    ;   Os == []
    ->  Path = [nohead(S, P, In)]
    ;   msort(Os, [o(ND1, _, K1)-Gs1|_]),
        Done1 is -ND1,
        Path = [step(S, P, In, K1, Done1, NT)|Rest],
        (   cw_cause(Gs1, G) -> cw_path(G, ByS, Kids, Rest) ; Rest = [] )
    ).
cw_path(failed(S, P, In), _, _, [failed(S, P, In)]) :- !.
cw_path(ended(S, P, In, F), _, _, [ended(S, P, In, F)]) :- !.
cw_path(_, _, _, []).

cw_last_failed_kid(Ks, ByS, K) :-
    reverse(Ks, Rev),
    member(K, Rev),
    get_assoc(K, ByS, call(_, Name/Ar, _, _, _, _, _, _, _, fail)),
    \+ ( Ar =:= 0, memberchk(Name, [fail, false]) ), !.

cw_cause(Gs, G) :-
    reverse(Gs, Rev),
    member(G0, Rev), G0 \= exited(_, _, _, _), !,
    (   arg(2, G0, F/0), memberchk(F, [fail, false]),   % a why node here: every call has a panel
        member(G1, Rev), G1 = why(_, _, _, Tries), Tries \== []
    ->  G = G1
    ;   G = G0
    ).

%% the inferences a clause's calls spent: from its first call to the last inference under its last
cw_span([], 0).
cw_span([G|Gs], Span) :-
    arg(1, G, S0),
    last([G|Gs], L),
    cw_last_inference(L, M),
    Span is M - S0 + 1.

cw_last_inference(why(S, _, _, Tries), M) :- !,
    findall(M1, ( member(entered(_, Gs), Tries), member(G, Gs), cw_last_inference(G, M1) ), Ms),
    max_list([S|Ms], M).
cw_last_inference(G, S) :-
    arg(1, G, S).

cw_print_step(ByS, step(S, _, _, K, Done, Tried)) :- !,
    cw_goal_text(ByS, S, G),
    format("   ~w ~w: failed in clause ~w (the furthest of ~w tried, ~w of its calls done)~n", [S, G, K, Tried, Done]).
cw_print_step(ByS, failed(S, _, _)) :- !,
    cw_goal_text(ByS, S, G),
    format("   ~w ~w: failed~n", [S, G]).
cw_print_step(ByS, inside(S, _, _)) :- !,
    cw_goal_text(ByS, S, G),
    format("   ~w ~w: failed, a goal it was handed failed~n", [S, G]).
cw_print_step(ByS, nohead(S, _, _)) :- !,
    cw_goal_text(ByS, S, G),
    format("   ~w ~w: failed, no clause entered~n", [S, G]).
cw_print_step(ByS, ended(S, _, _, Fate)) :- !,
    cw_goal_text(ByS, S, G),
    format("   ~w ~w: ~w~n", [S, G, Fate]).
cw_print_step(_, X) :-
    format("   ~q~n", [X]).

cw_print_call(ByS, S, Ind) :-
    get_assoc(S, ByS, call(_, _, _, _, _, _, Cl, _, _, Fate)),
    cw_goal_text(ByS, S, G),
    cw_clauses(Cl, CT),
    format("~w~w ~w: ~w~w~n", [Ind, S, G, Fate, CT]).

cw_clauses([], '') :- !.
cw_clauses(Cl, T) :-
    findall(K, member(c(K, _), Cl), Ks),
    (   Ks == [] -> T = '' ; atomic_list_concat(Ks, ' ', KT), atomic_list_concat([' (clauses entered: ', KT, ')'], T) ).

%% the goal as it was called, its arguments as the window wrote them
cw_goal_text(ByS, S, G) :-
    get_assoc(S, ByS, call(_, Name/_, _, _, _, _, _, In, _, _)),
    (   In == [] -> format(atom(G), '~q', [Name])
    ;   cw_arg_texts(In, Ts), atomic_list_concat(Ts, ', ', AT), format(atom(G), '~q(~w)', [Name, AT])
    ).

%% an argument as the window wrote it: its text, or cut(Text, Length) for one cut short
cw_arg_texts([], []).
cw_arg_texts([A|As], [T|Ts]) :-
    (   atomic(A) -> T = A
    ;   A = cut(T0, L) -> format(atom(T), '~w...[~w]', [T0, L])
    ;   format(atom(T), '~q', [A])
    ),
    cw_arg_texts(As, Ts).
