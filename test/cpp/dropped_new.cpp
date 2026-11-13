// NEW MEMORY THROWN AWAY (0.309): C++'s new-expression as a statement leaks its block, refused, as malloc's is
int main() {
    new int(3);
    return 0;
}
