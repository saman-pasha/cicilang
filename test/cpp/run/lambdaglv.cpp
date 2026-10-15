// A lambda made in a member function of a NESTED class sees that class's statics, and its `if constexpr' keeps one
// branch; its written `-> auto &&' result is deduced as a function's is (join_view's iterator: `[this]() -> auto && {
// if constexpr (__ref_is_glvalue) return *__get_outer(); else ... }()').
#include <type_traits>
#include <utility>
#include <vector>
#include <cstdio>
template <class V> struct View {
  struct Iter {
    V *base;
    static constexpr bool glv = std::is_reference_v<decltype(*std::declval<V &>().begin())>;
    int get() {
      auto &&inner = [this]() -> auto && {
        if constexpr (glv) return *base->begin();
        else return base->missing();
      }();
      return inner;
    }
    int get2() {
      if constexpr (glv) return base->back();
      else return base->missing();
    }
  };
};
int main() { std::vector<int> v{7, 8}; View<std::vector<int>>::Iter it{&v}; std::printf("%d\n", it.get() * 10 + it.get2()); return 0; }
