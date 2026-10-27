// a local's address stored in a pointer member through a reference parameter: refused (0.217)
struct S { int *p; };
void put(S &s) { int x = 1; s.p = &x; }
int main() { S s; put(s); return 0; }
