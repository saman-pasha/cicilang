%% AUTODROP (0.262): a type whose drop frees nothing, for test/c/safe/drop_leaks.c
type_bag([T], base([], [typedef(N)]), Items) :-
    ccl_instance_name(bag, [T], N),
    ccl_c_items("typedef struct @N { own @T *data; } @N;
void @{N}_fill(@N *b) { free(b->data); b->data = malloc(sizeof(@T)); }
void @{N}_drop(@N *b) { (void)b; }", ['N' = name(N), 'T' = type(T)], Items).
