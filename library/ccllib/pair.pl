%% ccllib's <pair.pl> (0.301; CCLLIB.md's phase 1b): std::pair for cicilang's C, and for cicilang++ beside libc++'s.
%%
%%   #include <pair.pl>
%%   pair<int, double> p = {1, 2.5};    a struct of first and second, named as C++'s members are
%%   p.first = 3;  p.second += 1;       C's own members
%%   pair<int, double> q;               born zero: {0, 0}, as C++'s pair is made
%%   if (p == q || p < q) swap(p, q);
%%
%% type_pair/3 gives the instance's type, `pair_int_double', a struct of `first' and `second': a value with no heap and
%% no drop, so `q := p' and `f(p)' copy, as std::pair's do. fn_pair/3 gives ONE function of the instance at its first
%% use, a call's or an operator's. What differs from C++:
%%   each member is a value with no pointer in it (CCLLIB.md's open decision 2), and no array;
%%   a pair is made by braces, `pair<int, double> p = {1, 2.5};', or member by member: there is no make_pair, whose
%%     arguments name no instance, and no pair made of a pair of other types;
%%   `get<0>(p)' has no form in C: `p.first';
%%   the relations are C++20's: `==' of each member, and `<' by the first members' order, then the second's, where a
%%     first member that is unordered with the other (a NaN) ends the comparison, false;
%%   hash comes with phase 1b's hash.
:- ensure_loaded(library(ccllib/ccllib)).
type_pair([A, B], base([], [typedef(N)]), Items) :- !,
    ccllib_plain_element('a pair''s member', A), ccllib_plain_element('a pair''s member', B),
    ( ( catch(ccl_resolve_type(A, arr(_, _)), _, fail) ; catch(ccl_resolve_type(B, arr(_, _)), _, fail) )
    -> ccl_macro_error('a pair''s member is no array') ; true ),
    ccllib_pair_holes(A, B, N, Hs), ccl_c_items("typedef struct @N { @A first; @B second; } @N;", Hs, Items).
type_pair(_, _, _) :- ccl_macro_error('a pair takes two types, its members''').
fn_pair(Name, [A, B], Items) :-
    ccllib_pair_fn(Name, Text), ccllib_pair_holes(A, B, _, Hs), ccl_c_items(Text, Hs, Items).
%% the holes of a text: @N the instance's name, @A and @B the members' types
ccllib_pair_holes(A, B, N, ['N' = name(N), 'A' = type(A), 'B' = type(B)]) :- ccl_instance_name(pair, [A, B], N).
%% a function's C text by its name. `<' is C++20's synthesized three-way order of the members ([pairs.spec]/1): the
%% first members' `<', else their `==' -- which a NaN fails: unordered, so the pair is not less -- and the second
%% members' `<'. THE COMPARISONS ARE JOINED BY `&' AND `|', NOT BY `&&' AND `||': each is a 0 or a 1 with no effect,
%% so the value is the same, and the text has no branch -- the lowering writes `&&' and `||' as branches, which LLVM
%% kept, and over data of chance they mispredict: the count run of test/ccllib/pair.c took 0.62 s with them and 0.21 s
%% with these, against the twin's 0.31 s (0.301)
ccllib_pair_fn(swap, "void @{N}_swap(@N *a, @N *b) { @N t = *a; *a = *b; *b = t; }").
ccllib_pair_fn(eq, "int @{N}_eq(const @N *a, const @N *b) {
    return (a->first == b->first) & (a->second == b->second);
}").
ccllib_pair_fn(lt, "int @{N}_lt(const @N *a, const @N *b) {
    return (a->first < b->first) | ((a->first == b->first) & (a->second < b->second));
}").
