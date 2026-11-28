/* GCC's alias of a name that nothing defines, refused in clang's words at its line (1.6.58) */
int g(int) __attribute__((alias("missing")));
int main(void) { return 0; }
