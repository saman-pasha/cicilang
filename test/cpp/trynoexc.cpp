// -fno-exceptions (0.193): the program's own `try' is refused, as clang++ -fno-exceptions refuses it
int f(int x) { return x; }
int main() {
    try {
        return f(0);
    } catch (...) {
        return 1;
    }
}
