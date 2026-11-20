%% what ccllib's macro files share (0.275; CCLLIB.md's phase 1). A module loads this file by a directive,
%% `:- ensure_loaded(library(ccllib/ccllib)).', so a predicate that two modules need is written once, here: the flow
%% gate refuses a predicate in two files. No program includes this file.
%%
%% AN ELEMENT IS A VALUE WITH NO POINTER IN IT (CCLLIB.md's open decision 2): a container refuses another where its
%% type is written. What is the head of the message, `a vector''s element'
ccllib_plain_element(What, T) :-
    (   ccl_holds_pointer(T)
    ->  ccl_arg_words([T], [W]),
        atomic_list_concat([What, ' is a value with no pointer in it, and ', W, ' holds one'], M), ccl_macro_error(M)
    ;   true ).

%% AN OPERAND READ ONCE (1.6.2; the review of 1.1.3 to 1.6.0, its ninth item): C++ reads each argument of min, max,
%% clamp, count, find, lower_bound, upper_bound and binary_search once, where a text that named an operand at each of
%% its uses read `min(i++, 10)' two times and `count(v, f())' once an element. ccllib_once(+Kind, +Text, +Ops, +Holes,
%% -Out) reads Text, a C text of Kind expr or stmts whose hole @K is the operand K = E of Ops: an operand with no effect
%% of its own (ccllib_pure/1) stands where the text names it, so that a constant stays a constant -- `int a[max(3, 4)]'
%% --, and each other operand is read once, in the order of Ops, into a fresh local of its own type, which the text
%% names in its place. The locals' names are fresh and reserved (`__ccl_once_N', C17 7.1.3), so that no name of the
%% program's in an operand means one of them
ccllib_once(Kind, Text0, Ops, Hs0, Out) :-
    ( is_list(Text0) -> atom_codes(Text, Text0) ; Text = Text0 ),
    ccllib_once_bind(Ops, Ds, Hs1), append(Hs1, Hs0, Hs),
    (   Ds == [] -> T1 = Text
    ;   atomic_list_concat(Ds, D), ccllib_once_wrap(Kind, D, Text, T1) ),
    ccllib_once_read(Kind, T1, Hs, Out).
ccllib_once_bind([], [], []).
ccllib_once_bind([K = E|Ops], Ds, [K = expr(E)|Hs]) :- ccllib_pure(E), !, ccllib_once_bind(Ops, Ds, Hs).
ccllib_once_bind([K = E|Ops], [D|Ds], [KV = expr(E), K = name(G)|Hs]) :-
    (   catch(ccl_type_of(E, ET), _, fail), ET \== unknown -> true
    ;   ccl_macro_error('an operand with an effect of its own is read once, into a local of its type, and the read knows no type of it: name it first') ),
    ccl_gensym('__ccl_once', G), atom_concat(K, '_value', KV),
    atomic_list_concat(['__typeof__(@', KV, ') ', G, ' = @', KV, '; '], D), ccllib_once_bind(Ops, Ds, Hs).
ccllib_once_wrap(expr, D, Text, T) :- atomic_list_concat(['({ ', D, Text, '; })'], T).
ccllib_once_wrap(stmts, D, Text, T) :- atomic_list_concat(['{ ', D, Text, ' }'], T).
ccllib_once_read(expr, T, Hs, E) :- ccl_c_expr(T, Hs, E).
ccllib_once_read(stmts, T, Hs, S) :- ccl_c_stmts(T, Hs, S).
%% an operand with no effect of its own: a name, a constant, a string, sizeof, alignof and offsetof, and a member, an
%% element, a dereference, an address, a cast or an operator over such -- not a call, an assignment, `++' or `--', a
%% statement expression, a compound literal, a lambda, a move, va_arg, new or delete
ccllib_pure(E) :- var(E), !, fail.
ccllib_pure(E) :- atomic(E), !.
ccllib_pure(E) :- functor(E, F, _), memberchk(F, [id, int, long, uint, ulong, chr, wchr, str, wstr, float, ldbl, bool, wb, uwb,
    imag, imagf, imagi, imagl, sizeof, sizeof_type, alignof_type, alignof_expr, offsetof, scoped]), !.
ccllib_pure(E) :- ccllib_pure_parts(E, Ps), !, ccllib_pure_all(Ps).
ccllib_pure_parts(member(E, _), [E]).
ccllib_pure_parts(arrow(E, _), [E]).
ccllib_pure_parts(deref(E), [E]).
ccllib_pure_parts(addr(E), [E]).
ccllib_pure_parts(not(E), [E]).
ccllib_pure_parts(neg(E), [E]).
ccllib_pure_parts(pos(E), [E]).
ccllib_pure_parts(bitnot(E), [E]).
ccllib_pure_parts(real_part(E), [E]).
ccllib_pure_parts(imag_part(E), [E]).
ccllib_pure_parts(cast(_, E), [E]).
ccllib_pure_parts(index(A, B), [A, B]).
ccllib_pure_parts(bin(_, A, B), [A, B]).
ccllib_pure_parts(comma(A, B), [A, B]).
ccllib_pure_parts(cond(C, A, B), [C, A, B]).
ccllib_pure_all([]).
ccllib_pure_all([E|Es]) :- ccllib_pure(E), ccllib_pure_all(Es).

%% A MERGE SORT BY THE LINKS OF AN ARENA'S NODES (<list.pl>, <forward_list.pl>): the text of `@{N}__NAME', which sorts
%% the n nodes from the place p on by their `next' and gives the run's first node, the node after the run in *rest. No
%% element moves, each keeps its place, and equal elements keep their order. Param and Arg are the comparison's
%% parameter and argument (`, int (*lt)(@T, @T)' and `, lt', or nothing), Lt is `the element at b comes before the one
%% at a'
ccllib_msort_text(Name, Param, Arg, Lt, Text) :-
    append(["static size_t @{N}__", Name, "(@N *v, size_t p, size_t n, size_t *rest", Param, ") {
    size_t a, b, q, h = 0, t = 0;
    if (n == 1) { *rest = v->data[p - 1].next; v->data[p - 1].next = 0; return p; }
    a = @{N}__", Name, "(v, p, n / 2, &q", Arg, ");
    b = @{N}__", Name, "(v, q, n - n / 2, rest", Arg, ");
    while (a && b) {
        size_t e;
        if (", Lt, ") { e = b; b = v->data[b - 1].next; }
        else { e = a; a = v->data[a - 1].next; }
        if (t) v->data[t - 1].next = e; else h = e;
        t = e;
    }
    v->data[t - 1].next = a ? a : b;
    return h;
}"], Text).

%% A TEXT THAT A FEW CONTAINERS SHARE (0.283; the tree of <set.pl> and <map.pl>, the table of the unordered ones): a
%% list of lines, where a line with a condition is kept where the condition holds -- `multi-"..."' where `multi' is one
%% of Holds, `multi+map-"..."' where both are; the lines that are kept are joined, each with its end.
%% ccllib_text_lines(+Holds, +Lines, -Text)
ccllib_text_lines(_, [], []).
ccllib_text_lines(H, [L|Ls], Text) :-
    (   L = C-Codes -> ( ccllib_text_holds(C, H) -> Line = Codes ; Line = none ) ; Line = L ),
    ccllib_text_lines(H, Ls, Rest),
    (   Line == none -> Text = Rest ; append(Line, [10|Rest], Text) ).
ccllib_text_holds(A+B, H) :- !, ccllib_text_holds(A, H), ccllib_text_holds(B, H).
ccllib_text_holds(C, H) :- memberchk(C, H).
%% AN INDEX IN A FUNCTION'S NAME (0.305; the typed call `get<1>(t)', whose function is `<instance>_get_1'): the word after
%% the name's `_' is a number written as a number -- digits, no `0' before another digit -- and I its value. A call by
%% name asks `<name><count>' first (`get_01' for `get_0(t)', `get_11' for `get_1(t)'), so a word that is not written so
%% is no index, and a module's table makes no function of it; nor of an index past the end, which it does not fail on
%% with an error for the same reason. ccllib_index_word(+Word, -I)
ccllib_index_word(W, I) :- atom(W), atom_codes(W, Cs), Cs = [C|_], C >= 0'0, C =< 0'9,
    forall(member(D, Cs), ( D >= 0'0, D =< 0'9 )), number_codes(I, Cs), number_codes(I, Cs1), Cs1 == Cs.

%% A RANDOM-ACCESS RANGE OF AN INSTANCE, for <algorithm.pl> and <numeric.pl> (phase 1c): V is an object of
%% vector<T>, array<T, N>, deque<T>, span<T>, basic_string<char>, or basic_string_view<char>; Kind is the type
%% macro's name, N the instance's, T the element's. The five mutable kinds have `_index', which gives a place; a view
%% is read-only. ccllib_alg_range(+V, -Kind, -N, -T)
ccllib_alg_range(V, Kind, N, T) :-
    ccl_type_of(V, VT), ccl_iop_inst_type(VT, N), nb_getval('$ccl_instances', Is),
    member(inst(Kind, As, IT, _), Is), ccl_inst_type_name(IT, N), ccllib_alg_kind(Kind, As, T).
ccllib_alg_kind(vector, [T], T).
ccllib_alg_kind(array, [T, _], T).
ccllib_alg_kind(deque, [T], T).
ccllib_alg_kind(span, [T], T).
ccllib_alg_kind(basic_string, [base([], [char])], base([], [char])).
ccllib_alg_kind(basic_string_view, [base([], [char])], base([], [char])).
%% a kind whose elements a mutating algorithm may write: all but the view
ccllib_alg_mutable(Kind) :- memberchk(Kind, [vector, array, deque, span, basic_string]), !.
%% the element type of a range, for a variable in a generated loop
ccllib_alg_element_type(V, T) :- ccllib_alg_range(V, _, _, T).

%% a range that a mutating algorithm may write, or the module's refusal by name
ccllib_alg_mut(V, Kind, N, T, What) :- ccllib_alg_range(V, Kind, N, T),
    ( ccllib_alg_mutable(Kind) -> true ; atomic_list_concat([What, ' over a view: a view is read-only'], M), ccl_macro_error(M) ).
