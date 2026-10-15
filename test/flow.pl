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
%%       file's largest arity, and Dir/roots.txt a line `BASE N'. The root
%%       comes after the text, so every line keeps its number.
%%
%%   fg_modules_main(+Files, +Out)
%%       cicilang's own C predicates, which the chart's generated tables do
%%       not hold (they are cocolog's modules'), written to Out as rows of
%%       the same shape, flow_t_portal(Module, Name, Arity, CFunction, File,
%%       Line, Modes, Names): each `("name" N c_function)' dispatch row of a
%%       module's source, its modes and names from the `;;;;   name(+A, -B)'
%%       line of the module's header (each `?' without one). Loaded with the
%%       chart, the rows join its own, and a call of ccl_lex_native/6 is a C
%%       portal with its modes, never an unknown procedure.
%%
%%   fg_dynamic_main(+Files, +Out)
%%       the predicates the compiler declares or asserts AS IT RUNS --
%%       dynamic(N/A) and cpp_reset(N/A) with a written name, asserta/1,
%%       assertz/1 and assert/1 of a written head -- each declared in Out by
%%       `:- dynamic(N/A).' The desugaring's tables ('$cpp_cls'/2 and some
%%       seventy more) are declared when a unit is desugared, never by a
%%       directive, and the chart, which runs nothing, took each call of one
%%       for an unknown procedure (1221 of ccl_cpp.pl's first 1291
%%       findings). A predicate the chart is told is dynamic may bind any
%%       argument, fail or answer again, which is what such a table does.
%%
%%   fg_findings_main(+Src, +N, +Loads, +Out)
%%       Src charted from '$fg_all'/N, the files in Loads loaded first
%%       (the rest of the compiler: a call into it is then no unknown
%%       procedure), and each finding written to Out, a line each, its fields
%%       apart by a tab: KIND SEVERITY IN LINE COL TEXT. A finding in the
%%       root itself is the gate's own making and is left out.

:- use_module(library(stream)).

fg_modules_main(Files, Out) :-
    open(Out, write, S),
    format(S, "%% cicilang's C predicates, for library(flow/chart): written by test/flow.pl~n", []),
    forall(member(F, Files), fg_module_rows(F, S)),
    close(S).

fg_module_rows(F, S) :-
    fg_base_name(F, Base),
    (   atom_concat(Module, '.cicili', Base) -> true ; Module = Base ),
    read_file_to_codes(F, Cs),
    atom_codes(Text, Cs),
    atomic_list_concat(Lines, '\n', Text),
    findall(Name-Sig, ( member(L, Lines), fg_sig_line(L, Name, Sig) ), Sigs),
    forall(( nth1(I, Lines, L), fg_row_line(L, Name, Arity, CFun) ),
           ( fg_row_modes(Name, Arity, Sigs, Modes, Names),
             format(S, "~q.~n", [flow_t_portal(Module, Name, Arity, CFun, F, I, Modes, Names)]) )).

%% a dispatch row: ... ("name" N c_function) ...
fg_row_line(L, Name, Arity, CFun) :-
    sub_atom(L, B, 2, _, '("'),
    B1 is B + 2,
    sub_atom(L, B1, _, 0, R1),
    sub_atom(R1, E, 1, _, '"'), !,
    sub_atom(R1, 0, E, _, Name),
    E1 is E + 1,
    sub_atom(R1, E1, _, 0, R2),
    atomic_list_concat(Ws0, ' ', R2),
    exclude(==(''), Ws0, [AT, CF0|_]),
    atom_number(AT, Arity), integer(Arity),
    fg_strip_parens(CF0, CFun),
    CFun \== ''.

fg_strip_parens(A, B) :-
    (   atom_concat(A1, ')', A) -> fg_strip_parens(A1, B) ; B = A ).

%% a header line ;;;;   name(+A, -B) ...
fg_sig_line(L, Name, Sig) :-
    atom_concat(';;;;', R, L),
    atomic_list_concat(Ws, ' ', R),
    member(W, Ws), W \== '',
    sub_atom(W, P, 1, _, '('), P > 0, !,
    sub_atom(W, 0, P, _, Name),
    sub_atom(L, S0, _, _, W), !,
    sub_atom(L, S0, _, 0, From),
    sub_atom(From, Open, 1, _, '('),
    sub_atom(From, Close, 1, _, ')'), Close > Open, !,
    A0 is Open + 1, Len is Close - A0,
    sub_atom(From, A0, Len, _, Sig).

fg_row_modes(Name, Arity, Sigs, Modes, Names) :-
    (   memberchk(Name-Sig, Sigs),
        atomic_list_concat(Parts, ',', Sig),
        length(Parts, Arity)
    ->  fg_sig_parts(Parts, Modes, Names)
    ;   length(Modes, Arity), fg_all_q(Modes),
        fg_root_args(1, Arity, Names)
    ).

fg_sig_parts([], [], []).
fg_sig_parts([P0|Ps], [M|Ms], [N|Ns]) :-
    fg_trim(P0, P),
    (   sub_atom(P, 0, 1, _, M0), memberchk(M0, ['+', '-', '?'])
    ->  M = M0, sub_atom(P, 1, _, 0, N)
    ;   M = '?', N = P
    ),
    fg_sig_parts(Ps, Ms, Ns).

fg_all_q([]).
fg_all_q(['?'|Ms]) :- fg_all_q(Ms).

%% an atom without its leading and trailing blanks
fg_trim(A0, A) :-
    atom_codes(A0, Cs0),
    fg_drop_blanks(Cs0, Cs1),
    reverse(Cs1, Rs0),
    fg_drop_blanks(Rs0, Rs),
    reverse(Rs, Cs),
    atom_codes(A, Cs).

fg_drop_blanks([C|Cs], Out) :- memberchk(C, [0' , 0'\t]), !, fg_drop_blanks(Cs, Out).
fg_drop_blanks(Cs, Cs).

fg_roots_main(Files, Dir) :-
    atom_concat(Dir, '/roots.txt', RF),
    open(RF, write, RS),
    forall(member(F, Files), fg_root_file(F, Dir, RS)),
    close(RS).

fg_root_file(F, Dir, RS) :-
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

fg_dynamic_main(Files, Out) :-
    findall(PI, ( member(F, Files), fg_file_terms(F, Ts), member(T, Ts), fg_runtime_dynamic(T, PI) ), PIs0),
    sort(PIs0, PIs),
    open(Out, write, S),
    format(S, "%% what the compiler declares as it runs, for library(flow/chart): written by test/flow.pl~n", []),
    forall(member(PI, PIs), format(S, ":- ~q.~n", [dynamic(PI)])),
    close(S).

fg_file_terms(F, Ts) :-
    open(F, read, S),
    fg_read_all(S, Ts),
    close(S).

fg_read_all(S, Ts) :-
    read_term(S, T, []),
    (   T == end_of_file -> Ts = [] ; Ts = [T|Ts1], fg_read_all(S, Ts1) ).

%% each N/A a term declares as it runs, wherever it stands in the term
fg_runtime_dynamic(T, PI) :-
    fg_subterm(T, X),
    fg_declares(X, PI).

fg_subterm(T, T).
fg_subterm(T, X) :-
    compound(T),
    T =.. [_|As],
    member(A, As),
    fg_subterm(A, X).

fg_declares(X, PI) :-
    compound(X),
    (   X = dynamic(D) -> fg_pi_list(D, PI)
    ;   X = cpp_reset(D) -> fg_pi_list(D, PI)
    ;   ( X = asserta(H0) ; X = assertz(H0) ; X = assert(H0) )
    ->  nonvar(H0),
        ( H0 = (H :- _) -> true ; H = H0 ),
        nonvar(H), callable(H), functor(H, N, A), PI = N/A
    ).

fg_pi_list(D, _) :- var(D), !, fail.
fg_pi_list((A, B), PI) :- !, ( fg_pi_list(A, PI) ; fg_pi_list(B, PI) ).
fg_pi_list([D|Ds], PI) :- !, ( fg_pi_list(D, PI) ; fg_pi_list(Ds, PI) ).
fg_pi_list(N/A, N/A) :- atom(N), integer(A).

fg_findings_main(Src, N, Loads, Out) :-
    flow_graph('$fg_all'/N, G, [source(Src), load(Loads)]),
    flow_findings(G, Fs),
    open(Out, write, S),
    forall(( member(F, Fs), F = finding(_, _, _, _, In, _, _, _), In \== '$fg_all'/N ),
           fg_finding_line(S, F)),
    close(S).

fg_finding_line(S, finding(_, Kind, Sev, _, In, Where, Text, _)) :-
    (   Where = where(_, L, C) -> true ; L = 0, C = 0 ),
    (   atom(In) -> IA = In ; format(atom(IA), '~q', [In]) ),
    format(S, "~w\t~w\t~w\t~w\t~w\t~w~n", [Kind, Sev, IA, L, C, Text]).
