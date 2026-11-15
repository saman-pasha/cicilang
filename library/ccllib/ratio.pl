%% ccllib's <ratio.pl> (phase 1c): C++'s compile-time rationals as type macros. `ratio<1, 2> r;' gives the reduced
%% ratio, and num(r) and den(r) its two numbers; ratio_add<1, 2, 1, 3>, ratio_subtract, ratio_multiply and
%% ratio_divide take the two ratios' four numbers and give the reduced result. A denominator is never zero or
%% negative, as std::ratio normalizes it. In C++ these are `std::ratio<1, 2>::num' and `std::ratio_add<...>::num';
%% C has no member call, so the instance is named and num(r) is called.
:- ensure_loaded(library(ccllib/ccllib)).
type_ratio([N, D], base([], [typedef(TN)]), Items) :- ccllib_ratio_parts(N, D, _, _), ccl_instance_name(ratio, [N, D], TN),
    ccl_c_items("typedef struct @N { char unused; } @N;", ['N' = name(TN)], Items).
fn_ratio(Name, [N, D], Items) :- ccllib_ratio_parts(N, D, RN, RD), ccl_instance_name(ratio, [N, D], TN),
    ccllib_ratio_fn(Name, RN, RD, Text), ccl_c_items(Text, ['N' = name(TN)], Items).
ccllib_ratio_fn(num, N, _, Text) :- atom_number(KA, N), atomic_list_concat(['int @{N}_num(const @N *r) { (void)r; return ', KA, '; }'], Text).
ccllib_ratio_fn(den, _, D, Text) :- atom_number(KA, D), atomic_list_concat(['int @{N}_den(const @N *r) { (void)r; return ', KA, '; }'], Text).

type_ratio_add([A, B, C, D], base([], [typedef(N)]), Items) :- ccllib_ratio_op(add, A, B, C, D, N, Items).
type_ratio_subtract([A, B, C, D], base([], [typedef(N)]), Items) :- ccllib_ratio_op(sub, A, B, C, D, N, Items).
type_ratio_multiply([A, B, C, D], base([], [typedef(N)]), Items) :- ccllib_ratio_op(mul, A, B, C, D, N, Items).
type_ratio_divide([A, B, C, D], base([], [typedef(N)]), Items) :- ccllib_ratio_op(div, A, B, C, D, N, Items).
fn_ratio_add(Name, [A, B, C, D], Items) :- ccllib_ratio_op_fn(add, Name, A, B, C, D, Items).
fn_ratio_subtract(Name, [A, B, C, D], Items) :- ccllib_ratio_op_fn(sub, Name, A, B, C, D, Items).
fn_ratio_multiply(Name, [A, B, C, D], Items) :- ccllib_ratio_op_fn(mul, Name, A, B, C, D, Items).
fn_ratio_divide(Name, [A, B, C, D], Items) :- ccllib_ratio_op_fn(div, Name, A, B, C, D, Items).
ccllib_ratio_op(Op, A0, B0, C0, D0, N, Items) :- ccllib_ratio_int(A0, A), ccllib_ratio_int(B0, B), ccllib_ratio_int(C0, C), ccllib_ratio_int(D0, D), ccllib_ratio_calc(Op, A, B, C, D, RN, RD),
    ccl_instance_name(ratio_Op, [A, B, C, D], N), ccl_c_items("typedef struct @N { char unused; } @N;", ['N' = name(N)], Items).
ccllib_ratio_op_fn(Op, Name, A0, B0, C0, D0, Items) :- ccllib_ratio_int(A0, A), ccllib_ratio_int(B0, B), ccllib_ratio_int(C0, C), ccllib_ratio_int(D0, D), ccllib_ratio_calc(Op, A, B, C, D, RN, RD),
    ccl_instance_name(ratio_Op, [A, B, C, D], N),
    ( Name == num -> atom_number(K, RN) ; Name == den -> atom_number(K, RD) ; fail ),
    ccllib_ratio_op_text(Name, K, Text), ccl_c_items(Text, ['N' = name(N)], Items).
ccllib_ratio_op_text(num, K, Text) :- !, atomic_list_concat(['int @{N}_num(const @N *r) { (void)r; return ', K, '; }'], Text).
ccllib_ratio_op_text(den, K, Text) :- atomic_list_concat(['int @{N}_den(const @N *r) { (void)r; return ', K, '; }'], Text).

ccllib_ratio_parts(N, D, RN, RD) :- ccllib_ratio_int(N, A), ccllib_ratio_int(D, B), B \== 0,
    ccllib_ratio_calc(ratio, A, 1, B, 1, RN, RD).
ccllib_ratio_int(int(V), V) :- integer(V), !.
ccllib_ratio_int(V, V) :- integer(V), !.
ccllib_ratio_int(_, _) :- ccl_macro_error('a ratio takes two integer numbers').
ccllib_ratio_calc(ratio, A, _, B, _, RN, RD) :- !, ccllib_ratio_reduce(A, B, RN, RD).
ccllib_ratio_calc(add, A, B, C, D, RN, RD) :- N is A * D + C * B, M is B * D, ccllib_ratio_reduce(N, M, RN, RD).
ccllib_ratio_calc(sub, A, B, C, D, RN, RD) :- N is A * D - C * B, M is B * D, ccllib_ratio_reduce(N, M, RN, RD).
ccllib_ratio_calc(mul, A, B, C, D, RN, RD) :- N is A * C, M is B * D, ccllib_ratio_reduce(N, M, RN, RD).
ccllib_ratio_calc(div, A, B, C, D, RN, RD) :- C \== 0, N is A * D, M is B * C, ccllib_ratio_reduce(N, M, RN, RD).
ccllib_ratio_reduce(N, D, RN, RD) :- D \== 0, G is gcd(abs(N), abs(D)), RN0 is N // G, RD0 is D // G,
    ( RD0 < 0 -> RN is -RN0, RD is -RD0 ; RN = RN0, RD = RD0 ).
