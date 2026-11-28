// GCC's alias of an Itanium name that the program does not define, refused in clang++'s words (1.6.58)
int g(int) __attribute__((alias("_Z7missingi")));
int main() { return 0; }
