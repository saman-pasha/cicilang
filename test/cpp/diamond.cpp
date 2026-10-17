// a diamond over TWO virtual bases (0.163): the paths H1 and H2 each hold A and W further in, and a class laid out here
// holds one virtual base at its end -- refused by name, where the Itanium layout of a class over one virtual base is had
struct A { int a = 1; };
struct W { int w = 2; };
struct Q1 : virtual A { int q1 = 3; };
struct R1 : virtual W { int r1 = 4; };
struct Q2 : virtual A { int q2 = 5; };
struct R2 : virtual W { int r2 = 6; };
struct H1 : Q1, R1 { int h1 = 7; };
struct H2 : Q2, R2 { int h2 = 8; };
struct D : H1, H2 { int d = 9; };
int main() { D d; return d.a + d.w + d.h1 + d.h2 - 18; }
