// A TEMPLATE'S INSTANCE, by its name as clang++ spells it (1.6.55)
template <class T> struct W { T t; };
struct X { X() = delete; };
int main() {
  W<X> w;
  return 0;
}
