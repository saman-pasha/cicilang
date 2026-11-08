%% ARGUMENTS READ AFTER THE MACRO (0.264; CCLLIB.md's phase 0.7): unread(_) at a place of a clause head takes that
%% argument unread, its tokens, and the macro's C text reads it where the text puts it -- after the text declares the
%% names that the argument uses, so a macro in the argument sees them. loop(n, k, body): body for n from 0 to k - 1
loop(id(N), K, unread(B), S) :- ccl_c_stmts("for (int @n = 0; @n < @k; @n++) { @b; }", [n = name(N), k = expr(K), b = unread(B)], S).
%% each(v, x, body): body for each element x of the vector v, x of its element type
each(V, id(X), unread(B), S) :- ur_elem(V, T), ccl_gensym(i, I),
    ccl_c_stmts("for (size_t @i = 0; @i < @v.len; @i++) { @T @x = @v.data[@i]; @b; }", ['T' = type(T), v = expr(V), i = name(I), x = name(X), b = unread(B)], S).
%% sum_by(v, x, e): the sum of e over the elements x of v, a value
sum_by(V, id(X), unread(E), R) :- ur_elem(V, T), ccl_gensym(i, I), ccl_gensym(s, Sm),
    ccl_c_expr("({ @T @s = 0; for (size_t @i = 0; @i < @v.len; @i++) { @T @x = @v.data[@i]; @s += (@e); } @s; })",
        ['T' = type(T), v = expr(V), i = name(I), s = name(Sm), x = name(X), e = unread(E)], R).
%% sort_by(v, a, b, before): an insertion sort, `before' true where a goes before b -- an expression put into the loop,
%% no function pointer (CCLLIB.md's first example)
sort_by(V, id(A), id(B), unread(C), S) :- ur_elem(V, T), ccl_gensym(i, I), ccl_gensym(j, J),
    ccl_c_stmts("for (size_t @i = 1; @i < @v.len; @i++) for (size_t @j = @i; @j > 0; @j--) { @T @a = @v.data[@j], @b = @v.data[@j - 1]; if (!(@c)) break; @v.data[@j - 1] = @a; @v.data[@j] = @b; }",
        ['T' = type(T), v = expr(V), i = name(I), j = name(J), a = name(A), b = name(B), c = unread(C)], S).
%% the element type: the result of the instance's `at'
ur_elem(V, T) :- ccl_type_of(V, base(_, [typedef(N)])), atom_concat(N, '_at', F), ccl_type_of(call(id(F), [addr(V), int(0)]), T).
