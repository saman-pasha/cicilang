%% AUTODROP (0.262; CCLLIB.md's phase 0.5): track<T> holds a name that it owns and a value; its drop prints the name
%% and frees it. A moved object is left empty, its name null, and its drop prints nothing
type_track([T], base([], [typedef(N)]), Items) :-
    ccl_instance_name(track, [T], N),
    ccl_c_items("typedef struct @N { own char *tag; @T val; } @N;
@N @{N}_make(const char *tag, @T v) { @N t = { strdup(tag), v }; return t; }
void @{N}_drop(@N *t) { if (t->tag) printf(\"drop %s\\n\", t->tag); free(t->tag); }", ['N' = name(N), 'T' = type(T)], Items).
%% tracked<T>(tag, v): a new track<T>, its instance made by the declaration that names the type
tracked(types([T]), Tag, V, call(id(F), [Tag, V])) :- ccl_instance_name(track, [T], N), atom_concat(N, '_make', F).
