// `new X(X())' OF A CLASS WHOSE DESTRUCTOR IS DELETED (1.6.56): clang++ binds the temporary, and refuses it as 1.6.55 does
struct X { int k = 4; ~X() = delete; };
int main() {
  X *p = new X(X());
  int r = p->k;
  return r;
}
