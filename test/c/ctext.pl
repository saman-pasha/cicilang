%% C TEXT (0.260): the reader gate's macros -- the type door, a literal that holds no hole, a name the program
%% #defines, and texts that do not read
ctype(X, str(Codes)) :- ccl_type_of(X, T), ccl_c_type("const @T *", ['T' = type(T)], P), term_to_atom(P, A), atom_codes(A, Codes).
lit(_, E) :- ccl_c_expr("\"@x and @{y}\"", [], E).
plus_n(X, E) :- ccl_c_expr("@x + N", [x = expr(X)], E).
bad_items(_, Items) :- ccl_c_items("int f(void) {
    return 1
}", [], Items).
no_hole(X, E) :- ccl_c_expr("@y + 1", [x = expr(X)], E).
