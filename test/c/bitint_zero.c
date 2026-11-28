/* an unsigned _BitInt of no bit, in a cast's type name, refused in clang's words at its line (1.6.57; C23 6.7.2.1/3) */
int main(void) {
  return (int) (unsigned _BitInt(0)) 0;
}
