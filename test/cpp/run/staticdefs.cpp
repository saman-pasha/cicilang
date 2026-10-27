// static data members defined by their class or out of it (0.218): a class template's defined out of it with no initializer
// -- a scalar, an array and a library type, zero or default-constructed in each instance --, an inline one of a library type
// in a class template, the program's class with a constructor and a destructor inline with no initializer, a class over a
// library member, inline arrays and two declarators, and out-of-class definitions whose types name the class's own words
#include <cstdio>
#include <map>
#include <string>
#include <vector>
template <class T> struct R { static int count; static T pair[2]; static std::string name; static inline std::vector<T> items; };
template <class T> int R<T>::count;
template <class T> T R<T>::pair[2];
template <class T> std::string R<T>::name;
struct C { int v; C() : v(42) {} ~C() { std::puts("bye"); } };
struct P { std::map<int, int> m; };
struct K {
  static constexpr int N = 3;
  using size_type = unsigned long;
  struct In { int a; };
  static int arr[N];
  static size_type count;
  static In in;
  static inline C c;
  static inline P p;
  static inline int a[3];
  static inline int b, d;
};
int K::arr[N] = {1, 2, 3};
K::size_type K::count = 5;
K::In K::in = {7};
int main() {
  R<int>::count += 2;
  R<long>::pair[1] = 7;
  R<int>::name = "ri";
  R<int>::items.push_back(3);
  R<int>::items.push_back(4);
  R<long>::items.push_back(9);
  std::printf("%d %d %ld %ld %s %zu\n", R<int>::count, R<long>::count, R<long>::pair[0], R<long>::pair[1], R<int>::name.c_str(), R<long>::name.size());
  std::printf("%zu %d %zu\n", R<int>::items.size(), R<int>::items[1], R<long>::items.size());
  K::p.m[3] = 9;
  K::a[1] = 5;
  K::d = 2;
  std::printf("%d %lu %d %zu %d %zu %d %d %d %d\n", K::arr[2], K::count, K::in.a, sizeof K::arr / sizeof K::arr[0], K::c.v, K::p.m.size(), K::a[0], K::a[1], K::b, K::d);
  return 0;
}
