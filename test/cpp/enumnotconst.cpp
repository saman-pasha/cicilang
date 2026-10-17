// An enumerator whose initializer folds nowhere is refused by name (0.160), as clang++ refuses it ("not an integral constant
// expression"): it took the value after the one before it, silently
int seed();
enum Bad { A = 1, B = seed(), C };
int main() { return C; }
