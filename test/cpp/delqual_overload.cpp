// A QUALIFIED CALL THAT CHOOSES A DELETED OVERLOAD (1.6.55): overload resolution, so clang++'s words name the function
void h(int) = delete;
void h(double) {}
int main() {
  ::h(1);
  return 0;
}
