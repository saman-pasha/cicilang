%% ccllib's <array.pl> (0.275; CCLLIB.md's phase 1a): std::array for cicilang's C, and for cicilang++ beside libc++'s.
%%
%%   #include <array.pl>
%%   array<int, 3> a = [5, 3, 9];   a struct of three ints: no heap, no drop
%%   a[0] = 7;  fill(a, 1);  b := a; an array is a value: `b := a' and `f(a)' copy, as std::array's do
%%
%% type_array/3 gives the instance's type, `array_int_3', a struct of one C array; fn_array/3 gives ONE function of the
%% instance at its first call (ccl_inst_ensure/1 in library(ccl_syntax)). The names are std::array's. What differs from
%% C++:
%%   an element is a value with no pointer in it, as a vector's is (CCLLIB.md's open decision 2);
%%   at(a, i) and a[i] stop the program (abort) at an index past the end, where C++'s at throws and [] is undefined;
%%     a literal of more elements than the array has stops it too, where C++ refuses it where it is written;
%%   begin(a), end(a), data(a) and &a[i] are borrows of the array, tied to it;
%%   the comparisons compare with `==' and `<'; a count of zero is refused, since C has no array of none.
:- ensure_loaded(library(ccllib/ccllib)).
type_array([T, int(K)], base([], [typedef(N)]), Items) :-
    ccl_instance_name(array, [T, K], N), ccllib_plain_element('an array''s element', T),
    ( K >= 1 -> true ; ccl_macro_error('an array has one element at least') ),
    atom_number(KA, K),
    ccl_c_items("typedef struct @N { @T a[@k]; } @N;", ['N' = name(N), 'T' = type(T), k = name(KA)], Items).
fn_array(Name, [T, int(K)], Items) :-
    ( ccllib_array_get(Name, K, Text) -> true ; ccllib_array_fn(Name, Text) ), ccl_instance_name(array, [T, K], N), atom_number(KA, K),
    ccl_c_items(Text, ['N' = name(N), 'T' = type(T), k = name(KA)], Items).
%% a function's C text by its name; @k is the count
ccllib_array_fn(size, "size_t @{N}_size(const @N *v) { return sizeof(v->a) / sizeof(v->a[0]); }").
ccllib_array_fn(len, "size_t @{N}_len(const @N *v) { return sizeof(v->a) / sizeof(v->a[0]); }").
ccllib_array_fn(max_size, "size_t @{N}_max_size(const @N *v) { return sizeof(v->a) / sizeof(v->a[0]); }").
ccllib_array_fn(empty, "int @{N}_empty(const @N *v) { return sizeof(v->a) == 0; }").
ccllib_array_fn(at, "@T @{N}_at(const @N *v, size_t i) { if (i >= @k) abort(); return v->a[i]; }").
ccllib_array_fn(index, "@T *@{N}_index(const @N *v, size_t i) tie v { if (i >= @k) abort(); return (@T *)&v->a[i]; }").
ccllib_array_fn(front, "@T @{N}_front(const @N *v) { return v->a[0]; }").
ccllib_array_fn(back, "@T @{N}_back(const @N *v) { return v->a[@k - 1]; }").
ccllib_array_fn(data, "@T *@{N}_data(const @N *v) tie v { return (@T *)v->a; }").
ccllib_array_fn(begin, "@T *@{N}_begin(const @N *v) tie v { return (@T *)v->a; }").
ccllib_array_fn(end, "@T *@{N}_end(const @N *v) tie v { return (@T *)v->a + @k; }").
ccllib_array_fn(fill, "void @{N}_fill(@N *v, @T x) { for (size_t i = 0; i < @k; i++) v->a[i] = x; }").
ccllib_array_fn(swap, "void @{N}_swap(@N *a, @N *b) { @N t = *a; *a = *b; *b = t; }").
ccllib_array_fn(from, "@N @{N}_from(const @T *a, size_t n) {
    @N v = {0};
    if (n > @k) abort();
    for (size_t i = 0; i < n; i++) v.a[i] = a[i];
    return v;
}").
ccllib_array_fn(eq, "int @{N}_eq(const @N *a, const @N *b) {
    for (size_t i = 0; i < @k; i++) if (!(a->a[i] == b->a[i])) return 0;
    return 1;
}").
%% THE RELATIONS ARE C++20'S (0.304): the synthesized three-way order of the elements, where a pair that is neither
%% `<' nor `==' either way -- a NaN -- is unordered and ends the comparison, every relation false; `<=' and `>=' are
%% _le and _ge, which the reader asks first
ccllib_array_fn(lt, "int @{N}_lt(const @N *a, const @N *b) {
    for (size_t i = 0; i < @k; i++) {
        if (a->a[i] < b->a[i]) return 1;
        if (b->a[i] < a->a[i]) return 0;
        if (!(a->a[i] == b->a[i])) return 0;
    }
    return 0;
}").
ccllib_array_fn(le, "int @{N}_le(const @N *a, const @N *b) {
    for (size_t i = 0; i < @k; i++) {
        if (a->a[i] < b->a[i]) return 1;
        if (b->a[i] < a->a[i]) return 0;
        if (!(a->a[i] == b->a[i])) return 0;
    }
    return 1;
}").
ccllib_array_fn(ge, "int @{N}_ge(const @N *a, const @N *b) { return @{N}_le(b, a); }").
%% `get<I>(a)' IS ELEMENT I'S PLACE (0.305; the reader's typed call by name, dereferenced by the fact place_array_get):
%% an index within the count, which the read checks, as C++'s get is checked where it is written, where `a[i]' is
%% checked when it runs; an index past the end is no function
ccllib_array_get(Name, K, Text) :- atom(Name), atom_concat(get_, W, Name), ccllib_index_word(W, I), I < K,
    atomic_list_concat(['@T *@{N}_', Name, '(const @N *v) tie v { return (@T *)&v->a[', I, ']; }'], Text).
place_array_get.
