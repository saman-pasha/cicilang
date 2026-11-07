template <class T> T a6(T t) { return t; }
static_assert(a6(1) == 1);
int main() { return a6(1); }
