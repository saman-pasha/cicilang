// -fno-exceptions (0.193): the program's own `throw' is refused, as clang++ -fno-exceptions refuses it
int f(int x) {
    if (x < 0)
        throw x;
    return x;
}
int main() { return f(1) - 1; }
