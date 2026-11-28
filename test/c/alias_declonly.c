/* GCC's alias of a function that the unit declares and does not define, refused in clang's words (1.6.58) */
int decl_only(int);
int da(int) __attribute__((alias("decl_only")));
int main(void) { return 0; }
