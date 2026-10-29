%% test/flow.pl -- the flow gate's Prolog half (0.144), run by test/flow.sh.
%%
%% cocolog's library(flow/chart) reads a program and says, WITHOUT RUNNING
%% IT, what will go wrong: a call nothing answers, a predicate defined twice,
%% a clause no call can reach, an argument free where a builtin needs it
%% bound, a recursion that never reads any input -- each at its file, line
%% and column. A chart starts at one call pattern, and a library file has no
%% one entry, so each file is charted from a ROOT that calls every predicate
%% the file defines, each argument `?'.
%%
%%   fg_roots_main(+Files, +Dir)
%%       for each file F, Dir/<F's base name> holds F's text and, after it,
%%       the root '$fg_all'(A1, ..., AN) :- ( p1(A1, ...) ; ... ), N the
%%       file's largest arity, and Dir/roots.txt a line `BASE N K', K the
%%       predicates the root calls. The root comes after the text, so every
%%       line keeps its number. Dir/twice.txt holds each predicate that two
%%       of the files define, a line `Name/Arity FILE ...' (fg_twice/2, 0.223).
%%
%%   fg_findings_main(+Src, +N, +Loads, +Mods, +Out)
%%       Src charted from '$fg_all'/N, the files in Loads loaded first
%%       (the rest of the compiler: a call into it is then no unknown
%%       procedure) and the modules' Cicili sources in Mods read for their C
%%       predicates, and each finding written to Out, a line each, its fields
%%       apart by a tab: KIND SEVERITY IN LINE COL TEXT. A finding in the
%%       root itself is the gate's own making and is left out.
%%
%% WHAT THE CHART IS TOLD (cocolog 1.11.4, 0.146): modules(Mods) gives it
%% cicilang's own C predicates (ccl_lex_native/6 ...), each ("name" N
%% c_function) row of a module's source with the modes its header's `;;;;
%% name(+A, -B)' line gives; and the predicates the compiler declares AS IT
%% RUNS -- dynamic/1 of a written name, an assert of a written head,
%% cpp_reset/1, a declarer of its own, called with one -- count as declared,
%% which the chart finds in the source, in the files Loads names and in the
%% libraries the modules' Prolog halves load. Before 1.11.4 this file wrote
%% both itself (0.144): the rows from the modules' sources, and a `:-
%% dynamic' line for each of 73 tables, without which 1221 of ccl_cpp.pl's
%% 1291 findings were unknown procedures.

:- use_module(library(stream)).

fg_roots_main(Files, Dir) :-
    atom_concat(Dir, '/roots.txt', RF),
    open(RF, write, RS),
    fg_root_files(Files, Dir, RS, FPs),
    close(RS),
    fg_twice(FPs, Dir).

fg_root_files([], _, _, []).
fg_root_files([F|Fs], Dir, RS, [F-Ps|FPs]) :- fg_root_file(F, Dir, RS, Ps), fg_root_files(Fs, Dir, RS, FPs).

fg_root_file(F, Dir, RS, Ps) :-
    fg_defined(F, Ps),
    fg_max_arity(Ps, 0, N),
    fg_base_name(F, Base),
    atomic_list_concat([Dir, '/', Base], Out),
    read_file_to_codes(F, Codes),
    open(Out, write, S),
    format(S, "~s", [Codes]),
    (   append(_, [0'\n], Codes) -> true ; nl(S) ),
    fg_root_args(1, N, Args),
    atomic_list_concat(Args, ',', ArgText),
    (   N =:= 0 -> format(S, "~n'$fg_all' :-~n    (   ", [])
    ;   format(S, "~n'$fg_all'(~w) :-~n    (   ", [ArgText])
    ),
    fg_root_calls(Ps, S, first),
    format(S, "~n    ).~n", []),
    close(S),
    length(Ps, K),
    format(RS, "~w ~w ~w~n", [Base, N, K]).

fg_base_name(F, Base) :-
    atomic_list_concat(Parts, '/', F),
    last(Parts, Base).

%% every Name/Arity the file's clauses define, in the order they first stand
%% (a grammar rule's arity is its nonterminal's plus 2)
fg_defined(F, Ps) :-
    open(F, read, S),
    fg_read_heads(S, [], Ps0),
    close(S),
    reverse(Ps0, Ps).

fg_read_heads(S, Acc, Ps) :-
    read_term(S, T, []),
    (   T == end_of_file
    ->  Ps = Acc
    ;   (   fg_head_pi(T, PI), \+ memberchk(PI, Acc) -> Acc1 = [PI|Acc] ; Acc1 = Acc ),
        fg_read_heads(S, Acc1, Ps)
    ).

fg_head_pi((:- _), _) :- !, fail.
fg_head_pi((H --> _), N/A) :- !, fg_head(H, H1), functor(H1, N, A0), A is A0 + 2.
fg_head_pi((H :- _), N/A) :- !, fg_head(H, H1), functor(H1, N, A).
fg_head_pi(H, N/A) :- fg_head(H, H1), functor(H1, N, A).

fg_head((H, _), H) :- !.
fg_head(H, H).

fg_max_arity([], N, N).
fg_max_arity([_/A|Ps], N0, N) :- N1 is max(N0, A), fg_max_arity(Ps, N1, N).

fg_root_args(I, N, []) :- I > N, !.
fg_root_args(I, N, [A|As]) :- atom_concat('A', I, A), I1 is I + 1, fg_root_args(I1, N, As).

fg_root_calls([], _, _).
fg_root_calls([Name/A|Ps], S, Pos) :-
    (   Pos == first -> true ; format(S, "~n    ;   ", []) ),
    (   A =:= 0
    ->  format(S, "~q", [Name])
    ;   fg_root_args(1, A, As),
        atomic_list_concat(As, ',', AT),
        format(S, "~q(~w)", [Name, AT])
    ),
    fg_root_calls(Ps, S, next).

%% A PREDICATE IN TWO FILES (0.223). cocolog has one namespace, so a predicate whose clauses stand in two files of the
%% library -- or in a gate program and the library it is loaded with -- is one predicate read from two places, and no
%% chart sees it: a chart reads one file, the rest loaded. Since 0.223 the desugaring is seventeen files, and a clause
%% put into the wrong one is what a `discontiguous' finding is inside one file. Dir/twice.txt gets a line `Name/Arity
%% FILE ...' for each such predicate, and test/flow.sh holds it empty. Two gate programs may share a name: each is
%% loaded with the library alone.
fg_twice(FPs, Dir) :-
    findall(PI-F, ( member(F-Ps, FPs), member(PI, Ps) ), Pairs0),
    msort(Pairs0, Pairs),
    fg_pi_groups(Pairs, Groups),
    atom_concat(Dir, '/twice.txt', TF),
    open(TF, write, S),
    forall(( member(PI-Fs, Groups), Fs = [_, _|_], once(( member(F1, Fs), fg_library_file(F1) )) ),
           ( format(S, "~q", [PI]), forall(member(F, Fs), format(S, " ~w", [F])), nl(S) )),
    close(S).

%% the sorted PI-File pairs grouped by PI: PI-[File, ...]
fg_pi_groups([], []).
fg_pi_groups([PI-F|Ps], [PI-[F|Fs]|Gs]) :- fg_pi_rest(PI, Ps, Fs, Rest), fg_pi_groups(Rest, Gs).

fg_pi_rest(PI, [PI1-F|Ps], [F|Fs], Rest) :- PI1 == PI, !, fg_pi_rest(PI, Ps, Fs, Rest).
fg_pi_rest(_, Rest, [], Rest).

%% a file of library/, by the directory it stands in
fg_library_file(F) :- atomic_list_concat(Parts, '/', F), append(_, [library, _], Parts), !.

fg_findings_main(Src, N, Loads, Mods, Out) :-
    flow_graph('$fg_all'/N, G, [source(Src), load(Loads), modules(Mods)]),
    flow_findings(G, Fs),
    open(Out, write, S),
    forall(( member(F, Fs), F = finding(_, _, _, _, In, _, _, _), In \== '$fg_all'/N ),
           fg_finding_line(S, F)),
    close(S).

fg_finding_line(S, finding(_, Kind, Sev, _, In, Where, Text, _)) :-
    (   Where = where(_, L, C) -> true ; L = 0, C = 0 ),
    (   atom(In) -> IA = In ; format(atom(IA), '~q', [In]) ),
    format(S, "~w\t~w\t~w\t~w\t~w\t~w~n", [Kind, Sev, IA, L, C, Text]).
