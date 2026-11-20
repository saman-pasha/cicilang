/* ccllib 1.6.3 (CCLLIB.md's phase 1d): the streams as C++'s -- `<<' and `>>' chained, endl a value of its own, an
   integer's own bits in hex and oct, the precision that a program set, a value longer than the frame's buffer, a
   read that fails and the state that says so, a character read after the white space, the width of a stringstream,
   an empty stream, a line that keeps its carriage return, and str as a borrow; and the forms beside them: a signed
   and an unsigned char written as characters, a stringstream that writes what an ostream writes, and a line longer
   than getline's buffer, in a file and in a stringstream. Built by cicilang as C and by
   cicilang++ as C++, and compared with streamchain.cpp over std::, which clang++ builds. */
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <iostream.pl>
#include <iomanip.pl>
#include <fstream.pl>
#include <stringstream.pl>

int main(void) {
    cout << "a" << 1 << " " << 2.5 << endl;
    hex(cout);
    cout << -1 << " " << (short)-1 << " " << 255 << " " << -1L << endl;
    oct(cout);
    cout << 8 << " " << -1 << endl;
    dec(cout);
    fixed(cout);
    setprecision(cout, 0);
    cout << 3.7 << " " << 2.5 << endl;
    setprecision(cout, 3);
    cout << 3.14159 << endl;
    scientific(cout);
    cout << 1234.5 << endl;

    char path[64];
    snprintf(path, sizeof path, "/tmp/ccllib_streamchain_%d.txt", (int)getpid());
    fstream<char> f;
    open(f, path, "w");
    fixed(f);
    setprecision(f, 600);
    f << 0.25 << endl;
    close(f);
    open(f, path, "r");
    char line[700];
    getline(f, line, sizeof line);
    printf("%zu %.6s\n", strlen(line), line);
    close(f);
    remove(path);

    stringstream<> s;
    setw(s, 40);
    s << 7;
    printf("%zu [%s]\n", strlen(str(s)), str(s) + 38);

    stringstream<> e;
    int x = 5;
    int ok = (e >> x) != 0;
    printf("%d %d %d %d\n", ok, x, fail(e), eof(e));

    stringstream<> t;
    t << "12 34 x 9";
    int a = 0, b = 0, c = 7, d = 8;
    t >> a >> b;
    int ok2 = (t >> c >> d) != 0;
    printf("%d %d %d %d %d %d\n", a, b, ok2, c, d, good(t));
    int e2 = 9;
    t >> e2;
    int a2 = 0, a3 = 0, a4 = 0;
    clear(t);
    t << "5";
    t >> a3;
    printf("%d %d %d\n", e2, a3, eof(t));
    t >> a4;
    rewind(t);
    t >> a2;
    printf("%d %d %d\n", a4, a2, good(t));

    stringstream<> u;
    u << " a  b\tc";
    char p = 0, q = 0, r = 0;
    u >> p >> q >> r;
    printf("[%c][%c][%c]\n", p, q, r);

    stringstream<> w;
    w << "line one\r" << endl << "two";
    char buf[32];
    getline(w, buf, sizeof buf);
    printf("%zu\n", strlen(buf));
    getline(w, buf, sizeof buf);
    printf("%s %d\n", buf, eof(w));

    stringstream<> v;
    fixed(v);
    setprecision(v, 600);
    v << 0.25;
    printf("%zu %.6s\n", strlen(str(v)), str(v));

    stringstream<> z;
    z << 3 << " " << 4.5 << " " << "z" << endl;
    printf("%s", str(z));

    signed char sc = 'A';
    unsigned char uc = 'B';
    cout << sc << uc << " ";
    setw(cout, 3);
    cout << sc << endl;
    setw(cout, 4);
    put(cout, 'p');
    write(cout, "qr", 2);
    cout << 7 << endl;
    stringstream<> m;
    m << (short)-2 << " " << (unsigned short)65535 << " " << sc << uc << " " << 1.5L << endl;
    printf("%s", str(m));

    open(f, path, "w");
    f << "abcdefghij" << endl << "wxyz" << endl << "cr\r" << endl;
    close(f);
    open(f, path, "r");
    char g[5];
    int g1 = getline(f, g, sizeof g) != 0;
    printf("%d [%s] %d %d\n", g1, g, fail(f), good(f));
    int q = 3;
    f >> q;
    printf("%d\n", q);
    int g1b = getline(f, g, sizeof g) != 0;
    printf("%d [%s]\n", g1b, g);
    clear(f);
    int g2 = getline(f, g, sizeof g) != 0;
    printf("%d [%s]\n", g2, g);
    clear(f);
    int g3 = getline(f, g, sizeof g) != 0;
    printf("%d [%s]\n", g3, g);
    int g4 = getline(f, g, sizeof g) != 0;
    printf("%d [%s] %d\n", g4, g, eof(f));
    int g5 = getline(f, g, sizeof g) != 0;
    printf("%d %zu\n", g5, strlen(g));
    int g6 = getline(f, g, sizeof g) != 0;
    printf("%d %d %d\n", g6, fail(f), eof(f));
    close(f);
    open(f, path, "r");
    int g7 = getline(f, g, sizeof g) != 0;
    printf("%d [%s]\n", g7, g);
    close(f);
    remove(path);
    stringstream<> h;
    h << "abcdefgh" << endl;
    char hb[5];
    int h1 = getline(h, hb, sizeof hb) != 0;
    printf("%d [%s] %d\n", h1, hb, fail(h));
    cout << "end" << endl;
    return 0;
}
