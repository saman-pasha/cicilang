// a diamond whose paths hold the virtual base FURTHER IN (0.160): P1 and P2 reach A through Q1 and Q2, and their `.nv'
// forms would need the Itanium layout of every class over a virtual base, A at the complete object's end; refused by name
struct A { int a = 1; };
struct Q1 : virtual A { int q1 = 2; };
struct Q2 : virtual A { int q2 = 3; };
struct P1 : Q1 { int p1 = 4; };
struct P2 : Q2 { int p2 = 5; };
struct D : P1, P2 { int d = 6; };
int main() { D d; return d.a + d.p1 + d.p2 - 10; }
