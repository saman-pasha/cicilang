%% test/prof.pl -- WHERE A BUILD'S INFERENCES AND ITS TIME GO (0.148, 0.152), read from cocolog's library(flow/debug),
%% run by test/prof.sh.
%%
%% A build's cost was found by hand until 0.148: a scratch copy of the library with a timer in every clause (CLAUDE.md,
%% Finding a cost). library(flow/debug) records windows of a run and says where their inferences went (cocolog
%% 1.11.10), and where their time went (1.13.3). The build runs once at full speed to learn its length; then N windows
%% of W inferences spread along it -- the last ending where the run ends -- are recorded, each by a cocolog of its own
%% that runs the build twice to its window's end (a probe and a replay), J at a time (flow_debug_windows/4), and their
%% rows are added up (flow_profile_merge/4, and /5 with the time).
%%
%%   cp_main(+Top, +Base, +N, +W, +J, +K, +Time)
%%       Top is the program test/prof.sh writes -- library(cicilang) and cp_goal, the build of the command's
%%       arguments. Printed, the first K rows of each view, and Base.prof holds them whole:
%%         INCLUSIVE  each predicate's calls and the inferences spent inside them, a call charged from its Call to
%%                    its first Exit or Fail (flow_profile_text/2)
%%         STEPS      the windows' inferences by what took them: each call is one, the control constructs' steps
%%                    (if-then-else, cut, catch/3, \+, call/N) the rest (flow_steps_text/2)
%%         CALLERS    who made each predicate's calls (flow_callers_text/2)
%%         REPEATS    the goals asked more than once, by predicate: where a memo would serve (flow_repeats_text/2)
%%         TIME       with Time yes (cocolog 1.13.3): each predicate's calls, its inclusive and self time in
%%                    microseconds and its largest call's, the most inclusive first, and the control constructs'
%%                    time last (flow_time_text/2). Each window's probe runs the build untraced under a clock read
%%                    at every inference of the window (time(T)), and the replay says whose each inference was. A
%%                    call's self time is its own inference: a predicate's head and the guards its clause runs as it
%%                    is entered, a builtin's whole run.
%%       A count of inferences is no count of time: a copy of a global (nb_getval/2), a unification of big terms and
%%       an assert are one inference however long they take (CLAUDE.md, Time and memory). The TIME view says what
%%       such an inference costs. A reading of the clock costs some 35 ns, measured as the probe starts and taken
%%       off, so a cheap predicate is read by its count and a costly one by its time. svg(false) and xml(false): no
%%       window draws its documents, the cheap way to a profile.

:- use_module(library(flow/debug)).

cp_main(Top, Base, N, W, J, K, Time) :-
    (   Time == yes -> TO = [time(_)] ; TO = [] ),
    append([source(Top), windows(N), window(W), jobs(J), svg(false), xml(false)], TO, Opts),
    flow_debug_windows(cp_goal, Base, Opts, windows(end(How, At, _), Ws)),
    length(Ws, NW),
    findall(S, ( member(window(_, _, run(_, _, _, window(F, To), _, _, _, _), _), Ws), format(atom(S), '~w-~w', [F, To]) ),
            Spans),
    atomic_list_concat(Spans, ', ', SpansA),
    format("-- the windows: the build ended ~q at inference ~w; ~w windows of up to ~w inferences: ~w~n",
           [How, At, NW, W, SpansA]),
    findall(Rows, member(window(_, _, _, Rows), Ws), RLs),
    (   Time == yes
    ->  flow_profile_merge(RLs, P, C, R, Ti),
        flow_time_text(Ti, T5),
        Tail = [time-T5]
    ;   flow_profile_merge(RLs, P, C, R),
        Tail = []
    ),
    flow_profile_text(P, T1),
    flow_steps_text(P, T2),
    flow_callers_text(C, T3),
    flow_repeats_text(R, T4),
    Views = [inclusive-T1, steps-T2, callers-T3, repeats-T4|Tail],
    findall(VT, member(_-VT, Views), VTs),
    atomic_list_concat(VTs, '\n', All),
    atom_concat(Base, '.prof', PF),
    open(PF, write, Out), write(Out, All), close(Out),
    forall(member(V-VT, Views), cp_head(V, VT, K)).

%% a view's heading -- its leading lines that begin with % -- and its first K rows; the control constructs' row,
%% which the time view puts last, is printed where it falls past them
cp_head(V, Text, K) :-
    atomic_list_concat(Lines0, '\n', Text),
    exclude(==(''), Lines0, Lines),
    cp_split_head(Lines, Hs, Rows),
    (   Hs = [H|Cs]
    ->  format("-- ~w: ~w~n", [V, H]),
        forall(member(C, Cs), format("   ~w~n", [C])),
        length(Rows, NR),
        (   NR =< K -> Top = Rows, Rest = [] ; length(Top, K), append(Top, Rest, Rows) ),
        forall(member(L, Top), format("   ~w~n", [L])),
        findall(L, ( member(L, Rest), sub_atom(L, _, _, 0, '(control constructs)') ), Ks),
        forall(member(L, Ks), format("   ~w~n", [L])),
        length(Ks, NK),
        More is NR - K - NK,
        (   More > 0 -> format("   ... and ~w lines more (PROF_KEEP=DIR keeps them all, DIR/prof.prof)~n", [More]) ; true )
    ;   format("-- ~w: ~w~n", [V, Text])
    ).

%% the heading lines and the rows after them
cp_split_head([L|Ls], [L|Hs], Rows) :-
    sub_atom(L, 0, 1, _, '%'), !,
    cp_split_head(Ls, Hs, Rows).
cp_split_head(Rows, [], Rows).
