%% THE FIRST PROOF AFTER PHASE 0 (0.273; CCLLIB.md's Order): vector<T> with push, at, len and sort, dropped where its
%% scope ends -- a type macro's instance (0.261), its literal's from (0.263), its drop (autodrop, 0.262), all of it C text
%% (0.260). at stops the program at an index past the end, where std::vector's at throws, and push where no memory is
%% left. sort is std::sort's kind over `<', in place and with no function pointer: a quicksort about the median of
%% three whose partition has no branch on a comparison (a place is given always, the count goes on by the comparison's
%% value), the part below the pivot by a call and the rest in the loop; what is equal to the pivot of the range before
%% it is passed over in one pass, so many equal values cost one pass each; an insertion sort for a range of sixteen or
%% less; and a heap sort for a range that 2 * log2(len) partitions did not end, so the worst case is n log n too.
%% A null pointer is written 0: the text is lexed, never preprocessed, and NULL is a header's macro
type_vector([T], base([], [typedef(N)]), Items) :-
    ccl_instance_name(vector, [T], N),
    ccl_c_items("typedef struct @N { size_t len, cap; own @T *data; } @N;
void @{N}_push(@N *v, @T x) {
    if (v->len == v->cap) {
        v->cap = v->cap ? 2 * v->cap : 4;
        v->data = (@T *)realloc(v->data, v->cap * sizeof(@T));
        if (!v->data) abort();
    }
    v->data[v->len++] = x;
}
@T @{N}_at(const @N *v, size_t i) { if (i >= v->len) abort(); return v->data[i]; }
size_t @{N}_len(const @N *v) { return v->len; }
static void @{N}_sift(@T *a, size_t i, size_t n) {
    for (;;) {
        size_t k = 2 * i + 1;
        if (k >= n) return;
        if (k + 1 < n && a[k] < a[k + 1]) k++;
        if (!(a[i] < a[k])) return;
        @T t = a[i]; a[i] = a[k]; a[k] = t;
        i = k;
    }
}
static void @{N}_heap(@T *a, size_t n) {
    for (size_t i = n / 2; i > 0; i--) @{N}_sift(a, i - 1, n);
    for (size_t m = n; m > 1; m--) { @T t = a[0]; a[0] = a[m - 1]; a[m - 1] = t; @{N}_sift(a, 0, m - 1); }
}
static void @{N}_intro(@T *a, size_t n, int depth, const @T *low) {
    while (n > 16) {
        if (depth-- == 0) { @{N}_heap(a, n); return; }
        size_t m = n / 2, i = 1;
        if (a[m] < a[0]) { @T t = a[m]; a[m] = a[0]; a[0] = t; }
        if (a[n - 1] < a[0]) { @T t = a[n - 1]; a[n - 1] = a[0]; a[0] = t; }
        if (a[n - 1] < a[m]) { @T t = a[n - 1]; a[n - 1] = a[m]; a[m] = t; }
        @T p = a[m];
        a[m] = a[0];
        if (low && !(*low < p)) {
            for (size_t j = 1; j < n; j++) { @T x = a[j]; a[j] = a[i]; a[i] = x; i += !(p < x); }
            a[0] = p;
            low = a + i - 1; a += i; n -= i;
            continue;
        }
        for (size_t j = 1; j < n; j++) { @T x = a[j]; a[j] = a[i]; a[i] = x; i += x < p; }
        a[0] = a[i - 1]; a[i - 1] = p;
        @{N}_intro(a, i - 1, depth, low);
        low = a + i - 1; a += i; n -= i;
    }
    for (size_t i = 1; i < n; i++) {
        @T t = a[i];
        size_t j = i;
        while (j > 0 && t < a[j - 1]) { a[j] = a[j - 1]; j--; }
        a[j] = t;
    }
}
void @{N}_sort(@N *v) {
    int depth = 0;
    for (size_t n = v->len; n > 1; n >>= 1) depth += 2;
    @{N}_intro(v->data, v->len, depth, 0);
}
void @{N}_drop(@N *v) { free(v->data); }
@N @{N}_from(const @T *a, size_t n) { @N v = {0}; for (size_t i = 0; i < n; i++) @{N}_push(&v, a[i]); return v; }", ['N' = name(N), 'T' = type(T)], Items).
%% the generic calls find their instance by the type of their first argument; a macro named as a builtin of cocolog's at
%% its arity is written ccl_macro_NAME (sort/2)
push(V, X, call(id(F), [addr(V), X])) :- vec_name(V, N), atom_concat(N, '_push', F).
at(V, I, call(id(F), [addr(V), I])) :- vec_name(V, N), atom_concat(N, '_at', F).
len(V, call(id(F), [addr(V)])) :- vec_name(V, N), atom_concat(N, '_len', F).
ccl_macro_sort(V, call(id(F), [addr(V)])) :- vec_name(V, N), atom_concat(N, '_sort', F).
vec_name(V, N) :- ccl_type_of(V, base(_, [typedef(N)])).
