// a static member function with an ellipsis taken as a value: its thunk passes no argument past the named ones (1.6.38)
struct T { static int s(int a) { return a + 30; } static int s(int a, ...) { return a + 40; } };
int main() { int (*p)(int, ...) = T::s; return p(1, 2); }
