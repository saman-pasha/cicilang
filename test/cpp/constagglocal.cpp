struct A { int x, y; };
int f() { const A a = {3, 4}; static_assert(a.x == 3); return a.y; }
int main() { return f(); }
