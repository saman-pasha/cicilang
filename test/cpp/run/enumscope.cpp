// A qualified enumerator takes the value its own enum gives it, whatever another enum holds under the same enumerator name:
// file-scope enum classes, a namespace's, enums nested in two classes, a nested enum named bare by a member that is
// declared before it (libc++ 21's grapheme cluster rules switch over one whose Consonant is also another enum's), the
// instance of a class template.
#include <cstdio>

enum class A { X, Y };
enum class B { Y = 7, X = 5 };
namespace n {
enum class C { Z = 11, X = 13 };
enum Plain { P = 3, Q };
}  // namespace n

struct S1 {
  enum class D { X = 21, W = 22 };
  enum E { P = 30, Q };
  int f(D d) {
    switch (d) {
    case D::X: return 1;
    case D::W: return 2;
    }
    return 0;
  }
  static int h() { return (int)D::X + (int)E::Q + (int)P; }
};
struct T1 {
  enum class D { X = 41, W = 42 };
  static int h() { return (int)D::X + (int)D::W; }
};

namespace ns {
enum class prop : unsigned char { none, Consonant, Extend, Linker };
}
struct Cluster {
  int eval(ns::prop p) {
    if (p == ns::prop::none) return -1;
    switch (s_) {
    case state::Consonant:
      if (p == ns::prop::Extend) return 0;
      if (p == ns::prop::Linker) {
        s_ = state::Linker;
        return 1;
      }
      return 2;
    case state::Linker:
      if (p == ns::prop::Extend) return 3;
      if (p == ns::prop::Consonant) {
        s_ = state::Consonant;
        return 4;
      }
      return 5;
    }
    return -2;
  }
  enum class state { Consonant, Linker };
  state s_ = state::Consonant;
};

template <class T>
struct Box {
  enum class kind { Small = 1, Big = 9 };
  int rank(kind k) {
    switch (k) {
    case kind::Small: return sizeof(T);
    case kind::Big: return 10 * sizeof(T);
    }
    return 0;
  }
};

int g(B b) {
  switch (b) {
  case B::X: return 100;
  case B::Y: return 200;
  }
  return 0;
}

int main() {
  std::printf("%d %d %d %d\n", (int)A::X, (int)B::X, (int)B::Y, (int)n::C::X);
  std::printf("%d %d %d %d\n", g(B::X), g(B::Y), (int)A::Y, (int)n::Plain::Q);
  S1 s;
  std::printf("%d %d %d %d\n", s.f(S1::D::X), s.f(S1::D::W), (int)S1::D::W, S1::h());
  std::printf("%d %d %d\n", T1::h(), (int)T1::D::X, (int)T1::D::W);
  Cluster c;
  std::printf("%d %d %d %d %d\n", c.eval(ns::prop::Linker), c.eval(ns::prop::Extend), c.eval(ns::prop::Consonant), c.eval(ns::prop::none), c.eval(ns::prop::Extend));
  Box<int> bi;
  Box<char> bc;
  std::printf("%d %d %d %d\n", bi.rank(Box<int>::kind::Small), bi.rank(Box<int>::kind::Big), bc.rank(Box<char>::kind::Small), bc.rank(Box<char>::kind::Big));
  return 0;
}
