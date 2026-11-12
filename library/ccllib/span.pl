%% ccllib's <span.pl> (0.295; CCLLIB.md's phase 1a): std::span<T> for cicilang's C, and for cicilang++ beside libc++'s,
%% of a count that its object holds (std::span's dynamic_extent).
%%
%%   #include <span.pl>
%%   int a[5];  span<int> s = a;      of a C array, its count the array's; of a vector<int>, of an array<int, 5>
%%   span<int> t = {p, n};            of a pointer and a count, by C's own braces of a struct
%%   span<const int> c = s;           a span of const elements, of a span, a vector or an array of the same type
%%   s[0] = 7;  u := first(s, 2);  w := subspan(s, 1, 3);  for (int *p = begin(s); p != end(s); p++) ...;
%%
%% A SPAN IS A BORROW (the safe part's topic of views, ck_view_type/1): the fact `view_span' below names this type
%% macro a view's, so the safe part takes a span for a borrow of the elements that it sees, as a string_view of
%% <string_view.pl> is one: a span used after its source ends, or after a call that may replace a vector's buffer, is
%% refused, and so is a span of a local that leaves its function. A span frees nothing and has no drop; `b = a' and a
%% call that takes a span by value copy the borrow.
%%
%% type_span/3 gives the instance's type, `span_int': the first element and the count. fn_span/3 gives ONE function of
%% the instance at its first use. The names are std::span's. What differs from C++ is CCLLIB.md's section of the span:
%% an element is a value with no pointer in it, as a vector's is (CCLLIB.md's open decision 2); a place or a count past
%% the end stops the program (abort), where C++ is undefined; front, back and at are values, as a vector's are; there
%% is no fixed extent (`span<int, 5>'), no as_bytes (C has no std::byte) and no reverse iterator.
:- ensure_loaded(library(ccllib/ccllib)).
view_span.
type_span([T], base([], [typedef(N)]), Items) :- !,
    ccl_instance_name(span, [T], N), ccllib_plain_element('a span''s element', T),
    ccl_c_items("typedef struct @N { @T *data; size_t len; } @N;", ['N' = name(N), 'T' = type(T)], Items).
type_span(_, _, _) :- ccl_macro_error('a span has one type argument: its count is its object''s, and a fixed extent (span<T, N>) waits').
fn_span(Name, [T], Items) :-
    ccl_instance_name(span, [T], N), ccllib_span_fn(Name, N, T, Text, Holes),
    ccl_c_items(Text, ['N' = name(N), 'T' = type(T)|Holes], Items).
%% a function's C text by its name, and the holes that it has besides @N and @T.
%% -- A SPAN MADE: of a C array of a known count, by the function named with the array's word, `_of_arr_5_int', which
%% the reader asks first for an array (0.295); of an instance whose elements stand in one buffer -- a vector, an array
%% of <array.pl> --, and of a span, for a span of const elements; each tied to its source. Its elements are the
%% source's, or const ones of the same type, as C++ converts them
ccllib_span_fn(Name, N, T, "@N @{N}_@{F}(@T *a) tie a { return (@N){ a, @k }; }", ['F' = name(Name), k = name(KA)]) :-
    atom_concat('of_arr_', Rest, Name), atomic_list_concat([KA|Ws], '_', Rest), Ws \== [],
    catch(atom_number(KA, K), _, fail), integer(K), !, atomic_list_concat(Ws, '_', EW), ccllib_span_takes(N, T, 'an array of', EW).
ccllib_span_fn(Name, N, T, Text, ['F' = name(Name), 'S' = name(IW)|Hs]) :-
    atom_concat(of_, IW, Name), nb_current('$ccl_instances', Is), member(inst(M, As, _, _), Is),
    ccl_instance_name(M, As, IW), ccllib_span_source(M, As, Text, Hs), !,
    As = [ET|_], ccl_arg_words([ET], [EW]), ccllib_span_takes(N, T, 'the elements', EW).
ccllib_span_fn(Name, _, _, Text, []) :- ccllib_span_text(Name, Text).
%% the instances that a span is made of: the text of the function, whose name is @F and whose source's type is @S, and
%% the hole of an array's count
ccllib_span_source(vector, [_], "@N @{N}_@{F}(const @S *v) tie v { return (@N){ v->data, v->len }; }", []).
ccllib_span_source(array, [_, K0], "@N @{N}_@{F}(const @S *v) tie v { return (@N){ (@T *)v->a, @k }; }", [k = name(KA)]) :-
    ( K0 = int(K) -> true ; K = K0 ), atom_number(KA, K).
ccllib_span_source(span, [_], "@N @{N}_@{F}(const @S *v) tie v { return (@N){ v->data, v->len }; }", []).
%% a span of T takes elements of T, and of the type whose const T is
ccllib_span_takes(N, T, What, EW) :-
    ccl_arg_words([T], [TW]),
    (   TW == EW -> true
    ;   atom_concat(const_, EW, TW) -> true
    ;   atomic_list_concat(['a ', N, ' is not made of ', What, ' ', EW, ': its elements are ', TW], M), ccl_macro_error(M) ).
%% -- the count and the elements. `s[i]' is a place, the element's (`_index'); front, back and at are values
ccllib_span_text(size, "size_t @{N}_size(const @N *v) { return v->len; }").
ccllib_span_text(size_bytes, "size_t @{N}_size_bytes(const @N *v) { return v->len * sizeof(@T); }").
ccllib_span_text(empty, "int @{N}_empty(const @N *v) { return v->len == 0; }").
ccllib_span_text(data, "@T *@{N}_data(const @N *v) tie v { return v->data; }").
ccllib_span_text(begin, "@T *@{N}_begin(const @N *v) tie v { return v->data; }").
ccllib_span_text(end, "@T *@{N}_end(const @N *v) tie v { return v->data + v->len; }").
ccllib_span_text(index, "@T *@{N}_index(const @N *v, size_t i) tie v { if (i >= v->len) abort(); return &v->data[i]; }").
ccllib_span_text(at, "@T @{N}_at(const @N *v, size_t i) { if (i >= v->len) abort(); return v->data[i]; }").
ccllib_span_text(front, "@T @{N}_front(const @N *v) { if (v->len == 0) abort(); return v->data[0]; }").
ccllib_span_text(back, "@T @{N}_back(const @N *v) { if (v->len == 0) abort(); return v->data[v->len - 1]; }").
%% -- a part of the elements: the first n, the last n, from an offset on, and n of them from an offset (n ==
%% dynamic_extent, every element after the offset)
ccllib_span_text(first, "@N @{N}_first(const @N *v, size_t n) tie v { if (n > v->len) abort(); return (@N){ v->data, n }; }").
ccllib_span_text(last, "@N @{N}_last(const @N *v, size_t n) tie v {
    if (n > v->len) abort();
    return (@N){ v->data + (v->len - n), n };
}").
ccllib_span_text(subspan, "@N @{N}_subspan(const @N *v, size_t off) tie v {
    if (off > v->len) abort();
    return (@N){ v->data + off, v->len - off };
}").
ccllib_span_text(subspan3, "@N @{N}_subspan3(const @N *v, size_t off, size_t n) tie v {
    if (off > v->len) abort();
    if (n == (size_t)-1) n = v->len - off;
    else if (n > v->len - off) abort();
    return (@N){ v->data + off, n };
}").
