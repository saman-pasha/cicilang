/* THE RULES OF A VIEW of <string_view.pl> AND OF A SPAN of <span.pl> (0.295), checked from outside over texts of
   chance, each answer held to a naive model, an array of bytes and its count. A VIEW SEES ITS SOURCE'S CHARACTERS: its
   count, each character by [] and its first character's place, data, are the source's part, after substr,
   remove_prefix and remove_suffix, for a view of a text and its count, of a text of C and of a string, short and long;
   THE SEARCHES ARE THE MODEL'S: find, rfind and the four of a set of characters, from each place of the view, past it
   and from npos, over a part of the view itself, a text of chance with no NUL, the empty text, and a character -- each
   form of the call; THE TESTS AND THE COMPARISONS ARE THE MODEL'S: starts_with, ends_with and contains, compare, ==, <
   and >, as unsigned bytes and then by the count; copy cuts its count at the end; A STRING WHERE A VIEW IS TAKEN IS
   ITS CHARACTERS, short (in its object) and long (in its block); A VIEW BORN ZERO IS THE EMPTY TEXT.
   A SPAN SEES ITS SOURCE'S ELEMENTS: its count and its first element's place, for a span of a C array, of a vector and
   of a pointer and a count; first, last and subspan give the model's elements and counts; a write through a span is
   its source's; size_bytes is the count by the element's size. A text of chance has NUL bytes, bytes past 127 and
   three letters, so that the searches find. cicilang builds this file as C and cicilang++ as C++; both print
   view_rules.expect. It has no twin */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <string.pl>
#include <string_view.pl>
#include <vector.pl>
#include <span.pl>
#define NONE ((size_t)-1)
static unsigned seed = 1;
static unsigned rnd(void) { seed = seed * 1103515245u + 12345u; return seed >> 8; }
static size_t checks;
static void no(const char *what) { printf("NOT HELD: %s\n", what); exit(1); }
static void is(int ok, const char *what) { checks++; if (!ok) no(what); }
/* a text of chance: n bytes, NUL ones where nul says */
static size_t text(unsigned char *t, size_t max, int nul) {
    size_t n = rnd() % (max + 1);
    for (size_t i = 0; i < n; i++) {
        unsigned r = rnd() % 10;
        t[i] = (unsigned char)(r < 6 ? 'a' + r % 3 : r < 8 ? 0xE9 : nul && r == 8 ? 0 : 0x80 + rnd() % 3);
    }
    t[n] = 0;
    return n;
}
/* THE MODELS: [string.view.find]'s definitions read as loops over every place */
static int same(const unsigned char *a, const unsigned char *b, size_t k) {
    for (size_t i = 0; i < k; i++) if (a[i] != b[i]) return 0;
    return 1;
}
static size_t mfind(const unsigned char *a, size_t n, const unsigned char *s, size_t k, size_t pos) {
    for (size_t x = pos; x <= n && k <= n - x; x++) if (same(a + x, s, k)) return x;
    return NONE;
}
static size_t mrfind(const unsigned char *a, size_t n, const unsigned char *s, size_t k, size_t pos) {
    size_t r = NONE;
    for (size_t x = 0; x <= pos && k <= n && x <= n - k; x++) if (same(a + x, s, k)) r = x;
    return r;
}
static int inset(unsigned char c, const unsigned char *s, size_t k) {
    for (size_t i = 0; i < k; i++) if (s[i] == c) return 1;
    return 0;
}
static size_t mfirst(const unsigned char *a, size_t n, const unsigned char *s, size_t k, size_t pos, int in) {
    for (size_t x = pos; x < n; x++) if (inset(a[x], s, k) == in) return x;
    return NONE;
}
static size_t mlast(const unsigned char *a, size_t n, const unsigned char *s, size_t k, size_t pos, int in) {
    size_t r = NONE;
    for (size_t x = 0; x < n && x <= pos; x++) if (inset(a[x], s, k) == in) r = x;
    return r;
}
static int mcmp(const unsigned char *a, size_t n, const unsigned char *b, size_t k) {
    for (size_t i = 0; i < n && i < k; i++) if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1;
    return n < k ? -1 : n > k;
}
static int sgn(int c) { return (c > 0) - (c < 0); }
/* the view w sees the n characters at a */
static void sees(string_view w, const unsigned char *a, size_t n) {
    is(size(w) == n, "a view's count is its part's");
    is(n == 0 || (const unsigned char *)data(w) == a, "a view's first character is its source's, in its place");
    for (size_t i = 0; i < n; i++) is((unsigned char)w[i] == a[i], "each character of a view is its source's, by []");
}
/* each search, test and comparison of w (the n characters at a) with the needle t (k characters at s), as a view, and
   as a text of C where it has no NUL, from each place */
static void asks(string_view w, const unsigned char *a, size_t n, string_view t, const unsigned char *s, size_t k) {
    const char *c = (const char *)s;
    int text_ok = strlen(c) == k;
    for (size_t pos = 0; pos <= n + 2; pos++) {
        size_t p = pos == n + 2 ? NONE : pos;
        is(find(w, t, p) == mfind(a, n, s, k, p), "find of a view");
        is(rfind(w, t, p) == mrfind(a, n, s, k, p), "rfind of a view");
        is(find_first_of(w, t, p) == mfirst(a, n, s, k, p, 1), "find_first_of a view");
        is(find_first_not_of(w, t, p) == mfirst(a, n, s, k, p, 0), "find_first_not_of a view");
        is(find_last_of(w, t, p) == mlast(a, n, s, k, p, 1), "find_last_of a view");
        is(find_last_not_of(w, t, p) == mlast(a, n, s, k, p, 0), "find_last_not_of a view");
        is(find(w, c, p, k) == mfind(a, n, s, k, p), "find of a text and its count");
        is(find_first_of(w, c, p, k) == mfirst(a, n, s, k, p, 1), "find_first_of a text and its count");
        is(find_last_not_of(w, c, p, k) == mlast(a, n, s, k, p, 0), "find_last_not_of a text and its count");
        if (text_ok) {
            is(find(w, c, p) == mfind(a, n, s, k, p), "find of a text");
            is(rfind(w, c, p) == mrfind(a, n, s, k, p), "rfind of a text");
            is(find_last_of(w, c, p) == mlast(a, n, s, k, p, 1), "find_last_of a text");
        }
        if (k > 0) {
            char ch = (char)s[0];
            is(find(w, ch, p) == mfind(a, n, s, 1, p), "find of a character");
            is(rfind(w, ch, p) == mrfind(a, n, s, 1, p), "rfind of a character");
            is(find_first_not_of(w, ch, p) == mfirst(a, n, s, 1, p, 0), "find_first_not_of a character");
            is(find_last_of(w, ch, p) == mlast(a, n, s, 1, p, 1), "find_last_of a character");
        }
    }
    is(find(w, t) == mfind(a, n, s, k, 0), "find of a view from the start");
    is(rfind(w, t) == mrfind(a, n, s, k, NONE), "rfind of a view from the end");
    is(find_last_of(w, t) == mlast(a, n, s, k, NONE, 1), "find_last_of a view from the end");
    is(starts_with(w, t) == (k <= n && same(a, s, k)), "starts_with a view");
    is(ends_with(w, t) == (k <= n && same(a + (n - k), s, k)), "ends_with a view");
    is(contains(w, t) == (mfind(a, n, s, k, 0) != NONE), "contains a view");
    int m = mcmp(a, n, s, k);
    is(sgn(compare(w, t)) == m, "compare with a view, as unsigned bytes and then by the count");
    is((w == t) == (m == 0) && (w != t) == (m != 0), "== and != of two views");
    is((w < t) == (m < 0) && (w > t) == (m > 0) && (w <= t) == (m <= 0) && (w >= t) == (m >= 0), "< > <= >= of two views");
    if (text_ok) {
        is(starts_with(w, c) == (k <= n && same(a, s, k)), "starts_with a text");
        is(ends_with(w, c) == (k <= n && same(a + (n - k), s, k)), "ends_with a text");
        is(contains(w, c) == (mfind(a, n, s, k, 0) != NONE), "contains a text");
        is(sgn(compare(w, c)) == m, "compare with a text");
        is((w == c) == (m == 0) && (w < c) == (m < 0) && (w > c) == (m > 0) && (w <= c) == (m <= 0), "the relations with a text");
        is((c == w) == (m == 0) && (c < w) == (m > 0) && (c > w) == (m < 0) && (c >= w) == (m <= 0), "a text on the left");
    }
    if (k > 0) {
        char ch = (char)s[0];
        is(starts_with(w, ch) == (n > 0 && a[0] == s[0]), "starts_with a character");
        is(ends_with(w, ch) == (n > 0 && a[n - 1] == s[0]), "ends_with a character");
        is(contains(w, ch) == (mfind(a, n, s, 1, 0) != NONE), "contains a character");
    }
    for (size_t pos = 0; pos <= n; pos++) {
        size_t cnt = rnd() % (n + 2);
        size_t cut = cnt < n - pos ? cnt : n - pos;
        is(sgn(compare(w, pos, cnt, t)) == mcmp(a + pos, cut, s, k), "compare of a part with a view");
        size_t at = k ? rnd() % (k + 1) : 0, kn = rnd() % (k + 2), kcut = kn < k - at ? kn : k - at;
        is(sgn(compare(w, pos, cnt, t, at, kn)) == mcmp(a + pos, cut, s + at, kcut), "compare of a part with a part");
        is(sgn(compare(w, pos, cnt, c, k)) == mcmp(a + pos, cut, s, k), "compare of a part with a text and its count");
        char out[64];
        is(copy(w, out, cnt, pos) == cut && same((const unsigned char *)out, a + pos, cut), "copy cuts its count at the end");
    }
}
/* the forms that take a string where a view is taken, over the string at ss: its characters, in its object or in
   its block */
static void asks_string(string_view w, const unsigned char *a, size_t n, const string *ss) {
    const unsigned char *s = (const unsigned char *)c_str(*ss);
    size_t k = size(*ss);
    for (size_t pos = 0; pos <= n + 1; pos++) {
        is(find(w, *ss, pos) == mfind(a, n, s, k, pos), "find of a string");
        is(rfind(w, *ss, pos) == mrfind(a, n, s, k, pos), "rfind of a string");
        is(find_first_of(w, *ss, pos) == mfirst(a, n, s, k, pos, 1), "find_first_of a string");
        is(find_last_not_of(w, *ss, pos) == mlast(a, n, s, k, pos, 0), "find_last_not_of a string");
    }
    is(find(w, *ss) == mfind(a, n, s, k, 0) && rfind(w, *ss) == mrfind(a, n, s, k, NONE), "find and rfind of a string");
    is(find_first_not_of(w, *ss) == mfirst(a, n, s, k, 0, 0), "find_first_not_of a string from the start");
    is(find_last_of(w, *ss) == mlast(a, n, s, k, NONE, 1), "find_last_of a string from the end");
    is(starts_with(w, *ss) == (k <= n && same(a, s, k)), "starts_with a string");
    is(ends_with(w, *ss) == (k <= n && same(a + (n - k), s, k)), "ends_with a string");
    is(contains(w, *ss) == (mfind(a, n, s, k, 0) != NONE), "contains a string");
    int m = mcmp(a, n, s, k);
    is(sgn(compare(w, *ss)) == m, "compare with a string");
    is((w == *ss) == (m == 0) && (w < *ss) == (m < 0) && (w > *ss) == (m > 0) && (w <= *ss) == (m <= 0), "the relations with a string");
}
/* the rules of the view w over the n characters at a: its parts, and each needle */
static void view_rules(string_view w, const unsigned char *a, size_t n) {
    sees(w, a, n);
    size_t pos = rnd() % (n + 1), cnt = rnd() % (n + 2), cut = cnt < n - pos ? cnt : n - pos;
    string_view p = substr(w, pos, cnt);
    sees(p, a + pos, cut);
    string_view q = substr(w, pos);
    sees(q, a + pos, n - pos);
    string_view r = w;
    size_t front_n = rnd() % (n + 1), back_n = rnd() % (n - front_n + 1);
    remove_prefix(r, front_n);
    remove_suffix(r, back_n);
    sees(r, a + front_n, n - front_n - back_n);
    unsigned char s[40];
    size_t k = text(s, 6, 0);
    string_view t = {(const char *)s, k};
    asks(w, a, n, t, s, k);
    asks(w, a, n, p, a + pos, cut);
    string_view none;
    asks(w, a, n, none, (const unsigned char *)"", 0);
    asks(none, (const unsigned char *)"", 0, t, s, k);
}
/* the rules of a span over the n ints at m, whose model is the copy at e */
static void span_rules(span<int> s, int *m, int *e, size_t n) {
    is(size(s) == n && (n == 0 || data(s) == m), "a span sees its source's elements, in their place");
    is(size_bytes(s) == n * sizeof(int), "size_bytes is the count by the element's size");
    size_t k = rnd() % (n + 1), off = rnd() % (n + 1), cnt = rnd() % (n - off + 1);
    span<int> f = first(s, k);
    span<int> l = last(s, k);
    span<int> o = subspan(s, off);
    span<int> c = subspan(s, off, cnt);
    span<int> d = subspan(s, off, dynamic_extent);
    is(size(f) == k && data(f) == m, "first gives the first k elements");
    is(size(l) == k && data(l) == m + (n - k), "last gives the last k elements");
    is(size(o) == n - off && data(o) == m + off, "subspan from an offset gives the rest");
    is(size(c) == cnt && data(c) == m + off, "subspan of a count gives that many");
    is(size(d) == n - off && data(d) == m + off, "subspan of dynamic_extent gives the rest");
    for (size_t i = 0; i < cnt; i++) {
        int x = (int)(rnd() % 1000);
        c[i] = x;
        e[off + i] = x;
    }
    for (size_t i = 0; i < n; i++) is(s[i] == e[i] && m[i] == e[i], "a write through a span is its source's");
    if (n > 0) is(front(s) == e[0] && back(s) == e[n - 1] && at(s, n / 2) == e[n / 2], "front, back and at");
}
int main(void) {
    for (int walk = 0; walk < 300; walk++) {
        unsigned char a[40];
        size_t n = text(a, 32, 1);
        string_view w = {(const char *)a, n};
        view_rules(w, a, n);
        size_t z = strlen((const char *)a);
        string_view c = (const char *)a;
        sees(c, a, z);
        string s = c;
        for (int i = rnd() % 3; i > 0; i--) append(s, c);
        string_view v = s;
        sees(v, (const unsigned char *)c_str(s), size(s));
        view_rules(v, (const unsigned char *)c_str(s), size(s));
        string l = c;
        append(l, "a text of its own block, long");
        size_t at = size(s) ? rnd() % size(s) : 0;
        string part = substr(s, at, rnd() % 4);
        asks_string(w, a, n, &s);
        asks_string(w, a, n, &l);
        asks_string(w, a, n, &part);
        asks_string(v, (const unsigned char *)c_str(s), size(s), &part);
        asks_string(v, (const unsigned char *)c_str(s), size(s), &l);
    }
    string_view e;
    is(size(e) == 0 && empty(e) && find(e, "") == 0 && find(e, "a") == NONE && rfind(e, "") == 0, "a view born zero is the empty text");
    is(compare(e, "") == 0 && e == "" && !(e < "") && find_first_of(e, "a") == NONE && find_last_not_of(e, "a") == NONE,
       "a view born zero compares as the empty text");
    for (int walk = 0; walk < 300; walk++) {
        int m[40], x[40];
        size_t n = rnd() % 41;
        for (size_t i = 0; i < n; i++) m[i] = x[i] = (int)(rnd() % 1000);
        span<int> s = {m, n};
        span_rules(s, m, x, n);
        int arr[24];
        for (size_t i = 0; i < 24; i++) arr[i] = x[i] = (int)i;
        span<int> sa = arr;
        span_rules(sa, arr, x, 24);
        vector<int> v;
        for (size_t i = 0; i < n; i++) push_back(v, (int)i);
        for (size_t i = 0; i < n; i++) x[i] = (int)i;
        span<int> sv = v;
        span_rules(sv, data(v), x, n);
    }
    printf("the rules held at %zu checks, over 300 walks of views and 300 of spans\n", checks);
    return 0;
}
