// string_view.c's twin over std::string_view (0.295): what clang++ and libc++ print is string_view.expect
#include <cstdio>
#include <cstdlib>
#include <string>
#include <string_view>
static void show(const char *what, std::string_view v) {
    std::printf("%s=[", what);
    for (size_t i = 0; i < v.size(); i++) std::putchar(v[i]);
    std::printf("] %zu\n", v.length());
}
static int sgn(int c) { return (c > 0) - (c < 0); }
static std::string_view word(const char *text) {
    std::string_view a = text;
    return a.substr(0, 3);
}
static int many(long n) {
    std::string src;
    unsigned x = 12345;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        unsigned r = (x >> 8) % 8;
        src.push_back(r < 2 ? ' ' : (char)('a' + r % 3));
    }
    std::string_view v = src;
    std::string_view last;
    size_t words = 0, letters = 0, abs = 0, same = 0, at = 0;
    while ((at = v.find_first_not_of(' ', at)) != std::string_view::npos) {
        size_t e = v.find_first_of(' ', at);
        if (e == std::string_view::npos) e = v.size();
        std::string_view w = v.substr(at, e - at);
        words++;
        letters += w.size();
        if (w.starts_with("ab")) abs++;
        if (w == last) same++;
        last = w;
        at = e;
    }
    std::printf("%zu %zu %zu %zu %zu %d\n", words, letters, abs, same, (size_t) (v.rfind("abc") != std::string_view::npos),
                sgn(last.compare("c")));
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(std::atol(argv[1]));
    char buf[16] = "buffer";
    const char *ptr = "pointer";
    std::string s = "a string";
    std::string_view v = "hello world";
    std::string_view b = buf;
    std::string_view p = ptr;
    std::string_view w = s;
    std::string_view t(buf + 1, 3);
    std::string_view e;
    show("v", v);
    show("b", b);
    show("p", p);
    show("w", w);
    show("t", t);
    show("e", e);
    std::printf("%zu %zu %d %d %d\n", v.length(), b.size(), (int) e.empty(), (int) v.empty(), (int) (v.max_size() > 1000000));
    std::printf("%c %c %c %c %c\n", v[0], v.at(4), p.front(), p.back(), *t.data());
    size_t sum = 0;
    for (const char *q = v.data(); q != v.data() + v.size(); q++) sum += (unsigned char)*q;
    std::printf("%zu\n", sum);
    b.remove_prefix(2);
    b.remove_suffix(1);
    show("b", b);
    std::string_view x = v.substr(6, 5);
    std::string_view y = v.substr(6);
    std::string_view z = v.substr();
    show("x", x);
    show("y", y);
    show("z", z);
    char out[16] = {0};
    size_t k1 = v.copy(out, 5);
    size_t k2 = v.copy(out + 5, 3, 8);
    std::printf("%s %zu %zu\n", out, k1, k2);
    std::printf("%d %d %d %d %d %d\n", (int) (x == y), (int) (x != v), (int) (v < x), (int) (x <= y), (int) (v > x), (int) (x >= y));
    std::printf("%d %d %d %d %d %d\n", (int) (x == "world"), (int) (x != "word"), (int) (x < "worle"), (int) (x > "wor"),
                (int) (x <= "world"), (int) (x >= "worlds"));
    std::printf("%d %d %d %d\n", (int) ("world" == x), (int) ("abc" < v), (int) ("zzz" > v), (int) ("hello world" <= v));
    std::printf("%d %d %d %d\n", (int) (w == s), (int) (w < s), (int) (v > s), (int) (w != s));
    std::printf("%d %d %d %d\n", sgn(x.compare(y)), sgn(v.compare(x)), sgn(x.compare("worl")), sgn(w.compare(s)));
    std::printf("%d %d %d %d\n", sgn(v.compare(6, 5, x)), sgn(v.compare(0, 5, "hello")), sgn(v.compare(0, 4, "help", 3)),
                sgn(v.compare(6, 3, y, 0, 3)));
    std::string o = "o";
    std::printf("%zu %zu %zu %zu %zu %zu\n", v.find(x), v.find("o"), v.find('o'), v.find("o", 5), v.find('l', 4), v.find("orange", 0, 2));
    std::printf("%zu %zu %zu %zu %zu\n", v.find(o), v.find(o, 5), v.find(y, 3), (size_t) (v.find("zz") == std::string_view::npos),
                (size_t) (e.find("") == 0));
    std::printf("%zu %zu %zu %zu %zu\n", v.rfind("o"), v.rfind('o', 6), v.rfind(x), v.rfind("lo", 3, 1), v.rfind(o));
    std::printf("%zu %zu %zu %zu\n", v.find_first_of("wd"), v.find_first_of('o', 5), (size_t) (v.find_first_of("xyz") == std::string_view::npos),
                v.find_first_of(o, 6));
    std::printf("%zu %zu %zu %zu\n", v.find_first_not_of("hel"), v.find_first_not_of('h'),
                (size_t) (v.find_first_not_of(z) == std::string_view::npos), v.find_first_not_of("hello ", 0, 5));
    std::printf("%zu %zu %zu %zu\n", v.find_last_of("lo"), v.find_last_of('l', 5), v.find_last_of(x, 3), v.find_last_of(o));
    std::printf("%zu %zu %zu %zu\n", v.find_last_not_of("dl"), v.find_last_not_of('d'), v.find_last_not_of("rld", 8), v.find_last_not_of(x));
    std::printf("%d %d %d %d %d %d\n", (int) v.starts_with("hell"), (int) v.starts_with('h'), (int) v.starts_with(z),
                (int) v.ends_with("world"), (int) v.ends_with('d'), (int) v.ends_with(x));
    std::printf("%d %d %d %d %d\n", (int) v.contains("o w"), (int) v.contains('z'), (int) v.contains(x), (int) w.contains(s),
                (int) w.starts_with(s));
    std::string_view k3 = word("abcdef");
    show("word", k3);
    std::string u(x);
    u.append(t);
    u.append(v, 6);
    u.append(v, 1, 2);
    u += y;
    u.insert(0, x);
    u.insert(1, t, 1);
    u.insert(2, t, 1, 1);
    u.replace(0, 5, t);
    std::printf("u=[%s] %zu\n", u.c_str(), u.size());
    std::string r;
    r.assign(v);
    r.assign(v, 6);
    std::string q;
    q.assign(v, 0, 4);
    q.replace(0, 1, x, 1);
    q.replace(0, 1, x, 1, 2);
    std::printf("r=[%s] q=[%s]\n", r.c_str(), q.c_str());
    std::printf("%zu %zu %zu %zu %zu\n", u.find(x), u.rfind(t), u.find_first_of(t, 2), u.find_last_not_of(x), u.find(x, 3));
    std::printf("%d %d %d %d %d %d\n", (int) (r == x), (int) (r != x), (int) (r < v), (int) (r > v), sgn(u.compare(x)), sgn(r.compare(y)));
    std::printf("%d %d %d\n", (int) u.starts_with(t), (int) r.ends_with(y), (int) u.contains(x));
    return 0;
}
