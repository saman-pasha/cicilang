// A CONST OBJECT OF A TEMPLATE'S INSTANCE, whose words the instance's class spells with its const (1.6.55, cpp_object_words/4)
template <class T> struct W { T t; };
struct X { X() = delete; };
int main() {
  const W<X> w;
  return 0;
}
