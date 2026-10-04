// A hidden friend of a class template's nested class (C++20): its parameter types read in the class, and its
// `const It &' taking no other class -- `Sub<Walk<int>::It>' is false, as `views::iota''s iterator `operator-' never
// made two filter iterators a sized sentinel
#include <cstdio>
template <class T> struct Count {
  struct It {
    T v;
    explicit It(T x) : v(x) {}
    friend T operator-(const It &a, const It &b) { return a.v - b.v; }
  };
};
template <class T> struct Walk {
  struct It { T *p; };
};
template <class T> concept Sub = requires(const T &a, const T &b) { a - b; };
int main() {
  Count<int>::It a(7), b(3);
  std::printf("%d\n", a - b);
  std::printf("%d %d\n", (int) Sub<Count<int>::It>, (int) Sub<Walk<int>::It>);
  return 0;
}
