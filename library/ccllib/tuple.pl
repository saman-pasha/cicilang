%% ccllib's <tuple.pl> (0.305; CCLLIB.md's phase 1b): std::tuple for cicilang's C, and for cicilang++ beside libc++'s.
%%
%%   #include <tuple.pl>
%%   tuple<int, double, char> t = {1, 2.5, 'c'};    a struct of its elements, named _0, _1, _2
%%   get<0>(t) = 3;  get<double>(t) += 1;           an element's place, by its index or by its type
%%   tuple<int, double, char> u;                    born zero, as C++'s tuple is made
%%   if (t == u || t < u) swap(t, u);
%%
%% type_tuple/3 gives the instance's type, `tuple_int_double_char', a struct of its elements: a value with no heap and
%% no drop, so `u := t' and `f(t)' copy, as std::tuple's do. fn_tuple/3 gives ONE function of the instance at its first
%% use, a call's, an operator's or a typed call's (the reader's typed call by name, 0.305): `get<1>(t)' is
%% `*tuple_int_double_char_get_1(&t)', the element's place (the fact place_tuple_get), and `get<double>(t)' the place
%% of the one element of that type. What differs from C++:
%%   each element is a value with no pointer in it (CCLLIB.md's open decision 2), and no array; a tuple has one element
%%     at least, since C has no struct of none;
%%   a tuple is made by braces or element by element: there is no make_tuple, whose arguments name no instance, no tie,
%%     no forward_as_tuple, no tuple_cat, no apply, and no tuple made of a tuple of other types;
%%   get<I> past the end, and get<T> of a type that the tuple holds twice or not at all, make no function, and the reader
%%     refuses the call by the name of the function that the module has not, where C++ fails a static assertion;
%%   tuple_size and tuple_element have no form: the count and the types are the instance's own;
%%   the relations are C++20's: `==' of each element, and `<', `<=', `>' and `>=' by the elements' order, where an
%%     element that is unordered with the other's (a NaN) ends the comparison, all four false;
%%   hash comes with phase 1b's hash.
:- ensure_loaded(library(ccllib/ccllib)).
type_tuple([], _, _) :- !, ccl_macro_error('a tuple takes one type at least, its first element''s').
type_tuple(Ts, base([], [typedef(N)]), Items) :-
    forall(member(T, Ts), ccllib_plain_element('a tuple''s element', T)),
    ( member(T, Ts), catch(ccl_resolve_type(T, arr(_, _)), _, fail) -> ccl_macro_error('a tuple''s element is no array') ; true ),
    ccllib_tuple_holes(Ts, N, Hs), ccllib_tuple_indices(Ts, Is),
    findall(M, ( member(I, Is), atomic_list_concat(['@T', I, ' _', I, '; '], M) ), Ms),
    atomic_list_concat(['typedef struct @N { '|Ms], S0), atomic_list_concat([S0, '} @N;'], Text),
    ccl_c_items(Text, Hs, Items).
fn_tuple(Name, Ts, Items) :- ccllib_tuple_text(Name, Ts, Text), ccllib_tuple_holes(Ts, _, Hs), ccl_c_items(Text, Hs, Items).
%% the holes of a text: @N the instance's name, @T0, @T1 ... the elements' types
ccllib_tuple_holes(Ts, N, ['N' = name(N)|Hs]) :- ccl_instance_name(tuple, Ts, N), ccllib_tuple_type_holes(Ts, 0, Hs).
ccllib_tuple_type_holes([], _, []).
ccllib_tuple_type_holes([T|Ts], I, [H = type(T)|Hs]) :- atomic_list_concat(['T', I], H), I1 is I + 1, ccllib_tuple_type_holes(Ts, I1, Hs).
%% a function's C text by its name. THE RELATIONS ARE C++20'S ([tuple.rel]): `==' of each element, and `<' by the
%% synthesized three-way order -- the first elements' `<', else their `==' and the rest's `<' -- so that an element that
%% is unordered with the other's, a NaN, ends the comparison, false; `<=' the same with the last elements' `<' or `=='.
%% The comparisons are joined by `&' and `|', with no branch, as the pair's are (0.301). `get_I' gives element I's place
%% and `get_<word>' that of the one element whose type has the word; a name that fits no element is no function -- an
%% index past the end, a type that the tuple holds twice or not at all --, and the reader refuses its typed call by that
%% name. No name of the table fails with an error: a call by name asks `<name><count>' first (`get_01' for `get_0(t)'),
%% and only a number written as a number is an index
ccllib_tuple_text(swap, _, "void @{N}_swap(@N *a, @N *b) { @N t = *a; *a = *b; *b = t; }") :- !.
ccllib_tuple_text(eq, Ts, Text) :- !, ccllib_tuple_indices(Ts, Is),
    findall(E, ( member(I, Is), atomic_list_concat(['(a->_', I, ' == b->_', I, ')'], E) ), Es), atomic_list_concat(Es, ' & ', Body),
    atomic_list_concat(['int @{N}_eq(const @N *a, const @N *b) { return ', Body, '; }'], Text).
ccllib_tuple_text(lt, Ts, Text) :- !, ccllib_tuple_indices(Ts, Is), ccllib_tuple_order(Is, lt, Body),
    atomic_list_concat(['int @{N}_lt(const @N *a, const @N *b) { return ', Body, '; }'], Text).
ccllib_tuple_text(le, Ts, Text) :- !, ccllib_tuple_indices(Ts, Is), ccllib_tuple_order(Is, le, Body),
    atomic_list_concat(['int @{N}_le(const @N *a, const @N *b) { return ', Body, '; }'], Text).
ccllib_tuple_text(ge, _, "int @{N}_ge(const @N *a, const @N *b) { return @{N}_le(b, a); }") :- !.
ccllib_tuple_text(Name, Ts, Text) :- atom(Name), atom_concat(get_, W, Name), ccllib_tuple_get_index(W, Ts, I), !,
    atomic_list_concat(['@T', I, ' *@{N}_', Name, '(const @N *t) tie t { return (@T', I, ' *)&t->_', I, '; }'], Text).
%% the element that `get_W' names: W a number written as one, within the count, or the word of exactly one element's type
ccllib_tuple_get_index(W, Ts, I) :- ccllib_index_word(W, I0), !, length(Ts, K), I0 < K, I = I0.
ccllib_tuple_get_index(W, Ts, I) :- findall(J, ( nth0(J, Ts, T), catch(ccl_type_word(T, W), _, fail) ), [I]).
ccllib_tuple_indices(Ts, Is) :- length(Ts, K), K1 is K - 1, findall(I, between(0, K1, I), Is).
%% the order of the elements from the first of Is: the last element's `<' (lt) or `<' or `==' (le), and before it each
%% element's `<', else its `==' and the rest's order
ccllib_tuple_order([I], lt, E) :- !, atomic_list_concat(['(a->_', I, ' < b->_', I, ')'], E).
ccllib_tuple_order([I], le, E) :- !, atomic_list_concat(['((a->_', I, ' < b->_', I, ') | (a->_', I, ' == b->_', I, '))'], E).
ccllib_tuple_order([I|Is], K, E) :- ccllib_tuple_order(Is, K, E1),
    atomic_list_concat(['(a->_', I, ' < b->_', I, ') | ((a->_', I, ' == b->_', I, ') & (', E1, '))'], E).
%% `get<I>(t)' and `get<T>(t)' are the element's place: the reader dereferences the call (ccl_typed_place/2)
place_tuple_get.
