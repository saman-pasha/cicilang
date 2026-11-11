/* <string.pl> (0.291; CCLLIB.md's phase 1a): the whole surface of ccllib's string, each function once at least.
   cicilang builds this file as C and cicilang++ as C++; string.cpp is its twin over std::string, which clang++ builds
   over libc++: the three print the same lines, string.expect. With a count, `string 1000000', it builds a text of that
   many characters, puts "xyz" in the place of each "ab" by a search and appends, and reads numbers back from their
   texts: the run that the costs time */
#include <stdio.h>
#include <stdlib.h>
#include <string.pl>
static void show(const char *what, const string *s) {
    printf("%s=[%s] %zu\n", what, c_str(*s), size(*s));
}
static size_t sum(const string *s) {
    size_t k = 0;
    for (const char *p = begin(*s); p != end(*s); p++) k = k * 31 + (unsigned char)*p;
    return k;
}
static int many(long n) {
    string src;
    unsigned x = 12345;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) { x = x * 1103515245u + 12345u; push_back(src, (char)('a' + (x >> 8) % 4)); }
    string out;
    size_t at = 0, k, hits = 0;
    while ((k = find(src, "ab", at)) != npos) {
        append(out, src, at, k - at);
        append(out, "xyz");
        at = k + 2;
        hits++;
    }
    append(out, src, at);
    long total = 0;
    for (long i = 0; i < n / 100; i++) {
        string t = to_string(i * 7919 % 1000003);
        total += stoi(t);
    }
    int cmp = compare(src, 0, 64, out, 0, 64);
    printf("%zu %zu %zu %zu %ld %d\n", size(src), size(out), hits, sum(&out), total, (cmp > 0) - (cmp < 0));
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1]));
    string a = "hello";
    string b = "0123456789abcdefXYZ";
    string e;
    char buf8[8] = "buf";
    const char *ptr = "ptr";
    string fb = buf8;
    string fp = ptr;
    printf("%d %d %d %d %zu %zu %d\n", a[0], a[5], a[4], empty(e), length(a), len(b), capacity(e) >= 15);
    show("fb", &fb);
    show("fp", &fp);
    printf("%d %c %c %c %d\n", at(a, 1), front(a), back(a), *data(a), max_size(a) > 1000000);
    /* append, in its six forms */
    append(a, b, 16);
    append(a, b, 2, 3);
    append(a, 2, '-');
    append(a, "xyz", 2);
    append(a, "!");
    append(a, e);
    show("append", &a);
    /* insert, in its six forms */
    insert(a, 0, "<<");
    insert(a, 2, b, 10, 3);
    insert(a, 0, 2, '#');
    insert(a, size(a), e);
    insert(a, 1, "lit", 1);
    insert(a, 0, b, 17);
    show("insert", &a);
    /* replace, in its six forms */
    replace(a, 0, 2, "++");
    replace(a, 2, 1, b);
    replace(a, 0, 4, 1, '=');
    replace(a, 1, 3, "abcdef", 2);
    replace(a, 3, 2, b, 16);
    replace(a, 3, 0, b, 0, 2);
    show("replace", &a);
    erase(a, 5, 3);
    erase(a, 20);
    show("erase", &a);
    /* assign, in its six forms */
    assign(e, "one");
    assign(e, a, 2);
    assign(e, a, 0, 3);
    assign(e, 3, 'z');
    assign(e, "abcdef", 4);
    show("assign", &e);
    assign(e, a);
    show("assign", &e);
    erase(e);
    show("erase", &e);
    /* a change by a part of the string itself */
    string self = "abcdefghijklmnop";
    append(self, self);
    append(self, c_str(self) + 30);
    insert(self, 1, self, 0, 3);
    replace(self, 0, 4, self);
    assign(self, self, 2, 40);
    self += self;
    show("self", &self);
    /* the searches */
    printf("%zu %zu %zu %zu %zu %d\n", find(b, "abc"), find(b, 'X'), find(b, fb), find(b, "9", 3),
           find(b, "abcXX", 0, 3), find(b, "nope") == npos);
    char cX = 'X';
    printf("%zu %zu %zu %zu %zu\n", find(b, cX), find(b, cX, 17), find(b, 'a', 11), rfind(b, "a"), rfind(b, 'Z'));
    printf("%zu %zu %zu %zu\n", rfind(b, "0", 5), rfind(b, b), rfind(b, "abcd", 9, 2), rfind(b, 'a', 9));
    printf("%zu %zu %zu %zu\n", find_first_of(b, "fed"), find_first_not_of(b, "0123"), find_last_of(b, "abc"),
           find_last_not_of(b, "XYZ"));
    printf("%zu %zu %zu %zu\n", find_first_of(b, 'c'), find_first_of(b, "fed", 14), find_last_of(b, "0123", 2),
           find_last_not_of(b, 'Z', 17));
    /* the tests of a part */
    printf("%d %d %d %d %d %d %d %d\n", starts_with(b, "012"), starts_with(b, '0'), ends_with(b, "XYZ"),
           ends_with(b, 'Q'), contains(b, "9ab"), contains(b, fb), contains(b, 'Y'), starts_with(b, b));
    /* the comparisons */
    string lo = "abc", hi = "abd";
    printf("%d %d %d %d %d\n", compare(lo, hi) < 0, compare(hi, "abc") > 0, compare(b, 0, 3, "012"),
           compare(b, 10, 3, lo), compare(b, 10, 3, "abcdef", 3));
    printf("%d %d\n", compare(b, 0, 2, lo, 0, 2) > 0, compare(b, 10, 3, lo, 0) == 0);
    printf("%d %d %d %d %d %d\n", lo == hi, lo != hi, lo < hi, lo > hi, lo <= hi, lo >= hi);
    printf("%d %d %d %d %d %d\n", lo == "abc", lo != "abc", lo < "abd", lo > "abb", lo <= "abc", lo >= "abd");
    printf("%d %d %d %d %d %d\n", "abc" == lo, "abc" != lo, "abb" < lo, "abd" > lo, "abc" <= lo, "abb" >= lo);
    /* a part, and the operators that make a string */
    string u = substr(b, 10, 3);
    string w = substr(b, 16);
    string whole = substr(b);
    string c = u + w;
    string d = c + "!";
    string f = d + '?';
    string g = "<" + u;
    string h = '(' + u;
    d += '?';
    d += u;
    d += "..";
    show("u", &u); show("w", &w); show("whole", &whole); show("c", &c); show("d", &d); show("f", &f);
    show("g", &g); show("h", &h);
    /* the numbers of a text, and the text of a number */
    string n = "  -42xyz";
    size_t used = 0;
    string hx = "ff", big = "9223372036854775807", neg = "-1", fl = "2.75e1rest";
    printf("%d %d %zu %d %ld %lld\n", stoi(n), stoi(n, &used), used, stoi(hx, 0, 16), stol(n), stoll(big));
    printf("%lu %llu %lu\n", stoul(hx, 0, 16), stoull(big), stoul(neg));
    printf("%g %g %zu %Lg\n", (double)stof(fl), stod(fl, &used), used, stold(fl));
    string n1 = to_string(-12345);
    string n2 = to_string(7UL);
    string n3 = to_string(2.5);
    string n4 = to_string(1.5f);
    string n5 = to_string(0);
    string n6 = to_string(-9223372036854775807LL - 1);
    string n7 = to_string(18446744073709551615ULL);
    string n8 = to_string(0.1L);
    printf("[%s] [%s] [%s] [%s] [%s] [%s] [%s] [%s]\n", c_str(n1), c_str(n2), c_str(n3), c_str(n4), c_str(n5),
           c_str(n6), c_str(n7), c_str(n8));
    /* the rest: swap, the ends, the capacity, a copy out, a value taken away, the place after the last character */
    swap(u, d);
    show("u", &u); show("d", &d);
    char pb = pop_back(u);
    push(u, '#');
    char pp = pop(u);
    printf("%c %c %c %c %d\n", front(u), back(u), pb, pp, capacity(u) >= size(u));
    reserve(e, 100);
    printf("%d\n", capacity(e) >= 100);
    resize(e, 3, 'k');
    resize(e, 5);
    shrink_to_fit(e);
    printf("%zu %d %d %d\n", size(e), capacity(e) >= size(e), e[3], e[size(e)]);
    char buf[8] = {0};
    size_t got = copy(b, buf, 4, 10);
    printf("%zu [%s]", got, buf);
    got = copy(b, buf, 3);
    printf(" %zu [%s]\n", got, buf);
    string many_a = "banana bandana";
    printf("%zu\n", erase_value(many_a, 'a'));
    show("erase_value", &many_a);
    string longer = "a text that is longer than fifteen characters";
    string kept = clone(longer);
    shrink_to_fit(longer);
    clear(longer);
    show("longer", &longer);
    show("kept", &kept);
    printf("%d %zu\n", capacity(longer) >= size(kept), sum(&kept));
    string grow;
    for (int i = 0; i < 100; i++) push_back(grow, (char)('a' + i % 26));
    printf("%zu %c %c %zu\n", size(grow), grow[0], grow[99], sum(&grow));
    return 0;
}
