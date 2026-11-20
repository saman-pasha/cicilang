%% ccllib's <ratio.pl> (phase 1c): C++'s compile-time rationals as type macros. `ratio<1, 2> r;' gives the reduced
%% ratio, and num(r) and den(r) its two numbers; ratio_add<1, 2, 1, 3>, ratio_subtract, ratio_multiply and
%% ratio_divide take the two ratios' four numbers and give the reduced result. A denominator is never zero or
%% negative, as std::ratio normalizes it. In C++ these are `std::ratio<1, 2>::num' and `std::ratio_add<...>::num';
%% C has no member call, so the instance is named and num(r) is called.
%%
%% (1.6.4) Each operation's instance is named by its own name, `ratio_add_1_2_1_3' and `ratio_multiply_1_2_1_3' -- through
%% 1.6.3 the four were one name, `ratio_Op_...', and the second of two operations over one four numbers was refused; a
%% number is any constant integer expression, a negative one among them, named `m1' in the instance's name; num and den
%% are long long, std::ratio's intmax_t. THE RESULT IS LIBC++'S, BY ITS FORMULAS: each ratio reduced, then the operation
%% over the two's gcds, each product and each sum checked as libc++'s __ll_mul and __ll_add check them, so that an
%% operation is refused where C++ refuses it -- a zero denominator, a number past intmax_t, a product or a sum past it,
%% and a ratio_divide by a numerator 0, each by name. cocolog's integers are 64 bits, and a product past them is an
%% error, not a larger number.
:- ensure_loaded(library(ccllib/ccllib)).
type_ratio([N, D], base([], [typedef(TN)]), Items) :- ccllib_ratio_parts(N, D, _, _), ccllib_ratio_name(ratio, [N, D], TN),
    ccl_c_items("typedef struct @N { char unused; } @N;", ['N' = name(TN)], Items).
fn_ratio(Name, [N, D], Items) :- ccllib_ratio_parts(N, D, RN, RD), ccllib_ratio_name(ratio, [N, D], TN),
    ccllib_ratio_fn(Name, RN, RD, Text), ccl_c_items(Text, ['N' = name(TN)], Items).
ccllib_ratio_fn(num, N, _, Text) :- ccllib_ratio_text(num, N, Text).
ccllib_ratio_fn(den, _, D, Text) :- ccllib_ratio_text(den, D, Text).

type_ratio_add([A, B, C, D], base([], [typedef(N)]), Items) :- ccllib_ratio_op(add, ratio_add, A, B, C, D, N, Items).
type_ratio_subtract([A, B, C, D], base([], [typedef(N)]), Items) :- ccllib_ratio_op(sub, ratio_subtract, A, B, C, D, N, Items).
type_ratio_multiply([A, B, C, D], base([], [typedef(N)]), Items) :- ccllib_ratio_op(mul, ratio_multiply, A, B, C, D, N, Items).
type_ratio_divide([A, B, C, D], base([], [typedef(N)]), Items) :- ccllib_ratio_op(div, ratio_divide, A, B, C, D, N, Items).
fn_ratio_add(Name, [A, B, C, D], Items) :- ccllib_ratio_op_fn(add, ratio_add, Name, A, B, C, D, Items).
fn_ratio_subtract(Name, [A, B, C, D], Items) :- ccllib_ratio_op_fn(sub, ratio_subtract, Name, A, B, C, D, Items).
fn_ratio_multiply(Name, [A, B, C, D], Items) :- ccllib_ratio_op_fn(mul, ratio_multiply, Name, A, B, C, D, Items).
fn_ratio_divide(Name, [A, B, C, D], Items) :- ccllib_ratio_op_fn(div, ratio_divide, Name, A, B, C, D, Items).
ccllib_ratio_op(Op, Base, A0, B0, C0, D0, N, Items) :- ccllib_ratio_four(A0, B0, C0, D0, A, B, C, D), ccllib_ratio_calc(Op, A, B, C, D, _, _),
    ccllib_ratio_name(Base, [A, B, C, D], N), ccl_c_items("typedef struct @N { char unused; } @N;", ['N' = name(N)], Items).
ccllib_ratio_op_fn(Op, Base, Name, A0, B0, C0, D0, Items) :- ccllib_ratio_four(A0, B0, C0, D0, A, B, C, D), ccllib_ratio_calc(Op, A, B, C, D, RN, RD),
    ccllib_ratio_name(Base, [A, B, C, D], N),
    ( Name == num -> K = RN ; Name == den -> K = RD ; fail ),
    ccllib_ratio_text(Name, K, Text), ccl_c_items(Text, ['N' = name(N)], Items).
ccllib_ratio_four(A0, B0, C0, D0, A, B, C, D) :- ccllib_ratio_parts(A0, B0, _, _), ccllib_ratio_parts(C0, D0, _, _),
    ccllib_ratio_int(A0, A), ccllib_ratio_int(B0, B), ccllib_ratio_int(C0, C), ccllib_ratio_int(D0, D).
%% num and den: a long long of the reduced number
ccllib_ratio_text(Name, K, Text) :- ( K < 0 -> K1 is -K, format(atom(L), '(-~dLL)', [K1]) ; format(atom(L), '~dLL', [K]) ),
    atomic_list_concat(['long long @{N}_', Name, '(const @N *r) { (void)r; return ', L, '; }'], Text).
%% the instance's name: its macro's name and its numbers, a negative one m and its magnitude
ccllib_ratio_name(Base, As, Name) :- maplist(ccllib_ratio_word, As, Ws), atomic_list_concat([Base|Ws], '_', Name).
ccllib_ratio_word(A, W) :- ccllib_ratio_int(A, V), ( V < 0 -> V1 is -V, atom_concat(m, V1, W) ; W = V ).

ccllib_ratio_parts(N, D, RN, RD) :- ccllib_ratio_int(N, A), ccllib_ratio_int(D, B), ccllib_ratio_reduce(A, B, RN, RD).
%% a number: an integer constant expression, of intmax_t's range (std::ratio's: its magnitude at most INTMAX_MAX); a
%% literal past 2^60 folds to big(Atom), the lexers' term
ccllib_ratio_int(X, V) :- ( integer(X) -> V0 = X ; X = int(V0), integer(V0) -> true ; catch(ccl_const_eval(X, V1), _, fail), ccllib_ratio_value(V1, V0) ), !,
    ( catch(_ is abs(V0), _, fail) -> V = V0 ; ccl_macro_error('a ratio''s number is past intmax_t') ).
ccllib_ratio_int(_, _) :- ccl_macro_error('a ratio takes two integer numbers').
ccllib_ratio_value(V, V) :- integer(V), !.
ccllib_ratio_value(big(A), V) :- ( catch(atom_number(A, V), _, fail), integer(V) -> true ; ccl_macro_error('a ratio''s number is past intmax_t') ).
%% the two ratios reduced, then libc++'s formula of the operation
ccllib_ratio_calc(Op, A, B, C, D, RN, RD) :- ccllib_ratio_reduce(A, B, N1, D1), ccllib_ratio_reduce(C, D, N2, D2),
    ccllib_ratio_libcxx(Op, N1, D1, N2, D2, RN, RD).
%% libc++'s __ratio_multiply, __ratio_divide, __ratio_add and __ratio_subtract over reduced ratios
ccllib_ratio_libcxx(mul, N1, D1, N2, D2, RN, RD) :- !, ccllib_ratio_gcd(N1, D2, G1), ccllib_ratio_gcd(D1, N2, G2),
    ccllib_ratio_mul(N1 // G1, N2 // G2, N), ccllib_ratio_mul(D2 // G1, D1 // G2, D), ccllib_ratio_reduce(N, D, RN, RD).
ccllib_ratio_libcxx(div, N1, D1, N2, D2, RN, RD) :- !, ccllib_ratio_gcd(N1, N2, G1), ccllib_ratio_gcd(D1, D2, G2),
    ccllib_ratio_mul(N1 // G1, D2 // G2, N), ccllib_ratio_mul(N2 // G1, D1 // G2, D),
    ( D =:= 0 -> ccl_macro_error('a ratio_divide by a ratio of numerator 0, as std::ratio_divide''s') ; true ),
    ccllib_ratio_reduce(N, D, RN, RD).
ccllib_ratio_libcxx(Op, N1, D1, N2, D2, RN, RD) :- ( Op == add -> S = 1 ; S = -1 ),
    ccllib_ratio_gcd(N1, N2, GN), ccllib_ratio_gcd(D1, D2, GD),
    ccllib_ratio_mul(N1 // GN, D2 // GD, X), ccllib_ratio_mul(N2 // GN, D1 // GD, Y0), Y is S * Y0, ccllib_ratio_sum(X, Y, Z),
    ccllib_ratio_reduce(GN, D1 // GD, AN, AD), ccllib_ratio_reduce(Z, D2, BN, BD),
    ccllib_ratio_libcxx(mul, AN, AD, BN, BD, RN, RD).
%% __ll_mul and __ll_add: a result whose magnitude is past INTMAX_MAX is refused, as their static assertions refuse it
ccllib_ratio_mul(A0, B0, Z) :- A is A0, B is B0,
    ( catch(( Z is A * B, _ is abs(Z) ), _, fail) -> true ; ccl_macro_error('a ratio''s product is past intmax_t, as std::ratio''s __ll_mul refuses it') ).
ccllib_ratio_sum(A, B, Z) :-
    ( catch(( Z is A + B, _ is abs(Z) ), _, fail) -> true ; ccl_macro_error('a ratio''s sum is past intmax_t, as std::ratio''s __ll_add refuses it') ).
%% __static_gcd's magnitude, 1 of two zeros
ccllib_ratio_gcd(A, B, 1) :- A =:= 0, B =:= 0, !.
ccllib_ratio_gcd(A, B, G) :- G is gcd(abs(A), abs(B)).
%% std::ratio's own reduction: the denominator positive and the two numbers prime to each other
ccllib_ratio_reduce(N0, D0, RN, RD) :- N is N0, D is D0,
    ( D =:= 0 -> ccl_macro_error('a ratio''s denominator is not zero, as std::ratio''s') ; true ),
    G is gcd(abs(N), abs(D)), ( D < 0 -> RN is -(N // G), RD is -(D // G) ; RN is N // G, RD is D // G ).
