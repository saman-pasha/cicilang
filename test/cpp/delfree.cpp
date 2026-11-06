// A CALL OF A DELETED FUNCTION IS REFUSED WITH ITS REASON (0.257; C++26's = delete("why"), P2573): it was `not lowered yet: undeclared(g)'
void g(int) = delete("call g(long)");
void g(long) {}
int main() { g(1); return 42; }
