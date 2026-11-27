// C++'s type name takes no storage class: a compound literal's `static', in clang++'s words (1.6.39)
int *keep() {
  return &(static int){ 7 };
}
int main() { return *keep(); }
