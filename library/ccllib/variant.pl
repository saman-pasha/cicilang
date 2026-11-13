%% ccllib's <variant.pl> (0.308; CCLLIB.md's phase 1b): std::variant and std::visit for cicilang's C, and for cicilang++
%% beside libc++'s.
%%
%%   #include <variant.pl>
%%   variant<int, double, char> v;                  born zero: the first alternative, holding 0
%%   v = 2.5;  variant<int, double, char> w = (char)'x';    of a value of one alternative's type, by the type's _of
%%   if (holds_alternative<double>(v)) get<1>(v) += 1;  x := get<double>(v);  if (get_if<int>(&w)) ...
%%   index(v);  emplace<0>(v, 4);  swap(v, w);  if (v == w || v < w) ...
%%   r := visit<show>(v);                           show_int(x), show_double(x) or show_char(x), by v's alternative
%%
%% type_variant/3 gives the instance's type, `variant_int_double_char', a struct of a union of the alternatives, _0, _1
%% ..., and the index of the one that it holds: a value with no heap and no drop, so `u := v' and `f(v)' copy, as
%% std::variant's do. fn_variant/3 gives ONE function of the instance at its first use, a call's, an operator's or a
%% typed call's (the reader's typed call by name, 0.305): `get<1>(v)' is `*variant_int_double_char_get_1(&v)', the
%% alternative's place (the fact place_variant_get). What differs from C++:
%%   each alternative is a value with no pointer in it (CCLLIB.md's open decision 2), no array and no void; a variant
%%     has one alternative at least, as in C++, and 255 at most;
%%   a variant is made of a value whose type is exactly one alternative's, by its _of of that type's word: a value of
%%     another type is refused by name, where C++ converts it to the alternative that its overload resolution picks, and
%%     C's character constant is an int, so `v = 'c'' makes the int alternative where C++ makes the char one --
%%     `(char)'c'' makes the char one in both; there is no in_place_index or in_place_type, and no variant made of
%%     another;
%%   get<I>(v) and get<T>(v) of an alternative that v does not hold stop the program (abort), where C++ throws
%%     bad_variant_access; get<I> past the end, and a type that the variant holds twice or not at all, make no function,
%%     and the reader refuses the call by the name of the function that the module has not;
%%   visit<f>(v) takes one variant, and calls f_<word> for its alternative -- f_int, f_double, f_monostate -- each
%%     declared before the visit, taking the alternative by value or by a pointer to it, and all giving one type: C has
%%     no overloaded function; C++'s visit takes a callable and any count of variants;
%%   variant_size and variant_alternative have no form: the count and the types are the instance's own;
%%     valueless_by_exception is false: C has no exception;
%%   the relations are C++20's: two variants that hold different alternatives are ordered by the index, and two that
%%     hold one by its own relation, so that a NaN makes `==', `<', `<=', `>' and `>=' false; two monostates are
%%     equal, and monostate has no relation of its own;
%%   the place that get or get_if gives is the variant's storage, and a store of another alternative leaves it so, where
%%     C++ ends the alternative's object;
%%   hash comes with phase 1b's hash.
:- ensure_loaded(library(ccllib/ccllib)).
type_variant([], _, _) :- !, ccl_macro_error('a variant takes one type at least, its first alternative''s').
type_variant(Ts, base([], [typedef(N)]), Items) :-
    length(Ts, K), ( K > 255 -> ccl_macro_error('a variant holds 255 alternatives at most') ; true ),
    forall(member(T, Ts), ccllib_plain_element('a variant''s alternative', T)),
    ( member(T, Ts), catch(ccl_resolve_type(T, arr(_, _)), _, fail) -> ccl_macro_error('a variant''s alternative is no array') ; true ),
    ( member(T, Ts), catch(ccl_resolve_type(T, base(_, [void])), _, fail) -> ccl_macro_error('a variant''s alternative is no void') ; true ),
    ccllib_variant_holes(Ts, N, Hs), ccllib_variant_indices(Ts, Is),
    findall(M, ( member(I, Is), atomic_list_concat(['@T', I, ' _', I, '; '], M) ), Ms),
    atomic_list_concat(['typedef struct @N { union { '|Ms], S0), atomic_list_concat([S0, '} u; unsigned char index; } @N;'], Text),
    ccl_c_items(Text, Hs, Items).
fn_variant(Name, Ts, Items) :- atom(Name), atom_concat(visit_, F, Name), F \== '', !,
    ccllib_variant_visit(F, Ts, Text, R), ccllib_variant_holes(Ts, _, Hs), ccl_c_items(Text, ['R' = type(R)|Hs], Items).
fn_variant(Name, Ts, Items) :- ccllib_variant_text(Name, Ts, Text), ccllib_variant_holes(Ts, _, Hs), ccl_c_items(Text, Hs, Items).
%% the holes of a text: @N the instance's name, @T0, @T1 ... the alternatives' types
ccllib_variant_holes(Ts, N, ['N' = name(N)|Hs]) :- ccl_instance_name(variant, Ts, N), ccllib_variant_type_holes(Ts, 0, Hs).
ccllib_variant_type_holes([], _, []).
ccllib_variant_type_holes([T|Ts], I, [H = type(T)|Hs]) :- atomic_list_concat(['T', I], H), I1 is I + 1, ccllib_variant_type_holes(Ts, I1, Hs).
%% a function's C text by its name. `of_<word>' makes a variant of a value of the one alternative whose type has the
%% word; `get_I' and `get_<word>' give an alternative's place, and stop the program where the variant holds another;
%% `get_if_...' gives its address, or a null pointer; `emplace_...' stores a value of it and gives its place;
%% `holds_alternative_<word>' asks the index. THE RELATIONS ARE C++20'S ([variant.relops]): an index that differs
%% decides -- `==' false, `<' and `<=' by the indices --, else the alternative's own `==', `<' or `<='; `>=' is `<=' the
%% other way, and the reader asks `<' the other way for `>' and the negation of `==' for `!='. A name that fits no
%% alternative is no function -- an index past the end, a type that the variant holds twice or not at all --, and the
%% reader refuses its call by that name. No name of the table fails with an error, and visit's only where the program
%% declares a function of its family: a call by name asks `<name><count>' first (`index1' for `index(v)',
%% `visit_show1' for `visit_show(v)'), and only a number written as a number is an index
ccllib_variant_text(index, _, "size_t @{N}_index(const @N *v) { return v->index; }") :- !.
ccllib_variant_text(valueless_by_exception, _, "int @{N}_valueless_by_exception(const @N *v) { (void)v; return 0; }") :- !.
ccllib_variant_text(swap, _, "void @{N}_swap(@N *a, @N *b) { @N t = *a; *a = *b; *b = t; }") :- !.
ccllib_variant_text(eq, Ts, Text) :- !, ccllib_variant_cases(Ts, eq, Cs),
    atomic_list_concat(['int @{N}_eq(const @N *a, const @N *b) { if (a->index != b->index) return 0; switch (a->index) { ', Cs, '} return 1; }'], Text).
ccllib_variant_text(lt, Ts, Text) :- !, ccllib_variant_cases(Ts, lt, Cs),
    atomic_list_concat(['int @{N}_lt(const @N *a, const @N *b) { if (a->index != b->index) return a->index < b->index; switch (a->index) { ', Cs, '} return 0; }'], Text).
ccllib_variant_text(le, Ts, Text) :- !, ccllib_variant_cases(Ts, le, Cs),
    atomic_list_concat(['int @{N}_le(const @N *a, const @N *b) { if (a->index != b->index) return a->index < b->index; switch (a->index) { ', Cs, '} return 1; }'], Text).
ccllib_variant_text(ge, _, "int @{N}_ge(const @N *a, const @N *b) { return @{N}_le(b, a); }") :- !.
ccllib_variant_text(Name, Ts, Text) :- atom(Name), atom_concat(of_, W, Name), ccllib_variant_type_index(W, Ts, I), !,
    atomic_list_concat(['@N @{N}_', Name, '(@T', I, ' x) { @N v = {0}; v.u._', I, ' = x; v.index = ', I, '; return v; }'], Text).
ccllib_variant_text(Name, Ts, Text) :- atom(Name), atom_concat(holds_alternative_, W, Name), ccllib_variant_type_index(W, Ts, I), !,
    atomic_list_concat(['int @{N}_', Name, '(const @N *v) { return v->index == ', I, '; }'], Text).
ccllib_variant_text(Name, Ts, Text) :- atom(Name), atom_concat(get_if_, W, Name), ccllib_variant_alt(W, Ts, I), !,
    atomic_list_concat(['@T', I, ' *@{N}_', Name, '(const @N *v) tie v { return v && v->index == ', I, ' ? (@T', I, ' *)&v->u._', I, ' : 0; }'], Text).
ccllib_variant_text(Name, Ts, Text) :- atom(Name), atom_concat(get_, W, Name), ccllib_variant_alt(W, Ts, I), !,
    atomic_list_concat(['@T', I, ' *@{N}_', Name, '(const @N *v) tie v { if (v->index != ', I, ') abort(); return (@T', I, ' *)&v->u._', I, '; }'], Text).
ccllib_variant_text(Name, Ts, Text) :- atom(Name), atom_concat(emplace_, W, Name), ccllib_variant_alt(W, Ts, I), !,
    atomic_list_concat(['@T', I, ' *@{N}_', Name, '(@N *v, @T', I, ' x) tie v { v->u._', I, ' = x; v->index = ', I, '; return &v->u._', I, '; }'], Text).
%% the alternative that `get_W', `get_if_W' and `emplace_W' name: W a number written as one, within the count, or the
%% word of exactly one alternative's type
ccllib_variant_alt(W, Ts, I) :- ccllib_index_word(W, I0), !, length(Ts, K), I0 < K, I = I0.
ccllib_variant_alt(W, Ts, I) :- ccllib_variant_type_index(W, Ts, I).
ccllib_variant_type_index(W, Ts, I) :- findall(J, ( nth0(J, Ts, T), catch(ccl_type_word(T, W), _, fail) ), [I]).
ccllib_variant_indices(Ts, Is) :- length(Ts, K), K1 is K - 1, findall(I, between(0, K1, I), Is).
%% the cases of a relation, one an alternative: the alternative's own `==', `<' or `<=' -- two monostates are equal, and
%% neither is before the other
ccllib_variant_cases(Ts, Rel, Cs) :-
    findall(C, ( nth0(I, Ts, T), ccllib_variant_case(Rel, I, T, C) ), L), atomic_list_concat(L, Cs).
ccllib_variant_case(Rel, I, T, C) :- catch(ccl_type_word(T, monostate), _, fail), !,
    ( Rel == lt -> V = 0 ; V = 1 ), atomic_list_concat(['case ', I, ': return ', V, '; '], C).
ccllib_variant_case(Rel, I, _, C) :- ccllib_variant_op(Rel, Op),
    atomic_list_concat(['case ', I, ': return a->u._', I, ' ', Op, ' b->u._', I, '; '], C).
ccllib_variant_op(eq, '==').
ccllib_variant_op(lt, '<').
ccllib_variant_op(le, '<=').
%% VISIT<F>(V) (0.308; std::visit, which C's names cannot spell: a callable that takes each alternative): the typed call
%% by name with a function's name between its < and >, `visit<show>(v)', whose word is the name (ccl_typed_name_word/2),
%% is `variant_int_double_visit_show(&v)': it calls the function of the program that the alternative's type names,
%% show_<word> -- show_int, show_double --, each declared before the visit with one parameter, the alternative by value
%% or a pointer to it, and all of one result type, which the visit gives. The words are the refusals of a family that
%% does not fit; R is the visit's result, its text's @R
ccllib_variant_visit(F, Ts, Text, R0) :-
    ccllib_variant_family(F, Ts),
    findall(I-T, nth0(I, Ts, T), ITs),
    maplist(ccllib_variant_visitor(F), ITs, Vs),
    Vs = [v(_, _, R0, _)|_],
    forall(member(v(G, _, R, _), Vs), ( ccllib_variant_same_type(R, R0) -> true
        ; Vs = [v(G0, _, _, _)|_], atomic_list_concat(['visit<', F, '> gives one type, and ', G, '''s is not ', G0, '''s'], M), ccl_macro_error(M) )),
    ( catch(ccl_resolve_type(R0, base(_, [void])), _, fail) -> Void = yes ; Void = no ),
    findall(C, ( member(v(G, I, _, Arg), Vs), ccllib_variant_visit_case(Void, G, I, Arg, C) ), Cs), atomic_list_concat(Cs, Body),
    atomic_list_concat(['@R @{N}_visit_', F, '(@N *v) { switch (v->index) { ', Body, '} abort(); }'], Text).
%% a family of which the program declares no function is no visit, and fails with no error: a call by name asks
%% `visit_show1' first for a plain `visit_show(v)', and an error there would refuse a call that has its
%% function
ccllib_variant_family(F, Ts) :- member(T, Ts), catch(ccl_type_word(T, W), _, fail), atomic_list_concat([F, '_', W], G),
    catch(ccl_declared(G, _), _, fail), !.
%% the visitor of alternative I: G, the family's name and the word of its type, declared a function of one parameter,
%% the alternative's type or a pointer to it; R its result, Arg how the alternative goes to it
ccllib_variant_visitor(F, I-T, v(G, I, R, Arg)) :-
    ( catch(ccl_type_word(T, W), _, fail) -> true ; W = '?' ),
    atomic_list_concat([F, '_', W], G),
    (   catch(ccl_declared(G, FT), _, fail), catch(ccl_resolve_type(FT, fn(R, Ps, _)), _, fail) -> true
    ;   atomic_list_concat(['visit<', F, '> calls ', G, ' for the alternative ', W, ', and no function ', G, ' is declared before it'], M), ccl_macro_error(M) ),
    (   Ps = [param(PT, _)], ccllib_variant_takes(PT, T, Arg) -> true
    ;   atomic_list_concat(['visit<', F, '>: ', G, ' takes one parameter, the alternative ', W, ' or a pointer to it'], M), ccl_macro_error(M) ).
ccllib_variant_takes(PT, T, value) :- ccllib_variant_same_type(PT, T), !.
ccllib_variant_takes(PT, T, pointer) :- catch(ccl_resolve_type(PT, ptr(_, P)), _, fail), ccllib_variant_same_type(P, T).
%% two types are one where their words are, with no `const' or `volatile' of their own: a visitor takes `const point *'
ccllib_variant_same_type(A, B) :- ccllib_variant_unqual(A, A1), ccllib_variant_unqual(B, B1),
    catch(ccl_type_word(A1, W), _, fail), catch(ccl_type_word(B1, W), _, fail), !.
ccllib_variant_unqual(base(Q, S), base(Q1, S)) :- !, findall(X, ( member(X, Q), \+ memberchk(X, [const, volatile]) ), Q1).
ccllib_variant_unqual(T, T).
ccllib_variant_visit_case(Void, G, I, Arg, C) :-
    ( Arg == pointer -> atomic_list_concat(['&v->u._', I], X) ; atomic_list_concat(['v->u._', I], X) ),
    (   Void == yes -> atomic_list_concat(['case ', I, ': ', G, '(', X, '); return; '], C)
    ;   atomic_list_concat(['case ', I, ': return ', G, '(', X, '); '], C) ).
%% `get<I>(v)', `get<T>(v)' and `emplace<I>(v, x)' are the alternative's place: the reader dereferences the call
%% (ccl_typed_place/2)
place_variant_get.
place_variant_emplace.
