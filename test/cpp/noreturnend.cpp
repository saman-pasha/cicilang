// THE END OF A [[noreturn]] FUNCTION THAT A PATH REACHES (1.6.17): a throw on one branch alone, refused in clang++'s words
[[noreturn]] void check(int x) {
    if (x)
        throw 1;
}
int main() { try { check(1); } catch (int) { } return 0; }
