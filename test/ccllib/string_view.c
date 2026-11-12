/* <string_view.pl> (0.295; CCLLIB.md's phase 1a): the whole surface of ccllib's string_view, each function once at
   least, and the forms of <string.pl> that take a view. cicilang builds this file as C and cicilang++ as C++;
   string_view.cpp is its twin over std::string_view, which clang++ builds over libc++: the three print the same
   lines, string_view.expect. With a count, `string_view 1000000', it makes a text of that many characters and reads
   its words by views -- the searches of a set of characters, a part, the tests and the comparisons --: the run that
   the costs time */
#include <stdio.h>
#include <stdlib.h>
#include <string.pl>
#include <string_view.pl>
static void show(const char *what, string_view v) {
    printf("%s=[", what);
    for (size_t i = 0; i < size(v); i++) putchar(v[i]);
    printf("] %zu\n", length(v));
}
/* compare's sign: C++ says no more of its answer than its sign, and libc++ gives memcmp's difference */
static int sgn(int c) { return (c > 0) - (c < 0); }
/* a view of the function's own text, returned: tied to the text */
static string_view word(const char *text) tie text {
    string_view a = text;
    return substr(a, 0, 3);
}
static int many(long n) {
    string src;
    unsigned x = 12345;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        unsigned r = (x >> 8) % 8;
        push_back(src, r < 2 ? ' ' : (char)('a' + r % 3));
    }
    string_view v = src;
    string_view last;
    size_t words = 0, letters = 0, abs = 0, same = 0, at = 0;
    while ((at = find_first_not_of(v, ' ', at)) != npos) {
        size_t e = find_first_of(v, ' ', at);
        if (e == npos) e = size(v);
        string_view w = substr(v, at, e - at);
        words++;
        letters += size(w);
        if (starts_with(w, "ab")) abs++;
        if (w == last) same++;
        last = w;
        at = e;
    }
    printf("%zu %zu %zu %zu %zu %d\n", words, letters, abs, same, rfind(v, "abc") != npos, sgn(compare(last, "c")));
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1]));
    /* made: of a literal, a char array, a pointer, a string, a text and its count; born zero */
    char buf[16] = "buffer";
    const char *ptr = "pointer";
    string s = "a string";
    string_view v = "hello world";
    string_view b = buf;
    string_view p = ptr;
    string_view w = s;
    string_view t = {buf + 1, 3};
    string_view e;
    show("v", v);
    show("b", b);
    show("p", p);
    show("w", w);
    show("t", t);
    show("e", e);
    printf("%zu %zu %d %d %d\n", len(v), size(b), empty(e), empty(v), max_size(v) > 1000000);
    printf("%c %c %c %c %c\n", v[0], at(v, 4), front(p), back(p), *data(t));
    size_t sum = 0;
    for (const char *q = begin(v); q != end(v); q++) sum += (unsigned char)*q;
    printf("%zu\n", sum);
    /* narrowed: the view itself, and a part of it */
    remove_prefix(b, 2);
    remove_suffix(b, 1);
    show("b", b);
    string_view x = substr(v, 6, 5);
    string_view y = substr(v, 6);
    string_view z = substr(v);
    show("x", x);
    show("y", y);
    show("z", z);
    char out[16] = {0};
    size_t k1 = copy(v, out, 5);
    size_t k2 = copy(v, out + 5, 3, 8);
    printf("%s %zu %zu\n", out, k1, k2);
    /* compared: with a view, a text, a string; a text on the left */
    printf("%d %d %d %d %d %d\n", x == y, x != v, v < x, x <= y, v > x, x >= y);
    printf("%d %d %d %d %d %d\n", x == "world", x != "word", x < "worle", x > "wor", x <= "world", x >= "worlds");
    printf("%d %d %d %d\n", "world" == x, "abc" < v, "zzz" > v, "hello world" <= v);
    printf("%d %d %d %d\n", w == s, w < s, v > s, w != s);
    printf("%d %d %d %d\n", sgn(compare(x, y)), sgn(compare(v, x)), sgn(compare(x, "worl")), sgn(compare(w, s)));
    printf("%d %d %d %d\n", sgn(compare(v, 6, 5, x)), sgn(compare(v, 0, 5, "hello")), sgn(compare(v, 0, 4, "help", 3)),
           sgn(compare(v, 6, 3, y, 0, 3)));
    /* searched: by a view, a string, a text, a character; from a place */
    string o = "o";
    printf("%zu %zu %zu %zu %zu %zu\n", find(v, x), find(v, "o"), find(v, 'o'), find(v, "o", 5), find(v, 'l', 4),
           find(v, "orange", 0, 2));
    printf("%zu %zu %zu %zu %zu\n", find(v, o), find(v, o, 5), find(v, y, 3), find(v, "zz") == npos, find(e, "") == 0);
    printf("%zu %zu %zu %zu %zu\n", rfind(v, "o"), rfind(v, 'o', 6), rfind(v, x), rfind(v, "lo", 3, 1), rfind(v, o));
    printf("%zu %zu %zu %zu\n", find_first_of(v, "wd"), find_first_of(v, 'o', 5), find_first_of(v, "xyz") == npos,
           find_first_of(v, o, 6));
    printf("%zu %zu %zu %zu\n", find_first_not_of(v, "hel"), find_first_not_of(v, 'h'), find_first_not_of(v, z) == npos,
           find_first_not_of(v, "hello ", 0, 5));
    printf("%zu %zu %zu %zu\n", find_last_of(v, "lo"), find_last_of(v, 'l', 5), find_last_of(v, x, 3),
           find_last_of(v, o));
    printf("%zu %zu %zu %zu\n", find_last_not_of(v, "dl"), find_last_not_of(v, 'd'), find_last_not_of(v, "rld", 8),
           find_last_not_of(v, x));
    /* the tests of a part */
    printf("%d %d %d %d %d %d\n", starts_with(v, "hell"), starts_with(v, 'h'), starts_with(v, z), ends_with(v, "world"),
           ends_with(v, 'd'), ends_with(v, x));
    printf("%d %d %d %d %d\n", contains(v, "o w"), contains(v, 'z'), contains(v, x), contains(w, s), starts_with(w, s));
    string_view k3 = word("abcdef");
    show("word", k3);
    /* <string.pl> over a view: made of one, changed by one, searched, tested and compared by one */
    string u = x;
    append(u, t);
    append(u, v, 6);
    append(u, v, 1, 2);
    u += y;
    insert(u, 0, x);
    insert(u, 1, t, 1);
    insert(u, 2, t, 1, 1);
    replace(u, 0, 5, t);
    printf("u=[%s] %zu\n", c_str(u), size(u));
    string r;
    assign(r, v);
    assign(r, v, 6);
    string q;
    assign(q, v, 0, 4);
    replace(q, 0, 1, x, 1);
    replace(q, 0, 1, x, 1, 2);
    printf("r=[%s] q=[%s]\n", c_str(r), c_str(q));
    printf("%zu %zu %zu %zu %zu\n", find(u, x), rfind(u, t), find_first_of(u, t, 2), find_last_not_of(u, x),
           find(u, x, 3));
    printf("%d %d %d %d %d %d\n", r == x, r != x, r < v, r > v, sgn(compare(u, x)), sgn(compare(r, y)));
    printf("%d %d %d\n", starts_with(u, t), ends_with(r, y), contains(u, x));
    return 0;
}
