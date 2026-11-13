// NEW MEMORY THROWN AWAY (0.309): C++'s new[] as a statement leaks its block through the library's operator new[],
// refused as new is
int main() {
    new int[4];
    return 0;
}
