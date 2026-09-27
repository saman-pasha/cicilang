#include <cstdio>
struct Tr { static bool eq(char a, char b) { return a == b; } static int twice(int x) { return 2 * x; } static void hello() { printf("hello\n"); } };
template <class P> int count_if_eq(const char *s, int n, char c, P pred) { int k = 0; for (int i = 0; i < n; i++) if (pred(s[i], c)) k++; return k; }
int apply(int (*f)(int), int x) { return f(x); }
int main() {
    printf("%d %d\n", count_if_eq("banana", 6, 'a', Tr::eq), apply(Tr::twice, 21));
    bool (*pe)(char, char) = Tr::eq; void (*ph)() = Tr::hello; ph();
    printf("%d %d\n", (int) pe('x', 'x'), Tr::twice(4));
    return 0;
}
