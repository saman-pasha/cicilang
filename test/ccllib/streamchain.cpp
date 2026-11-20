// the twin of streamchain.c over std::, built by clang++ over libc++: what the program prints
#include <cstdio>
#include <cstring>
#include <unistd.h>
#include <iostream>
#include <iomanip>
#include <fstream>
#include <sstream>
#include <string>

int main() {
    std::cout << "a" << 1 << " " << 2.5 << std::endl;
    std::cout << std::hex;
    std::cout << -1 << " " << (short)-1 << " " << 255 << " " << -1L << std::endl;
    std::cout << std::oct;
    std::cout << 8 << " " << -1 << std::endl;
    std::cout << std::dec;
    std::cout << std::fixed << std::setprecision(0);
    std::cout << 3.7 << " " << 2.5 << std::endl;
    std::cout << std::setprecision(3);
    std::cout << 3.14159 << std::endl;
    std::cout << std::scientific;
    std::cout << 1234.5 << std::endl;

    char path[64];
    std::snprintf(path, sizeof path, "/tmp/ccllib_streamchain_%d.txt", (int)getpid());
    {
        std::ofstream f(path);
        f << std::fixed << std::setprecision(600);
        f << 0.25 << std::endl;
    }
    {
        std::ifstream f(path);
        std::string line;
        std::getline(f, line);
        std::printf("%zu %.6s\n", line.size(), line.c_str());
    }
    std::remove(path);

    std::stringstream s;
    s << std::setw(40) << 7;
    std::string ss = s.str();
    std::printf("%zu [%s]\n", ss.size(), ss.c_str() + 38);

    std::stringstream e;
    int x = 5;
    int ok = (bool)(e >> x);
    std::printf("%d %d %d %d\n", ok, x, (int)e.fail(), (int)e.eof());

    std::stringstream t;
    t << "12 34 x 9";
    int a = 0, b = 0, c = 7, d = 8;
    t >> a >> b;
    int ok2 = (bool)(t >> c >> d);
    std::printf("%d %d %d %d %d %d\n", a, b, ok2, c, d, (int)t.good());
    int e2 = 9;
    t >> e2;
    int a2 = 0, a3 = 0, a4 = 0;
    t.str("");
    t.clear();
    t << "5";
    t >> a3;
    std::printf("%d %d %d\n", e2, a3, (int)t.eof());
    t >> a4;
    t.clear();
    t.seekg(0);
    t >> a2;
    std::printf("%d %d %d\n", a4, a2, (int)t.good());

    std::stringstream u;
    u << " a  b\tc";
    char p = 0, q = 0, r = 0;
    u >> p >> q >> r;
    std::printf("[%c][%c][%c]\n", p, q, r);

    std::stringstream w;
    w << "line one\r" << std::endl << "two";
    std::string buf;
    std::getline(w, buf);
    std::printf("%zu\n", buf.size());
    std::getline(w, buf);
    std::printf("%s %d\n", buf.c_str(), (int)w.eof());

    std::stringstream v;
    v << std::fixed << std::setprecision(600) << 0.25;
    std::string vs = v.str();
    std::printf("%zu %.6s\n", vs.size(), vs.c_str());

    std::stringstream z;
    z << 3 << " " << 4.5 << " " << "z" << std::endl;
    std::printf("%s", z.str().c_str());

    signed char sc = 'A';
    unsigned char uc = 'B';
    std::cout << sc << uc << " ";
    std::cout << std::setw(3);
    std::cout << sc << std::endl;
    std::cout << std::setw(4);
    std::cout.put('p');
    std::cout.write("qr", 2);
    std::cout << 7 << std::endl;
    std::stringstream m;
    m << (short)-2 << " " << (unsigned short)65535 << " " << sc << uc << " " << 1.5L << std::endl;
    std::printf("%s", m.str().c_str());

    {
        std::ofstream o(path);
        o << "abcdefghij" << std::endl << "wxyz" << std::endl << "cr\r" << std::endl;
    }
    {
        std::ifstream f(path);
        char g[5];
        int g1 = (bool)f.getline(g, sizeof g);
        std::printf("%d [%s] %d %d\n", g1, g, (int)f.fail(), (int)f.good());
        int q = 3;
        f >> q;
        std::printf("%d\n", q);
        int g1b = (bool)f.getline(g, sizeof g);
        std::printf("%d [%s]\n", g1b, g);
        f.clear();
        int g2 = (bool)f.getline(g, sizeof g);
        std::printf("%d [%s]\n", g2, g);
        f.clear();
        int g3 = (bool)f.getline(g, sizeof g);
        std::printf("%d [%s]\n", g3, g);
        int g4 = (bool)f.getline(g, sizeof g);
        std::printf("%d [%s] %d\n", g4, g, (int)f.eof());
        int g5 = (bool)f.getline(g, sizeof g);
        std::printf("%d %zu\n", g5, std::strlen(g));
        int g6 = (bool)f.getline(g, sizeof g);
        std::printf("%d %d %d\n", g6, (int)f.fail(), (int)f.eof());
        f.close();
        f.open(path);
        int g7 = (bool)f.getline(g, sizeof g);
        std::printf("%d [%s]\n", g7, g);
    }
    std::remove(path);
    std::stringstream h;
    h << "abcdefgh" << std::endl;
    char hb[5];
    int h1 = (bool)h.getline(hb, sizeof hb);
    std::printf("%d [%s] %d\n", h1, hb, (int)h.fail());
    std::cout << "end" << std::endl;
    return 0;
}
