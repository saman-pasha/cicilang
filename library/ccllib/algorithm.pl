%% ccllib's <algorithm.pl> (phase 1c): C++'s algorithms over the random-access ranges of ccllib -- vector<T>,
%% array<T, N>, deque<T>, span<T>, basic_string<char>, and read-only basic_string_view<char> -- with the names of
%% std::algorithm where a C expression can carry them. A call is a macro: it knows the range's instance and element
%% type at read time, and puts a loop at the user's line. What differs from C++:
%%   a range is an object, not a pair of iterators: sort(v), reverse(v), count(v, x), find(v, x);
%%   a place is an index into the range, end(v) is size(v), as in the containers' own names;
%%   a comparison is an expression after the two element names, `sort_by(v, a, b, a > b)';
%%   sort, stable_sort and partial_sort are insertion sorts here, O(n^2), and wait for a measured rewrite;
%%   a view is read-only, so a mutating algorithm over one is refused by name.
:- ensure_loaded(library(ccllib/ccllib)).
%% the range's text: V is evaluated more than once by a call, as a container's own names do; a range with side effects
%% is named first
ccllib_alg_holes(V, N, T, ['V' = expr(V), 'N' = name(N), 'T' = type(T)]).
ccllib_alg_type(V, Kind, N, T) :- ccllib_alg_range(V, Kind, N, T).

%% -- the sorts. Insertion sort, stable, with no function pointer: a comparison is an expression in the loop
ccl_macro_sort(V, S) :- ccllib_alg_mut(V, _, N, T, 'sort'), ccllib_alg_holes(V, N, T, Hs),
    ccl_c_stmts("{ size_t alg_n = @{N}_size(&@V); for (size_t alg_i = 1; alg_i < alg_n; alg_i++) { @T alg_x = @{N}_at(&@V, alg_i); size_t alg_j = alg_i; while (alg_j > 0) { if (!(alg_x < @{N}_at(&@V, alg_j - 1))) break; *@{N}_index(&@V, alg_j) = @{N}_at(&@V, alg_j - 1); alg_j--; } *@{N}_index(&@V, alg_j) = alg_x; } }", Hs, S).
ccl_macro_stable_sort(V, S) :- ccl_macro_sort(V, S).
ccl_macro_sort_by(V, id(A), id(B), unread(C), S) :- ccllib_alg_mut(V, _, N, T, 'sort_by'), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t alg_n = @{N}_size(&@V); for (size_t alg_i = 1; alg_i < alg_n; alg_i++) { @T alg_x = @{N}_at(&@V, alg_i); size_t alg_j = alg_i; while (alg_j > 0) { @T @A = alg_x, @B = @{N}_at(&@V, alg_j - 1); if (!(@C)) break; *@{N}_index(&@V, alg_j) = @B; alg_j--; } *@{N}_index(&@V, alg_j) = alg_x; } }",
                ['A' = name(A), 'B' = name(B), 'C' = unread(C)|Hs0], S).
ccl_macro_stable_sort_by(V, id(A), id(B), unread(C), S) :- ccl_macro_sort_by(V, id(A), id(B), unread(C), S).
%% partial_sort(v, n): the first n elements in order, the rest where they were (a selection sort over the prefix)
ccl_macro_partial_sort(V, K, S) :- ccllib_alg_mut(V, _, N, T, 'partial_sort'), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t alg_n = @{N}_size(&@V); size_t alg_k = @K; if (alg_k > alg_n) alg_k = alg_n; for (size_t alg_i = 0; alg_i < alg_k; alg_i++) { size_t alg_m = alg_i; for (size_t alg_j = alg_i + 1; alg_j < alg_n; alg_j++) if (@{N}_at(&@V, alg_j) < @{N}_at(&@V, alg_m)) alg_m = alg_j; if (alg_m != alg_i) { @T alg_x = @{N}_at(&@V, alg_i); *@{N}_index(&@V, alg_i) = @{N}_at(&@V, alg_m); *@{N}_index(&@V, alg_m) = alg_x; } } }",
                ['K' = expr(K)|Hs0], S).

%% -- the order of the elements
ccl_macro_reverse(V, S) :- ccllib_alg_mut(V, _, N, T, 'reverse'), ccllib_alg_holes(V, N, T, Hs),
    ccl_c_stmts("{ size_t alg_n = @{N}_size(&@V); for (size_t alg_i = 0; alg_i < alg_n / 2; alg_i++) { @T alg_x = @{N}_at(&@V, alg_i); *@{N}_index(&@V, alg_i) = @{N}_at(&@V, alg_n - 1 - alg_i); *@{N}_index(&@V, alg_n - 1 - alg_i) = alg_x; } }", Hs, S).
ccl_macro_fill(V, X, S) :- ccllib_alg_mut(V, _, N, T, 'fill'), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t alg_n = @{N}_size(&@V); @T alg_x = @X; for (size_t alg_i = 0; alg_i < alg_n; alg_i++) *@{N}_index(&@V, alg_i) = alg_x; }", ['X' = expr(X)|Hs0], S).
ccl_macro_replace(V, X, Y, S) :- ccllib_alg_mut(V, _, N, T, 'replace'), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t alg_n = @{N}_size(&@V); @T alg_x = @X, alg_y = @Y; for (size_t alg_i = 0; alg_i < alg_n; alg_i++) if (@{N}_at(&@V, alg_i) == alg_x) *@{N}_index(&@V, alg_i) = alg_y; }", ['X' = expr(X), 'Y' = expr(Y)|Hs0], S).
ccl_macro_replace_if(V, id(A), unread(C), Y, S) :- ccllib_alg_mut(V, _, N, T, 'replace_if'), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t alg_n = @{N}_size(&@V); @T alg_y = @Y; for (size_t alg_i = 0; alg_i < alg_n; alg_i++) { @T @A = @{N}_at(&@V, alg_i); if (@C) *@{N}_index(&@V, alg_i) = alg_y; } }",
                ['A' = name(A), 'C' = unread(C), 'Y' = expr(Y)|Hs0], S).

%% -- the counts and the tests. A place is an index, and the end is the size
ccl_macro_count(V, X, E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_expr("({ size_t alg_n = @{N}_size(&@V), alg_k = 0; for (size_t alg_i = 0; alg_i < alg_n; alg_i++) if (@{N}_at(&@V, alg_i) == @X) alg_k++; alg_k; })",
               ['X' = expr(X)|Hs0], E).
ccl_macro_count_if(V, id(A), unread(C), E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_expr("({ size_t alg_n = @{N}_size(&@V), alg_k = 0; for (size_t alg_i = 0; alg_i < alg_n; alg_i++) { @T @A = @{N}_at(&@V, alg_i); if (@C) alg_k++; } alg_k; })",
               ['A' = name(A), 'C' = unread(C)|Hs0], E).
ccl_macro_all_of(V, id(A), unread(C), E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_expr("({ size_t alg_n = @{N}_size(&@V); int alg_ok = 1; for (size_t alg_i = 0; alg_i < alg_n; alg_i++) { @T @A = @{N}_at(&@V, alg_i); if (!(@C)) { alg_ok = 0; break; } } alg_ok; })",
               ['A' = name(A), 'C' = unread(C)|Hs0], E).
ccl_macro_any_of(V, id(A), unread(C), E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_expr("({ size_t alg_n = @{N}_size(&@V); int alg_ok = 0; for (size_t alg_i = 0; alg_i < alg_n; alg_i++) { @T @A = @{N}_at(&@V, alg_i); if (@C) { alg_ok = 1; break; } } alg_ok; })",
               ['A' = name(A), 'C' = unread(C)|Hs0], E).
ccl_macro_none_of(V, id(A), unread(C), E) :- ccl_macro_all_of(V, id(A), unread(C), E0),
    ccl_c_expr("!(@A0)", ['A0' = expr(E0)], E).

%% -- the places
ccl_macro_find(V, X, E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_expr("({ size_t alg_n = @{N}_size(&@V), alg_k = alg_n; for (size_t alg_i = 0; alg_i < alg_n; alg_i++) if (@{N}_at(&@V, alg_i) == @X) { alg_k = alg_i; break; } alg_k; })", ['X' = expr(X)|Hs0], E).
ccl_macro_find_if(V, id(A), unread(C), E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_expr("({ size_t alg_n = @{N}_size(&@V), alg_k = alg_n; for (size_t alg_i = 0; alg_i < alg_n; alg_i++) { @T @A = @{N}_at(&@V, alg_i); if (@C) { alg_k = alg_i; break; } } alg_k; })",
               ['A' = name(A), 'C' = unread(C)|Hs0], E).
ccl_macro_min_element(V, E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_expr("({ size_t alg_n = @{N}_size(&@V), alg_k = 0; for (size_t alg_i = 1; alg_i < alg_n; alg_i++) if (@{N}_at(&@V, alg_i) < @{N}_at(&@V, alg_k)) alg_k = alg_i; alg_k; })", Hs0, E).
ccl_macro_max_element(V, E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_expr("({ size_t alg_n = @{N}_size(&@V), alg_k = 0; for (size_t alg_i = 1; alg_i < alg_n; alg_i++) if (@{N}_at(&@V, alg_k) < @{N}_at(&@V, alg_i)) alg_k = alg_i; alg_k; })", Hs0, E).

%% -- the order tests
ccl_macro_equal(A, B, E) :- ccllib_alg_range(A, _, N, T), ccllib_alg_range(B, _, M, _), ccllib_alg_holes(A, N, T, Hs0),
    ccl_c_expr("({ size_t alg_n = @{N}_size(&@A), alg_m = @{M}_size(&@B); int alg_ok = alg_n == alg_m; for (size_t alg_i = 0; alg_ok && alg_i < alg_n; alg_i++) if (!(@{N}_at(&@A, alg_i) == @{M}_at(&@B, alg_i))) alg_ok = 0; alg_ok; })",
               ['A' = expr(A), 'B' = expr(B), 'M' = name(M)|Hs0], E).
ccl_macro_lexicographical_compare(A, B, E) :- ccllib_alg_range(A, _, N, T), ccllib_alg_range(B, _, M, _), ccllib_alg_holes(A, N, T, Hs0),
    ccl_c_expr("({ size_t alg_n = @{N}_size(&@A), alg_m = @{M}_size(&@B), alg_i = 0; int alg_ok = 0; while (alg_i < alg_n && alg_i < alg_m) { if (@{N}_at(&@A, alg_i) < @{M}_at(&@B, alg_i)) { alg_ok = 1; break; } if (@{M}_at(&@B, alg_i) < @{N}_at(&@A, alg_i)) break; alg_i++; } if (alg_i == alg_n || alg_i == alg_m) alg_ok = alg_n < alg_m; alg_ok; })",
               ['A' = expr(A), 'B' = expr(B), 'M' = name(M)|Hs0], E).

%% -- the value helpers of <algorithm>
ccl_macro_min(A, B, E) :- ccl_c_expr("((@A) < (@B) ? (@A) : (@B))", ['A' = expr(A), 'B' = expr(B)], E).
ccl_macro_max(A, B, E) :- ccl_c_expr("((@A) < (@B) ? (@B) : (@A))", ['A' = expr(A), 'B' = expr(B)], E).
ccl_macro_clamp(V, Lo, Hi, E) :- ccl_c_expr("((@V) < (@Lo) ? (@Lo) : (@Hi) < (@V) ? (@Hi) : (@V))", ['V' = expr(V), 'Lo' = expr(Lo), 'Hi' = expr(Hi)], E).
ccl_macro_swap_values(A, B, S) :- ccl_c_stmts("{ __typeof__(@A) alg_t = @A; @A = @B; @B = alg_t; }", ['A' = expr(A), 'B' = expr(B)], S).

%% -- the searches over an ordered range: a place is an index, end is size
ccllib_alg_lower(V, X, E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_expr("({ size_t alg_lo = 0, alg_hi = @{N}_size(&@V); while (alg_lo < alg_hi) { size_t alg_m = alg_lo + (alg_hi - alg_lo) / 2; if (@{N}_at(&@V, alg_m) < @X) alg_lo = alg_m + 1; else alg_hi = alg_m; } alg_lo; })", ['X' = expr(X)|Hs0], E).
ccl_macro_lower_bound(V, X, E) :- ccllib_alg_lower(V, X, E).
ccllib_alg_upper(V, X, E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_expr("({ size_t alg_lo = 0, alg_hi = @{N}_size(&@V); while (alg_lo < alg_hi) { size_t alg_m = alg_lo + (alg_hi - alg_lo) / 2; if (!(@X < @{N}_at(&@V, alg_m))) alg_lo = alg_m + 1; else alg_hi = alg_m; } alg_lo; })", ['X' = expr(X)|Hs0], E).
ccl_macro_upper_bound(V, X, E) :- ccllib_alg_upper(V, X, E).
ccl_macro_binary_search(V, X, E) :- ccllib_alg_lower(V, X, K), ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_expr("({ size_t alg_k = @K; alg_k < @{N}_size(&@V) && !(@X < @{N}_at(&@V, alg_k)) && !(@{N}_at(&@V, alg_k) < @X); })", ['K' = expr(K), 'X' = expr(X)|Hs0], E).

%% -- a loop over the elements, as C++20's ranges::for_each and the views become
ccl_macro_for_each(V, id(A), unread(B), S) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t alg_n = @{N}_size(&@V); for (size_t alg_i = 0; alg_i < alg_n; alg_i++) { @T @A = @{N}_at(&@V, alg_i); @B; } }",
                ['A' = name(A), 'B' = unread(B)|Hs0], S).
ccl_macro_each(V, id(A), unread(B), S) :- ccl_macro_for_each(V, id(A), unread(B), S).
ccl_macro_transform(V, id(A), unread(C), S) :- ccllib_alg_mut(V, _, N, T, 'transform'), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t alg_n = @{N}_size(&@V); for (size_t alg_i = 0; alg_i < alg_n; alg_i++) { @T @A = @{N}_at(&@V, alg_i); *@{N}_index(&@V, alg_i) = (@C); } }",
                ['A' = name(A), 'C' = unread(C)|Hs0], S).
ccl_macro_copy(A, B, S) :- ccllib_alg_range(A, _, N, T), ccllib_alg_mut(B, _, M, _, 'copy'), ccllib_alg_holes(A, N, T, Hs0),
    ccl_c_stmts("{ size_t alg_n = @{N}_size(&@A), alg_m = @{M}_size(&@B); if (alg_m < alg_n) alg_n = alg_m; for (size_t alg_i = 0; alg_i < alg_n; alg_i++) *@{M}_index(&@B, alg_i) = @{N}_at(&@A, alg_i); }",
                ['B' = expr(B), 'M' = name(M)|Hs0], S).

%% -- the filter view as a loop
ccl_macro_filter(V, id(A), unread(C), unread(B), S) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t alg_n = @{N}_size(&@V); for (size_t alg_i = 0; alg_i < alg_n; alg_i++) { @T @A = @{N}_at(&@V, alg_i); if (@C) { @B; } } }",
                ['A' = name(A), 'C' = unread(C), 'B' = unread(B)|Hs0], S).
ccl_macro_take(V, K, id(A), unread(B), S) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t alg_n = @{N}_size(&@V), alg_k = @K; if (alg_k > alg_n) alg_k = alg_n; for (size_t alg_i = 0; alg_i < alg_k; alg_i++) { @T @A = @{N}_at(&@V, alg_i); @B; } }",
                ['K' = expr(K), 'A' = name(A), 'B' = unread(B)|Hs0], S).
ccl_macro_drop(V, K, id(A), unread(B), S) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t alg_n = @{N}_size(&@V), alg_k = @K, alg_i = alg_k < alg_n ? alg_k : alg_n; for (; alg_i < alg_n; alg_i++) { @T @A = @{N}_at(&@V, alg_i); @B; } }",
                ['K' = expr(K), 'A' = name(A), 'B' = unread(B)|Hs0], S).
