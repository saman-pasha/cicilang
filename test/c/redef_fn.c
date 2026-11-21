/* A FUNCTION DEFINED TWO TIMES AT FILE SCOPE (1.6.7; C17 6.9/5): refused at the second one's line, where LLVM's
   parser refused the IR at no line */
static int f(void) { return 1; }
static int f(void) { return 2; }
int main(void) { return f(); }
