// A conversion function declared through a class typedef and defined out of its class through the class's name.
#include <cstdio>
template <class T> struct Box { T v; };
template <class T> struct Expr {
  typedef T result_type;
  T a, b;
  operator Box<result_type>() const;
};
template <class T> Expr<T>::operator Box<typename Expr::result_type>() const { return Box<T>{a + b}; }
int main() { Expr<int> e{20, 22}; Box<int> b = e; std::printf("%d\n", b.v); return 0; }
