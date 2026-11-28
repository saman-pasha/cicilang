/* a signed _BitInt of one bit, refused in clang's words at its line (1.6.57; C23 6.7.2.1/3) */
int main(void) {
  signed _BitInt(1) b = 0;
  return (int) b;
}
