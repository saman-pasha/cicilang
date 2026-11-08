%% TYPE MACROS THAT ARE REFUSED (0.261): one that fails, two instances that one name names, a typed call of a macro
%% that has no typed form
type_none([_], _, _) :- fail.
type_pair([A, B], base([], [typedef(N)]), Items) :-
    ccl_instance_name(pair, [A, B], N),
    ccl_c_items("typedef struct @N { @A first; @B second; } @N;", ['N' = name(N), 'A' = type(A), 'B' = type(B)], Items).
twice(X, bin('*', X, int(2))).
