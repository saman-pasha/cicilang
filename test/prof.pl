%% test/prof.pl -- WHERE A BUILD'S STEPS AND ITS TIME GO (0.148, 0.152, 0.156), read from cocolog's
%% library(flow/debug), run by test/prof.sh.
%%
%% A build's cost was found by hand until 0.148: a scratch copy of the library with a timer in every clause (RULES.md,
%% Finding a cost). library(flow/debug) records windows of a run and says where their steps went (cocolog
%% 1.11.10), and where their time went (1.13.3). The build runs once at full speed to learn its length; then N windows
%% of W steps spread along it -- the last ending where the run ends -- are recorded, each by a cocolog of its own
%% that runs the build twice to its window's end (a probe and a replay), J at a time (flow_debug_windows/4), and their
%% rows are added up (flow_profile_merge/4, and /5 with the time). Since 1.15.0 the whole run's time is read too, by
%% predicate, once more untraced under a clock read at every step (flow_run_time/3).
%%
%%   cp_main(+Top, +Base, +N, +W, +J, +K, +Time, +Run, +Secs)
%%       Top is the program test/prof.sh writes -- library(cicilang) and cp_goal, the build of the command's
%%       arguments. Printed, the first K rows of each view, and Base.prof holds them whole:
%%         INCLUSIVE  each predicate's calls and the steps spent inside them, a call charged from its Call to
%%                    its first Exit or Fail (flow_profile_text/2)
%%         STEPS      the windows' steps by what took them: each call is one, the control constructs' steps
%%                    (if-then-else, cut, catch/3, \+, call/N) the rest (flow_steps_text/2)
%%         CALLERS    who made each predicate's calls (flow_callers_text/2)
%%         REPEATS    the goals asked more than once, by predicate: where a memo would serve (flow_repeats_text/2)
%%         TIME       with Time yes (cocolog 1.13.3): each predicate's calls, its inclusive and self time in
%%                    microseconds and its largest call's, the most inclusive first, and the control constructs'
%%                    time last (flow_time_text/2). Each window's probe runs the build untraced under a clock read
%%                    at every step of the window (time(T)), and the replay says whose each step was. A
%%                    call's self time is its own step: a predicate's head and the guards its clause runs as it
%%                    is entered, a builtin's whole run. Since 1.15.0 each row ends ` @W:S', window W and step
%%                    S of its largest call: a window recorded around S (from(S), to(S + K)) reads that call
%%                    with its arguments.
%%         RUN        with Run yes (cocolog 1.15.0): the WHOLE run's self time by predicate, the most first --
%%                    what its steps took and what its retries took, in microseconds and as shares of the run,
%%                    and its steps -- read by flow_run_time/3 (flow_run_time_text/2): the build run once more,
%%                    untraced to its end, under a clock read at every step, each step's time charged to the
%%                    predicate its goal names and a retry's to the predicate retried. No window, no replay: the
%%                    time of the run, where the windows are a sample of it. It takes about twice the build's
%%                    time, under Secs seconds.
%%       A count of steps is no count of time: a copy of a global (nb_getval/2), a unification of big terms and
%%       an assert are one step however long they take (RULES.md, Time and memory). The TIME view says what
%%       such a step costs. A reading of the clock costs some 35 ns, measured as the probe starts and taken
%%       off, so a cheap predicate is read by its count and a costly one by its time. svg(false) and xml(false): no
%%       window draws its documents, the cheap way to a profile. A STEP is every goal the debugger's clock counts,
%%       a `true/0' and an `=/2' among them, which statistics/2's inferences leave out (cocolog 1.12.2); cocolog
%%       1.13.6 calls them steps, and each view says how many of them were inferences.

:- use_module(library(flow/debug)).

cp_main(Top, Base, N, W, J, K, Time, Run, Secs) :-
    (   Time == yes -> TO = [time(_)] ; TO = [] ),
    append([source(Top), windows(N), window(W), jobs(J), svg(false), xml(false)], TO, Opts),
    flow_debug_windows(cp_goal, Base, Opts, windows(end(How, At, _), Ws)),
    length(Ws, NW),
    findall(S, ( member(window(_, _, run(_, _, _, window(F, To), _, _, _, _), _), Ws), format(atom(S), '~w-~w', [F, To]) ),
            Spans),
    atomic_list_concat(Spans, ', ', SpansA),
    format("-- the windows: the build ended ~q at step ~w; ~w windows of up to ~w steps: ~w~n",
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
    Views0 = [inclusive-T1, steps-T2, callers-T3, repeats-T4|Tail],
    (   Run == yes
    ->  Ms is Secs * 1000,
        flow_run_time(cp_goal, [source(Top), timeout(Ms)], RT),
        RT = run_time(end(RHow, RAt, _), total(Ns, Reads, _, _, _), RRows),
        length(RRows, NRR),
        Sec is Ns / 1.0e9,
        format("-- the whole run: the build ended ~q at step ~w; the clock read ~w steps, ~3f s untraced, ~w rows~n",
               [RHow, RAt, Reads, Sec, NRR]),
        flow_run_time_text(RT, T6),
        append(Views0, [run-T6], Views)
    ;   Views = Views0
    ),
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
