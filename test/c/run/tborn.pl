%% AN INSTANCE'S BIRTH (0.285): an object declared with no initializer is given zero, with a drop or with none, and an
%% object is made of a value of another type by its type macro's `_of'.
%% mask<K>: K bits in a word, a value with no drop. It is made of a number (`_of'), cut to its K bits, and of a text of
%% 0 and 1 whose last character is the bit 0 (`_of_ptr_char'; a literal is `const char *' in C++, `_of_ptr_const_char')
type_mask([int(K)], base([], [typedef(N)]), Items) :- ccl_instance_name(mask, [K], N), atom_number(KA, K),
    ccl_c_items("typedef struct @N { unsigned long long w; } @N;
@N @{N}_of(unsigned long long x) { @N r = { @k >= 64 ? x : x & ((1ULL << @k) - 1) }; return r; }
static @N @{N}__text(const char *s) {
    unsigned long long x = 0;
    for (; *s; s++) x = x << 1 | (unsigned long long)(*s == '1');
    return @{N}_of(x);
}
@N @{N}_of_ptr_char(char *s) { return @{N}__text(s); }
@N @{N}_of_ptr_const_char(const char *s) { return @{N}__text(s); }", ['N' = name(N), k = name(KA)], Items).
%% box<T>: one T on the heap, or none: a type that has a drop. Declared with no initializer it is the empty box, and
%% `box<int> q = 42;' is `box_int_of(42)'
type_box([T], base([], [typedef(N)]), Items) :- ccl_instance_name(box, [T], N),
    ccl_c_items("typedef struct @N { own @T *p; } @N;
@N @{N}_of(@T x) {
    @N b = {0};
    b.p = (@T *)malloc(sizeof(@T));
    if (!b.p) abort();
    *b.p = x;
    return b;
}
int @{N}_full(const @N *b) { return b->p != 0; }
@T @{N}_get(const @N *b) { return *b->p; }
void @{N}_drop(@N *b) { free(b->p); }", ['N' = name(N), 'T' = type(T)], Items).
