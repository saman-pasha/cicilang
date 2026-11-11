%% ccllib's <unordered_set.pl> (0.283; CCLLIB.md's phase 1a): std::unordered_set and std::unordered_multiset for
%% cicilang's C, and for cicilang++ beside libc++'s.
%%
%%   #include <unordered_set.pl>
%%   unordered_set<int> s;          an empty set; dropped where its scope ends (autodrop)
%%   insert(s, 7);  if (contains(s, 7)) erase(s, 7);
%%   for (size_t p = begin(s); p != end(s); p = next(s, p)) printf("%d ", key(s, p));
%%   unordered_set<point, point_hash, point_eq> ps;
%%                                  a struct names its two functions: `unsigned long point_hash(point p)' and
%%                                  `int point_eq(point a, point b)', where C++ writes two types
%%   unordered_multiset<int> m;     equal elements are kept
%%
%% The instance is a hash table whose slots stand in one own buffer (open addressing): library(ccllib/table) holds its
%% text, which <unordered_map.pl> shares, and says what a place is. type_unordered_set/3 and type_unordered_multiset/3
%% give `unordered_set_int' and `unordered_multiset_int', and with the functions' names
%% `unordered_set_point_point_hash_point_eq'; fn_unordered_set/3 and fn_unordered_multiset/3 give ONE function of the
%% instance at its first call. The names are std::unordered_set's. What differs from C++:
%%   an element is a value with no pointer in it, as a vector's is (CCLLIB.md's open decision 2);
%%   `w = s' and `f(s)' move, as every object of an instance's type does; clone(s) copies;
%%   an integer and a floating number have a hash and an `==' of their own; another element's type names the function
%%     that hashes an element and the one that tells whether two are equal, the type's last arguments, where C++
%%     writes their types. The hash's result is mixed, so a function that gives the element itself is good enough;
%%   A PLACE ENDS WHERE THE SET TAKES A NEW ELEMENT OR LOSES ONE, and at clear, swap, merge, rehash and reserve, where
%%     C++'s iterator ends at a rehash alone: one used after it stops the program (abort), as a place that is no
%%     element's does. An insert that finds its element and an erase that finds none change nothing, and end no
%%     place. erase_at gives the place that a walk comes to next, so a walk that erases meets each element once;
%%   insert and emplace give 1 for a new element and 0 for one that was there, where C++ gives a pair; find gives a
%%     place, which is end(s) for none; erase takes a KEY and gives the count that it took away, and erase_at takes a
%%     place -- C++ calls both erase, and tells them by their types;
%%   key(s, p) gives the element at a place; a walk gives the elements in the slots' order, which is not C++'s;
%%   a multiset's equal elements do NOT stand side by side in a walk: count(s, k) says how many they are, and
%%     find(s, k, i) gives the place of each, i from 0; there is no equal_range;
%%   the slots are C++'s buckets: bucket_count, load_factor and max_load_factor (three of four, and not to be set),
%%     rehash and reserve are there; bucket, bucket_size and the walk of one bucket are not, since a slot holds one
%%     element;
%%   merge takes the other set's elements one by one, and the other's places end; an element that this set holds
%%     stays in the other, as in C++;
%%   there is `==' and no `<', as in C++; no extract and no insert with a hint.
:- ensure_loaded(library(ccllib/ccllib)).
:- ensure_loaded(library(ccllib/table)).
type_unordered_set(As, base([], [typedef(N)]), Items) :-
    ccllib_uset_opts(unordered_set, unique, As, O), O = table(_, _, _, _, N, _, _), ccllib_table_type(O, Items).
fn_unordered_set(Name, As, Items) :- ccllib_uset_opts(unordered_set, unique, As, O), ccllib_table_fn(O, Name, Items).
type_unordered_multiset(As, base([], [typedef(N)]), Items) :-
    ccllib_uset_opts(unordered_multiset, multi, As, O), O = table(_, _, _, _, N, _, _), ccllib_table_type(O, Items).
fn_unordered_multiset(Name, As, Items) :-
    ccllib_uset_opts(unordered_multiset, multi, As, O), ccllib_table_fn(O, Name, Items).
%% an unordered set's arguments: the element's type, and maybe the names of its hash's function and its equality's
ccllib_uset_opts(Base, Multi, [K|Fs], O) :- !, ccllib_table_opts(set, Base, Multi, [K], Fs, O).
ccllib_uset_opts(Base, _, _, _) :-
    atomic_list_concat(['an ', Base, ' takes its element''s type'], M), ccl_macro_error(M).
