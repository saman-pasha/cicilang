%% ccllib's <numeric.pl> (phase 1c): C++'s numeric algorithms over the same random-access ranges as <algorithm.pl>.
%% The names are std::numeric's where a C expression carries them; a fold that takes an operation takes it as an
%% expression after the accumulator and the element's names.
:- ensure_loaded(library(ccllib/ccllib)).
ccllib_num_holes(V, N, T, ['V' = expr(V), 'N' = name(N), 'T' = type(T)]).

%% accumulate(v, init): init + each element, in order, in init's type, as C++'s `T init' ([accumulate]/2): through 1.6.0
%% the sum was the element's type, and the five letters of "hello" summed in a char (20, where C++ gives 532)
ccl_macro_accumulate(V, Init, E) :- ccllib_alg_range(V, _, N, T), ccllib_num_holes(V, N, T, Hs0),
    ccl_c_expr("({ __typeof__(@Init) __ccl_acc = @Init; for (size_t __ccl_i = 0; __ccl_i < @{N}_size(&@V); __ccl_i++) __ccl_acc += @{N}_at(&@V, __ccl_i); __ccl_acc; })",
               ['Init' = expr(Init)|Hs0], E).
ccl_macro_reduce(V, Init, E) :- ccl_macro_accumulate(V, Init, E).
ccl_macro_accumulate_by(V, Init, id(A), unread(C), E) :- ccllib_alg_range(V, _, N, T), ccllib_num_holes(V, N, T, Hs0),
    ccl_c_expr("({ __typeof__(@Init) acc = @Init; for (size_t __ccl_i = 0; __ccl_i < @{N}_size(&@V); __ccl_i++) { @T @A = @{N}_at(&@V, __ccl_i); acc = (@C); } acc; })",
               ['Init' = expr(Init), 'A' = name(A), 'C' = unread(C)|Hs0], E).

%% inner_product(a, b, init)
ccl_macro_inner_product(A, B, Init, E) :- ccllib_alg_range(A, _, N, T), ccllib_alg_range(B, _, M, _), ccllib_num_holes(A, N, T, Hs0),
    ccl_c_expr("({ __typeof__(@Init) __ccl_acc = @Init; size_t __ccl_n = @{N}_size(&@A), __ccl_m = @{M}_size(&@B); if (__ccl_m < __ccl_n) __ccl_n = __ccl_m; for (size_t __ccl_i = 0; __ccl_i < __ccl_n; __ccl_i++) __ccl_acc += @{N}_at(&@A, __ccl_i) * @{M}_at(&@B, __ccl_i); __ccl_acc; })",
               ['A' = expr(A), 'B' = expr(B), 'M' = name(M), 'Init' = expr(Init)|Hs0], E).

%% iota(v, x): x, x + 1, ... over the range
ccl_macro_iota(V, X, S) :- ccllib_alg_mut(V, _, N, T, 'iota'), ccllib_num_holes(V, N, T, Hs0),
    ccl_c_stmts("{ @T __ccl_x = @X; size_t __ccl_n = @{N}_size(&@V); for (size_t __ccl_i = 0; __ccl_i < __ccl_n; __ccl_i++) *@{N}_index(&@V, __ccl_i) = __ccl_x++; }",
                ['X' = expr(X)|Hs0], S).

%% partial_sum(v, out): out[i] is v[0] + ... + v[i]
ccl_macro_partial_sum(V, W, S) :- ccllib_alg_range(V, _, N, T), ccllib_alg_mut(W, _, M, _, 'partial_sum'), ccllib_num_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t __ccl_n = @{N}_size(&@V), __ccl_m = @{M}_size(&@W); if (__ccl_m < __ccl_n) __ccl_n = __ccl_m; @T __ccl_acc = 0; for (size_t __ccl_i = 0; __ccl_i < __ccl_n; __ccl_i++) { __ccl_acc += @{N}_at(&@V, __ccl_i); *@{M}_index(&@W, __ccl_i) = __ccl_acc; } }",
                ['W' = expr(W), 'M' = name(M)|Hs0], S).

%% adjacent_difference(v, out): out[0] is v[0], out[i] is v[i] - v[i - 1]
ccl_macro_adjacent_difference(V, W, S) :- ccllib_alg_range(V, _, N, T), ccllib_alg_mut(W, _, M, _, 'adjacent_difference'), ccllib_num_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t __ccl_n = @{N}_size(&@V), __ccl_m = @{M}_size(&@W); if (__ccl_m < __ccl_n) __ccl_n = __ccl_m; if (__ccl_n) { @T __ccl_prev = @{N}_at(&@V, 0), __ccl_cur; *@{M}_index(&@W, 0) = __ccl_prev; for (size_t __ccl_i = 1; __ccl_i < __ccl_n; __ccl_i++) { __ccl_cur = @{N}_at(&@V, __ccl_i); *@{M}_index(&@W, __ccl_i) = __ccl_cur - __ccl_prev; __ccl_prev = __ccl_cur; } } }",
                ['W' = expr(W), 'M' = name(M)|Hs0], S).

%% gcd(a, b) and lcm(a, b), C++17's ([numeric.ops.gcd], [numeric.ops.lcm]): in the two operands' common type, each read
%% once, their magnitudes taken as an unsigned long long, so that the lowest value of a signed type has one; a result of
%% 0 for the zero pair, and lcm 0 where either is 0. Through 1.6.0 each read its operands two and three times, in the
%% first one's type
ccllib_num_abs_text("__typeof__((@A) + (@B)) __ccl_m = @A, __ccl_n = @B; unsigned long long __ccl_a = __ccl_m < 0 ? 0ULL - (unsigned long long)__ccl_m : (unsigned long long)__ccl_m, __ccl_b = __ccl_n < 0 ? 0ULL - (unsigned long long)__ccl_n : (unsigned long long)__ccl_n, __ccl_x = __ccl_a, __ccl_y = __ccl_b; while (__ccl_y) { unsigned long long __ccl_t = __ccl_x % __ccl_y; __ccl_x = __ccl_y; __ccl_y = __ccl_t; } ").
ccl_macro_gcd(A, B, E) :- ccllib_num_abs_text(G), append(["({ ", G, "(__typeof__(__ccl_m))__ccl_x; })"], Text),
    ccl_c_expr(Text, ['A' = expr(A), 'B' = expr(B)], E).
ccl_macro_lcm(A, B, E) :- ccllib_num_abs_text(G), append(["({ ", G, "(__typeof__(__ccl_m))(__ccl_x ? __ccl_a / __ccl_x * __ccl_b : 0); })"], Text),
    ccl_c_expr(Text, ['A' = expr(A), 'B' = expr(B)], E).

%% midpoint(a, b), C++20's ([numeric.ops.midpoint]), each operand read once: of two integers a + (b - a) / 2 rounded
%% towards a, with no overflow -- the distance an unsigned long long, so that midpoint(INT_MIN, INT_MAX) is -1 --, in
%% the operands' type where it is one, else their common type; of two pointers a + (b - a) / 2; of floating values
%% (a + b) / 2, and a / 2 + b / 2 where a + b overflows -- the value of C++'s four cases, which halve where a sum is no
%% finite value. Through 1.6.0 it was `a + (b - a) / 2' over a read of a three times, which overflowed for
%% (INT_MIN, INT_MAX)
ccl_macro_midpoint(A, B, E) :-
    ( catch(ccl_type_of(A, TA), _, fail) -> true ; TA = unknown ), ( catch(ccl_type_of(B, TB), _, fail) -> true ; TB = unknown ),
    ccllib_midpoint_text(TA, TB, Text), ccl_c_expr(Text, ['A' = expr(A), 'B' = expr(B)], E).
ccllib_midpoint_text(TA, TB, "({ __typeof__((@A) + (@B)) __ccl_a = @A, __ccl_b = @B, __ccl_s = __ccl_a + __ccl_b; __ccl_s - __ccl_s == 0 || __ccl_a - __ccl_a != 0 || __ccl_b - __ccl_b != 0 ? __ccl_s / 2 : __ccl_a / 2 + __ccl_b / 2; })") :-
    ( ccl_is_float(TA) ; ccl_is_float(TB) ), !.
ccllib_midpoint_text(TA, _, "({ __typeof__(@A) __ccl_a = @A, __ccl_b = @B; __ccl_a + (__ccl_b - __ccl_a) / 2; })") :- ccl_is_pointer(TA), !.
ccllib_midpoint_text(TA, TB, Text) :-
    ( TA \== unknown, catch(ccl_resolve_type(TA, R), _, fail), catch(ccl_resolve_type(TB, R), _, fail) -> Ty = "__typeof__(@A)" ; Ty = "__typeof__((@A) + (@B))" ),
    append(["({ ", Ty, " __ccl_a = @A, __ccl_b = @B; unsigned long long __ccl_d = __ccl_a < __ccl_b ? (unsigned long long)__ccl_b - (unsigned long long)__ccl_a : (unsigned long long)__ccl_a - (unsigned long long)__ccl_b; __ccl_a < __ccl_b ? (__typeof__(__ccl_a))(__ccl_a + (__typeof__(__ccl_a))(__ccl_d / 2)) : (__typeof__(__ccl_a))(__ccl_a - (__typeof__(__ccl_a))(__ccl_d / 2)); })"], Text).
