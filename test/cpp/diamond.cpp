// a diamond over a virtual base WITHOUT a table: nothing reaches the shared base from a path, so it is refused by name
struct A { int a; };
struct B : virtual A { int b; };
struct C : virtual A { int c; };
struct D : B, C { int d; };
int main() { D d; d.b = 1; return d.b; }
