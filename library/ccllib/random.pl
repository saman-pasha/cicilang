%% ccllib's <random.pl> (phase 1c): C++'s std::mt19937 and a few distributions. C++ writes `std::mt19937 rng;'; a
%% type macro of no arguments is written with its empty list, `mt19937<> rng;', as <any.pl> does. seed(rng, s) is the
%% standard Mersenne Twister's seed, next(rng) its next 32-bit value, discard(rng, n), min(rng), max(rng); uniform_int,
%% uniform_real and bernoulli take the engine and a bound. The values are std::mt19937's own, so a twin over libc++
%% prints the same ones.
:- ensure_loaded(library(ccllib/ccllib)).
type_mt19937([], base([], [typedef(N)]), Items) :- ccl_instance_name(mt19937, [], N),
    ccl_c_items("typedef struct @N { uint32_t mt[624]; size_t idx; } @N;", ['N' = name(N)], Items).
fn_mt19937(Name, [], Items) :- ccl_instance_name(mt19937, [], N), ccllib_random_fn(Name, Text), ccl_c_items(Text, ['N' = name(N)], Items).
ccllib_random_fn(seed, "void @{N}_seed(@N *r, uint32_t s) {
    r->mt[0] = s; r->idx = 624;
    for (size_t i = 1; i < 624; i++) r->mt[i] = 1812433253u * (r->mt[i - 1] ^ (r->mt[i - 1] >> 30)) + (uint32_t)i;
}").
ccllib_random_fn('_twist', "static void @{N}__twist(@N *r) {
    for (size_t i = 0; i < 624; i++) { uint32_t y = (r->mt[i] & 0x80000000u) | (r->mt[(i + 1) % 624] & 0x7fffffffu); r->mt[i] = r->mt[(i + 397) % 624] ^ (y >> 1) ^ ((y & 1u) ? 0x9908b0dfu : 0u); }
    r->idx = 0;
}").
ccllib_random_fn(next, "uint32_t @{N}_next(@N *r) {
    if (r->idx >= 624) @{N}__twist(r);
    uint32_t y = r->mt[r->idx++]; y ^= y >> 11; y ^= (y << 7) & 0x9d2c5680u; y ^= (y << 15) & 0xefc60000u; y ^= y >> 18; return y;
}").
ccllib_random_fn(discard, "void @{N}_discard(@N *r, unsigned long long n) { while (n--) (void)@{N}_next(r); }").
ccllib_random_fn(min, "uint32_t @{N}_min(const @N *r) { (void)r; return 0u; }").
ccllib_random_fn(max, "uint32_t @{N}_max(const @N *r) { (void)r; return 4294967295u; }").

%% the engine's instance: the type macro is `mt19937<>'
ccllib_random_engine(R, N) :- ccl_type_of(R, T), T = base(_, [typedef(N)]), nb_getval('$ccl_instances', Is), memberchk(inst(mt19937, [], base(_, [typedef(N)]), _), Is).
%% a value in [lo, hi], by the engine's next value as C++'s modulo form has it
ccl_macro_uniform_int(R, Lo, Hi, E) :- ccllib_random_engine(R, N),
    ccl_c_expr("((@Lo) + (@{N}_next(&@R) % ((@Hi) - (@Lo) + 1u)))", ['R' = expr(R), 'Lo' = expr(Lo), 'Hi' = expr(Hi), 'N' = name(N)], E).
%% a value in [lo, hi)
ccl_macro_uniform_real(R, Lo, Hi, E) :- ccllib_random_engine(R, N),
    ccl_c_expr("((@Lo) + ((@Hi) - (@Lo)) * (@{N}_next(&@R) / 4294967296.0))", ['R' = expr(R), 'Lo' = expr(Lo), 'Hi' = expr(Hi), 'N' = name(N)], E).
ccl_macro_bernoulli(R, P, E) :- ccllib_random_engine(R, N),
    ccl_c_expr("(((@{N}_next(&@R) / 4294967296.0) < (@P)) ? 1 : 0)", ['R' = expr(R), 'P' = expr(P), 'N' = name(N)], E).
%% shuffle(v, rng): the C++ std::shuffle's Fisher-Yates, with the engine's next value
ccl_macro_shuffle(V, R, S) :- ccllib_alg_mut(V, _, N, T, 'shuffle'), ccllib_random_engine(R, EN),
    ccl_c_stmts("{ size_t alg_n = @{N}_size(&@V); for (size_t alg_i = alg_n; alg_i > 1; alg_i--) { size_t alg_j = @{EN}_next(&@R) % alg_i; @T alg_x = @{N}_at(&@V, alg_i - 1); *@{N}_index(&@V, alg_i - 1) = @{N}_at(&@V, alg_j); *@{N}_index(&@V, alg_j) = alg_x; } }",
                ['V' = expr(V), 'R' = expr(R), 'N' = name(N), 'T' = type(T), 'EN' = name(EN)], S).
