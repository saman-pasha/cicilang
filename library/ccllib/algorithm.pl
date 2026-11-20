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
    ccl_c_stmts("{ size_t __ccl_n = @{N}_size(&@V); for (size_t __ccl_i = 1; __ccl_i < __ccl_n; __ccl_i++) { @T __ccl_x = @{N}_at(&@V, __ccl_i); size_t __ccl_j = __ccl_i; while (__ccl_j > 0) { if (!(__ccl_x < @{N}_at(&@V, __ccl_j - 1))) break; *@{N}_index(&@V, __ccl_j) = @{N}_at(&@V, __ccl_j - 1); __ccl_j--; } *@{N}_index(&@V, __ccl_j) = __ccl_x; } }", Hs, S).
ccl_macro_stable_sort(V, S) :- ccl_macro_sort(V, S).
ccl_macro_sort_by(V, id(A), id(B), unread(C), S) :- ccllib_alg_mut(V, _, N, T, 'sort_by'), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t __ccl_n = @{N}_size(&@V); for (size_t __ccl_i = 1; __ccl_i < __ccl_n; __ccl_i++) { @T __ccl_x = @{N}_at(&@V, __ccl_i); size_t __ccl_j = __ccl_i; while (__ccl_j > 0) { @T @A = __ccl_x, @B = @{N}_at(&@V, __ccl_j - 1); if (!(@C)) break; *@{N}_index(&@V, __ccl_j) = @B; __ccl_j--; } *@{N}_index(&@V, __ccl_j) = __ccl_x; } }",
                ['A' = name(A), 'B' = name(B), 'C' = unread(C)|Hs0], S).
ccl_macro_stable_sort_by(V, id(A), id(B), unread(C), S) :- ccl_macro_sort_by(V, id(A), id(B), unread(C), S).
%% partial_sort(v, n): the first n elements in order, the rest where they were (a selection sort over the prefix)
ccl_macro_partial_sort(V, K, S) :- ccllib_alg_mut(V, _, N, T, 'partial_sort'), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t __ccl_n = @{N}_size(&@V); size_t __ccl_k = @K; if (__ccl_k > __ccl_n) __ccl_k = __ccl_n; for (size_t __ccl_i = 0; __ccl_i < __ccl_k; __ccl_i++) { size_t __ccl_m = __ccl_i; for (size_t __ccl_j = __ccl_i + 1; __ccl_j < __ccl_n; __ccl_j++) if (@{N}_at(&@V, __ccl_j) < @{N}_at(&@V, __ccl_m)) __ccl_m = __ccl_j; if (__ccl_m != __ccl_i) { @T __ccl_x = @{N}_at(&@V, __ccl_i); *@{N}_index(&@V, __ccl_i) = @{N}_at(&@V, __ccl_m); *@{N}_index(&@V, __ccl_m) = __ccl_x; } } }",
                ['K' = expr(K)|Hs0], S).

%% -- the order of the elements
ccl_macro_reverse(V, S) :- ccllib_alg_mut(V, _, N, T, 'reverse'), ccllib_alg_holes(V, N, T, Hs),
    ccl_c_stmts("{ size_t __ccl_n = @{N}_size(&@V); for (size_t __ccl_i = 0; __ccl_i < __ccl_n / 2; __ccl_i++) { @T __ccl_x = @{N}_at(&@V, __ccl_i); *@{N}_index(&@V, __ccl_i) = @{N}_at(&@V, __ccl_n - 1 - __ccl_i); *@{N}_index(&@V, __ccl_n - 1 - __ccl_i) = __ccl_x; } }", Hs, S).
ccl_macro_fill(V, X, S) :- ccllib_alg_mut(V, _, N, T, 'fill'), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t __ccl_n = @{N}_size(&@V); @T __ccl_x = @X; for (size_t __ccl_i = 0; __ccl_i < __ccl_n; __ccl_i++) *@{N}_index(&@V, __ccl_i) = __ccl_x; }", ['X' = expr(X)|Hs0], S).
ccl_macro_replace(V, X, Y, S) :- ccllib_alg_mut(V, _, N, T, 'replace'), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t __ccl_n = @{N}_size(&@V); __typeof__(@X) __ccl_x = @X; @T __ccl_y = @Y; for (size_t __ccl_i = 0; __ccl_i < __ccl_n; __ccl_i++) if (@{N}_at(&@V, __ccl_i) == __ccl_x) *@{N}_index(&@V, __ccl_i) = __ccl_y; }", ['X' = expr(X), 'Y' = expr(Y)|Hs0], S).
ccl_macro_replace_if(V, id(A), unread(C), Y, S) :- ccllib_alg_mut(V, _, N, T, 'replace_if'), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t __ccl_n = @{N}_size(&@V); @T __ccl_y = @Y; for (size_t __ccl_i = 0; __ccl_i < __ccl_n; __ccl_i++) { @T @A = @{N}_at(&@V, __ccl_i); if (@C) *@{N}_index(&@V, __ccl_i) = __ccl_y; } }",
                ['A' = name(A), 'C' = unread(C), 'Y' = expr(Y)|Hs0], S).

%% -- the counts and the tests. A place is an index, and the end is the size
ccl_macro_count(V, X, E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccllib_once(expr, "({ size_t __ccl_n = @{N}_size(&@V), __ccl_k = 0; for (size_t __ccl_i = 0; __ccl_i < __ccl_n; __ccl_i++) if (@{N}_at(&@V, __ccl_i) == @X) __ccl_k++; __ccl_k; })",
                ['X' = X], Hs0, E).
ccl_macro_count_if(V, id(A), unread(C), E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_expr("({ size_t __ccl_n = @{N}_size(&@V), __ccl_k = 0; for (size_t __ccl_i = 0; __ccl_i < __ccl_n; __ccl_i++) { @T @A = @{N}_at(&@V, __ccl_i); if (@C) __ccl_k++; } __ccl_k; })",
               ['A' = name(A), 'C' = unread(C)|Hs0], E).
ccl_macro_all_of(V, id(A), unread(C), E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_expr("({ size_t __ccl_n = @{N}_size(&@V); int __ccl_ok = 1; for (size_t __ccl_i = 0; __ccl_i < __ccl_n; __ccl_i++) { @T @A = @{N}_at(&@V, __ccl_i); if (!(@C)) { __ccl_ok = 0; break; } } __ccl_ok; })",
               ['A' = name(A), 'C' = unread(C)|Hs0], E).
ccl_macro_any_of(V, id(A), unread(C), E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_expr("({ size_t __ccl_n = @{N}_size(&@V); int __ccl_ok = 0; for (size_t __ccl_i = 0; __ccl_i < __ccl_n; __ccl_i++) { @T @A = @{N}_at(&@V, __ccl_i); if (@C) { __ccl_ok = 1; break; } } __ccl_ok; })",
               ['A' = name(A), 'C' = unread(C)|Hs0], E).
ccl_macro_none_of(V, id(A), unread(C), E) :- ccl_macro_all_of(V, id(A), unread(C), E0),
    ccl_c_expr("!(@A0)", ['A0' = expr(E0)], E).

%% -- the places
ccl_macro_find(V, X, E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccllib_once(expr, "({ size_t __ccl_n = @{N}_size(&@V), __ccl_k = __ccl_n; for (size_t __ccl_i = 0; __ccl_i < __ccl_n; __ccl_i++) if (@{N}_at(&@V, __ccl_i) == @X) { __ccl_k = __ccl_i; break; } __ccl_k; })", ['X' = X], Hs0, E).
ccl_macro_find_if(V, id(A), unread(C), E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_expr("({ size_t __ccl_n = @{N}_size(&@V), __ccl_k = __ccl_n; for (size_t __ccl_i = 0; __ccl_i < __ccl_n; __ccl_i++) { @T @A = @{N}_at(&@V, __ccl_i); if (@C) { __ccl_k = __ccl_i; break; } } __ccl_k; })",
               ['A' = name(A), 'C' = unread(C)|Hs0], E).
ccl_macro_min_element(V, E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_expr("({ size_t __ccl_n = @{N}_size(&@V), __ccl_k = 0; for (size_t __ccl_i = 1; __ccl_i < __ccl_n; __ccl_i++) if (@{N}_at(&@V, __ccl_i) < @{N}_at(&@V, __ccl_k)) __ccl_k = __ccl_i; __ccl_k; })", Hs0, E).
ccl_macro_max_element(V, E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_expr("({ size_t __ccl_n = @{N}_size(&@V), __ccl_k = 0; for (size_t __ccl_i = 1; __ccl_i < __ccl_n; __ccl_i++) if (@{N}_at(&@V, __ccl_k) < @{N}_at(&@V, __ccl_i)) __ccl_k = __ccl_i; __ccl_k; })", Hs0, E).

%% -- the order tests
ccl_macro_equal(A, B, E) :- ccllib_alg_range(A, _, N, T), ccllib_alg_range(B, _, M, _), ccllib_alg_holes(A, N, T, Hs0),
    ccl_c_expr("({ size_t __ccl_n = @{N}_size(&@A), __ccl_m = @{M}_size(&@B); int __ccl_ok = __ccl_n == __ccl_m; for (size_t __ccl_i = 0; __ccl_ok && __ccl_i < __ccl_n; __ccl_i++) if (!(@{N}_at(&@A, __ccl_i) == @{M}_at(&@B, __ccl_i))) __ccl_ok = 0; __ccl_ok; })",
               ['A' = expr(A), 'B' = expr(B), 'M' = name(M)|Hs0], E).
ccl_macro_lexicographical_compare(A, B, E) :- ccllib_alg_range(A, _, N, T), ccllib_alg_range(B, _, M, _), ccllib_alg_holes(A, N, T, Hs0),
    ccl_c_expr("({ size_t __ccl_n = @{N}_size(&@A), __ccl_m = @{M}_size(&@B), __ccl_i = 0; int __ccl_ok = 0; while (__ccl_i < __ccl_n && __ccl_i < __ccl_m) { if (@{N}_at(&@A, __ccl_i) < @{M}_at(&@B, __ccl_i)) { __ccl_ok = 1; break; } if (@{M}_at(&@B, __ccl_i) < @{N}_at(&@A, __ccl_i)) break; __ccl_i++; } if (__ccl_i == __ccl_n || __ccl_i == __ccl_m) __ccl_ok = __ccl_n < __ccl_m; __ccl_ok; })",
               ['A' = expr(A), 'B' = expr(B), 'M' = name(M)|Hs0], E).

%% -- the value helpers of <algorithm>, C++'s formulas: min gives a where neither is less ([alg.min.max]/3, `b < a ? b :
%% a'), max gives a where neither is greater, clamp gives v where it is in the bounds. Each operand is read once
%% (ccllib_once/5), and swap_values takes each place once, by its address, as std::swap binds a reference
ccl_macro_min(A, B, E) :- ccllib_once(expr, "((@B) < (@A) ? (@B) : (@A))", ['A' = A, 'B' = B], [], E).
ccl_macro_max(A, B, E) :- ccllib_once(expr, "((@A) < (@B) ? (@B) : (@A))", ['A' = A, 'B' = B], [], E).
ccl_macro_clamp(V, Lo, Hi, E) :- ccllib_once(expr, "((@V) < (@Lo) ? (@Lo) : (@Hi) < (@V) ? (@Hi) : (@V))", ['V' = V, 'Lo' = Lo, 'Hi' = Hi], [], E).
ccl_macro_swap_values(A, B, S) :- ccl_c_stmts("{ __typeof__(@A) *__ccl_pa = &(@A); __typeof__(@B) *__ccl_pb = &(@B); __typeof__(@A) __ccl_t = *__ccl_pa; *__ccl_pa = *__ccl_pb; *__ccl_pb = __ccl_t; }", ['A' = expr(A), 'B' = expr(B)], S).

%% -- the searches over an ordered range: a place is an index, end is size. The value is read once (ccllib_once/5), and
%% binary_search is lower_bound's loop, then C++'s one test, `!(value < *first)' ([binary.search]/2)
ccllib_alg_lower_loop("size_t __ccl_lo = 0, __ccl_hi = @{N}_size(&@V); while (__ccl_lo < __ccl_hi) { size_t __ccl_m = __ccl_lo + (__ccl_hi - __ccl_lo) / 2; if (@{N}_at(&@V, __ccl_m) < @X) __ccl_lo = __ccl_m + 1; else __ccl_hi = __ccl_m; } ").
ccllib_alg_lower(V, X, E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0), ccllib_alg_lower_loop(L), append(["({ ", L, "__ccl_lo; })"], Text),
    ccllib_once(expr, Text, ['X' = X], Hs0, E).
ccl_macro_lower_bound(V, X, E) :- ccllib_alg_lower(V, X, E).
ccllib_alg_upper(V, X, E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccllib_once(expr, "({ size_t __ccl_lo = 0, __ccl_hi = @{N}_size(&@V); while (__ccl_lo < __ccl_hi) { size_t __ccl_m = __ccl_lo + (__ccl_hi - __ccl_lo) / 2; if (!(@X < @{N}_at(&@V, __ccl_m))) __ccl_lo = __ccl_m + 1; else __ccl_hi = __ccl_m; } __ccl_lo; })", ['X' = X], Hs0, E).
ccl_macro_upper_bound(V, X, E) :- ccllib_alg_upper(V, X, E).
ccl_macro_binary_search(V, X, E) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0), ccllib_alg_lower_loop(L),
    append(["({ ", L, "__ccl_lo < @{N}_size(&@V) && !(@X < @{N}_at(&@V, __ccl_lo)); })"], Text), ccllib_once(expr, Text, ['X' = X], Hs0, E).

%% -- a loop over the elements, as C++20's ranges::for_each and the views become
ccl_macro_for_each(V, id(A), unread(B), S) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t __ccl_n = @{N}_size(&@V); for (size_t __ccl_i = 0; __ccl_i < __ccl_n; __ccl_i++) { @T @A = @{N}_at(&@V, __ccl_i); @B; } }",
                ['A' = name(A), 'B' = unread(B)|Hs0], S).
ccl_macro_each(V, id(A), unread(B), S) :- ccl_macro_for_each(V, id(A), unread(B), S).
ccl_macro_transform(V, id(A), unread(C), S) :- ccllib_alg_mut(V, _, N, T, 'transform'), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t __ccl_n = @{N}_size(&@V); for (size_t __ccl_i = 0; __ccl_i < __ccl_n; __ccl_i++) { @T @A = @{N}_at(&@V, __ccl_i); *@{N}_index(&@V, __ccl_i) = (@C); } }",
                ['A' = name(A), 'C' = unread(C)|Hs0], S).
ccl_macro_copy(A, B, S) :- ccllib_alg_range(A, _, N, T), ccllib_alg_mut(B, _, M, _, 'copy'), ccllib_alg_holes(A, N, T, Hs0),
    ccl_c_stmts("{ size_t __ccl_n = @{N}_size(&@A), __ccl_m = @{M}_size(&@B); if (__ccl_m < __ccl_n) __ccl_n = __ccl_m; for (size_t __ccl_i = 0; __ccl_i < __ccl_n; __ccl_i++) *@{M}_index(&@B, __ccl_i) = @{N}_at(&@A, __ccl_i); }",
                ['B' = expr(B), 'M' = name(M)|Hs0], S).

%% -- the filter view as a loop
ccl_macro_filter(V, id(A), unread(C), unread(B), S) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t __ccl_n = @{N}_size(&@V); for (size_t __ccl_i = 0; __ccl_i < __ccl_n; __ccl_i++) { @T @A = @{N}_at(&@V, __ccl_i); if (@C) { @B; } } }",
                ['A' = name(A), 'C' = unread(C), 'B' = unread(B)|Hs0], S).
ccl_macro_take(V, K, id(A), unread(B), S) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t __ccl_n = @{N}_size(&@V), __ccl_k = @K; if (__ccl_k > __ccl_n) __ccl_k = __ccl_n; for (size_t __ccl_i = 0; __ccl_i < __ccl_k; __ccl_i++) { @T @A = @{N}_at(&@V, __ccl_i); @B; } }",
                ['K' = expr(K), 'A' = name(A), 'B' = unread(B)|Hs0], S).
ccl_macro_drop(V, K, id(A), unread(B), S) :- ccllib_alg_range(V, _, N, T), ccllib_alg_holes(V, N, T, Hs0),
    ccl_c_stmts("{ size_t __ccl_n = @{N}_size(&@V), __ccl_k = @K, __ccl_i = __ccl_k < __ccl_n ? __ccl_k : __ccl_n; for (; __ccl_i < __ccl_n; __ccl_i++) { @T @A = @{N}_at(&@V, __ccl_i); @B; } }",
                ['K' = expr(K), 'A' = name(A), 'B' = unread(B)|Hs0], S).
