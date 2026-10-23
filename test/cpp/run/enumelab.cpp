// AN ENUM NAMED BY ITS ELABORATED TYPE SPECIFIER (0.194): `enum E e;' and `enum F f;' of an enum with a FIXED underlying
// type are the base's size, a struct's member too; they were an int's 4 bytes
extern "C" int printf(const char *, ...);
enum class E : char { A = 3 };
enum F : long { X = 1, Y = 1L << 40 };
enum G { P, Q };
struct S { enum E e; enum F f; };
int main() {
  enum E e = E::A; enum F f = X; enum G g = Q;
  S s{E::A, Y};
  printf("%d %d %d %d %d %d\n", (int) sizeof(e), (int) sizeof(f), (int) sizeof(X), (int) sizeof(g), (int) sizeof(S), (int) e);
  printf("%ld %d\n", (long) s.f, (int) s.e);
  return 0;
}
