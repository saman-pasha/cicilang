%% the hash table of ccllib's unordered containers (0.283; CCLLIB.md's phase 1a): what <unordered_set.pl> and
%% <unordered_map.pl> share, loaded by a directive of each (`:- ensure_loaded(library(ccllib/table)).'). No program
%% includes this file.
%%
%% ccllib_table_type(+Opts, -Items) gives an instance's types and its drop, ccllib_table_fn(+Opts, +Name, -Items) ONE
%% function of it. Opts is table(Kind, Multi, Hash, Eq, N, K, V): Kind `set' or `map', Multi `unique' or `multi', Hash
%% how a key is hashed -- `int', as an integer; `float', as a floating number; fn(F), by the function F --, Eq `none'
%% or the name of the function that tells whether two keys are equal, N the instance's name, K and V the key's and the
%% value's types (V `none' in a set). ccllib_table_opts/6 makes Opts of a type's arguments.
%%
%% THE TABLE. The slots stand in ONE own buffer, as many as a power of two, and an entry stands in the first slot that
%% is free from the one that its hash names on (open addressing): there is no node and no link. A slot holds the
%% entry's hash -- 0 says an empty slot, 1 an erased entry's --, the key, and in a map the value. A search walks from
%% the hash's slot to the first empty one. NO ENTRY MOVES but where the table is made again: an erase marks its slot,
%% and a mark is taken away where no search needs it (the slot after it is empty). The table is made again, twice as
%% large or as large, where three slots of four hold an entry or a mark.
%%
%% A MULTI container's entries of one key are numbered from 0, and the entry i of the key k stands where the hash of
%% (k, i) names: equal keys do NOT stand side by side, so a key of many entries makes no long row that every search
%% near it must walk. The key's entry 0 counts the key's entries (`dup': 0x80000000 and the count; another entry's is
%% its number), so an insert and a count take one search, and an erase gives the erased entry's number to the key's
%% last entry.
%%
%% A PLACE is a size_t (of 64 bits) that holds a slot's number and the low 28 bits of the table's count of changes,
%% `mods', as a tree's place does (library(ccllib/tree)): it ENDS where the table takes a new entry or loses one, and
%% at clear, swap, merge, rehash and reserve; a place whose count is not the table's stops the program (__pos). An
%% insert that finds its key and an erase that finds none change NOTHING. end(m) is 0. A walk by places gives the
%% entries in the slots' order, which is no order of the keys and no order of the inserts.
:- ensure_loaded(library(ccllib/ccllib)).
ccllib_table_type(O, Items) :-
    O = table(_, _, _, _, N, K, V),
    ccllib_table_lines(O, [
        "typedef struct @{N}_slot {",
        "    unsigned h;",
        multi-"    unsigned dup;",
        "    @K key;",
        map-"    @V val;",
        "} @{N}_slot;",
        "typedef struct @N { size_t len, used, cap, first, mods; own @{N}_slot *data; } @N;",
        "void @{N}_drop(@N *v) { free(v->data); }"], Text),
    ccllib_table_holes(N, K, V, Hs), ccl_c_items(Text, Hs, Items).
ccllib_table_fn(O, Name, Items) :-
    O = table(_, _, _, _, N, K, V),
    ccllib_table_text(Name, O, Lines), ccllib_table_lines(O, Lines, Text),
    ccllib_table_holes(N, K, V, Hs), ccl_c_items(Text, Hs, Items).
ccllib_table_holes(N, K, none, ['N' = name(N), 'K' = type(K)]) :- !.
ccllib_table_holes(N, K, V, ['N' = name(N), 'K' = type(K), 'V' = type(V)]).
ccllib_table_lines(table(Kind, Multi, _, _, _, _, _), Lines, Text) :- ccllib_text_lines([Kind, Multi], Lines, Text).
%% ---- a type's arguments ---------------------------------------------------------------------------------------------
%% ccllib_table_opts(+Kind, +Base, +Multi, +Types, +Fns, -Opts): Types is the key's type, and the value's after it in a
%% map; Fns is what stands after them, the names of the hash's function and of the equality's. A key and a value hold
%% no pointer (CCLLIB.md's open decision 2). An integer and a floating number have a hash and an `==' of their own;
%% another key names its two functions, since C has no `==' of two structs
ccllib_table_opts(Kind, Base, Multi, Ts, Fs, table(Kind, Multi, Hash, Eq, N, K, V)) :-
    (   Ts = [K] -> V = none ; Ts = [K, V] ),
    (   Kind == set -> KW = '''s element' ; KW = '''s key' ),
    atomic_list_concat(['an ', Base, KW], WK), ccllib_plain_element(WK, K),
    (   V == none -> true ; atomic_list_concat(['an ', Base, '''s value'], WV), ccllib_plain_element(WV, V) ),
    ccllib_table_fns(Base, K, Fs, Hash, Eq, Suffix),
    ccl_instance_name(Base, Ts, N0), atomic_list_concat([N0|Suffix], N).
ccllib_table_fns(Base, K, [], Hash, none, []) :- !, ccllib_table_own(Base, K, Hash).
ccllib_table_fns(Base, K, [id(H)], fn(H), none, ['_', H]) :- atom(H), !, ccllib_table_own(Base, K, _).
ccllib_table_fns(_, _, [id(H), id(E)], fn(H), E, ['_', H, '_', E]) :- atom(H), atom(E), !.
ccllib_table_fns(Base, _, _, _, _, _) :-
    atomic_list_concat(['an ', Base, ' takes its types, and after them the name of the function that hashes a key and ',
                        'the name of the function that tells whether two keys are equal'], M),
    ccl_macro_error(M).
ccllib_table_own(Base, K, Hash) :-
    (   catch(ccl_is_integer(K), _, fail) -> Hash = int
    ;   catch(ccl_is_float(K), _, fail) -> Hash = float
    ;   ccl_arg_words([K], [W]),
        atomic_list_concat(['an ', Base, ' of ', W, ' takes the names of two functions after its types: one that ',
                            'hashes a key, and one that tells whether two keys are equal'], M),
        ccl_macro_error(M) ).
%% ---- the texts, by the function's name -----------------------------------------------------------------------------
%% -- __h: the hash of the key's entry i (i is 0 in a unique table): the key as a number, mixed (the last step of
%%    MurmurHash3), and never 0 or 1. A floating key goes by its value as a double, so 0.0 and -0.0, which are equal,
%%    have one hash; a function's result is mixed too, so a hash that gives the key itself is good enough
ccllib_table_text('_h', table(_, _, Hash, _, _, _, _), Lines) :-
    ccllib_table_number(Hash, Start),
    append([["static unsigned @{N}__h(@K k, unsigned i) {"], Start, [
        "    x += (unsigned long long)i * 0x9e3779b97f4a7c15ULL;",
        "    x ^= x >> 33;",
        "    x *= 0xff51afd7ed558ccdULL;",
        "    x ^= x >> 33;",
        "    x *= 0xc4ceb9fe1a85ec53ULL;",
        "    x ^= x >> 33;",
        "    return (unsigned)x < 2 ? (unsigned)x + 2 : (unsigned)x;",
        "}"]], Lines).
%% -- whether two keys are equal: `==', or the function that the type names
ccllib_table_text('_eq', table(_, _, _, none, _, _, _), ["static int @{N}__eq(@K a, @K b) { return a == b; }"]) :- !.
ccllib_table_text('_eq', table(_, _, _, F, _, _, _), [Line]) :-
    atom_codes(F, Fs), append(["static int @{N}__eq(@K a, @K b) { return ", Fs, "(a, b); }"], Line).
%% -- __no: the number of an entry among its key's entries, of its `dup'
ccllib_table_text('_no', table(_, multi, _, _, _, _, _), [
    "static unsigned @{N}__no(unsigned d) { return (d & 0x80000000u) ? 0 : d; }"]).
%% -- __look: where the key's entry i stands, its slot's number and 1, or 0 for none; h is the entry's hash. __must:
%%    the slot of an entry that the table holds; a table that does not hold it has a hash that does not go with its
%%    equality, and the program stops
ccllib_table_text('_look', _, [
    "static size_t @{N}__look(const @N *v, unsigned h, @K k, unsigned i) {",
    "    size_t m, j;",
    "    if (!v->cap) return 0;",
    "    m = v->cap - 1;",
    "    j = h & m;",
    "    while (v->data[j].h) {",
    unique-"        if (v->data[j].h == h && @{N}__eq(v->data[j].key, k)) return j + 1;",
    multi-"        if (v->data[j].h == h && @{N}__no(v->data[j].dup) == i && @{N}__eq(v->data[j].key, k))",
    multi-"            return j + 1;",
    "        j = (j + 1) & m;",
    "    }",
    "    return 0;",
    "}"]).
ccllib_table_text('_must', _, [
    "static size_t @{N}__must(const @N *v, @K k, unsigned i) {",
    "    size_t q = @{N}__look(v, @{N}__h(k, i), k, i);",
    "    if (!q) abort();",
    "    return q - 1;",
    "}"]).
%% -- __rehash: the table is made again with c slots, a power of two that holds its entries: each entry goes to the
%%    first free slot from its hash's on, and no mark is left. __room: a new entry will have a slot, and an empty slot
%%    will be left for the searches -- the table is made again where three slots of four hold an entry or a mark, twice
%%    as large where the entries alone fill half of it
ccllib_table_text('_rehash', _, [
    "static void @{N}__rehash(@N *v, size_t c) {",
    "    size_t m = c - 1, first = c;",
    "    if (c > 0x40000000u || c > (size_t)-1 / 2 / sizeof(@{N}_slot)) abort();",
    "    own @{N}_slot *d = (@{N}_slot *)malloc(c * sizeof(@{N}_slot));",
    "    if (!d) abort();",
    "    memset(d, 0, c * sizeof(@{N}_slot));",
    "    for (size_t j = 0; j < v->cap; j++) {",
    "        if (v->data[j].h >= 2) {",
    "            size_t i = v->data[j].h & m;",
    "            while (d[i].h) i = (i + 1) & m;",
    "            d[i] = v->data[j];",
    "            if (i < first) first = i;",
    "        }",
    "    }",
    "    free(v->data);",
    "    v->data = d;",
    "    v->cap = c;",
    "    v->used = v->len;",
    "    v->first = first;",
    "    v->mods++;",
    "}"]).
ccllib_table_text('_room', _, [
    "static void @{N}__room(@N *v) {",
    "    if ((v->used + 1) * 4 <= v->cap * 3) return;",
    "    @{N}__rehash(v, (v->len + 1) * 2 > v->cap ? (v->cap ? 2 * v->cap : 8) : v->cap);",
    "}"]).
%% -- __put: a NEW entry of the hash h and the key k goes to the first slot from the hash's on that holds no entry, an
%%    erased entry's among them; the table has room. It gives the slot. The one count of an insert's change
ccllib_table_text('_put', _, [
    "static size_t @{N}__put(@N *v, unsigned h, @K k) {",
    "    size_t m = v->cap - 1, j = h & m;",
    "    while (v->data[j].h >= 2) j = (j + 1) & m;",
    "    if (!v->data[j].h) v->used++;",
    "    v->data[j].h = h;",
    "    v->data[j].key = k;",
    "    if (!v->len || j < v->first) v->first = j;",
    "    v->len++;",
    "    v->mods++;",
    "    return j;",
    "}"]).
%% -- __ins: the key goes into the table, and *at is its slot: 1, a new entry; 0, a unique table had an entry of an
%%    equal key, whose slot *at is, and NOTHING of the table changed. A multi table's key counts one entry more at its
%%    entry 0, before the table may be made again, and the new entry is the key's last
ccllib_table_text('_ins', _, [
    "static int @{N}__ins(@N *v, @K k, size_t *at) {",
    "    unsigned h = @{N}__h(k, 0);",
    "    size_t q = @{N}__look(v, h, k, 0);",
    unique-"    if (q) { *at = q - 1; return 0; }",
    unique-"    @{N}__room(v);",
    unique-"    *at = @{N}__put(v, h, k);",
    multi-"    unsigned c = q ? v->data[q - 1].dup & 0x7fffffffu : 0;",
    multi-"    if (c == 0x7fffffffu) abort();",
    multi-"    if (c) v->data[q - 1].dup++;",
    multi-"    @{N}__room(v);",
    multi-"    *at = @{N}__put(v, c ? @{N}__h(k, c) : h, k);",
    multi-"    v->data[*at].dup = c ? c : 0x80000001u;",
    "    return 1;",
    "}"]).
%% -- __gone: the entry of the slot j is taken away. Its slot is marked; where the slot after it is empty no search
%%    walks over it, so it is empty too, and so are the marks before it. No entry moves. The one count of an erase's
%%    change; `first' goes on to the next entry
ccllib_table_text('_gone', _, [
    "static void @{N}__gone(@N *v, size_t j) {",
    "    size_t m = v->cap - 1, i = j;",
    "    v->data[j].h = 1;",
    "    if (!v->data[(j + 1) & m].h) {",
    "        do {",
    "            v->data[i].h = 0;",
    "            v->used--;",
    "            i = (i - 1) & m;",
    "        } while (v->data[i].h == 1);",
    "    }",
    "    v->len--;",
    "    v->mods++;",
    "    if (v->len && j == v->first) {",
    "        do j++; while (v->data[j].h < 2);",
    "        v->first = j;",
    "    }",
    "}"]).
%% -- a place: __place makes one of a slot, with the low 28 bits of the table's count of changes; __pos gives the slot
%%    of a place, and stops the program at a place that the table's changes ended or that is no entry's; __after, the
%%    place of the first entry after the slot j, 0 for none
ccllib_table_text('_place', _, [
    "static size_t @{N}__place(const @N *v, size_t j) { return ((j + 1) << 28) | (v->mods & 0xfffffff); }"]).
ccllib_table_text('_pos', _, [
    "static size_t @{N}__pos(const @N *v, size_t p) {",
    "    size_t q = p >> 28;",
    "    if ((p & 0xfffffff) != (v->mods & 0xfffffff) || q == 0 || q > v->cap) abort();",
    "    if (v->data[q - 1].h < 2) abort();",
    "    return q - 1;",
    "}"]).
ccllib_table_text('_after', _, [
    "static size_t @{N}__after(const @N *v, size_t j) {",
    "    for (j++; j < v->cap; j++) if (v->data[j].h >= 2) return @{N}__place(v, j);",
    "    return 0;",
    "}"]).
%% -- the capacity, and the table's own numbers: its slots are C++'s buckets, three of four of them the most that hold
%%    an entry. reserve makes room for n entries; rehash makes the table again with n slots at least, as few as hold
%%    its entries, and leaves no mark. BOTH END THE PLACES ALWAYS, reserve where it makes no new table too: a place
%%    that stays at one size of the table and ends at another would stop a program late, at the size that no test had.
%%    load_factor makes its doubles of SIGNED numbers: of a size_t the compiler makes, for a CPU that has it, an
%%    instruction of AVX-512, which valgrind 3.22 does not know (0.283)
ccllib_table_text(size, _, ["size_t @{N}_size(const @N *v) { return v->len; }"]).
ccllib_table_text(len, _, ["size_t @{N}_len(const @N *v) { return v->len; }"]).
ccllib_table_text(empty, _, ["int @{N}_empty(const @N *v) { return v->len == 0; }"]).
ccllib_table_text(max_size, _, ["size_t @{N}_max_size(const @N *v) { return (size_t)0x40000000u / 4 * 3; }"]).
ccllib_table_text(bucket_count, _, ["size_t @{N}_bucket_count(const @N *v) { return v->cap; }"]).
ccllib_table_text(load_factor, _, [
    "double @{N}_load_factor(const @N *v) {",
    "    return v->cap ? (double)(long long)v->len / (double)(long long)v->cap : 0.0;",
    "}"]).
ccllib_table_text(max_load_factor, _, ["double @{N}_max_load_factor(const @N *v) { return 0.75; }"]).
ccllib_table_text(reserve, _, [
    "void @{N}_reserve(@N *v, size_t n) {",
    "    size_t c = 8;",
    "    if (n > 0x30000000u) abort();",
    "    while (c * 3 < n * 4) c *= 2;",
    "    if (c > v->cap) @{N}__rehash(v, c); else v->mods++;",
    "}"]).
ccllib_table_text(rehash, _, [
    "void @{N}_rehash(@N *v, size_t n) {",
    "    size_t c = 8;",
    "    if (n > 0x40000000u) abort();",
    "    while (c < n || c * 3 < (v->len + 1) * 4) c *= 2;",
    "    @{N}__rehash(v, c);",
    "}"]).
%% -- the places and what stands at one
ccllib_table_text(begin, _, ["size_t @{N}_begin(const @N *v) { return v->len ? @{N}__place(v, v->first) : 0; }"]).
ccllib_table_text(end, _, ["size_t @{N}_end(const @N *v) { return 0; }"]).
ccllib_table_text(next, _, [
    "size_t @{N}_next(const @N *v, size_t p) { return @{N}__after(v, @{N}__pos(v, p)); }"]).
ccllib_table_text(key, _, ["@K @{N}_key(const @N *v, size_t p) { return v->data[@{N}__pos(v, p)].key; }"]).
ccllib_table_text(value, table(map, _, _, _, _, _, _), [
    "@V @{N}_value(const @N *v, size_t p) { return v->data[@{N}__pos(v, p)].val; }"]).
ccllib_table_text(set_value, table(map, _, _, _, _, _, _), [
    "void @{N}_set_value(@N *v, size_t p, @V y) { v->data[@{N}__pos(v, p)].val = y; }"]).
%% -- the lookups by a key. find3, of a multi table: the key's entry i, from 0 to its count
ccllib_table_text(find, _, [
    "size_t @{N}_find(const @N *v, @K k) {",
    "    size_t q = @{N}__look(v, @{N}__h(k, 0), k, 0);",
    "    return q ? @{N}__place(v, q - 1) : 0;",
    "}"]).
ccllib_table_text(find3, table(_, multi, _, _, _, _, _), [
    "size_t @{N}_find3(const @N *v, @K k, size_t i) {",
    "    size_t q;",
    "    if (i >= @{N}_count(v, k)) return 0;",
    "    q = @{N}__look(v, @{N}__h(k, (unsigned)i), k, (unsigned)i);",
    "    return q ? @{N}__place(v, q - 1) : 0;",
    "}"]).
ccllib_table_text(contains, _, [
    "int @{N}_contains(const @N *v, @K k) { return @{N}__look(v, @{N}__h(k, 0), k, 0) != 0; }"]).
ccllib_table_text(count, _, [
    "size_t @{N}_count(const @N *v, @K k) {",
    "    size_t q = @{N}__look(v, @{N}__h(k, 0), k, 0);",
    unique-"    return q != 0;",
    multi-"    return q ? v->data[q - 1].dup & 0x7fffffffu : 0;",
    "}"]).
ccllib_table_text(at, table(map, unique, _, _, _, _, _), [
    "@V @{N}_at(const @N *v, @K k) {",
    "    size_t q = @{N}__look(v, @{N}__h(k, 0), k, 0);",
    "    if (!q) abort();",
    "    return v->data[q - 1].val;",
    "}"]).
ccllib_table_text(get, table(map, unique, _, _, _, _, _), [
    "@V @{N}_get(const @N *v, @K k) { return @{N}_at(v, k); }"]).
ccllib_table_text(index, table(map, unique, _, _, _, _, _), [
    "@V *@{N}_index(@N *v, @K k) tie v {",
    "    size_t at;",
    "    if (@{N}__ins(v, k, &at)) memset(&v->data[at].val, 0, sizeof(@V));",
    "    return &v->data[at].val;",
    "}"]).
%% -- the modifiers
ccllib_table_text(insert, table(set, _, _, _, _, _, _), [
    "int @{N}_insert(@N *v, @K k) {",
    "    size_t at;",
    "    return @{N}__ins(v, k, &at);",
    "}"]).
ccllib_table_text(insert, table(map, _, _, _, _, _, _), [
    "int @{N}_insert(@N *v, @K k, @V y) {",
    "    size_t at;",
    "    if (!@{N}__ins(v, k, &at)) return 0;",
    "    v->data[at].val = y;",
    "    return 1;",
    "}"]).
ccllib_table_text(emplace, table(set, _, _, _, _, _, _), [
    "int @{N}_emplace(@N *v, @K k) { return @{N}_insert(v, k); }"]).
ccllib_table_text(emplace, table(map, _, _, _, _, _, _), [
    "int @{N}_emplace(@N *v, @K k, @V y) { return @{N}_insert(v, k, y); }"]).
ccllib_table_text(try_emplace, table(map, unique, _, _, _, _, _), [
    "int @{N}_try_emplace(@N *v, @K k, @V y) { return @{N}_insert(v, k, y); }"]).
ccllib_table_text(insert_or_assign, table(map, unique, _, _, _, _, _), [
    "int @{N}_insert_or_assign(@N *v, @K k, @V y) {",
    "    size_t at;",
    "    int r = @{N}__ins(v, k, &at);",
    "    v->data[at].val = y;",
    "    return r;",
    "}"]).
ccllib_table_text(put, table(map, unique, _, _, _, _, _), [
    "void @{N}_put(@N *v, @K k, @V y) { @{N}_insert_or_assign(v, k, y); }"]).
ccllib_table_text(insert_range, table(set, _, _, _, _, _, _), [
    "void @{N}_insert_range(@N *v, const @K *a, size_t n) {",
    "    for (size_t j = 0; j < n; j++) @{N}_insert(v, a[j]);",
    "}"]).
ccllib_table_text(erase, _, [
    "size_t @{N}_erase(@N *v, @K k) {",
    "    size_t q = @{N}__look(v, @{N}__h(k, 0), k, 0);",
    unique-"    if (!q) return 0;",
    unique-"    @{N}__gone(v, q - 1);",
    unique-"    return 1;",
    multi-"    unsigned c;",
    multi-"    if (!q) return 0;",
    multi-"    c = v->data[q - 1].dup & 0x7fffffffu;",
    multi-"    for (unsigned i = c - 1; i > 0; i--) @{N}__gone(v, @{N}__must(v, k, i));",
    multi-"    @{N}__gone(v, q - 1);",
    multi-"    return c;",
    "}"]).
%% -- erase_at gives the place of the entry that a walk comes to next. In a multi table the key's last entry takes the
%%    erased one's number and its slot; where it came from a slot further on, the walk has not met it, and its new
%%    slot is the next place
ccllib_table_text(erase_at, _, [
    "size_t @{N}_erase_at(@N *v, size_t p) {",
    "    size_t j = @{N}__pos(v, p);",
    unique-"    @{N}__gone(v, j);",
    multi-"    @K k = v->data[j].key;",
    multi-"    unsigned i = @{N}__no(v->data[j].dup);",
    multi-"    size_t head = i ? @{N}__must(v, k, 0) : j;",
    multi-"    unsigned c = v->data[head].dup & 0x7fffffffu;",
    multi-"    size_t last = i == c - 1 ? j : @{N}__must(v, k, c - 1);",
    multi-"    if (last != j) {",
    multi-"        v->data[j].key = v->data[last].key;",
    multi+map-"        v->data[j].val = v->data[last].val;",
    multi-"    }",
    multi-"    if (c > 1) v->data[head].dup--;",
    multi-"    @{N}__gone(v, last);",
    multi-"    if (last > j) return @{N}__place(v, j);",
    "    return @{N}__after(v, j);",
    "}"]).
ccllib_table_text(clear, _, [
    "void @{N}_clear(@N *v) {",
    "    if (v->cap) memset(v->data, 0, v->cap * sizeof(@{N}_slot));",
    "    v->len = 0;",
    "    v->used = 0;",
    "    v->mods++;",
    "}"]).
ccllib_table_text(swap, _, [
    "void @{N}_swap(@N *a, @N *b) {",
    "    size_t n = a->len, u = a->used, c = a->cap, f = a->first;",
    "    size_t m = (a->mods > b->mods ? a->mods : b->mods) + 1;",
    "    a->len = b->len; a->used = b->used; a->cap = b->cap; a->first = b->first; a->mods = m;",
    "    b->len = n; b->used = u; b->cap = c; b->first = f; b->mods = m;",
    "    own @{N}_slot *d = a->data;",
    "    a->data = b->data;",
    "    b->data = d;",
    "}"]).
ccllib_table_text(merge, _, [
    "void @{N}_merge(@N *v, @N *w) {",
    "    @N rest = {0};",
    "    if (v == w) return;",
    "    for (size_t j = 0; j < w->cap; j++) {",
    "        size_t at;",
    "        if (w->data[j].h < 2) continue;",
    "        if (@{N}__ins(v, w->data[j].key, &at)) {",
    map-"            v->data[at].val = w->data[j].val;",
    "        } else {",
    "            @{N}__ins(&rest, w->data[j].key, &at);",
    map-"            rest.data[at].val = w->data[j].val;",
    "        }",
    "    }",
    "    @{N}_swap(w, &rest);",
    "}"]).
%% -- a value of arrays, which a literal calls; a copy; the comparison that `==' calls. Two tables are equal where
%%    each key of one has as many entries in the other, and in a map equal values: the slots' order says nothing.
%%    There is no `<' of two tables, as C++ has none
ccllib_table_text(from, table(set, _, _, _, _, _, _), [
    "@N @{N}_from(const @K *a, size_t n) {",
    "    @N v = {0};",
    "    for (size_t j = 0; j < n; j++) { size_t at; @{N}__ins(&v, a[j], &at); }",
    "    return v;",
    "}"]).
ccllib_table_text(from, table(map, _, _, _, _, _, _), [
    "@N @{N}_from(const @K *a, const @V *b, size_t n) {",
    "    @N v = {0};",
    "    for (size_t j = 0; j < n; j++) {",
    "        size_t at;",
    "        if (@{N}__ins(&v, a[j], &at)) v.data[at].val = b[j];",
    "    }",
    "    return v;",
    "}"]).
ccllib_table_text(clone, _, [
    "@N @{N}_clone(const @N *v) {",
    "    @N w = {0};",
    "    if (v->cap) {",
    "        own @{N}_slot *d = (@{N}_slot *)malloc(v->cap * sizeof(@{N}_slot));",
    "        if (!d) abort();",
    "        memcpy(d, v->data, v->cap * sizeof(@{N}_slot));",
    "        w.data = d;",
    "    }",
    "    w.len = v->len; w.used = v->used; w.cap = v->cap; w.first = v->first;",
    "    return w;",
    "}"]).
ccllib_table_text(eq, table(set, unique, _, _, _, _, _), [
    "int @{N}_eq(const @N *a, const @N *b) {",
    "    if (a->len != b->len) return 0;",
    "    for (size_t j = 0; j < a->cap; j++) {",
    "        if (a->data[j].h >= 2 && !@{N}_contains(b, a->data[j].key)) return 0;",
    "    }",
    "    return 1;",
    "}"]).
ccllib_table_text(eq, table(map, unique, _, _, _, _, _), [
    "int @{N}_eq(const @N *a, const @N *b) {",
    "    if (a->len != b->len) return 0;",
    "    for (size_t j = 0; j < a->cap; j++) {",
    "        size_t q;",
    "        if (a->data[j].h < 2) continue;",
    "        q = @{N}__look(b, @{N}__h(a->data[j].key, 0), a->data[j].key, 0);",
    "        if (!q || !(a->data[j].val == b->data[q - 1].val)) return 0;",
    "    }",
    "    return 1;",
    "}"]).
ccllib_table_text(eq, table(set, multi, _, _, _, _, _), [
    "int @{N}_eq(const @N *a, const @N *b) {",
    "    if (a->len != b->len) return 0;",
    "    for (size_t j = 0; j < a->cap; j++) {",
    "        if (a->data[j].h < 2 || !(a->data[j].dup & 0x80000000u)) continue;",
    "        if (@{N}_count(b, a->data[j].key) != (a->data[j].dup & 0x7fffffffu)) return 0;",
    "    }",
    "    return 1;",
    "}"]).
ccllib_table_text(eq, table(map, multi, _, _, _, _, _), [
    "int @{N}_eq(const @N *a, const @N *b) {",
    "    if (a->len != b->len) return 0;",
    "    for (size_t j = 0; j < a->cap; j++) {",
    "        size_t c, na = 0, nb = 0;",
    "        if (a->data[j].h < 2) continue;",
    "        c = @{N}_count(a, a->data[j].key);",
    "        if (@{N}_count(b, a->data[j].key) != c) return 0;",
    "        for (size_t i = 0; i < c; i++) {",
    "            na += a->data[@{N}__must(a, a->data[j].key, (unsigned)i)].val == a->data[j].val;",
    "            nb += b->data[@{N}__must(b, a->data[j].key, (unsigned)i)].val == a->data[j].val;",
    "        }",
    "        if (na != nb) return 0;",
    "    }",
    "    return 1;",
    "}"]).
%% ---- what the texts stand on ---------------------------------------------------------------------------------------
%% ccllib_table_number(+Hash, -Lines): the first lines of __h, which make the number x of the key k -- an integer as it
%% is; a floating number by its value as a double, 0.0 for -0.0; another key by its function
ccllib_table_number(int, ["    unsigned long long x = (unsigned long long)k;"]).
ccllib_table_number(float, [
    "    double d = (double)k;",
    "    unsigned long long x;",
    "    if (d == 0) d = 0;",
    "    memcpy(&x, &d, sizeof x);"]).
ccllib_table_number(fn(F), [Line]) :-
    atom_codes(F, Fs), append(["    unsigned long long x = (unsigned long long)", Fs, "(k);"], Line).
