// Pointers to member functions cross a call between code that clang++ built (memptr_helper.cpp) and code that cicilang++
// built (memptr_main.cpp) (0.161): `{ ptr, adj }' as each machine's ABI has it -- x86-64's Itanium form (the virtual mark in
// ptr, 1 + the slot's offset) and arm64's ARM form (the mark in adj, adj twice the adjustment) -- through a second base's
// adjustment, a virtual member, an override of a second base's virtual, and the null pointer. C linkage: the program's
// own functions keep their own names here.
struct A { int a = 1; virtual int va() { return 10 + a; } int na() { return 20 + a; } };
struct B { int b = 2; virtual int vb() { return 30 + b; } int nb() { return 40 + b; } };
struct C : A, B { int c = 3; int vb() override { return 50 + c; } int nc() { return 60 + c; } };
typedef int (C::*CM)();
extern "C" {
int call_cm(C *p, CM m);   // the helper calls a pointer that main made
CM get_cm(int k);          // the helper makes a pointer that main calls: 0 va, 1 na, 2 vb, 3 nb (B's, converted to C's), 4 nc, else null
int is_null(CM m);         // the helper tests a pointer that main made
}
