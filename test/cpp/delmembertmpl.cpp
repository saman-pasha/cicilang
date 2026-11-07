struct S { template <class T> void f(T) = delete; void f(int) {} };
int main() { S s; s.f(1.5); }
