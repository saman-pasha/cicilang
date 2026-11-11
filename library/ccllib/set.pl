%% ccllib's <set.pl> (0.281; CCLLIB.md's phase 1a): std::set and std::multiset for cicilang's C, and for cicilang++
%% beside libc++'s.
%%
%%   #include <set.pl>
%%   set<int> s;                    an empty set; dropped where its scope ends (autodrop)
%%   insert(s, 7);  if (contains(s, 7)) erase(s, 7);
%%   for (size_t p = begin(s); p != end(s); p = next(s, p)) printf("%d ", key(s, p));
%%   set<int, later> d;             the order is the function's: `int later(int a, int b)' answers whether a comes
%%                                  before b, as C++'s comparison type does (std::greater gives the greatest first)
%%   multiset<int> m;               equal elements are kept, in the order of their insert
%%
%% The instance is a B-tree whose nodes stand in one own buffer: library(ccllib/tree) holds its text, which <map.pl>
%% shares, and says what a place is. type_set/3 and type_multiset/3 give `set_int' and `multiset_int', and with a
%% comparison's name `set_int_later'; fn_set/3 and fn_multiset/3 give ONE function of the instance at its first call.
%% The names are std::set's. What differs from C++:
%%   an element is a value with no pointer in it, as a vector's is (CCLLIB.md's open decision 2);
%%   `w = s' and `f(s)' move, as every object of an instance's type does; clone(s) copies;
%%   A PLACE ENDS WHERE THE SET TAKES A NEW ELEMENT OR LOSES ONE, and at clear, swap and merge, where C++'s iterator
%%     of a set stays: one used after it stops the program (abort), as a place that is no element's does. An insert
%%     that finds its element and an erase that finds none change nothing, and end no place. erase_at gives the place
%%     after the erased element;
%%   insert and emplace give 1 for a new element and 0 for one that was there, where C++ gives a pair; find gives a
%%     place, which is end(s) for none; erase takes a KEY and gives the count that it took away, and erase_at takes a
%%     place -- C++ calls both erase, and tells them by their types;
%%   key(s, p) gives the element at a place; there is no index;
%%   find of a multiset gives the first of the equal elements, where C++ says any of them;
%%   merge takes the other set's elements one by one, and the other's places end; an element that this set holds
%%     stays in the other, as in C++;
%%   there is no equal_range (lower_bound and upper_bound give its two places), no extract and no insert with a hint.
:- ensure_loaded(library(ccllib/ccllib)).
:- ensure_loaded(library(ccllib/tree)).
type_set(As, base([], [typedef(N)]), Items) :-
    ccllib_set_opts(set, unique, As, O), O = tree(_, _, _, N, K, _),
    ccllib_plain_element('a set''s element', K), ccllib_tree_type(O, Items).
fn_set(Name, As, Items) :- ccllib_set_opts(set, unique, As, O), ccllib_tree_fn(O, Name, Items).
type_multiset(As, base([], [typedef(N)]), Items) :-
    ccllib_set_opts(multiset, multi, As, O), O = tree(_, _, _, N, K, _),
    ccllib_plain_element('a multiset''s element', K), ccllib_tree_type(O, Items).
fn_multiset(Name, As, Items) :- ccllib_set_opts(multiset, multi, As, O), ccllib_tree_fn(O, Name, Items).
%% a set's arguments: the element's type, and maybe the name of the function that orders two elements
ccllib_set_opts(Base, Multi, [K], tree(set, Multi, none, N, K, none)) :- !, ccl_instance_name(Base, [K], N).
ccllib_set_opts(Base, Multi, [K, id(F)], tree(set, Multi, F, N, K, none)) :- atom(F), !,
    ccl_instance_name(Base, [K], N0), atomic_list_concat([N0, '_', F], N).
ccllib_set_opts(Base, _, _, _) :-
    atomic_list_concat(['a ', Base, ' takes its element''s type, and after it the name of a function that orders two ',
                        elements], M),
    ccl_macro_error(M).
