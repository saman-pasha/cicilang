/* ccllib phase 1d (CCLLIB.md): <iostream>, <iomanip>, <fstream> and <stringstream> over C's stdio, built by cicilang as
   C and by cicilang++ as C++, and compared with iostreams.cpp over std::, which clang++ builds. The three print
   iostreams.expect. */
#include <stdio.h>
#include <stdbool.h>
#include <iostream.pl>
#include <iomanip.pl>
#include <fstream.pl>
#include <stringstream.pl>

int main(void) {
    cout << "hello";
    cout << endl;
    cout << 42;
    cout << endl;
    cout << -7;
    cout << endl;
    cout << 3.5;
    cout << endl;
    setprecision(cout, 4);
    cout << "pi=";
    cout << 3.14159265;
    cout << endl;
    setw(cout, 6);
    setfill(cout, '0');
    cout << 42;
    cout << endl;
    hex(cout);
    cout << 255;
    cout << endl;
    dec(cout);
    bool yes = true;
    boolalpha(cout);
    cout << yes;
    cout << endl;
    noboolalpha(cout);
    cout << yes;
    cout << endl;
    put(cout, 'X');
    cout << endl;
    fixed(cout);
    setprecision(cout, 2);
    cout << "fixed=";
    cout << 3.14159;
    cout << endl;

    fstream<char> f;
    open(f, "/tmp/ccllib_iostreams.txt", "w");
    f << "line1";
    f << endl;
    f << 7;
    f << endl;
    close(f);
    open(f, "/tmp/ccllib_iostreams.txt", "r");
    char buf[64];
    getline(f, buf, 64);
    int file_number = 0;
    f >> file_number;
    printf("file=%s %d\n", buf, file_number);
    close(f);

    stringstream<> s;
    s << "abc";
    s << 42;
    cout << "sstr=";
    cout << str(s);
    cout << endl;
    clear(s);
    s << "12 3.5";
    int a = 0;
    double b = 0;
    s >> a;
    s >> b;
    printf("parsed=%d %g\n", a, b);

    int cin_number = 0;
    cin >> cin_number;
    printf("cin=%d eof=%d\n", cin_number, eof(cin));
    printf("cerr=%d\n", good(cerr));
    flush(cout);
    printf("cout=%d\n", good(cout));
    return 0;
}
