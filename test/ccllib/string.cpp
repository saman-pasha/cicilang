// string.c's twin over std::string (0.291): the same lines, which clang++ builds over libc++; string.expect is what
// it prints. With a count it does what string.c's count run does
#include <cstdio>
#include <cstdlib>
#include <string>
using std::string;
static const size_t npos = string::npos;
static void show(const char *what, const string *s) {
    printf("%s=[%s] %zu\n", what, s->c_str(), s->size());
}
static size_t sum(const string *s) {
    size_t k = 0;
    for (const char *p = s->data(); p != s->data() + s->size(); p++) k = k * 31 + (unsigned char)*p;
    return k;
}
static int many(long n) {
    string src;
    unsigned x = 12345;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) { x = x * 1103515245u + 12345u; src.push_back((char)('a' + (x >> 8) % 4)); }
    string out;
    size_t at = 0, k, hits = 0;
    while ((k = src.find("ab", at)) != npos) {
        out.append(src, at, k - at);
        out.append("xyz");
        at = k + 2;
        hits++;
    }
    out.append(src, at);
    long total = 0;
    for (long i = 0; i < n / 100; i++) {
        string t = std::to_string(i * 7919 % 1000003);
        total += std::stoi(t);
    }
    int cmp = src.compare(0, 64, out, 0, 64);
    printf("%zu %zu %zu %zu %ld %d\n", src.size(), out.size(), hits, sum(&out), total, (cmp > 0) - (cmp < 0));
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
    printf("%d %d %d %d %zu %zu %d\n", a[0], a[5], a[4], e.empty(), a.length(), b.size(), e.capacity() >= 15);
    show("fb", &fb);
    show("fp", &fp);
    printf("%d %c %c %c %d\n", a.at(1), a.front(), a.back(), *a.data(), a.max_size() > 1000000);
    a.append(b, 16);
    a.append(b, 2, 3);
    a.append(2, '-');
    a.append("xyz", 2);
    a.append("!");
    a.append(e);
    show("append", &a);
    a.insert(0, "<<");
    a.insert(2, b, 10, 3);
    a.insert(0, 2, '#');
    a.insert(a.size(), e);
    a.insert(1, "lit", 1);
    a.insert(0, b, 17);
    show("insert", &a);
    a.replace(0, 2, "++");
    a.replace(2, 1, b);
    a.replace(0, 4, 1, '=');
    a.replace(1, 3, "abcdef", 2);
    a.replace(3, 2, b, 16);
    a.replace(3, 0, b, 0, 2);
    show("replace", &a);
    a.erase(5, 3);
    a.erase(20);
    show("erase", &a);
    e.assign("one");
    e.assign(a, 2);
    e.assign(a, 0, 3);
    e.assign(3, 'z');
    e.assign("abcdef", 4);
    show("assign", &e);
    e.assign(a);
    show("assign", &e);
    e.erase();
    show("erase", &e);
    string self = "abcdefghijklmnop";
    self.append(self);
    self.append(self, 30);
    self.insert(1, self, 0, 3);
    self.replace(0, 4, self);
    self.assign(self, 2, 40);
    self += self;
    show("self", &self);
    printf("%zu %zu %zu %zu %zu %d\n", b.find("abc"), b.find('X'), b.find(fb), b.find("9", 3),
           b.find("abcXX", 0, 3), b.find("nope") == npos);
    char cX = 'X';
    printf("%zu %zu %zu %zu %zu\n", b.find(cX), b.find(cX, 17), b.find('a', 11), b.rfind("a"), b.rfind('Z'));
    printf("%zu %zu %zu %zu\n", b.rfind("0", 5), b.rfind(b), b.rfind("abcd", 9, 2), b.rfind('a', 9));
    printf("%zu %zu %zu %zu\n", b.find_first_of("fed"), b.find_first_not_of("0123"), b.find_last_of("abc"),
           b.find_last_not_of("XYZ"));
    printf("%zu %zu %zu %zu\n", b.find_first_of('c'), b.find_first_of("fed", 14), b.find_last_of("0123", 2),
           b.find_last_not_of('Z', 17));
    printf("%d %d %d %d %d %d %d %d\n", b.starts_with("012"), b.starts_with('0'), b.ends_with("XYZ"),
           b.ends_with('Q'), b.contains("9ab"), b.contains(fb), b.contains('Y'), b.starts_with(b));
    string lo = "abc", hi = "abd";
    printf("%d %d %d %d %d\n", lo.compare(hi) < 0, hi.compare("abc") > 0, b.compare(0, 3, "012"),
           b.compare(10, 3, lo), b.compare(10, 3, "abcdef", 3));
    printf("%d %d\n", b.compare(0, 2, lo, 0, 2) > 0, b.compare(10, 3, lo, 0) == 0);
    printf("%d %d %d %d %d %d\n", lo == hi, lo != hi, lo < hi, lo > hi, lo <= hi, lo >= hi);
    printf("%d %d %d %d %d %d\n", lo == "abc", lo != "abc", lo < "abd", lo > "abb", lo <= "abc", lo >= "abd");
    printf("%d %d %d %d %d %d\n", "abc" == lo, "abc" != lo, "abb" < lo, "abd" > lo, "abc" <= lo, "abb" >= lo);
    string u = b.substr(10, 3);
    string w = b.substr(16);
    string whole = b.substr();
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
    string n = "  -42xyz";
    size_t used = 0;
    string hx = "ff", big = "9223372036854775807", neg = "-1", fl = "2.75e1rest";
    printf("%d %d %zu %d %ld %lld\n", std::stoi(n), std::stoi(n, &used), used, std::stoi(hx, 0, 16), std::stol(n),
           std::stoll(big));
    printf("%lu %llu %lu\n", std::stoul(hx, 0, 16), std::stoull(big), std::stoul(neg));
    printf("%g %g %zu %Lg\n", (double)std::stof(fl), std::stod(fl, &used), used, std::stold(fl));
    string n1 = std::to_string(-12345);
    string n2 = std::to_string(7UL);
    string n3 = std::to_string(2.5);
    string n4 = std::to_string(1.5f);
    string n5 = std::to_string(0);
    string n6 = std::to_string(-9223372036854775807LL - 1);
    string n7 = std::to_string(18446744073709551615ULL);
    string n8 = std::to_string(0.1L);
    printf("[%s] [%s] [%s] [%s] [%s] [%s] [%s] [%s]\n", n1.c_str(), n2.c_str(), n3.c_str(), n4.c_str(), n5.c_str(),
           n6.c_str(), n7.c_str(), n8.c_str());
    swap(u, d);
    show("u", &u); show("d", &d);
    char pb = u.back();
    u.pop_back();
    u.push_back('#');
    char pp = u.back();
    u.pop_back();
    printf("%c %c %c %c %d\n", u.front(), u.back(), pb, pp, u.capacity() >= u.size());
    e.reserve(100);
    printf("%d\n", e.capacity() >= 100);
    e.resize(3, 'k');
    e.resize(5);
    e.shrink_to_fit();
    printf("%zu %d %d %d\n", e.size(), e.capacity() >= e.size(), e[3], e[e.size()]);
    char buf[8] = {0};
    size_t got = b.copy(buf, 4, 10);
    printf("%zu [%s]", got, buf);
    got = b.copy(buf, 3);
    printf(" %zu [%s]\n", got, buf);
    string many_a = "banana bandana";
    printf("%zu\n", std::erase(many_a, 'a'));
    show("erase_value", &many_a);
    string longer = "a text that is longer than fifteen characters";
    string kept = longer;
    longer.shrink_to_fit();
    longer.clear();
    show("longer", &longer);
    show("kept", &kept);
    printf("%d %zu\n", longer.capacity() >= kept.size(), sum(&kept));
    string grow;
    for (int i = 0; i < 100; i++) grow.push_back((char)('a' + i % 26));
    printf("%zu %c %c %zu\n", grow.size(), grow[0], grow[99], sum(&grow));
    return 0;
}
