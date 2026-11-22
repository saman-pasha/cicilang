// A RETURN OF A MEMBER FUNCTION DECLARED [[noreturn]] (1.6.17), refused at its line in clang++'s words: `fail', not its
// class's name before it
struct Guard {
    [[noreturn]] void fail(int c) {
        if (c) return;
        throw c;
    }
};
int main() { Guard g; g.fail(0); }
