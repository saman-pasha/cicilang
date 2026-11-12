%% ccllib's <basic_string_view.pl> (0.295; CCLLIB.md's phase 1a): std::basic_string_view<char> for cicilang's C, and
%% for cicilang++ beside libc++'s. A program includes <string_view.pl>, whose header names the instance `string_view'.
%%
%%   #include <string_view.pl>
%%   string_view v = "hello world";   of a text of C; `string_view w = s;' of a string; `string_view e;' sees nothing
%%   string_view b = {buf, n};        of a text and its count, by C's own braces of a struct
%%   w := substr(v, 6, 5);  remove_prefix(v, 6);  n = find(v, "or");  if (starts_with(v, "wor") && v == w) ...;
%%   printf("%.*s\n", (int) size(v), data(v));
%%
%% A VIEW IS A BORROW (the safe part's topic of views, ck_view_type/1): the fact `view_basic_string_view' below names
%% this type macro a view's, so the safe part takes a string_view for a borrow of the characters that it sees -- a text of C, a char
%% array, a string's characters --, as a pointer is: a view used after its source ends, or after a call that may
%% replace a string's characters, is refused, and so is a view of a local that leaves its function. A view frees
%% nothing and has no drop; `b = a' and a call that takes a view by value copy the borrow.
%%
%% type_basic_string_view/3 gives the instance's type, `basic_string_view_char': the first character and the count.
%% fn_basic_string_view/3 gives ONE function of the instance at its first use. The names are std::string_view's; where
%% C++ tells two forms by their arguments' types, C tells them by the type of an argument (a name that ends with the
%% type's word: `_find_ptr_const_char') or by the count of the arguments (`_find3'), as <string.pl> does. What differs
%% from C++ is CCLLIB.md's section of the view: a place past the end stops the program (abort), where C++ throws or is
%% undefined; `v[i]' is a value, and has no address; there is no swap, since a function that puts a view of one source
%% in another's place is refused by the safe part; a string goes where a view is taken in the searches, the tests and
%% the comparisons, as C++ converts it, and in the other forms by a view of it.
:- ensure_loaded(library(ccllib/ccllib)).
view_basic_string_view.
type_basic_string_view([T], base([], [typedef(N)]), Items) :-
    (   ccl_arg_words([T], [char]) -> true
    ;   ccl_macro_error('a basic_string_view''s element is char: the other character types wait') ),
    ccl_instance_name(basic_string_view, [T], N),
    ccl_c_items("typedef struct @N { const char *data; size_t len; } @N;", ['N' = name(N)], Items).
fn_basic_string_view(Name, [T], Items) :-
    ccllib_view_fn(Name, Text), ccl_instance_name(basic_string_view, [T], N), ccl_c_items(Text, ['N' = name(N)], Items).
%% a function's C text by its name. A name that begins with `_' is an inner helper's. A view born zero has no first
%% character (data is null) and a count of 0: no function hands its null to the C library's memcmp, memcpy or memchr,
%% whose parameters are not null even for a count of 0 (C17 7.24.1/2)
%% -- A VIEW MADE: of a text of C (a literal, a char array, a pointer) and of a string's characters, each tied to its
%% source; of a text and its count by braces, `{p, n}'
ccllib_view_fn(of, "@N @{N}_of(const char *s) tie s { return (@N){ s, strlen(s) }; }").
ccllib_view_fn(of_basic_string_char, "@N @{N}_of_basic_string_char(const basic_string_char *s) tie s {
    return (@N){ s->data ? s->data : s->u.small, s->len };
}").
%% -- the size and the characters
ccllib_view_fn(size, "size_t @{N}_size(const @N *v) { return v->len; }").
ccllib_view_fn(length, "size_t @{N}_length(const @N *v) { return v->len; }").
ccllib_view_fn(len, "size_t @{N}_len(const @N *v) { return v->len; }").
ccllib_view_fn(empty, "int @{N}_empty(const @N *v) { return v->len == 0; }").
ccllib_view_fn(max_size, "size_t @{N}_max_size(const @N *v) { return (size_t)-1 / 2 - 1; }").
ccllib_view_fn(data, "const char *@{N}_data(const @N *v) tie v { return v->data; }").
ccllib_view_fn(begin, "const char *@{N}_begin(const @N *v) tie v { return v->data; }").
ccllib_view_fn(end, "const char *@{N}_end(const @N *v) tie v { return v->data + v->len; }").
%% `v[i]' is a value (the reader's `_item', 0.284), as a const view's character is: a char, and no place to write
ccllib_view_fn(item, "char @{N}_item(const @N *v, size_t i) { if (i >= v->len) abort(); return v->data[i]; }").
ccllib_view_fn(at, "char @{N}_at(const @N *v, size_t i) { if (i >= v->len) abort(); return v->data[i]; }").
ccllib_view_fn(front, "char @{N}_front(const @N *v) { if (v->len == 0) abort(); return v->data[0]; }").
ccllib_view_fn(back, "char @{N}_back(const @N *v) { if (v->len == 0) abort(); return v->data[v->len - 1]; }").
%% -- the view narrowed: a part of its characters, the view itself given its own source again
ccllib_view_fn(remove_prefix, "void @{N}_remove_prefix(@N *v, size_t n) {
    if (n > v->len) abort();
    *v = (@N){ v->data + n, v->len - n };
}").
ccllib_view_fn(remove_suffix, "void @{N}_remove_suffix(@N *v, size_t n) {
    if (n > v->len) abort();
    *v = (@N){ v->data, v->len - n };
}").
ccllib_view_fn(substr3, "@N @{N}_substr3(const @N *v, size_t pos, size_t n) tie v {
    if (pos > v->len) abort();
    if (n > v->len - pos) n = v->len - pos;
    return (@N){ v->data + pos, n };
}").
ccllib_view_fn(substr, "@N @{N}_substr(const @N *v, size_t pos) tie v {
    if (pos > v->len) abort();
    return (@N){ v->data + pos, v->len - pos };
}").
ccllib_view_fn(substr1, "@N @{N}_substr1(const @N *v) tie v { return *v; }").
ccllib_view_fn(copy, "size_t @{N}_copy(const @N *v, char *to, size_t n) {
    if (n > v->len) n = v->len;
    if (n) memcpy(to, v->data, n);
    return n;
}").
ccllib_view_fn(copy4, "size_t @{N}_copy4(const @N *v, char *to, size_t n, size_t pos) {
    if (pos > v->len) abort();
    if (n > v->len - pos) n = v->len - pos;
    if (n) memcpy(to, v->data + pos, n);
    return n;
}").
%% -- the comparisons: `__cmp' is -1, 0 or 1 by the characters as unsigned, then by the counts, as char_traits<char>
%% compares; `"abc" == v' and `"abc" < v' are the instance's own relations with the operands exchanged (the reader's
%% mirrored operators, 0.291). The relations and compare over a view, a text of C and a string are one family below
ccllib_view_fn('_cmp', "static int @{N}__cmp(const char *a, size_t n, const char *b, size_t m) {
    size_t k = n < m ? n : m;
    int r = k ? memcmp(a, b, k) : 0;
    return r < 0 ? -1 : r > 0 ? 1 : n < m ? -1 : n > m;
}").
ccllib_view_fn(compare4, "int @{N}_compare4(const @N *v, size_t pos, size_t n, const @N *t) {
    if (pos > v->len) abort();
    if (n > v->len - pos) n = v->len - pos;
    return @{N}__cmp(v->data + pos, n, t->data, t->len);
}").
ccllib_view_fn(compare4_ptr_const_char, "int @{N}_compare4_ptr_const_char(const @N *v, size_t pos, size_t n, const char *s) {
    if (pos > v->len) abort();
    if (n > v->len - pos) n = v->len - pos;
    return @{N}__cmp(v->data + pos, n, s, strlen(s));
}").
ccllib_view_fn(compare5_ptr_const_char,
"int @{N}_compare5_ptr_const_char(const @N *v, size_t pos, size_t n, const char *s, size_t k) {
    if (pos > v->len) abort();
    if (n > v->len - pos) n = v->len - pos;
    return @{N}__cmp(v->data + pos, n, s, k);
}").
ccllib_view_fn(compare6, "int @{N}_compare6(const @N *v, size_t pos, size_t n, const @N *t, size_t at, size_t k) {
    if (pos > v->len || at > t->len) abort();
    if (n > v->len - pos) n = v->len - pos;
    if (k > t->len - at) k = t->len - at;
    return @{N}__cmp(v->data + pos, n, t->data + at, k);
}").
%% -- the searches' inner helpers: the place of the first or the last find from the place pos, or npos
ccllib_view_fn('_find', "static size_t @{N}__find(const @N *v, const char *s, size_t n, size_t pos) {
    if (pos > v->len || n > v->len - pos) return (size_t)-1;
    if (n == 0) return pos;
    for (size_t i = pos; i + n <= v->len; i++) if (v->data[i] == s[0] && memcmp(v->data + i, s, n) == 0) return i;
    return (size_t)-1;
}").
ccllib_view_fn('_rfind', "static size_t @{N}__rfind(const @N *v, const char *s, size_t n, size_t pos) {
    if (n > v->len) return (size_t)-1;
    size_t i = v->len - n;
    if (pos < i) i = pos;
    for (;; i--) {
        if (n == 0 || memcmp(v->data + i, s, n) == 0) return i;
        if (i == 0) return (size_t)-1;
    }
}").
ccllib_view_fn('_first', "static size_t @{N}__first(const @N *v, const char *s, size_t n, size_t pos, int in) {
    for (size_t i = pos; i < v->len; i++) if ((n && memchr(s, v->data[i], n) != 0) == in) return i;
    return (size_t)-1;
}").
ccllib_view_fn('_last', "static size_t @{N}__last(const @N *v, const char *s, size_t n, size_t pos, int in) {
    if (v->len == 0) return (size_t)-1;
    size_t i = v->len - 1;
    if (pos < i) i = pos;
    for (;; i--) {
        if ((n && memchr(s, v->data[i], n) != 0) == in) return i;
        if (i == 0) return (size_t)-1;
    }
}").
%% -- THE FAMILIES, each a table's rows: a search in its eleven forms, a test of a part in its five, a relation or
%% compare in its three
ccllib_view_fn(Name, Text) :-
    ccllib_view_search(Base, Call, Last, First), ccllib_view_text(End, Params, Pre, At),
    atom_concat(Base, End, Name), !, ( At == pos -> Pos = "pos" ; Pos = First ), atom_codes(Name, NC),
    append(["size_t @{N}_", NC, "(const @N *v, ", Params, ") { ", Pre,
            " return @{N}__", Call, "(v, p, k, ", Pos, Last, "); }"], Text).
ccllib_view_fn(Name, Text) :-
    ccllib_view_test(Base, Expr), ccllib_view_text(End, Params, Pre, none), atom_concat(Base, End, Name), !,
    atom_codes(Name, NC),
    append(["int @{N}_", NC, "(const @N *v, ", Params, ") { ", Pre, " return ", Expr, "; }"], Text).
ccllib_view_fn(Name, Text) :-
    ccllib_view_rel(Base, Test), ccllib_view_text(End, Params, Pre, none), memberchk(End, ['', '_ptr_const_char', '_basic_string_char']),
    atom_concat(Base, End, Name), !, atom_codes(Name, NC),
    append(["int @{N}_", NC, "(const @N *v, ", Params, ") { ", Pre, " return @{N}__cmp(v->data, v->len, p, k)", Test, "; }"],
           Text).
%% the six searches: the inner helper, its last argument, and the place where a call that names none begins
ccllib_view_search(find, "find", "", "0").
ccllib_view_search(rfind, "rfind", "", "(size_t)-1").
ccllib_view_search(find_first_of, "first", ", 1", "0").
ccllib_view_search(find_first_not_of, "first", ", 0", "0").
ccllib_view_search(find_last_of, "last", ", 1", "(size_t)-1").
ccllib_view_search(find_last_not_of, "last", ", 0", "(size_t)-1").
%% the three tests of a part (C++20's starts_with and ends_with, C++23's contains)
ccllib_view_test(starts_with, "k <= v->len && (k == 0 || memcmp(v->data, p, k) == 0)").
ccllib_view_test(ends_with, "k <= v->len && (k == 0 || memcmp(v->data + (v->len - k), p, k) == 0)").
ccllib_view_test(contains, "@{N}__find(v, p, k, 0) != (size_t)-1").
%% the relations that the reader's operators call (`>' and `<=' over a text or a string are `_gt''s) and compare, by
%% `__cmp''s answer. A character is no text that a view is compared with: C++ has no such form
ccllib_view_rel(eq, " == 0").
ccllib_view_rel(lt, " < 0").
ccllib_view_rel(gt, " > 0").
ccllib_view_rel(compare, "").
%% THE TEXT THAT A SEARCH, A TEST OR A COMPARISON TAKES: the end of the function's name, its parameters after the view,
%% the lines that name the text's first character p and its count k, and `pos' where the form names a place. A view;
%% a string, which C++ takes as its view; a text of C, whose word a literal of C and of C++ asks; a char object; C's
%% character constant, an int
ccllib_view_text('', "const @N *t", "const char *p = t->data; size_t k = t->len;", none).
ccllib_view_text('3_basic_string_view_char', "const @N *t, size_t pos", "const char *p = t->data; size_t k = t->len;", pos).
ccllib_view_text('_basic_string_char', "const basic_string_char *t",
                 "const char *p = t->data ? t->data : t->u.small; size_t k = t->len;", none).
ccllib_view_text('3_basic_string_char', "const basic_string_char *t, size_t pos",
                 "const char *p = t->data ? t->data : t->u.small; size_t k = t->len;", pos).
ccllib_view_text('_ptr_const_char', "const char *p", "size_t k = strlen(p);", none).
ccllib_view_text('3_ptr_const_char', "const char *p, size_t pos", "size_t k = strlen(p);", pos).
ccllib_view_text('4_ptr_const_char', "const char *p, size_t pos, size_t k", "", pos).
ccllib_view_text('_char', "char c", "const char *p = &c; size_t k = 1;", none).
ccllib_view_text('3_char', "char c, size_t pos", "const char *p = &c; size_t k = 1;", pos).
ccllib_view_text('_int', "int c0", "char c = (char)c0; const char *p = &c; size_t k = 1;", none).
ccllib_view_text('3_int', "int c0, size_t pos", "char c = (char)c0; const char *p = &c; size_t k = 1;", pos).
