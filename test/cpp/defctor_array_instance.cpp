// AN ARRAY OF A TEMPLATE'S INSTANCE, its words the class's spelling and the bound (1.6.55, cpp_object_words/4)
template <class T> struct W { T t; };
struct X { X() = delete; };
int main() {
  W<X> a[2];
  return 0;
}
