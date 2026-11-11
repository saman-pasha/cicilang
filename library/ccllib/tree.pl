%% the B-tree of ccllib's ordered containers (0.281; CCLLIB.md's phase 1a): what <set.pl> and <map.pl> share, loaded by
%% a directive of each (`:- ensure_loaded(library(ccllib/tree)).'). No program includes this file.
%%
%% ccllib_tree_type(+Opts, -Items) gives an instance's types and its drop, ccllib_tree_fn(+Opts, +Name, -Items) ONE
%% function of it. Opts is tree(Kind, Multi, Cmp, N, K, V): Kind `set' or `map', Multi `unique' or `multi', Cmp `none'
%% or the name of the function that orders two keys, N the instance's name, K and V the key's and the value's types
%% (V `none' in a set).
%%
%% THE TREE. The nodes stand in ONE own buffer, an arena, and a node names its children by their NUMBERS (a node's
%% number is its place in the arena, from 1; 0 is none). A node holds 7 to 15 entries -- a key, with its value in a map
%% -- in the keys' order, and an inner node 8 to 16 children; the root may hold less. An insert and an erase walk down
%% ONCE WITH NO CHANGE: the walk finds the key, and the leaf that has room for a new entry or that can give one away.
%% Only for a full leaf a second walk splits each full node that it meets on its way down, and only for a leaf of 7
%% entries or for an inner node's entry a second walk fills each node of 7 entries that it meets from a sibling or
%% merges it with one; so neither goes back up. A MULTI container's entry has a number too, `seq', that grows with
%% each insert: its entries are in the order of (key, seq), all different, so equal keys stand in the order of their
%% insert and an erase finds the one entry that it was asked for.
%%
%% A PLACE is what C++ calls an iterator: a size_t (of 64 bits) that holds a node's number, a slot in it, and the low
%% 28 bits of the tree's count of changes, `mods'. An insert or an erase moves entries from slot to slot and from node
%% to node, so A PLACE ENDS WHERE THE TREE TAKES A NEW ENTRY OR LOSES ONE, where C++'s iterator of a map stays: a place
%% whose count is not the tree's stops the program (__pos). An insert that finds its key and an erase that finds none
%% change NOTHING, so every place stays; so it does at a write to a value. clear, swap and merge end them. end(m) is 0.
%%
%% The texts are the same for the four containers but for a few lines, which stand in a list with their condition
%% (`multi-"..."', `map-"..."'): ccllib_tree_lines/3 keeps the lines of the instance.
ccllib_tree_type(O, Items) :-
    O = tree(_, _, _, N, K, V),
    ccllib_tree_lines(O, [
        "typedef struct @{N}_node {",
        "    unsigned short n, leaf;",
        "    unsigned kid[16];",
        "    @K key[15];",
        multi-"    size_t seq[15];",
        map-"    @V val[15];",
        "} @{N}_node;",
        unique-"typedef struct @N { size_t len, cap, top, free, root, mods; own @{N}_node *data; } @N;",
        multi-"typedef struct @N { size_t len, cap, top, free, root, mods, seq; own @{N}_node *data; } @N;",
        "void @{N}_drop(@N *v) { free(v->data); }"], Text),
    ccllib_tree_holes(N, K, V, Hs), ccl_c_items(Text, Hs, Items).
ccllib_tree_fn(O, Name, Items) :-
    O = tree(_, _, _, N, K, V),
    ccllib_tree_text(Name, O, Lines), ccllib_tree_lines(O, Lines, Text),
    ccllib_tree_holes(N, K, V, Hs), ccl_c_items(Text, Hs, Items).
ccllib_tree_holes(N, K, none, ['N' = name(N), 'K' = type(K)]) :- !.
ccllib_tree_holes(N, K, V, ['N' = name(N), 'K' = type(K), 'V' = type(V)]).
%% the lines of an instance, joined: a line with a condition is kept where the condition holds
ccllib_tree_lines(_, [], []).
ccllib_tree_lines(O, [L|Ls], Text) :-
    (   L = C-Codes -> ( ccllib_tree_is(C, O) -> Line = Codes ; Line = none ) ; Line = L ),
    ccllib_tree_lines(O, Ls, Rest),
    (   Line == none -> Text = Rest ; append(Line, [10|Rest], Text) ).
ccllib_tree_is(set, tree(set, _, _, _, _, _)).
ccllib_tree_is(map, tree(map, _, _, _, _, _)).
ccllib_tree_is(unique, tree(_, unique, _, _, _, _)).
ccllib_tree_is(multi, tree(_, multi, _, _, _, _)).
%% ---- the texts, by the function's name -----------------------------------------------------------------------------
%% -- the order of two keys: `<', or the function that the type names
ccllib_tree_text('_lt', tree(_, _, none, _, _, _), ["static int @{N}__lt(@K a, @K b) { return a < b; }"]) :- !.
ccllib_tree_text('_lt', tree(_, _, F, _, _, _), [Line]) :-
    atom_codes(F, Fs), append(["static int @{N}__lt(@K a, @K b) { return ", Fs, "(a, b); }"], Line).
%% -- an entry against (k, s): __eb, the entry of the slot i of the node x comes before it; __be, it comes before the
%%    entry. A unique tree's entry is its key
ccllib_tree_text('_eb', _, [
    "static int @{N}__eb(const @N *v, unsigned x, int i, @K k, size_t s) {",
    unique-"    return @{N}__lt(v->data[x - 1].key[i], k);",
    multi-"    if (@{N}__lt(v->data[x - 1].key[i], k)) return 1;",
    multi-"    return !@{N}__lt(k, v->data[x - 1].key[i]) && v->data[x - 1].seq[i] < s;",
    "}"]).
ccllib_tree_text('_be', _, [
    "static int @{N}__be(const @N *v, unsigned x, int i, @K k, size_t s) {",
    unique-"    return @{N}__lt(k, v->data[x - 1].key[i]);",
    multi-"    if (@{N}__lt(k, v->data[x - 1].key[i])) return 1;",
    multi-"    return !@{N}__lt(v->data[x - 1].key[i], k) && s < v->data[x - 1].seq[i];",
    "}"]).
ccllib_tree_text('_seq', _, [
    "static size_t @{N}__seq(const @N *v, size_t q) {",
    unique-"    return 0;",
    multi-"    return v->data[(q >> 4) - 1].seq[q & 15];",
    "}"]).
%% -- an entry from the slot j of the node b to the slot i of the node a
ccllib_tree_text('_mv', _, [
    "static void @{N}__mv(@N *v, unsigned a, int i, unsigned b, int j) {",
    "    v->data[a - 1].key[i] = v->data[b - 1].key[j];",
    multi-"    v->data[a - 1].seq[i] = v->data[b - 1].seq[j];",
    map-"    v->data[a - 1].val[i] = v->data[b - 1].val[j];",
    "}"]).
%% -- the arena: __node gives a node's number, an erased node's or the arena's next, and the arena grows by twice;
%%    __free chains an erased node, whose `leaf' is 2
ccllib_tree_text('_node', _, [
    "static unsigned @{N}__node(@N *v, int leaf) {",
    "    size_t x = v->free;",
    "    if (x) v->free = v->data[x - 1].kid[0];",
    "    else {",
    "        if (v->top == v->cap) {",
    "            size_t c = v->cap ? 2 * v->cap : 1;",
    "            if (c > 0x7fffffffu || c > (size_t)-1 / 2 / sizeof(@{N}_node)) abort();",
    "            v->data = (@{N}_node *)realloc(v->data, c * sizeof(@{N}_node));",
    "            if (!v->data) abort();",
    "            v->cap = c;",
    "        }",
    "        x = ++v->top;",
    "    }",
    "    v->data[x - 1].n = 0;",
    "    v->data[x - 1].leaf = (unsigned short)leaf;",
    "    return (unsigned)x;",
    "}"]).
ccllib_tree_text('_free', _, [
    "static void @{N}__free(@N *v, unsigned x) {",
    "    v->data[x - 1].leaf = 2;",
    "    v->data[x - 1].n = 0;",
    "    v->data[x - 1].kid[0] = (unsigned)v->free;",
    "    v->free = x;",
    "}"]).
%% -- __split: the child i of x is full; its upper 7 entries go to a new node after it, its middle one up into x
ccllib_tree_text('_split', _, [
    "static void @{N}__split(@N *v, unsigned x, int i) {",
    "    unsigned y = v->data[x - 1].kid[i];",
    "    unsigned z = @{N}__node(v, v->data[y - 1].leaf);",
    "    for (int j = 0; j < 7; j++) @{N}__mv(v, z, j, y, j + 8);",
    "    if (!v->data[y - 1].leaf) for (int j = 0; j < 8; j++) v->data[z - 1].kid[j] = v->data[y - 1].kid[j + 8];",
    "    v->data[z - 1].n = 7;",
    "    v->data[y - 1].n = 7;",
    "    for (int j = v->data[x - 1].n; j > i; j--) v->data[x - 1].kid[j + 1] = v->data[x - 1].kid[j];",
    "    v->data[x - 1].kid[i + 1] = z;",
    "    for (int j = v->data[x - 1].n; j > i; j--) @{N}__mv(v, x, j, x, j - 1);",
    "    @{N}__mv(v, x, i, y, 7);",
    "    v->data[x - 1].n++;",
    "}"]).
%% -- __merge: the children i and i + 1 of x hold 7 entries each; the entry i of x and the second child's go into the
%%    first, and the second is erased. Only the root runs out of entries so: its one child is the root then
ccllib_tree_text('_merge', _, [
    "static void @{N}__merge(@N *v, unsigned x, int i) {",
    "    unsigned y = v->data[x - 1].kid[i], z = v->data[x - 1].kid[i + 1];",
    "    int ny = v->data[y - 1].n, nz = v->data[z - 1].n, n = v->data[x - 1].n;",
    "    @{N}__mv(v, y, ny, x, i);",
    "    for (int j = 0; j < nz; j++) @{N}__mv(v, y, ny + 1 + j, z, j);",
    "    if (!v->data[y - 1].leaf)",
    "        for (int j = 0; j <= nz; j++) v->data[y - 1].kid[ny + 1 + j] = v->data[z - 1].kid[j];",
    "    v->data[y - 1].n = (unsigned short)(ny + 1 + nz);",
    "    for (int j = i; j + 1 < n; j++) @{N}__mv(v, x, j, x, j + 1);",
    "    for (int j = i + 1; j < n; j++) v->data[x - 1].kid[j] = v->data[x - 1].kid[j + 1];",
    "    v->data[x - 1].n = (unsigned short)(n - 1);",
    "    @{N}__free(v, z);",
    "    if (n == 1) { v->root = y; @{N}__free(v, x); }",
    "}"]).
%% -- __fill: the child i of x holds 7 entries; it takes one from a sibling that holds more through x, or is merged
%%    with a sibling. It gives the node that holds the child's entries then
ccllib_tree_text('_fill', _, [
    "static unsigned @{N}__fill(@N *v, unsigned x, int i) {",
    "    unsigned c = v->data[x - 1].kid[i];",
    "    int n = v->data[x - 1].n, nc = v->data[c - 1].n;",
    "    if (i > 0 && v->data[v->data[x - 1].kid[i - 1] - 1].n >= 8) {",
    "        unsigned l = v->data[x - 1].kid[i - 1];",
    "        int nl = v->data[l - 1].n;",
    "        for (int j = nc; j > 0; j--) @{N}__mv(v, c, j, c, j - 1);",
    "        @{N}__mv(v, c, 0, x, i - 1);",
    "        @{N}__mv(v, x, i - 1, l, nl - 1);",
    "        if (!v->data[c - 1].leaf) {",
    "            for (int j = nc + 1; j > 0; j--) v->data[c - 1].kid[j] = v->data[c - 1].kid[j - 1];",
    "            v->data[c - 1].kid[0] = v->data[l - 1].kid[nl];",
    "        }",
    "        v->data[c - 1].n = (unsigned short)(nc + 1);",
    "        v->data[l - 1].n = (unsigned short)(nl - 1);",
    "        return c;",
    "    }",
    "    if (i < n && v->data[v->data[x - 1].kid[i + 1] - 1].n >= 8) {",
    "        unsigned r = v->data[x - 1].kid[i + 1];",
    "        int nr = v->data[r - 1].n;",
    "        @{N}__mv(v, c, nc, x, i);",
    "        @{N}__mv(v, x, i, r, 0);",
    "        for (int j = 0; j + 1 < nr; j++) @{N}__mv(v, r, j, r, j + 1);",
    "        if (!v->data[c - 1].leaf) {",
    "            v->data[c - 1].kid[nc + 1] = v->data[r - 1].kid[0];",
    "            for (int j = 0; j < nr; j++) v->data[r - 1].kid[j] = v->data[r - 1].kid[j + 1];",
    "        }",
    "        v->data[c - 1].n = (unsigned short)(nc + 1);",
    "        v->data[r - 1].n = (unsigned short)(nr - 1);",
    "        return c;",
    "    }",
    "    if (i < n) { @{N}__merge(v, x, i); return c; }",
    "    c = v->data[x - 1].kid[i - 1];",
    "    @{N}__merge(v, x, i - 1);",
    "    return c;",
    "}"]).
%% -- __put: the key k goes into the slot i of the leaf x, which has room; the one count of an insert's change
ccllib_tree_text('_put', _, [
    "static void @{N}__put(@N *v, unsigned x, int i, @K k) {",
    "    for (int j = v->data[x - 1].n; j > i; j--) @{N}__mv(v, x, j, x, j - 1);",
    "    v->data[x - 1].key[i] = k;",
    multi-"    v->data[x - 1].seq[i] = v->seq++;",
    "    v->data[x - 1].n++;",
    "    v->len++;",
    "    v->mods++;",
    "}"]).
%% -- __ins: the key goes where it belongs, and *at and *slot are its node and its slot: 1, a new entry; 0, a unique
%%    tree had an entry of an equal key, which they name, and NOTHING of the tree changed. The first walk down changes
%%    nothing: it finds the equal key, or the leaf of the new entry, which takes it where it has room. Only for a full
%%    leaf a second walk splits each full node that it meets on its way down, so that no split goes back up
ccllib_tree_text('_ins', _, [
    "static int @{N}__ins(@N *v, @K k, unsigned *at, int *slot) {",
    "    unsigned x;",
    "    if (!v->root) v->root = @{N}__node(v, 1);",
    "    x = (unsigned)v->root;",
    "    for (;;) {",
    "        int n = v->data[x - 1].n, i = 0;",
    unique-"        while (i < n && @{N}__lt(v->data[x - 1].key[i], k)) i++;",
    unique-"        if (i < n && !@{N}__lt(k, v->data[x - 1].key[i])) { *at = x; *slot = i; return 0; }",
    multi-"        while (i < n && !@{N}__lt(k, v->data[x - 1].key[i])) i++;",
    "        if (v->data[x - 1].leaf) {",
    "            if (n == 15) break;",
    "            @{N}__put(v, x, i, k);",
    "            *at = x;",
    "            *slot = i;",
    "            return 1;",
    "        }",
    "        x = v->data[x - 1].kid[i];",
    "    }",
    "    if (v->data[v->root - 1].n == 15) {",
    "        unsigned r = @{N}__node(v, 0);",
    "        v->data[r - 1].kid[0] = (unsigned)v->root;",
    "        v->root = r;",
    "        @{N}__split(v, r, 0);",
    "    }",
    "    x = (unsigned)v->root;",
    "    for (;;) {",
    "        int n = v->data[x - 1].n, i = 0;",
    unique-"        while (i < n && @{N}__lt(v->data[x - 1].key[i], k)) i++;",
    multi-"        while (i < n && !@{N}__lt(k, v->data[x - 1].key[i])) i++;",
    "        if (v->data[x - 1].leaf) {",
    "            @{N}__put(v, x, i, k);",
    "            *at = x;",
    "            *slot = i;",
    "            return 1;",
    "        }",
    "        if (v->data[v->data[x - 1].kid[i] - 1].n == 15) {",
    "            @{N}__split(v, x, i);",
    unique-"            if (@{N}__lt(v->data[x - 1].key[i], k)) i++;",
    multi-"            if (!@{N}__lt(k, v->data[x - 1].key[i])) i++;",
    "        }",
    "        x = v->data[x - 1].kid[i];",
    "    }",
    "}"]).
%% -- __del: the entry (k, s) is taken away: 1, or 0 where the tree has none, and then NOTHING of the tree changed.
%%    The first walk down changes nothing: it finds the entry, and takes it from a leaf that keeps 7 entries or is the
%%    root. Else __take walks down again. The one count of an erase's change
ccllib_tree_text('_del', _, [
    "static int @{N}__del(@N *v, @K k, size_t s) {",
    "    unsigned x = (unsigned)v->root;",
    "    int taken = 0;",
    "    if (!x) return 0;",
    "    for (;;) {",
    "        int n = v->data[x - 1].n, i = 0;",
    "        while (i < n && @{N}__eb(v, x, i, k, s)) i++;",
    "        if (i < n && !@{N}__be(v, x, i, k, s)) {",
    "            if (v->data[x - 1].leaf && (n > 7 || x == v->root)) {",
    "                for (int j = i; j + 1 < n; j++) @{N}__mv(v, x, j, x, j + 1);",
    "                v->data[x - 1].n--;",
    "                taken = 1;",
    "            }",
    "            break;",
    "        }",
    "        if (v->data[x - 1].leaf) return 0;",
    "        x = v->data[x - 1].kid[i];",
    "    }",
    "    if (!taken) @{N}__take(v, k, s);",
    "    v->len--;",
    "    v->mods++;",
    "    if (v->len == 0) { @{N}__free(v, (unsigned)v->root); v->root = 0; }",
    "    return 1;",
    "}"]).
%% -- __take: the entry (k, s), which the tree holds, is taken from it by one walk down, which fills each node of 7
%%    entries that it meets from a sibling or merges it with one, so that nothing goes back up. An inner node's entry
%%    gives its slot to the entry before it or after it, which is taken from its leaf then. A tree that does not hold
%%    the entry here is no tree in its order (a comparison that is no order): the program stops
ccllib_tree_text('_take', _, [
    "static void @{N}__take(@N *v, @K k, size_t s) {",
    "    unsigned x = (unsigned)v->root;",
    "    for (;;) {",
    "        int n = v->data[x - 1].n, i = 0, found;",
    "        while (i < n && @{N}__eb(v, x, i, k, s)) i++;",
    "        found = i < n && !@{N}__be(v, x, i, k, s);",
    "        if (v->data[x - 1].leaf) {",
    "            if (!found) abort();",
    "            for (int j = i; j + 1 < n; j++) @{N}__mv(v, x, j, x, j + 1);",
    "            v->data[x - 1].n--;",
    "            return;",
    "        }",
    "        if (found) {",
    "            unsigned y = v->data[x - 1].kid[i], z = v->data[x - 1].kid[i + 1];",
    "            if (v->data[y - 1].n >= 8) {",
    "                unsigned w = y;",
    "                while (!v->data[w - 1].leaf) w = v->data[w - 1].kid[v->data[w - 1].n];",
    "                @{N}__mv(v, x, i, w, v->data[w - 1].n - 1);",
    "                k = v->data[x - 1].key[i];",
    "                s = @{N}__seq(v, (size_t)x * 16 + i);",
    "                x = y;",
    "            } else if (v->data[z - 1].n >= 8) {",
    "                unsigned w = z;",
    "                while (!v->data[w - 1].leaf) w = v->data[w - 1].kid[0];",
    "                @{N}__mv(v, x, i, w, 0);",
    "                k = v->data[x - 1].key[i];",
    "                s = @{N}__seq(v, (size_t)x * 16 + i);",
    "                x = z;",
    "            } else {",
    "                @{N}__merge(v, x, i);",
    "                x = y;",
    "            }",
    "        } else {",
    "            unsigned c = v->data[x - 1].kid[i];",
    "            if (v->data[c - 1].n == 7) c = @{N}__fill(v, x, i);",
    "            x = c;",
    "        }",
    "    }",
    "}"]).
%% -- where an entry stands: its node's number * 16 + its slot, 0 for none. __lb, the first entry whose key is not
%%    before k; __ub, the first whose key is after k; __after and __before, the entry after and before the entry (k, s);
%%    __first and __last; __nx and __pv step
ccllib_tree_text('_lb', _, [
    "static size_t @{N}__lb(const @N *v, @K k) {",
    "    size_t best = 0;",
    "    unsigned x = (unsigned)v->root;",
    "    while (x) {",
    "        int n = v->data[x - 1].n, i = 0;",
    "        while (i < n && @{N}__lt(v->data[x - 1].key[i], k)) i++;",
    "        if (i < n) best = (size_t)x * 16 + i;",
    "        if (v->data[x - 1].leaf) break;",
    "        x = v->data[x - 1].kid[i];",
    "    }",
    "    return best;",
    "}"]).
ccllib_tree_text('_ub', _, [
    "static size_t @{N}__ub(const @N *v, @K k) {",
    "    size_t best = 0;",
    "    unsigned x = (unsigned)v->root;",
    "    while (x) {",
    "        int n = v->data[x - 1].n, i = 0;",
    "        while (i < n && !@{N}__lt(k, v->data[x - 1].key[i])) i++;",
    "        if (i < n) best = (size_t)x * 16 + i;",
    "        if (v->data[x - 1].leaf) break;",
    "        x = v->data[x - 1].kid[i];",
    "    }",
    "    return best;",
    "}"]).
ccllib_tree_text('_after', _, [
    "static size_t @{N}__after(const @N *v, @K k, size_t s) {",
    "    size_t best = 0;",
    "    unsigned x = (unsigned)v->root;",
    "    while (x) {",
    "        int n = v->data[x - 1].n, i = 0;",
    "        while (i < n && !@{N}__be(v, x, i, k, s)) i++;",
    "        if (i < n) best = (size_t)x * 16 + i;",
    "        if (v->data[x - 1].leaf) break;",
    "        x = v->data[x - 1].kid[i];",
    "    }",
    "    return best;",
    "}"]).
ccllib_tree_text('_before', _, [
    "static size_t @{N}__before(const @N *v, @K k, size_t s) {",
    "    size_t best = 0;",
    "    unsigned x = (unsigned)v->root;",
    "    while (x) {",
    "        int n = v->data[x - 1].n, i = 0;",
    "        while (i < n && @{N}__eb(v, x, i, k, s)) i++;",
    "        if (i > 0) best = (size_t)x * 16 + i - 1;",
    "        if (v->data[x - 1].leaf) break;",
    "        x = v->data[x - 1].kid[i];",
    "    }",
    "    return best;",
    "}"]).
ccllib_tree_text('_first', _, [
    "static size_t @{N}__first(const @N *v) {",
    "    unsigned x = (unsigned)v->root;",
    "    if (!x) return 0;",
    "    while (!v->data[x - 1].leaf) x = v->data[x - 1].kid[0];",
    "    return (size_t)x * 16;",
    "}"]).
ccllib_tree_text('_last', _, [
    "static size_t @{N}__last(const @N *v) {",
    "    unsigned x = (unsigned)v->root;",
    "    if (!x) return 0;",
    "    while (!v->data[x - 1].leaf) x = v->data[x - 1].kid[v->data[x - 1].n];",
    "    return (size_t)x * 16 + v->data[x - 1].n - 1;",
    "}"]).
ccllib_tree_text('_nx', _, [
    "static size_t @{N}__nx(const @N *v, size_t q) {",
    "    unsigned x = (unsigned)(q >> 4);",
    "    int i = (int)(q & 15);",
    "    if (!v->data[x - 1].leaf) {",
    "        x = v->data[x - 1].kid[i + 1];",
    "        while (!v->data[x - 1].leaf) x = v->data[x - 1].kid[0];",
    "        return (size_t)x * 16;",
    "    }",
    "    if (i + 1 < v->data[x - 1].n) return q + 1;",
    "    return @{N}__after(v, v->data[x - 1].key[i], @{N}__seq(v, q));",
    "}"]).
ccllib_tree_text('_pv', _, [
    "static size_t @{N}__pv(const @N *v, size_t q) {",
    "    unsigned x = (unsigned)(q >> 4);",
    "    int i = (int)(q & 15);",
    "    if (!v->data[x - 1].leaf) {",
    "        x = v->data[x - 1].kid[i];",
    "        while (!v->data[x - 1].leaf) x = v->data[x - 1].kid[v->data[x - 1].n];",
    "        return (size_t)x * 16 + v->data[x - 1].n - 1;",
    "    }",
    "    if (i > 0) return q - 1;",
    "    return @{N}__before(v, v->data[x - 1].key[i], @{N}__seq(v, q));",
    "}"]).
%% -- a place: __place makes one of where an entry stands, with the low 28 bits of the tree's count of changes (a
%%    node's number is under 2^31, so where an entry stands is under 2^35); __pos gives where the entry of a place
%%    stands, and stops the program at a place that the tree's changes ended or that is no entry's
ccllib_tree_text('_place', _, [
    "static size_t @{N}__place(const @N *v, size_t q) { return q ? (q << 28) | (v->mods & 0xfffffff) : 0; }"]).
ccllib_tree_text('_pos', _, [
    "static size_t @{N}__pos(const @N *v, size_t p) {",
    "    size_t q = p >> 28, x = q >> 4;",
    "    if ((p & 0xfffffff) != (v->mods & 0xfffffff) || x == 0 || x > v->top) abort();",
    "    if (v->data[x - 1].leaf == 2 || (q & 15) >= v->data[x - 1].n) abort();",
    "    return q;",
    "}"]).
%% -- the capacity
ccllib_tree_text(size, _, ["size_t @{N}_size(const @N *v) { return v->len; }"]).
ccllib_tree_text(len, _, ["size_t @{N}_len(const @N *v) { return v->len; }"]).
ccllib_tree_text(empty, _, ["int @{N}_empty(const @N *v) { return v->len == 0; }"]).
ccllib_tree_text(max_size, _, ["size_t @{N}_max_size(const @N *v) { return (size_t)0x7fffffffu * 7; }"]).
%% -- the places and what stands at one
ccllib_tree_text(begin, _, ["size_t @{N}_begin(const @N *v) { return @{N}__place(v, @{N}__first(v)); }"]).
ccllib_tree_text(end, _, ["size_t @{N}_end(const @N *v) { return 0; }"]).
ccllib_tree_text(next, _, [
    "size_t @{N}_next(const @N *v, size_t p) { return @{N}__place(v, @{N}__nx(v, @{N}__pos(v, p))); }"]).
ccllib_tree_text(prev, _, [
    "size_t @{N}_prev(const @N *v, size_t p) {",
    "    if (p == 0) return @{N}__place(v, @{N}__last(v));",
    "    return @{N}__place(v, @{N}__pv(v, @{N}__pos(v, p)));",
    "}"]).
ccllib_tree_text(key, _, [
    "@K @{N}_key(const @N *v, size_t p) {",
    "    size_t q = @{N}__pos(v, p);",
    "    return v->data[(q >> 4) - 1].key[q & 15];",
    "}"]).
ccllib_tree_text(value, tree(map, _, _, _, _, _), [
    "@V @{N}_value(const @N *v, size_t p) {",
    "    size_t q = @{N}__pos(v, p);",
    "    return v->data[(q >> 4) - 1].val[q & 15];",
    "}"]).
ccllib_tree_text(set_value, tree(map, _, _, _, _, _), [
    "void @{N}_set_value(@N *v, size_t p, @V y) {",
    "    size_t q = @{N}__pos(v, p);",
    "    v->data[(q >> 4) - 1].val[q & 15] = y;",
    "}"]).
%% -- the lookups by a key
ccllib_tree_text(find, _, [
    "size_t @{N}_find(const @N *v, @K k) {",
    "    size_t q = @{N}__lb(v, k);",
    "    if (q && @{N}__lt(k, v->data[(q >> 4) - 1].key[q & 15])) q = 0;",
    "    return @{N}__place(v, q);",
    "}"]).
ccllib_tree_text(contains, _, [
    "int @{N}_contains(const @N *v, @K k) {",
    "    size_t q = @{N}__lb(v, k);",
    "    return q && !@{N}__lt(k, v->data[(q >> 4) - 1].key[q & 15]);",
    "}"]).
ccllib_tree_text(count, _, [
    "size_t @{N}_count(const @N *v, @K k) {",
    "    size_t n = 0;",
    "    size_t q = @{N}__lb(v, k);",
    "    while (q && !@{N}__lt(k, v->data[(q >> 4) - 1].key[q & 15])) { n++; q = @{N}__nx(v, q); }",
    "    return n;",
    "}"]).
ccllib_tree_text(lower_bound, _, [
    "size_t @{N}_lower_bound(const @N *v, @K k) { return @{N}__place(v, @{N}__lb(v, k)); }"]).
ccllib_tree_text(upper_bound, _, [
    "size_t @{N}_upper_bound(const @N *v, @K k) { return @{N}__place(v, @{N}__ub(v, k)); }"]).
ccllib_tree_text(at, tree(map, unique, _, _, _, _), [
    "@V @{N}_at(const @N *v, @K k) {",
    "    size_t q = @{N}__lb(v, k);",
    "    if (!q || @{N}__lt(k, v->data[(q >> 4) - 1].key[q & 15])) abort();",
    "    return v->data[(q >> 4) - 1].val[q & 15];",
    "}"]).
ccllib_tree_text(get, tree(map, unique, _, _, _, _), ["@V @{N}_get(const @N *v, @K k) { return @{N}_at(v, k); }"]).
ccllib_tree_text(index, tree(map, unique, _, _, _, _), [
    "@V *@{N}_index(@N *v, @K k) tie v {",
    "    unsigned x;",
    "    int i;",
    "    if (@{N}__ins(v, k, &x, &i)) memset(&v->data[x - 1].val[i], 0, sizeof(@V));",
    "    return &v->data[x - 1].val[i];",
    "}"]).
%% -- the modifiers
ccllib_tree_text(insert, tree(set, _, _, _, _, _), [
    "int @{N}_insert(@N *v, @K k) {",
    "    unsigned x;",
    "    int i;",
    "    return @{N}__ins(v, k, &x, &i);",
    "}"]).
ccllib_tree_text(insert, tree(map, _, _, _, _, _), [
    "int @{N}_insert(@N *v, @K k, @V y) {",
    "    unsigned x;",
    "    int i;",
    "    if (!@{N}__ins(v, k, &x, &i)) return 0;",
    "    v->data[x - 1].val[i] = y;",
    "    return 1;",
    "}"]).
ccllib_tree_text(emplace, tree(set, _, _, _, _, _), ["int @{N}_emplace(@N *v, @K k) { return @{N}_insert(v, k); }"]).
ccllib_tree_text(emplace, tree(map, _, _, _, _, _), [
    "int @{N}_emplace(@N *v, @K k, @V y) { return @{N}_insert(v, k, y); }"]).
ccllib_tree_text(try_emplace, tree(map, unique, _, _, _, _), [
    "int @{N}_try_emplace(@N *v, @K k, @V y) { return @{N}_insert(v, k, y); }"]).
ccllib_tree_text(insert_or_assign, tree(map, unique, _, _, _, _), [
    "int @{N}_insert_or_assign(@N *v, @K k, @V y) {",
    "    unsigned x;",
    "    int i, r = @{N}__ins(v, k, &x, &i);",
    "    v->data[x - 1].val[i] = y;",
    "    return r;",
    "}"]).
ccllib_tree_text(put, tree(map, unique, _, _, _, _), [
    "void @{N}_put(@N *v, @K k, @V y) { @{N}_insert_or_assign(v, k, y); }"]).
ccllib_tree_text(insert_range, tree(set, _, _, _, _, _), [
    "void @{N}_insert_range(@N *v, const @K *a, size_t n) {",
    "    for (size_t j = 0; j < n; j++) @{N}_insert(v, a[j]);",
    "}"]).
ccllib_tree_text(erase, _, [
    "size_t @{N}_erase(@N *v, @K k) {",
    unique-"    return (size_t)@{N}__del(v, k, 0);",
    multi-"    size_t n = 0;",
    multi-"    for (;;) {",
    multi-"        size_t q = @{N}__lb(v, k);",
    multi-"        if (!q || @{N}__lt(k, v->data[(q >> 4) - 1].key[q & 15])) break;",
    multi-"        @{N}__del(v, k, @{N}__seq(v, q));",
    multi-"        n++;",
    multi-"    }",
    multi-"    return n;",
    "}"]).
ccllib_tree_text(erase_at, _, [
    "size_t @{N}_erase_at(@N *v, size_t p) {",
    "    size_t q = @{N}__pos(v, p), s = @{N}__seq(v, q);",
    "    @K k = v->data[(q >> 4) - 1].key[q & 15];",
    "    @{N}__del(v, k, s);",
    "    return @{N}__place(v, @{N}__after(v, k, s));",
    "}"]).
ccllib_tree_text(clear, _, ["void @{N}_clear(@N *v) { v->len = 0; v->top = 0; v->free = 0; v->root = 0; v->mods++; }"]).
ccllib_tree_text(swap, _, [
    "void @{N}_swap(@N *a, @N *b) {",
    "    size_t n = a->len, c = a->cap, t = a->top, f = a->free, r = a->root;",
    "    size_t m = (a->mods > b->mods ? a->mods : b->mods) + 1;",
    "    a->len = b->len; a->cap = b->cap; a->top = b->top; a->free = b->free; a->root = b->root; a->mods = m;",
    "    b->len = n; b->cap = c; b->top = t; b->free = f; b->root = r; b->mods = m;",
    multi-"    n = a->seq; a->seq = b->seq; b->seq = n;",
    "    own @{N}_node *d = a->data;",
    "    a->data = b->data;",
    "    b->data = d;",
    "}"]).
ccllib_tree_text(merge, _, [
    "void @{N}_merge(@N *v, @N *w) {",
    "    @N rest = {0};",
    "    if (v == w) return;",
    "    for (size_t q = @{N}__first(w); q; q = @{N}__nx(w, q)) {",
    "        unsigned x, y;",
    "        int i, j;",
    "        if (@{N}__ins(v, w->data[(q >> 4) - 1].key[q & 15], &x, &i)) {",
    map-"            v->data[x - 1].val[i] = w->data[(q >> 4) - 1].val[q & 15];",
    "        } else {",
    "            @{N}__ins(&rest, w->data[(q >> 4) - 1].key[q & 15], &y, &j);",
    map-"            rest.data[y - 1].val[j] = w->data[(q >> 4) - 1].val[q & 15];",
    "        }",
    "    }",
    "    @{N}_swap(w, &rest);",
    "}"]).
%% -- a value of arrays, which a literal calls; a copy; the comparisons that the operators call
ccllib_tree_text(from, tree(set, _, _, _, _, _), [
    "@N @{N}_from(const @K *a, size_t n) {",
    "    @N v = {0};",
    "    for (size_t j = 0; j < n; j++) { unsigned x; int i; @{N}__ins(&v, a[j], &x, &i); }",
    "    return v;",
    "}"]).
ccllib_tree_text(from, tree(map, _, _, _, _, _), [
    "@N @{N}_from(const @K *a, const @V *b, size_t n) {",
    "    @N v = {0};",
    "    for (size_t j = 0; j < n; j++) {",
    "        unsigned x;",
    "        int i;",
    "        if (@{N}__ins(&v, a[j], &x, &i)) v.data[x - 1].val[i] = b[j];",
    "    }",
    "    return v;",
    "}"]).
ccllib_tree_text(clone, _, [
    "@N @{N}_clone(const @N *v) {",
    "    @N w = {0};",
    "    if (v->top) {",
    "        own @{N}_node *d = (@{N}_node *)malloc(v->top * sizeof(@{N}_node));",
    "        if (!d) abort();",
    "        memcpy(d, v->data, v->top * sizeof(@{N}_node));",
    "        w.data = d;",
    "    }",
    "    w.len = v->len; w.cap = v->top; w.top = v->top; w.free = v->free; w.root = v->root;",
    multi-"    w.seq = v->seq;",
    "    return w;",
    "}"]).
ccllib_tree_text(eq, _, [
    "int @{N}_eq(const @N *a, const @N *b) {",
    "    size_t p = @{N}__first(a), q = @{N}__first(b);",
    "    if (a->len != b->len) return 0;",
    "    for (; p; p = @{N}__nx(a, p), q = @{N}__nx(b, q)) {",
    "        if (!(a->data[(p >> 4) - 1].key[p & 15] == b->data[(q >> 4) - 1].key[q & 15])) return 0;",
    map-"        if (!(a->data[(p >> 4) - 1].val[p & 15] == b->data[(q >> 4) - 1].val[q & 15])) return 0;",
    "    }",
    "    return 1;",
    "}"]).
ccllib_tree_text(lt, _, [
    "int @{N}_lt(const @N *a, const @N *b) {",
    "    size_t p = @{N}__first(a), q = @{N}__first(b);",
    "    for (; p && q; p = @{N}__nx(a, p), q = @{N}__nx(b, q)) {",
    "        if (a->data[(p >> 4) - 1].key[p & 15] < b->data[(q >> 4) - 1].key[q & 15]) return 1;",
    "        if (b->data[(q >> 4) - 1].key[q & 15] < a->data[(p >> 4) - 1].key[p & 15]) return 0;",
    map-"        if (a->data[(p >> 4) - 1].val[p & 15] < b->data[(q >> 4) - 1].val[q & 15]) return 1;",
    map-"        if (b->data[(q >> 4) - 1].val[q & 15] < a->data[(p >> 4) - 1].val[p & 15]) return 0;",
    "    }",
    "    return p == 0 && q != 0;",
    "}"]).
