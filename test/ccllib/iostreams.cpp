// the twin of iostreams.c over std:: (phase 1d): clang++ builds it over libc++ and it prints iostreams.expect
#include <cstdio>
#include <unistd.h>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>

int main() {
    std::cout << "hello" << std::endl;
    std::cout << 42 << std::endl;
    std::cout << -7 << std::endl;
    std::cout << 3.5 << std::endl;
    std::cout << std::setprecision(4);
    std::cout << "pi=" << 3.14159265 << std::endl;
    std::cout << std::setw(6) << std::setfill('0') << 42 << std::endl;
    std::cout << std::hex << 255 << std::dec << std::endl;
    bool yes = true;
    std::cout << std::boolalpha << yes << std::noboolalpha << std::endl;
    std::cout << yes << std::endl;
    std::cout << 'X' << std::endl;
    std::cout << std::fixed << std::setprecision(2) << "fixed=" << 3.14159 << std::endl;

    char path[64];
    std::snprintf(path, sizeof path, "/tmp/ccllib_iostreams_%d.txt", (int)getpid());
    std::fstream f;
    f.open(path, std::ios::out);
    f << "line1" << std::endl;
    f << 7 << std::endl;
    f.close();
    f.open(path, std::ios::in);
    std::string line;
    std::getline(f, line);
    int file_number = 0;
    f >> file_number;
    std::printf("file=%s %d\n", line.c_str(), file_number);
    f.close();
    std::remove(path);

    std::stringstream s;
    s << "abc" << 42;
    std::cout << "sstr=" << s.str() << std::endl;
    s.str("");
    s.clear();
    s << "12 3.5";
    int a = 0;
    double b = 0;
    s >> a >> b;
    std::printf("parsed=%d %g\n", a, b);

    int cin_number = 0;
    std::cin >> cin_number;
    std::printf("cin=%d eof=%d\n", cin_number, (int)std::cin.eof());
    std::printf("cerr=%d\n", (int)std::cerr.good());
    std::cout.flush();
    std::printf("cout=%d\n", (int)std::cout.good());
    return 0;
}
