%% ccllib's <basic_string.pl> (0.291; CCLLIB.md's phase 1a): std::basic_string<char> for cicilang's C, and for
%% cicilang++ beside libc++'s. A program includes <string.pl>, whose header names the instance `string'.
%%
%%   #include <string.pl>
%%   string s = "abc";              of a text of C; `string e;' is the empty string (an instance's object is born zero)
%%   s += "def";  s += '!';  push_back(s, '?');  append(s, t);  insert(s, 0, "<");  erase(s, 1, 2);
%%   if (s == "abc" || "abc" < s || s < t) ...;  n = find(s, "de");  if (n != npos) ...;  u := substr(s, n, 2);
%%   c := "<" + s;  d := c + ">";  printf("%s\n", c_str(d));  w := to_string(42);  k := stoi(w);
%%
%% A string that an operator or a call makes has no name, and a function of the instance takes its object's address:
%% `a + b + c' and `stoi(to_string(42))' are refused by name, and each part is named first, as above.
%%
%% type_basic_string/3 gives the instance's type, `basic_string_char': an own pointer, a length, and sixteen bytes that
%% hold the capacity, or -- while the string has fifteen characters or fewer -- the characters themselves, so that a
%% short string has no block of the heap (`data' is null then). fn_basic_string/3 gives ONE function of the instance at
%% its first use, a call's or an operator's. The names are std::string's; where C++ tells two forms by their arguments'
%% types, C tells them by the type of an argument (a name that ends with the type's word: `_append_ptr_const_char') or
%% by the count of the arguments (`_append3'), and a place is an index, as C++'s own index forms have it. What differs
%% from C++ is CCLLIB.md's section of the string.
:- ensure_loaded(library(ccllib/ccllib)).
type_basic_string([T], base([], [typedef(N)]), Items) :-
    (   ccl_arg_words([T], [char]) -> true
    ;   ccl_macro_error('a basic_string''s element is char: the other character types wait') ),
    ccl_instance_name(basic_string, [T], N),
    ccl_c_items("typedef struct @N { own char *data; size_t len; union { size_t cap; char small[16]; } u; } @N;
void @{N}_drop(@N *v) { free(v->data); }", ['N' = name(N)], Items).
fn_basic_string(Name, [T], Items) :-
    ccllib_string_fn(Name, Text), ccl_instance_name(basic_string, [T], N), ccl_c_items(Text, ['N' = name(N)], Items).
%% a function's C text by its name. A name that begins with `_' is an inner helper's.
%% -- THE FORM: `__p' the first character, in the block or in the object; `__set_cap' a block of c characters and the
%% NUL; `__room' room for `need' characters, by twice the capacity at least
ccllib_string_fn('_p', "static char *@{N}__p(const @N *v) tie v { return v->data ? v->data : (char *)v->u.small; }").
ccllib_string_fn('_set_cap', "static void @{N}__set_cap(@N *v, size_t c) {
    if (c > (size_t)-1 / 2 - 1) abort();
    if (v->data) {
        v->data = (char *)realloc(v->data, c + 1);
        if (!v->data) abort();
    } else {
        own char *d = (char *)malloc(c + 1);
        if (!d) abort();
        memcpy(d, v->u.small, v->len + 1);
        v->data = d;
    }
    v->u.cap = c;
}").
ccllib_string_fn('_room', "static void @{N}__room(@N *v, size_t need) {
    size_t cap = v->data ? v->u.cap : 15;
    if (need <= cap) return;
    @{N}__set_cap(v, need < 2 * cap ? 2 * cap : need);
}").
%% -- EVERY CHANGE OF THE CHARACTERS IS ONE OF TWO: `__replace' puts n2 characters of src in the place of the n1 at pos,
%% `__fill' n2 copies of c. A source that is in the string itself -- append(s, s), insert(s, 0, s, 2, 3) -- is
%% copied first: the room for the new characters may move the block, and the tail's move may go over the source. A
%% pointer into the string's own characters handed beside it -- append(s, c_str(s) + 2) -- is refused by the safe part
%% (0.293: a borrow handed to a call that may replace its owner), which does not see that the change copies it first:
%% the part goes by the string and its place, append(s, s, 2)
ccllib_string_fn('_splice', "static void @{N}__splice(@N *v, size_t pos, size_t n1, const char *src, size_t n2) {
    if (n2 > (size_t)-1 / 2 - 1 - (v->len - n1)) abort();
    size_t len = v->len - n1 + n2;
    @{N}__room(v, len);
    char *p = @{N}__p(v);
    memmove(p + pos + n2, p + pos + n1, v->len - pos - n1);
    if (n2) memcpy(p + pos, src, n2);
    v->len = len;
    p[len] = 0;
}").
ccllib_string_fn('_replace', "static void @{N}__replace(@N *v, size_t pos, size_t n1, const char *src, size_t n2) {
    if (pos > v->len) abort();
    if (n1 > v->len - pos) n1 = v->len - pos;
    const char *p = @{N}__p(v);
    if (n2 && src >= p && src <= p + v->len) {
        own char *tmp = (char *)malloc(n2);
        if (!tmp) abort();
        memcpy(tmp, src, n2);
        @{N}__splice(v, pos, n1, tmp, n2);
        free(tmp);
    } else @{N}__splice(v, pos, n1, src, n2);
}").
ccllib_string_fn('_fill', "static void @{N}__fill(@N *v, size_t pos, size_t n1, size_t n2, char c) {
    if (pos > v->len) abort();
    if (n1 > v->len - pos) n1 = v->len - pos;
    if (n2 > (size_t)-1 / 2 - 1 - (v->len - n1)) abort();
    size_t len = v->len - n1 + n2;
    @{N}__room(v, len);
    char *p = @{N}__p(v);
    memmove(p + pos + n2, p + pos + n1, v->len - pos - n1);
    memset(p + pos, c, n2);
    v->len = len;
    p[len] = 0;
}").
%% -- the capacity
ccllib_string_fn(size, "size_t @{N}_size(const @N *v) { return v->len; }").
ccllib_string_fn(length, "size_t @{N}_length(const @N *v) { return v->len; }").
ccllib_string_fn(len, "size_t @{N}_len(const @N *v) { return v->len; }").
ccllib_string_fn(empty, "int @{N}_empty(const @N *v) { return v->len == 0; }").
ccllib_string_fn(capacity, "size_t @{N}_capacity(const @N *v) { return v->data ? v->u.cap : 15; }").
ccllib_string_fn(max_size, "size_t @{N}_max_size(const @N *v) { return (size_t)-1 / 2 - 1; }").
ccllib_string_fn(reserve, "void @{N}_reserve(@N *v, size_t n) {
    if (n > (v->data ? v->u.cap : 15)) @{N}__set_cap(v, n);
}").
ccllib_string_fn(shrink_to_fit, "void @{N}_shrink_to_fit(@N *v) {
    if (!v->data || v->len == v->u.cap) return;
    if (v->len > 15) { @{N}__set_cap(v, v->len); return; }
    own char *d = v->data;
    v->data = 0;
    memcpy(v->u.small, d, v->len + 1);
    free(d);
}").
ccllib_string_fn(clear, "void @{N}_clear(@N *v) { v->len = 0; @{N}__p(v)[0] = 0; }").
ccllib_string_fn(resize3, "void @{N}_resize3(@N *v, size_t n, char c) {
    if (n > v->len) { @{N}__fill(v, v->len, 0, n - v->len, c); return; }
    v->len = n;
    @{N}__p(v)[n] = 0;
}").
ccllib_string_fn(resize, "void @{N}_resize(@N *v, size_t n) { @{N}_resize3(v, n, 0); }").
%% -- the characters. s[i] is a place: of the string's i-th character, and at i == size(s) of the NUL after the last
%% one, as C++'s is (a write of another character there is C++'s undefined behaviour, and here it ends c_str's text)
ccllib_string_fn(at, "char @{N}_at(const @N *v, size_t i) { if (i >= v->len) abort(); return @{N}__p(v)[i]; }").
ccllib_string_fn(index, "char *@{N}_index(const @N *v, size_t i) tie v {
    if (i > v->len) abort();
    return @{N}__p(v) + i;
}").
ccllib_string_fn(front, "char @{N}_front(const @N *v) { if (v->len == 0) abort(); return @{N}__p(v)[0]; }").
ccllib_string_fn(back, "char @{N}_back(const @N *v) { if (v->len == 0) abort(); return @{N}__p(v)[v->len - 1]; }").
ccllib_string_fn(c_str, "const char *@{N}_c_str(const @N *v) tie v { return v->data ? v->data : v->u.small; }").
ccllib_string_fn(data, "char *@{N}_data(const @N *v) tie v { return v->data ? v->data : (char *)v->u.small; }").
ccllib_string_fn(begin, "char *@{N}_begin(const @N *v) tie v { return v->data ? v->data : (char *)v->u.small; }").
ccllib_string_fn(end, "char *@{N}_end(const @N *v) tie v {
    return (v->data ? v->data : (char *)v->u.small) + v->len;
}").
%% -- the changes that have one form
ccllib_string_fn(push_back, "void @{N}_push_back(@N *v, char c) {
    @{N}__room(v, v->len + 1);
    char *p = @{N}__p(v);
    p[v->len++] = c;
    p[v->len] = 0;
}").
ccllib_string_fn(push, "void @{N}_push(@N *v, char c) { @{N}_push_back(v, c); }").
ccllib_string_fn(pop_back, "char @{N}_pop_back(@N *v) {
    if (v->len == 0) abort();
    char *p = @{N}__p(v);
    char c = p[--v->len];
    p[v->len] = 0;
    return c;
}").
ccllib_string_fn(pop, "char @{N}_pop(@N *v) { return @{N}_pop_back(v); }").
ccllib_string_fn(erase1, "void @{N}_erase1(@N *v) { v->len = 0; @{N}__p(v)[0] = 0; }").
ccllib_string_fn(erase, "void @{N}_erase(@N *v, size_t pos) { @{N}__replace(v, pos, (size_t)-1, \"\", 0); }").
ccllib_string_fn(erase3, "void @{N}_erase3(@N *v, size_t pos, size_t n) { @{N}__replace(v, pos, n, \"\", 0); }").
%% C++20's std::erase(s, c): the characters equal to c taken away, and their count
ccllib_string_fn(erase_value, "size_t @{N}_erase_value(@N *v, char c) {
    char *p = @{N}__p(v);
    size_t k = 0;
    for (size_t i = 0; i < v->len; i++) if (p[i] != c) p[k++] = p[i];
    size_t n = v->len - k;
    v->len = k;
    p[k] = 0;
    return n;
}").
ccllib_string_fn(swap, "void @{N}_swap(@N *a, @N *b) {
    if (a == b) return;
    size_t n = a->len;
    a->len = b->len;
    b->len = n;
    char t[16];
    memcpy(t, a->u.small, 16);
    memcpy(a->u.small, b->u.small, 16);
    memcpy(b->u.small, t, 16);
    own char *d = a->data;
    a->data = b->data;
    b->data = d;
}").
ccllib_string_fn(copy, "size_t @{N}_copy(const @N *v, char *to, size_t n) {
    if (n > v->len) n = v->len;
    memcpy(to, @{N}__p(v), n);
    return n;
}").
ccllib_string_fn(copy4, "size_t @{N}_copy4(const @N *v, char *to, size_t n, size_t pos) {
    if (pos > v->len) abort();
    if (n > v->len - pos) n = v->len - pos;
    memcpy(to, @{N}__p(v) + pos, n);
    return n;
}").
%% -- a string made: of a text of C (C's literal and C++'s), a copy, a part, a list literal's characters
ccllib_string_fn(of_ptr_const_char, "@N @{N}_of_ptr_const_char(const char *s) {
    @N r = {0};
    @{N}__replace(&r, 0, 0, s, strlen(s));
    return r;
}").
ccllib_string_fn(clone, "@N @{N}_clone(const @N *v) {
    @N r = {0};
    @{N}__replace(&r, 0, 0, @{N}__p(v), v->len);
    return r;
}").
ccllib_string_fn(from, "@N @{N}_from(const char *a, size_t n) {
    @N r = {0};
    @{N}__replace(&r, 0, 0, a, n);
    return r;
}").
ccllib_string_fn(substr3, "@N @{N}_substr3(const @N *v, size_t pos, size_t n) {
    if (pos > v->len) abort();
    if (n > v->len - pos) n = v->len - pos;
    @N r = {0};
    @{N}__replace(&r, 0, 0, @{N}__p(v) + pos, n);
    return r;
}").
ccllib_string_fn(substr, "@N @{N}_substr(const @N *v, size_t pos) { return @{N}_substr3(v, pos, (size_t)-1); }").
ccllib_string_fn(substr1, "@N @{N}_substr1(const @N *v) { return @{N}_substr3(v, 0, (size_t)-1); }").
%% -- the comparisons: `__cmp' is -1, 0 or 1 by the characters as unsigned, then by the lengths, as char_traits<char>
%% compares. `>' and `<=' over a text are `_gt_ptr_const_char''s; `"abc" == s' and `"abc" < s' are the instance's own
%% relations with the operands exchanged (the reader's mirrored operators, 0.291)
ccllib_string_fn('_cmp', "static int @{N}__cmp(const char *a, size_t n, const char *b, size_t m) {
    int r = memcmp(a, b, n < m ? n : m);
    return r < 0 ? -1 : r > 0 ? 1 : n < m ? -1 : n > m;
}").
ccllib_string_fn(eq, "int @{N}_eq(const @N *a, const @N *b) {
    return a->len == b->len && memcmp(@{N}__p(a), @{N}__p(b), a->len) == 0;
}").
ccllib_string_fn(eq_ptr_const_char, "int @{N}_eq_ptr_const_char(const @N *a, const char *s) {
    return @{N}__cmp(@{N}__p(a), a->len, s, strlen(s)) == 0;
}").
ccllib_string_fn(lt, "int @{N}_lt(const @N *a, const @N *b) {
    return @{N}__cmp(@{N}__p(a), a->len, @{N}__p(b), b->len) < 0;
}").
ccllib_string_fn(lt_ptr_const_char, "int @{N}_lt_ptr_const_char(const @N *a, const char *s) {
    return @{N}__cmp(@{N}__p(a), a->len, s, strlen(s)) < 0;
}").
ccllib_string_fn(gt_ptr_const_char, "int @{N}_gt_ptr_const_char(const @N *a, const char *s) {
    return @{N}__cmp(@{N}__p(a), a->len, s, strlen(s)) > 0;
}").
ccllib_string_fn(compare, "int @{N}_compare(const @N *v, const @N *t) {
    return @{N}__cmp(@{N}__p(v), v->len, @{N}__p(t), t->len);
}").
ccllib_string_fn(compare_ptr_const_char, "int @{N}_compare_ptr_const_char(const @N *v, const char *s) {
    return @{N}__cmp(@{N}__p(v), v->len, s, strlen(s));
}").
ccllib_string_fn(compare4, "int @{N}_compare4(const @N *v, size_t pos, size_t n, const @N *t) {
    if (pos > v->len) abort();
    if (n > v->len - pos) n = v->len - pos;
    return @{N}__cmp(@{N}__p(v) + pos, n, @{N}__p(t), t->len);
}").
ccllib_string_fn(compare4_ptr_const_char,
"int @{N}_compare4_ptr_const_char(const @N *v, size_t pos, size_t n, const char *s) {
    if (pos > v->len) abort();
    if (n > v->len - pos) n = v->len - pos;
    return @{N}__cmp(@{N}__p(v) + pos, n, s, strlen(s));
}").
ccllib_string_fn(compare5_ptr_const_char,
"int @{N}_compare5_ptr_const_char(const @N *v, size_t pos, size_t n, const char *s, size_t k) {
    if (pos > v->len) abort();
    if (n > v->len - pos) n = v->len - pos;
    return @{N}__cmp(@{N}__p(v) + pos, n, s, k);
}").
ccllib_string_fn(compare6, "int @{N}_compare6(const @N *v, size_t pos, size_t n, const @N *t, size_t at, size_t k) {
    if (pos > v->len || at > t->len) abort();
    if (n > v->len - pos) n = v->len - pos;
    if (k > t->len - at) k = t->len - at;
    return @{N}__cmp(@{N}__p(v) + pos, n, @{N}__p(t) + at, k);
}").
ccllib_string_fn(compare5_basic_string_char,
"int @{N}_compare5_basic_string_char(const @N *v, size_t pos, size_t n, const @N *t, size_t at) {
    return @{N}_compare6(v, pos, n, t, at, (size_t)-1);
}").
%% -- `+' gives a new string, and its operands stay; `+=' changes its object. A text or a character on the left of `+'
%% is `_radd''s (the reader's mirrored operators, 0.291)
ccllib_string_fn(add, "@N @{N}_add(const @N *a, const @N *b) { @N r = @{N}_clone(a); @{N}_append(&r, b); return r; }").
ccllib_string_fn(add_ptr_const_char, "@N @{N}_add_ptr_const_char(const @N *a, const char *s) {
    @N r = @{N}_clone(a);
    @{N}_append_ptr_const_char(&r, s);
    return r;
}").
ccllib_string_fn(add_char, "@N @{N}_add_char(const @N *a, char c) {
    @N r = @{N}_clone(a);
    @{N}_push_back(&r, c);
    return r;
}").
ccllib_string_fn(add_int, "@N @{N}_add_int(const @N *a, int c) {
    @N r = @{N}_clone(a);
    @{N}_push_back(&r, (char)c);
    return r;
}").
ccllib_string_fn(radd_ptr_const_char, "@N @{N}_radd_ptr_const_char(const char *s, const @N *b) {
    @N r = {0};
    @{N}__replace(&r, 0, 0, s, strlen(s));
    @{N}_append(&r, b);
    return r;
}").
ccllib_string_fn(radd_char, "@N @{N}_radd_char(char c, const @N *b) {
    @N r = {0};
    @{N}_push_back(&r, c);
    @{N}_append(&r, b);
    return r;
}").
ccllib_string_fn(radd_int, "@N @{N}_radd_int(int c, const @N *b) {
    @N r = {0};
    @{N}_push_back(&r, (char)c);
    @{N}_append(&r, b);
    return r;
}").
ccllib_string_fn(add_assign, "void @{N}_add_assign(@N *v, const @N *t) { @{N}_append(v, t); }").
ccllib_string_fn(add_assign_ptr_const_char, "void @{N}_add_assign_ptr_const_char(@N *v, const char *s) {
    @{N}_append_ptr_const_char(v, s);
}").
ccllib_string_fn(add_assign_char, "void @{N}_add_assign_char(@N *v, char c) { @{N}_push_back(v, c); }").
ccllib_string_fn(add_assign_int, "void @{N}_add_assign_int(@N *v, int c) { @{N}_push_back(v, (char)c); }").
%% -- the searches' inner helpers: the place of the first or the last find from the place pos, or npos
ccllib_string_fn('_find', "static size_t @{N}__find(const @N *v, const char *s, size_t n, size_t pos) {
    if (pos > v->len || n > v->len - pos) return (size_t)-1;
    if (n == 0) return pos;
    const char *p = @{N}__p(v);
    for (size_t i = pos; i + n <= v->len; i++) if (p[i] == s[0] && memcmp(p + i, s, n) == 0) return i;
    return (size_t)-1;
}").
ccllib_string_fn('_rfind', "static size_t @{N}__rfind(const @N *v, const char *s, size_t n, size_t pos) {
    if (n > v->len) return (size_t)-1;
    size_t i = v->len - n;
    if (pos < i) i = pos;
    const char *p = @{N}__p(v);
    for (;; i--) {
        if (memcmp(p + i, s, n) == 0) return i;
        if (i == 0) return (size_t)-1;
    }
}").
ccllib_string_fn('_first', "static size_t @{N}__first(const @N *v, const char *s, size_t n, size_t pos, int in) {
    const char *p = @{N}__p(v);
    for (size_t i = pos; i < v->len; i++) if ((memchr(s, p[i], n) != 0) == in) return i;
    return (size_t)-1;
}").
ccllib_string_fn('_last', "static size_t @{N}__last(const @N *v, const char *s, size_t n, size_t pos, int in) {
    if (v->len == 0) return (size_t)-1;
    size_t i = v->len - 1;
    if (pos < i) i = pos;
    const char *p = @{N}__p(v);
    for (;; i--) {
        if ((memchr(s, p[i], n) != 0) == in) return i;
        if (i == 0) return (size_t)-1;
    }
}").
%% -- THE NUMBERS OF A TEXT, as std::stoi and its kin read them: by the C library's conversion, the program stopped
%% where it reads no number or where the number is past the type's range, where C++ throws (the helpers of
%% basic_string.pl.h, which read errno and the limits: a C text is lexed and never preprocessed). A count after the
%% object tells the forms: stoi(s), stoi(s, &pos), stoi(s, &pos, base); a floating number takes no base
ccllib_string_fn(Name, Text) :-
    ccllib_string_number(Base, Ret, Help, Based), atom_concat(Base, End, Name),
    memberchk(End-K, ['1'-1, ''-1, '2'-2, '3'-3]), ( K =:= 3 -> Based == yes ; true ), !, atom_codes(Name, NC),
    (   K =:= 1 -> Ps = "", ( Based == yes -> As = "0, 10" ; As = "0" )
    ;   K =:= 2 -> Ps = ", size_t *pos", ( Based == yes -> As = "pos, 10" ; As = "pos" )
    ;   Ps = ", size_t *pos, int base", As = "pos, base" ),
    append([Ret, " @{N}_", NC, "(const @N *v", Ps, ") { return ", Help, "(@{N}__p(v), ", As, "); }"], Text).
%% -- the text of a number: to_string's four functions, which the macro of <string.pl> calls, as std::to_string writes
%% it -- an integer's digits, a floating number as printf's %f
ccllib_string_fn(to_string_ull, "@N @{N}_to_string_ull(unsigned long long x) {
    char b[24];
    size_t i = 24;
    do { b[--i] = (char)('0' + x % 10); x /= 10; } while (x);
    @N r = {0};
    @{N}__replace(&r, 0, 0, b + i, 24 - i);
    return r;
}").
ccllib_string_fn(to_string_ll, "@N @{N}_to_string_ll(long long x) {
    char b[24];
    size_t i = 24;
    unsigned long long u = x < 0 ? 0ULL - (unsigned long long)x : (unsigned long long)x;
    do { b[--i] = (char)('0' + u % 10); u /= 10; } while (u);
    if (x < 0) b[--i] = '-';
    @N r = {0};
    @{N}__replace(&r, 0, 0, b + i, 24 - i);
    return r;
}").
ccllib_string_fn(to_string_d, "@N @{N}_to_string_d(double x) {
    @N r = {0};
    int n = snprintf(0, 0, \"%f\", x);
    if (n < 0) abort();
    @{N}__fill(&r, 0, 0, (size_t)n, ' ');
    snprintf(@{N}__p(&r), (size_t)n + 1, \"%f\", x);
    return r;
}").
ccllib_string_fn(to_string_ld, "@N @{N}_to_string_ld(long double x) {
    @N r = {0};
    int n = snprintf(0, 0, \"%Lf\", x);
    if (n < 0) abort();
    @{N}__fill(&r, 0, 0, (size_t)n, ' ');
    snprintf(@{N}__p(&r), (size_t)n + 1, \"%Lf\", x);
    return r;
}").
%% -- THE FAMILIES, each a table's rows: a search in its nine forms, a test of a part in its four, a change of a part by
%% a text in its six
ccllib_string_fn(Name, Text) :-
    ccllib_string_search(Base, Call, Last, First), ccllib_string_text(End, Params, Pre, At),
    atom_concat(Base, End, Name), !, ( At == pos -> Pos = "pos" ; Pos = First ), atom_codes(Name, NC),
    append(["size_t @{N}_", NC, "(const @N *v, ", Params, ") { ", Pre,
            " return @{N}__", Call, "(v, p, k, ", Pos, Last, "); }"], Text).
ccllib_string_fn(Name, Text) :-
    ccllib_string_test(Base, Expr), ccllib_string_text(End, Params, Pre, none), atom_concat(Base, End, Name), !,
    atom_codes(Name, NC),
    append(["int @{N}_", NC, "(const @N *v, ", Params, ") { ", Pre, " return ", Expr, "; }"], Text).
ccllib_string_fn(Name, Text) :-
    ccllib_string_change(Base, Count, Lead, Pos, N1), ccllib_string_source(Plus, End, Params, Pre, Call, Args),
    ( Plus =:= 0 -> Mid = '' ; Mid is Count + Plus ), atomic_list_concat([Base, Mid, End], Name), !,
    atom_codes(Name, NC),
    append(["void @{N}_", NC, "(@N *v, ", Lead, Params, ") { ", Pre,
            "@{N}__", Call, "(v, ", Pos, ", ", N1, ", ", Args, "); }"], Text).
%% the numbers of a text: the function's name, its result's type, the helper of basic_string.pl.h that reads it, and
%% whether a base is given
ccllib_string_number(stoi, "int", "ccllib_stoi_", yes).
ccllib_string_number(stol, "long", "ccllib_stol_", yes).
ccllib_string_number(stoll, "long long", "ccllib_stoll_", yes).
ccllib_string_number(stoul, "unsigned long", "ccllib_stoul_", yes).
ccllib_string_number(stoull, "unsigned long long", "ccllib_stoull_", yes).
ccllib_string_number(stof, "float", "ccllib_stof_", no).
ccllib_string_number(stod, "double", "ccllib_stod_", no).
ccllib_string_number(stold, "long double", "ccllib_stold_", no).
%% the six searches: the inner helper, its last argument, and the place where a call that names none begins
ccllib_string_search(find, "find", "", "0").
ccllib_string_search(rfind, "rfind", "", "(size_t)-1").
ccllib_string_search(find_first_of, "first", ", 1", "0").
ccllib_string_search(find_first_not_of, "first", ", 0", "0").
ccllib_string_search(find_last_of, "last", ", 1", "(size_t)-1").
ccllib_string_search(find_last_not_of, "last", ", 0", "(size_t)-1").
%% the three tests of a part (C++20's starts_with and ends_with, C++23's contains)
ccllib_string_test(starts_with, "k <= v->len && memcmp(@{N}__p(v), p, k) == 0").
ccllib_string_test(ends_with, "k <= v->len && memcmp(@{N}__p(v) + (v->len - k), p, k) == 0").
ccllib_string_test(contains, "@{N}__find(v, p, k, 0) != (size_t)-1").
%% THE TEXT THAT A SEARCH OR A TEST TAKES: the end of the function's name, its parameters after the object, the lines
%% that name the text's first character p and its count k, and `pos' where the form names a place. A string; a text of
%% C, whose word a literal of C and of C++ asks; a char object; C's character constant, an int
ccllib_string_text('', "const @N *t", "const char *p = @{N}__p(t); size_t k = t->len;", none).
ccllib_string_text('3_basic_string_char', "const @N *t, size_t pos",
                   "const char *p = @{N}__p(t); size_t k = t->len;", pos).
ccllib_string_text('_ptr_const_char', "const char *p", "size_t k = strlen(p);", none).
ccllib_string_text('3_ptr_const_char', "const char *p, size_t pos", "size_t k = strlen(p);", pos).
ccllib_string_text('4_ptr_const_char', "const char *p, size_t pos, size_t k", "", pos).
ccllib_string_text('_char', "char c", "const char *p = &c; size_t k = 1;", none).
ccllib_string_text('3_char', "char c, size_t pos", "const char *p = &c; size_t k = 1;", pos).
ccllib_string_text('_int', "int c0", "char c = (char)c0; const char *p = &c; size_t k = 1;", none).
ccllib_string_text('3_int', "int c0, size_t pos", "char c = (char)c0; const char *p = &c; size_t k = 1;", pos).
%% the four changes of a part by a text: the count of the arguments of its shortest form, its parameters before the
%% text, and the part that goes, its place and its count
ccllib_string_change(append, 2, "", "v->len", "0").
ccllib_string_change(assign, 2, "", "0", "v->len").
ccllib_string_change(insert, 3, "size_t pos, ", "pos", "0").
ccllib_string_change(replace, 4, "size_t pos, size_t n, ", "pos", "n").
%% THE TEXT THAT A CHANGE TAKES: how many arguments more than the shortest form, the end of the function's name after
%% the count, the parameters, the lines before the change, the inner helper and its last arguments. A string; a text
%% of C; a text of C and its count; a count and a character; a string from a place on; a part of a string
ccllib_string_source(0, '', "const @N *t", "", "replace", "@{N}__p(t), t->len").
ccllib_string_source(0, '_ptr_const_char', "const char *s", "", "replace", "s, strlen(s)").
ccllib_string_source(1, '_ptr_const_char', "const char *s, size_t k", "", "replace", "s, k").
ccllib_string_source(1, '', "size_t k, char c", "", "fill", "k, c").
ccllib_string_source(1, '_basic_string_char', "const @N *t, size_t at",
                     "if (at > t->len) abort(); ", "replace", "@{N}__p(t) + at, t->len - at").
ccllib_string_source(2, '', "const @N *t, size_t at, size_t k",
                     "if (at > t->len) abort(); if (k > t->len - at) k = t->len - at; ",
                     "replace", "@{N}__p(t) + at, k").
