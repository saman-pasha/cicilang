// a lambda with an ellipsis converts to no pointer to a function, as clang++ has it (1.6.58)
int main() {
  auto sum = [](int n, ...) { return n; };
  int (*p)(int) = sum;
  return p(1);
}
