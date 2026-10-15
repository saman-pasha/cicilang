%% test/prof.pl -- WHERE A BUILD'S INFERENCES GO (0.148), read from cocolog 1.11.10's library(flow/debug), run by
%% test/prof.sh.
%%
%% A build's cost was found by hand until now: a scratch copy of the library with a timer in every clause (CLAUDE.md,
%% Finding a cost). library(flow/debug) records windows of a run and says where their inferences went. The build runs
%% once at full speed to learn its length; then N windows of W inferences spread along it -- the last ending where the
%% run ends -- are recorded, each by a cocolog of its own that runs the build twice to its window's end (a probe and a
%% replay), J at a time (flow_debug_windows/4), and their rows are added up (flow_profile_merge/4).
%%
%%   cp_main(+Top, +Base, +N, +W, +J, +K)
%%       Top is the program test/prof.sh writes -- library(cicilang) and cp_goal, the build of the command's
%%       arguments. Printed, the first K lines of each of four views, and Base.prof holds them whole:
%%         INCLUSIVE  each predicate's calls and the inferences spent inside them, a call charged from its Call to
%%                    its first Exit or Fail (flow_profile_text/2)
%%         STEPS      the windows' inferences by what took them: each call is one, the control constructs' steps
%%                    (if-then-else, cut, catch/3, \+, call/N) the rest (flow_steps_text/2)
%%         CALLERS    who made each predicate's calls (flow_callers_text/2)
%%         REPEATS    the goals asked more than once, by predicate: where a memo would serve (flow_repeats_text/2)
%%       A count of inferences is no count of time: a copy of a global (nb_getval/2), a unification of big terms and
%%       an assert are one inference however long they take (CLAUDE.md, Time and memory). svg(false) and xml(false):
%%       no window draws its documents, the cheap way to a profile.

:- use_module(library(flow/debug)).

cp_main(Top, Base, N, W, J, K) :-
    flow_debug_windows(cp_goal, Base, [source(Top), windows(N), window(W), jobs(J), svg(false), xml(false)],
                       windows(end(How, At, _), Ws)),
    length(Ws, NW),
    findall(T, ( member(window(_, _, run(_, _, _, window(F, To), _, _, _, _), _), Ws), format(atom(T), '~w-~w', [F, To]) ),
            Spans),
    atomic_list_concat(Spans, ', ', SpansA),
    format("-- the windows: the build ended ~q at inference ~w; ~w windows of up to ~w inferences: ~w~n",
           [How, At, NW, W, SpansA]),
    findall(Rows, member(window(_, _, _, Rows), Ws), RLs),
    flow_profile_merge(RLs, P, C, R),
    flow_profile_text(P, T1),
    flow_steps_text(P, T2),
    flow_callers_text(C, T3),
    flow_repeats_text(R, T4),
    atomic_list_concat([T1, T2, T3, T4], '\n', All),
    atom_concat(Base, '.prof', PF),
    open(PF, write, S), write(S, All), close(S),
    forall(member(V-T, [inclusive-T1, steps-T2, callers-T3, repeats-T4]), cp_head(V, T, K)).

%% a view's heading and its first K lines
cp_head(V, Text, K) :-
    atomic_list_concat(Lines0, '\n', Text),
    exclude(==(''), Lines0, Lines),
    (   Lines = [H, C|Rows]
    ->  format("-- ~w: ~w~n   ~w~n", [V, H, C]),
        length(Rows, NR),
        (   NR =< K -> Top = Rows ; length(Top, K), append(Top, _, Rows) ),
        forall(member(L, Top), format("   ~w~n", [L])),
        (   NR > K -> More is NR - K, format("   ... and ~w lines more (PROF_KEEP=DIR keeps them all, DIR/prof.prof)~n", [More]) ; true )
    ;   format("-- ~w: ~w~n", [V, Text])
    ).
