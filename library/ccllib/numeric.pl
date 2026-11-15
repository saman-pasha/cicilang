%% ccllib's <numeric.pl> (phase 1c): C++'s numeric algorithms over the same random-access ranges as <algorithm.pl>.
%% The names are std::numeric's where a C expression carries them; a fold that takes an operation takes it as an
%% expression after the accumulator and the element's names.
:- ensure_loaded(library(ccllib/ccllib)).
ccllib_num_holes(V, N, T, ['V' = expr(V), 'N' = name(N), 'T' = type(T)]).

%% accumulate(v, init): init + each element, in order
ccl_macro_accumulate(V, Init, E) :- ccllib_alg_range(V, _, N, T), ccllib_num_holes(V, N, T, Hs0),
    ccl_c_expr("({ @T alg_acc = @Init; for (size_t alg_i = 0; alg_i < @{N}_size(&@V); alg_i++) alg_acc += @{N}_at(&@V, alg_i); alg_acc; })",
               ['Init' = expr(Init)|Hs0], E).
ccl_macro_reduce(V, Init, E) :- ccl_macro_accumulate(V, Init, E).
ccl_macro_accumulate_by(V, Init, id(A), unread(C), E) :- ccllib_alg_range(V, _, N, T), ccllib_num_holes(V, N, T, Hs0),
    ccl_c_expr("({ __typeof__(@Init) acc = @Init; for (size_t alg_i = 0; alg_i < @{N}_size(&@V); alg_i++) { @T @A = @{N}_at(&@V, alg_i); acc = (@C); } acc; })",
               ['Init' = expr(Init), 'A' = name(A), 'C' = unread(C)|Hs0], E).

%% inner_product(a, b, init)
ccl_macro_inner_product(A, B, Init, E) :- ccllib_alg_range(A, _, N, T), ccllib_alg_range(B, _, M, _), ccllib_num_holes(A, N, T, Hs0),
    ccl_c_expr("({ __typeof__(@Init) alg_acc = @Init; size_t alg_n = @{N}_size(&@A), alg_m = @{M}_size(&@B); if (alg_m < alg_n) alg_n = alg_m; for (size_t alg_i = 0; alg_i < alg_n; alg_i++) alg_acc += @{N}_at(&@A, alg_i) * @{M}_at(&@B, alg_i); alg_acc; })",
               ['A' = expr(A), 'B' = expr(B), 'M' = name(M), 'Init' = expr(Init)|Hs0], E).

%% iota(v, x): x, x + 1, ... over the range
ccl_macro_iota(V, X, S) :- ccllib_alg_mut(V, _, N, T, 'iota'), ccllib_num_holes(V, N, T, Hs0),
    ccl_c_stmts("{ @T alg_x = @X; size_t alg_n = @{N}_size(&@V); for (size_t alg_i = 0; alg_i < alg_n; alg_i++) *@{N}_index(&@V, alg_i) = alg_x++; }",
                ['X' = expr(X)|Hs0], S).

%% partial_sum(v, out): out[i] is v[0] + ... + v[i]
ccl_macro_partial_sum(V, W, S) :- ccllib_alg_range(V, _, N, T), ccllib_alg_mut(W, _, M, _, 'partial_sum'), ccllib_num_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t alg_n = @{N}_size(&@V), alg_m = @{M}_size(&@W); if (alg_m < alg_n) alg_n = alg_m; @T alg_acc = 0; for (size_t alg_i = 0; alg_i < alg_n; alg_i++) { alg_acc += @{N}_at(&@V, alg_i); *@{M}_index(&@W, alg_i) = alg_acc; } }",
                ['W' = expr(W), 'M' = name(M)|Hs0], S).

%% adjacent_difference(v, out): out[0] is v[0], out[i] is v[i] - v[i - 1]
ccl_macro_adjacent_difference(V, W, S) :- ccllib_alg_range(V, _, N, T), ccllib_alg_mut(W, _, M, _, 'adjacent_difference'), ccllib_num_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t alg_n = @{N}_size(&@V), alg_m = @{M}_size(&@W); if (alg_m < alg_n) alg_n = alg_m; if (alg_n) { @T alg_prev = @{N}_at(&@V, 0), alg_cur; *@{M}_index(&@W, 0) = alg_prev; for (size_t alg_i = 1; alg_i < alg_n; alg_i++) { alg_cur = @{N}_at(&@V, alg_i); *@{M}_index(&@W, alg_i) = alg_cur - alg_prev; alg_prev = alg_cur; } } }",
                ['W' = expr(W), 'M' = name(M)|Hs0], S).

%% gcd(a, b) and lcm(a, b), C++17's; a result of 0 for the zero pair
ccl_macro_gcd(A, B, E) :- ccl_c_expr("({ __typeof__(@A) alg_a = (@A) < 0 ? -(@A) : (@A), alg_b = (@B) < 0 ? -(@B) : (@B); while (alg_b) { __typeof__(alg_a) alg_t = alg_a % alg_b; alg_a = alg_b; alg_b = alg_t; } alg_a; })",
    ['A' = expr(A), 'B' = expr(B)], E).
ccl_macro_lcm(A, B, E) :- ccl_macro_gcd(A, B, G),
    ccl_c_expr("({ __typeof__(@A) alg_g = @G, alg_a = (@A) < 0 ? -(@A) : (@A), alg_b = (@B) < 0 ? -(@B) : (@B); alg_g ? alg_a / alg_g * alg_b : 0; })",
               ['A' = expr(A), 'B' = expr(B), 'G' = expr(G)], E).

%% midpoint(a, b), C++20's: no overflow for two integers
ccl_macro_midpoint(A, B, E) :- ccl_c_expr("((@A) + ((@B) - (@A)) / 2)", ['A' = expr(A), 'B' = expr(B)], E).
