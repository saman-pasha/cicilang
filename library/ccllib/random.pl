%% ccllib's <random.pl> (phase 1c): C++'s std::mt19937 and a few distributions. C++ writes `std::mt19937 rng;'; a
%% type macro of no arguments is written with its empty list, `mt19937<> rng;', as <any.pl> does. seed(rng, s) is the
%% standard Mersenne Twister's seed, next(rng) its next 32-bit value, discard(rng, n), min(rng), max(rng); uniform_int,
%% uniform_real and bernoulli take the engine and a bound, and shuffle a range and the engine.
%%
%% THE VALUES ARE LIBC++'S (1.6.4): an engine that no seed has seeded is seeded with 5489, std::mt19937's default
%% (through 1.6.3 it gave 0, its words all zero); uniform_int(r, lo, hi) is libc++'s uniform_int_distribution of the
%% operands' type: the range's bits drawn and a draw past the range thrown away, 32 bits a draw, two draws of a type of 64
%% bits (__independent_bits_engine), the whole range of the type where hi - lo + 1 wraps to 0 (through 1.6.3 a modulo, in
%% the unsigned type of the sum, so `uniform_int(r, -5, 5) < 0' was never true and the whole range divided by zero);
%% uniform_real(r, lo, hi) is (hi - lo) * generate_canonical(r) + lo, the canonical value of two draws of a double or a
%% long double and one of a float; bernoulli(r, p) is a canonical double below p; shuffle is libc++'s, from the first
%% element, each swapped with one of the elements at it or after it. A draw's 32 bits go to a floating number through a
%% signed long long, since valgrind does not know AVX-512's conversion of an unsigned one (0.283).
:- ensure_loaded(library(ccllib/ccllib)).
type_mt19937([], base([], [typedef(N)]), Items) :- ccl_instance_name(mt19937, [], N),
    ccl_c_items("typedef struct @N { uint32_t mt[624]; size_t idx; int seeded; } @N;", ['N' = name(N)], Items).
fn_mt19937(Name, [], Items) :- ccl_instance_name(mt19937, [], N), ccllib_random_fn(Name, Text), ccl_c_items(Text, ['N' = name(N)], Items).
ccllib_random_fn(seed, "void @{N}_seed(@N *r, uint32_t s) {
    r->mt[0] = s; r->idx = 624; r->seeded = 1;
    for (size_t i = 1; i < 624; i++) r->mt[i] = 1812433253u * (r->mt[i - 1] ^ (r->mt[i - 1] >> 30)) + (uint32_t)i;
}").
ccllib_random_fn('_twist', "static void @{N}__twist(@N *r) {
    for (size_t i = 0; i < 624; i++) { uint32_t y = (r->mt[i] & 0x80000000u) | (r->mt[(i + 1) % 624] & 0x7fffffffu); r->mt[i] = r->mt[(i + 397) % 624] ^ (y >> 1) ^ ((y & 1u) ? 0x9908b0dfu : 0u); }
    r->idx = 0;
}").
ccllib_random_fn(next, "uint32_t @{N}_next(@N *r) {
    if (!r->seeded) @{N}_seed(r, 5489u);
    if (r->idx >= 624) @{N}__twist(r);
    uint32_t y = r->mt[r->idx++]; y ^= y >> 11; y ^= (y << 7) & 0x9d2c5680u; y ^= (y << 15) & 0xefc60000u; y ^= y >> 18; return y;
}").
ccllib_random_fn(discard, "void @{N}_discard(@N *r, unsigned long long n) { while (n--) (void)@{N}_next(r); }").
ccllib_random_fn(min, "uint32_t @{N}_min(const @N *r) { (void)r; return 0u; }").
ccllib_random_fn(max, "uint32_t @{N}_max(const @N *r) { (void)r; return 4294967295u; }").
%% libc++'s __independent_bits_engine over the engine's 32 bits: w bits of n0 draws of w0 bits and of the rest of w0 + 1
ccllib_random_fn('_bits', "static uint64_t @{N}__bits(@N *r, int w) {
    int n = w / 32 + (w % 32 != 0), w0 = w / n, n0 = n - w % n, k;
    uint64_t s = 0, m0 = w0 >= 32 ? 0xffffffffu : ((uint64_t)1 << w0) - 1, m1 = w0 + 1 >= 32 ? 0xffffffffu : ((uint64_t)1 << (w0 + 1)) - 1;
    for (k = 0; k < n0; k++) { s = w0 < 64 ? s << w0 : 0; s += @{N}_next(r) & m0; }
    for (; k < n; k++) { s = w0 + 1 < 64 ? s << (w0 + 1) : 0; s += @{N}_next(r) & m1; }
    return s;
}").
%% libc++'s uniform_int_distribution: lo and a value of [0, rp) of the type's bits, a draw past rp thrown away; rp 0 is the
%% whole width, the draw's bits alone, as libc++ adds no lo there
ccllib_random_fn('_uniform', "static uint64_t @{N}__uniform(@N *r, uint64_t lo, uint64_t rp, int dt) {
    if (rp == 1) return lo;
    if (rp == 0) return @{N}__bits(r, dt);
    int w = dt - __builtin_clzll(rp) + (64 - dt) - 1;
    if (rp & ((dt == 64 ? ~(uint64_t)0 : (((uint64_t)1 << dt) - 1)) >> (dt - w))) w++;
    uint64_t u;
    do u = @{N}__bits(r, w); while (u >= rp);
    return u + lo;
}").
%% libc++'s generate_canonical<double> and <long double>, two draws, and <float>, one: the first draw the low part
ccllib_random_fn('_canon', "static double @{N}__canon(@N *r) { double s = (double)(long long)@{N}_next(r); s += (double)(long long)@{N}_next(r) * 4294967296.0; return s / 18446744073709551616.0; }").
ccllib_random_fn('_canonl', "static long double @{N}__canonl(@N *r) { long double s = (long double)(long long)@{N}_next(r); s += (long double)(long long)@{N}_next(r) * 4294967296.0L; return s / 18446744073709551616.0L; }").
ccllib_random_fn('_canonf', "static float @{N}__canonf(@N *r) { float s = (float)(long long)@{N}_next(r); return s / 4294967296.0f; }").

%% the engine's instance: the type macro is `mt19937<>'
ccllib_random_engine(R, N) :- ccl_type_of(R, T), T = base(_, [typedef(N)]), nb_getval('$ccl_instances', Is), memberchk(inst(mt19937, [], base(_, [typedef(N)]), _), Is).
%% a value in [lo, hi] of the operands' type, each operand read once
ccl_macro_uniform_int(R, Lo, Hi, E) :- ccllib_random_engine(R, N),
    ccl_c_expr("({ __typeof__((@Lo) + (@Hi)) __ccl_lo = @Lo, __ccl_hi = @Hi; (__typeof__(__ccl_lo))(sizeof(__ccl_lo) <= 4
        ? (uint32_t)@{N}__uniform(&@R, (uint32_t)__ccl_lo, (uint32_t)((uint32_t)__ccl_hi - (uint32_t)__ccl_lo + 1u), 32)
        : @{N}__uniform(&@R, (uint64_t)__ccl_lo, (uint64_t)__ccl_hi - (uint64_t)__ccl_lo + 1u, 64)); })",
               ['R' = expr(R), 'Lo' = expr(Lo), 'Hi' = expr(Hi), 'N' = name(N)], E).
%% a value in [lo, hi): (hi - lo) * the canonical value + lo, in the operands' floating type, a double where they are integers
ccl_macro_uniform_real(R, Lo, Hi, E) :- ccllib_random_engine(R, N), ccllib_random_real(Lo, Hi, T, C),
    atomic_list_concat(['({ ', T, ' __ccl_lo = @Lo, __ccl_hi = @Hi; (__ccl_hi - __ccl_lo) * @{N}__', C, '(&@R) + __ccl_lo; })'], Text),
    ccl_c_expr(Text, ['R' = expr(R), 'Lo' = expr(Lo), 'Hi' = expr(Hi), 'N' = name(N)], E).
ccllib_random_real(Lo, Hi, T, C) :-
    (   catch(( ccl_type_of(Lo, TL), ccl_type_of(Hi, TH) ), _, fail), ccllib_random_fp(TL, KL), ccllib_random_fp(TH, KH)
    ->  ( (KL == ld ; KH == ld) -> T = 'long double', C = canonl ; (KL == d ; KH == d) -> T = double, C = canon ; T = float, C = canonf )
    ;   T = double, C = canon ).
ccllib_random_fp(T, K) :- catch(ccl_resolve_type(T, base(_, W)), _, fail), msort(W, M),
    ( M == [float] -> K = f ; M == [double] -> K = d ; M == [double, long] -> K = ld ; K = i ), !.
ccllib_random_fp(_, i).
%% libc++'s bernoulli_distribution: a canonical double below p
ccl_macro_bernoulli(R, P, E) :- ccllib_random_engine(R, N),
    ccl_c_expr("(@{N}__canon(&@R) < (@P) ? 1 : 0)", ['R' = expr(R), 'P' = expr(P), 'N' = name(N)], E).
%% shuffle(v, rng): libc++'s std::shuffle -- from the first element, each swapped with an element at it or after it, by
%% uniform_int_distribution<ptrdiff_t> of [0, d]
ccl_macro_shuffle(V, R, S) :- ccllib_alg_mut(V, _, N, T, 'shuffle'), ccllib_random_engine(R, EN),
    ccl_c_stmts("{ size_t __ccl_n = @{N}_size(&@V); if (__ccl_n > 1) { for (size_t __ccl_f = 0, __ccl_d = __ccl_n - 1; __ccl_d > 0; __ccl_f++, __ccl_d--) { size_t __ccl_i = (size_t)@{EN}__uniform(&@R, 0, (uint64_t)__ccl_d + 1u, 64); if (__ccl_i != 0) { @T __ccl_x = @{N}_at(&@V, __ccl_f); *@{N}_index(&@V, __ccl_f) = @{N}_at(&@V, __ccl_f + __ccl_i); *@{N}_index(&@V, __ccl_f + __ccl_i) = __ccl_x; } } } }",
                ['V' = expr(V), 'R' = expr(R), 'N' = name(N), 'T' = type(T), 'EN' = name(EN)], S).
