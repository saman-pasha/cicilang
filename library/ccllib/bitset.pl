%% ccllib's <bitset.pl> (0.286; CCLLIB.md's phase 1a): std::bitset for cicilang's C, and for cicilang++ beside libc++'s.
%%
%%   #include <bitset.pl>
%%   bitset<12> a;                  no bit is set: an instance's object is born zero (0.285)
%%   bitset<12> b = 0x0f0;          of a number, cut to its 12 bits; bitset<12> c = "1010"; of a text of 0 and 1
%%   set(a, 3);  a[5] = 1;  if (a[3] && test(a, 5)) flip(a, 3);  n = count(a);
%%   d := a & ~b | c << 2;  a ^= b;  a >>= 1;  if (a == d) reset(a);
%%
%% type_bitset/3 gives the instance's type, `bitset_12', a struct of words of 64 bits: a value with no heap and no drop,
%% so `b := a' and `f(a)' copy, as std::bitset's do. fn_bitset/3 gives ONE function of the instance at its first use,
%% a call's or an operator's. The names are std::bitset's. What differs from C++:
%%   test(b, i), b[i], b[i] = x, set(b, i), reset(b, i) and flip(b, i) stop the program (abort) at a place past the
%%     last bit, where C++'s test, set, reset and flip throw and its [] is undefined;
%%   b[i] is a bit's VALUE, the int 0 or 1, and b[i] = x writes the bit (0.284); a bit has no place of its own, where
%%     C++'s b[i] is a reference to it: `b[i] |= x' and `&b[i]' are refused by name -- flip(b, i) and set(b, i, x) are
%%     the calls --, and `~b[i]' is C's `~' of the number, where C++'s is the other bit: write `!b[i]';
%%   set, reset and flip give nothing back, where C++'s give the set of bits, so that calls chain;
%%   bitset<12> c = "1010" reads its text as C++'s constructor does -- the LAST character is the bit 0, the first 12
%%     characters are taken -- and stops the program at a character that is no 0 and no 1, where C++ throws;
%%   to_ulong(b) and to_ullong(b) stop the program where a bit past the result's width is set, where C++'s throw;
%%   there is no to_string (ccllib's string comes later) and no hash; a list literal makes no bitset;
%%   the operators take their operands by value: `a & b | c' chains, and an operand of 1000 bits is 125 bytes copied.
%%     `a &= b' changes a in its place. Both operands are sets of one count: a number is no operand -- `b == 5' and
%%     `b &= 5', which C++ takes through its constructor, are refused by name (`no conversion from 'int' to
%%     'bitset_12''), and so is a set of another count; `bitset<12> five = 5;' makes the set first.
:- ensure_loaded(library(ccllib/ccllib)).
type_bitset([int(K)], base([], [typedef(N)]), Items) :- integer(K), !,
    ( K >= 1 -> true ; ccl_macro_error('a bitset has one bit at least') ),
    ccllib_bitset_holes(K, N, Hs), ccl_c_items("typedef struct @N { unsigned long long w[@w]; } @N;", Hs, Items).
type_bitset(_, _, _) :- ccl_macro_error('a bitset takes the count of its bits, a number').
fn_bitset(Name, [int(K)], Items) :-
    integer(K), ccllib_bitset_fn(Name, Text), ccllib_bitset_holes(K, _, Hs), ccl_c_items(Text, Hs, Items).
%% the holes of a text: @N the instance's name, @k the count of its bits, @w the count of its words
ccllib_bitset_holes(K, N, ['N' = name(N), k = name(KA), w = name(WA)]) :-
    ccl_instance_name(bitset, [K], N), W is (K + 63) // 64, atom_number(KA, K), atom_number(WA, W).
%% a function's C text by its name. `_trim' is an inner helper: the bits of the last word past the count are ZERO after
%% every function, which count, any, all and `==' stand on
ccllib_bitset_fn('_trim', "static void @{N}__trim(@N *v) {
    v->w[@w - 1] &= @k % 64 ? (1ULL << (@k % 64)) - 1 : ~0ULL;
}").
ccllib_bitset_fn(size, "size_t @{N}_size(const @N *v) { return @k; }").
ccllib_bitset_fn(count, "size_t @{N}_count(const @N *v) {
    size_t n = 0;
    for (size_t i = 0; i < @w; i++) n += (size_t)__builtin_popcountll(v->w[i]);
    return n;
}").
ccllib_bitset_fn(any, "int @{N}_any(const @N *v) {
    for (size_t i = 0; i < @w; i++) if (v->w[i]) return 1;
    return 0;
}").
ccllib_bitset_fn(none, "int @{N}_none(const @N *v) { return !@{N}_any(v); }").
ccllib_bitset_fn(all, "int @{N}_all(const @N *v) { return @{N}_count(v) == @k; }").
ccllib_bitset_fn(test, "int @{N}_test(const @N *v, size_t i) {
    if (i >= @k) abort();
    return (int)(v->w[i / 64] >> (i % 64) & 1);
}").
%% b[i] and b[i] = x: a bit's value, and its write (the operators' part 2, 0.284)
ccllib_bitset_fn(item, "int @{N}_item(const @N *v, size_t i) {
    if (i >= @k) abort();
    return (int)(v->w[i / 64] >> (i % 64) & 1);
}").
ccllib_bitset_fn(set_item, "void @{N}_set_item(@N *v, size_t i, int x) {
    if (i >= @k) abort();
    if (x) v->w[i / 64] |= 1ULL << (i % 64); else v->w[i / 64] &= ~(1ULL << (i % 64));
}").
%% set(b), set(b, i) and set(b, i, x); reset(b) and reset(b, i); flip(b) and flip(b, i): told by the count of their
%% arguments
ccllib_bitset_fn(set, "void @{N}_set(@N *v) {
    for (size_t i = 0; i < @w; i++) v->w[i] = ~0ULL;
    @{N}__trim(v);
}").
ccllib_bitset_fn(set2, "void @{N}_set2(@N *v, size_t i) { @{N}_set_item(v, i, 1); }").
ccllib_bitset_fn(set3, "void @{N}_set3(@N *v, size_t i, int x) { @{N}_set_item(v, i, x); }").
ccllib_bitset_fn(reset, "void @{N}_reset(@N *v) { for (size_t i = 0; i < @w; i++) v->w[i] = 0; }").
ccllib_bitset_fn(reset2, "void @{N}_reset2(@N *v, size_t i) { @{N}_set_item(v, i, 0); }").
ccllib_bitset_fn(flip, "void @{N}_flip(@N *v) {
    for (size_t i = 0; i < @w; i++) v->w[i] = ~v->w[i];
    @{N}__trim(v);
}").
ccllib_bitset_fn(flip2, "void @{N}_flip2(@N *v, size_t i) {
    if (i >= @k) abort();
    v->w[i / 64] ^= 1ULL << (i % 64);
}").
%% the numbers of a set: the program stops where a bit past the result's width is set
ccllib_bitset_fn(to_ullong, "unsigned long long @{N}_to_ullong(const @N *v) {
    for (size_t i = 1; i < @w; i++) if (v->w[i]) abort();
    return v->w[0];
}").
ccllib_bitset_fn(to_ulong, "unsigned long @{N}_to_ulong(const @N *v) {
    unsigned long long x = @{N}_to_ullong(v);
    if ((unsigned long long)(unsigned long)x != x) abort();
    return (unsigned long)x;
}").
%% a set made of a value of another type (0.285): of a number, cut to the count of the bits; of a text of 0 and 1, whose
%% LAST character is the bit 0 -- C's literal and C++'s
ccllib_bitset_fn(of, "@N @{N}_of(unsigned long long x) {
    @N r = {0};
    r.w[0] = x;
    @{N}__trim(&r);
    return r;
}").
ccllib_bitset_fn('_text', "static @N @{N}__text(const char *s) {
    @N r = {0};
    size_t n = strlen(s), m = n < @k ? n : @k;
    for (size_t j = 0; j < n; j++) if (s[j] != '0' && s[j] != '1') abort();
    for (size_t j = 0; j < m; j++) if (s[m - 1 - j] == '1') r.w[j / 64] |= 1ULL << (j % 64);
    return r;
}").
ccllib_bitset_fn(of_ptr_char, "@N @{N}_of_ptr_char(char *s) { return @{N}__text(s); }").
ccllib_bitset_fn(of_ptr_const_char, "@N @{N}_of_ptr_const_char(const char *s) { return @{N}__text(s); }").
%% the operators (0.284): by value, so that they chain; the assignments change their object in its place
ccllib_bitset_fn(and, "@N @{N}_and(@N a, @N b) { for (size_t i = 0; i < @w; i++) a.w[i] &= b.w[i]; return a; }").
ccllib_bitset_fn(or, "@N @{N}_or(@N a, @N b) { for (size_t i = 0; i < @w; i++) a.w[i] |= b.w[i]; return a; }").
ccllib_bitset_fn(xor, "@N @{N}_xor(@N a, @N b) { for (size_t i = 0; i < @w; i++) a.w[i] ^= b.w[i]; return a; }").
ccllib_bitset_fn(compl, "@N @{N}_compl(@N a) {
    for (size_t i = 0; i < @w; i++) a.w[i] = ~a.w[i];
    @{N}__trim(&a);
    return a;
}").
ccllib_bitset_fn(shl, "@N @{N}_shl(@N a, size_t n) { @{N}_shl_assign(&a, n); return a; }").
ccllib_bitset_fn(shr, "@N @{N}_shr(@N a, size_t n) { @{N}_shr_assign(&a, n); return a; }").
ccllib_bitset_fn(eq, "int @{N}_eq(@N a, @N b) {
    for (size_t i = 0; i < @w; i++) if (a.w[i] != b.w[i]) return 0;
    return 1;
}").
ccllib_bitset_fn(and_assign, "void @{N}_and_assign(@N *a, @N b) {
    for (size_t i = 0; i < @w; i++) a->w[i] &= b.w[i];
}").
ccllib_bitset_fn(or_assign, "void @{N}_or_assign(@N *a, @N b) {
    for (size_t i = 0; i < @w; i++) a->w[i] |= b.w[i];
}").
ccllib_bitset_fn(xor_assign, "void @{N}_xor_assign(@N *a, @N b) {
    for (size_t i = 0; i < @w; i++) a->w[i] ^= b.w[i];
}").
%% a shift by n places: whole words by n / 64, then the bits of each word and of its neighbour by n % 64 -- a shift of
%% a word by 64 is no shift of C's, so the neighbour is taken only where n % 64 is not 0. A shift by the count of the
%% bits or more leaves none
ccllib_bitset_fn(shl_assign, "void @{N}_shl_assign(@N *a, size_t n) {
    size_t q = n / 64, r = n % 64;
    if (n >= @k) { for (size_t i = 0; i < @w; i++) a->w[i] = 0; return; }
    for (size_t i = @w; i-- > 0; ) {
        unsigned long long x = i >= q ? a->w[i - q] << r : 0;
        if (r && i > q) x |= a->w[i - q - 1] >> (64 - r);
        a->w[i] = x;
    }
    @{N}__trim(a);
}").
ccllib_bitset_fn(shr_assign, "void @{N}_shr_assign(@N *a, size_t n) {
    size_t q = n / 64, r = n % 64;
    if (n >= @k) { for (size_t i = 0; i < @w; i++) a->w[i] = 0; return; }
    for (size_t i = 0; i < @w; i++) {
        unsigned long long x = i + q < @w ? a->w[i + q] >> r : 0;
        if (r && i + q + 1 < @w) x |= a->w[i + q + 1] << (64 - r);
        a->w[i] = x;
    }
}").
