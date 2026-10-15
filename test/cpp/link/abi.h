// The C++ gate's ABI check (0.135): classes laid out as the Itanium ABI lays them cross a call between code that clang++
// built (abi_helper.cpp) and code that cicilang++ built (abi_main.cpp) -- a base's tail padding reused (D: d at 5, eight
// bytes, in a register), the table pointer first (VD: B at 8). The functions have C linkage: the program's own functions
// keep their own names here.
struct NP { NP(int a0, char c0) : a(a0), c(c0) {} int a; char c; };
struct D : NP { D(int a0, char c0, char d0) : NP(a0, c0), d(d0) {} char d; };
struct P { int b; };
struct VD : P { virtual int f() const { return 2; } int y; };
extern "C" {
D make_d(int a, char c, char d);
int sum_d(D v);
int sum_vd(const VD &v);
int size_d(void);
int size_vd(void);
}
