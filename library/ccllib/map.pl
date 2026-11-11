%% ccllib's <map.pl> (0.281; CCLLIB.md's phase 1a): std::map and std::multimap for cicilang's C, and for cicilang++
%% beside libc++'s.
%%
%%   #include <map.pl>
%%   map<int, double> m;            an empty map; dropped where its scope ends (autodrop)
%%   m[5] = 2.5;  m[7] += 1;  x := at(m, 5);  if (contains(m, 7)) erase(m, 7);
%%   e := [int:double; 1: 2.5, 2: 0.5];                         a literal makes one
%%   for (size_t p = begin(m); p != end(m); p = next(m, p)) printf("%d=%g ", key(m, p), value(m, p));
%%   map<int, double, later> d;     the order is the function's: `int later(int a, int b)' answers whether the key a
%%                                  comes before the key b, as C++'s comparison type does
%%   multimap<int, double> mm;      a key may have several values, in the order of their insert
%%
%% The instance is a B-tree whose nodes stand in one own buffer: library(ccllib/tree) holds its text, which <set.pl>
%% shares, and says what a place is. type_map/3 and type_multimap/3 give `map_int_double' and `multimap_int_double',
%% and with a comparison's name `map_int_double_later'; fn_map/3 and fn_multimap/3 give ONE function of the instance
%% at its first call. The names are std::map's. What differs from C++:
%%   a key and a value are values with no pointer in them, as a vector's element is (CCLLIB.md's open decision 2): a
%%     map of strings waits for the owner's rule on containers of owners;
%%   `w = m' and `f(m)' move, as every object of an instance's type does; clone(m) copies;
%%   A PLACE ENDS WHERE THE MAP TAKES A NEW ENTRY OR LOSES ONE, and at clear, swap and merge, where C++'s iterator of
%%     a map stays: one used after it stops the program (abort), as a place that is no entry's does. A write to a key
%%     that is there -- m[k] = v, insert_or_assign, set_value --, an insert that finds its key and an erase that finds
%%     none change no entry, and end no place. erase_at gives the place after the erased entry;
%%   &m[k] is a borrow of the arena, tied to the map, which each function that takes the map not as const ends;
%%   at(m, k) and get(m, k) stop the program at a key that the map has not, where C++'s at throws; m[k] makes the
%%     entry with a value of zero, as C++'s does;
%%   insert, emplace and try_emplace give 1 for a new key and 0 for one that was there (its value stays);
%%     insert_or_assign gives the same and writes the value, and put is its short name; C++ gives a pair;
%%   find gives a place, which is end(m) for none; key(m, p) and value(m, p) give what stands there, and
%%     set_value(m, p, v) writes the value; erase takes a KEY and gives the count that it took away, and erase_at
%%     takes a place -- C++ calls both erase, and tells them by their types;
%%   a multimap has no at, no index and no insert_or_assign, as C++'s has none; its find gives the first entry of
%%     the key, where C++ says any of them;
%%   merge takes the other map's entries one by one, and the other's places end; an entry whose key this map holds
%%     stays in the other, as in C++;
%%   there is no equal_range (lower_bound and upper_bound give its two places), no extract and no insert with a hint.
:- ensure_loaded(library(ccllib/ccllib)).
:- ensure_loaded(library(ccllib/tree)).
type_map(As, base([], [typedef(N)]), Items) :-
    ccllib_map_opts(map, unique, As, O), O = tree(_, _, _, N, K, V),
    ccllib_plain_element('a map''s key', K), ccllib_plain_element('a map''s value', V), ccllib_tree_type(O, Items).
fn_map(Name, As, Items) :- ccllib_map_opts(map, unique, As, O), ccllib_tree_fn(O, Name, Items).
type_multimap(As, base([], [typedef(N)]), Items) :-
    ccllib_map_opts(multimap, multi, As, O), O = tree(_, _, _, N, K, V),
    ccllib_plain_element('a multimap''s key', K), ccllib_plain_element('a multimap''s value', V),
    ccllib_tree_type(O, Items).
fn_multimap(Name, As, Items) :- ccllib_map_opts(multimap, multi, As, O), ccllib_tree_fn(O, Name, Items).
%% a map's arguments: the key's type and the value's, and maybe the name of the function that orders two keys
ccllib_map_opts(Base, Multi, [K, V], tree(map, Multi, none, N, K, V)) :- !, ccl_instance_name(Base, [K, V], N).
ccllib_map_opts(Base, Multi, [K, V, id(F)], tree(map, Multi, F, N, K, V)) :- atom(F), !,
    ccl_instance_name(Base, [K, V], N0), atomic_list_concat([N0, '_', F], N).
ccllib_map_opts(Base, _, _, _) :-
    atomic_list_concat(['a ', Base, ' takes its key''s type and its value''s, and after them the name of a function ',
                        'that orders two keys'], M),
    ccl_macro_error(M).
