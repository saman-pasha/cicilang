%% ccllib's <unordered_map.pl> (0.283; CCLLIB.md's phase 1a): std::unordered_map and std::unordered_multimap for
%% cicilang's C, and for cicilang++ beside libc++'s.
%%
%%   #include <unordered_map.pl>
%%   unordered_map<int, double> m;  an empty map; dropped where its scope ends (autodrop)
%%   m[5] = 2.5;  m[7] += 1;  x := at(m, 5);  if (contains(m, 7)) erase(m, 7);
%%   unordered_map<int, double> e = [1: 2.5, 2: 0.5];           a literal makes one
%%   for (size_t p = begin(m); p != end(m); p = next(m, p)) printf("%d=%g ", key(m, p), value(m, p));
%%   unordered_map<point, int, point_hash, point_eq> pm;
%%                                  a struct key names its two functions: `unsigned long point_hash(point p)' and
%%                                  `int point_eq(point a, point b)', where C++ writes two types
%%   unordered_multimap<int, double> mm;                        a key may have several values
%%
%% The instance is a hash table whose slots stand in one own buffer (open addressing): library(ccllib/table) holds its
%% text, which <unordered_set.pl> shares, and says what a place is. type_unordered_map/3 and type_unordered_multimap/3
%% give `unordered_map_int_double' and `unordered_multimap_int_double', and with the functions' names
%% `unordered_map_point_int_point_hash_point_eq'; fn_unordered_map/3 and fn_unordered_multimap/3 give ONE function of
%% the instance at its first call. The names are std::unordered_map's. What differs from C++:
%%   a key and a value are values with no pointer in them, as a vector's element is (CCLLIB.md's open decision 2): a
%%     map of strings waits for the owner's rule on containers of owners;
%%   `w = m' and `f(m)' move, as every object of an instance's type does; clone(m) copies;
%%   an integer and a floating number have a hash and an `==' of their own; another key's type names the function
%%     that hashes a key and the one that tells whether two keys are equal, the type's last arguments, where C++
%%     writes their types. The hash's result is mixed, so a function that gives the key itself is good enough;
%%   A PLACE ENDS WHERE THE MAP TAKES A NEW ENTRY OR LOSES ONE, and at clear, swap, merge, rehash and reserve, where
%%     C++'s iterator ends at a rehash alone: one used after it stops the program (abort), as a place that is no
%%     entry's does. A write to a key that is there -- m[k] = v, insert_or_assign, set_value --, an insert that finds
%%     its key and an erase that finds none change no entry, and end no place. erase_at gives the place that a walk
%%     comes to next, so a walk that erases meets each entry once;
%%   &m[k] is a borrow of the table, tied to the map, which each function that takes the map not as const ends;
%%   at(m, k) and get(m, k) stop the program at a key that the map has not, where C++'s at throws; m[k] makes the
%%     entry with a value of zero, as C++'s does;
%%   insert, emplace and try_emplace give 1 for a new key and 0 for one that was there (its value stays);
%%     insert_or_assign gives the same and writes the value, and put is its short name; C++ gives a pair;
%%   find gives a place, which is end(m) for none; key(m, p) and value(m, p) give what stands there, and
%%     set_value(m, p, v) writes the value; erase takes a KEY and gives the count that it took away, and erase_at
%%     takes a place -- C++ calls both erase, and tells them by their types;
%%   a walk gives the entries in the slots' order, which is not C++'s;
%%   a multimap has no at, no index and no insert_or_assign, as C++'s has none. Its entries of one key do NOT stand
%%     side by side in a walk: count(m, k) says how many they are, and find(m, k, i) gives the place of each, i from
%%     0; an erase gives the erased entry's number to the key's last entry; there is no equal_range;
%%   the slots are C++'s buckets: bucket_count, load_factor and max_load_factor (three of four, and not to be set),
%%     rehash and reserve are there; bucket, bucket_size and the walk of one bucket are not, since a slot holds one
%%     entry;
%%   merge takes the other map's entries one by one, and the other's places end; an entry whose key this map holds
%%     stays in the other, as in C++;
%%   there is `==' and no `<', as in C++; no extract and no insert with a hint.
:- ensure_loaded(library(ccllib/ccllib)).
:- ensure_loaded(library(ccllib/table)).
type_unordered_map(As, base([], [typedef(N)]), Items) :-
    ccllib_umap_opts(unordered_map, unique, As, O), O = table(_, _, _, _, N, _, _), ccllib_table_type(O, Items).
fn_unordered_map(Name, As, Items) :- ccllib_umap_opts(unordered_map, unique, As, O), ccllib_table_fn(O, Name, Items).
type_unordered_multimap(As, base([], [typedef(N)]), Items) :-
    ccllib_umap_opts(unordered_multimap, multi, As, O), O = table(_, _, _, _, N, _, _), ccllib_table_type(O, Items).
fn_unordered_multimap(Name, As, Items) :-
    ccllib_umap_opts(unordered_multimap, multi, As, O), ccllib_table_fn(O, Name, Items).
%% an unordered map's arguments: the key's type and the value's, and maybe the names of the hash's function and the
%% equality's. A name where the value's type stands is no type
ccllib_umap_opts(Base, Multi, [K, V|Fs], O) :- V \= id(_), !, ccllib_table_opts(map, Base, Multi, [K, V], Fs, O).
ccllib_umap_opts(Base, _, _, _) :-
    atomic_list_concat(['an ', Base, ' takes its key''s type and its value''s'], M), ccl_macro_error(M).
