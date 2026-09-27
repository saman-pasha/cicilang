// a closure holding a reference to a local leaves the function: refused by the safe part (borrow_escapes)
auto make(int n) { int x = n; auto f = [&x](int k) { return x + k; }; return f; }
int main() { auto f = make(3); return f(1); }
