// namespace aliases ([namespace.alias]) where two of the program's namespaces declare the same names: at file scope, in a
// namespace with a relative target, in a block (a block-declaration, which the reader refused until 1.6.21), an alias of an
// alias, a type, a variable and a using-directive through one, and one alias name with two targets in two blocks. Until
// 1.6.21 an alias was an item that did nothing, and `z::v()' called the bare v, a::in's: a silent wrong answer
#include <cstdio>
namespace a { namespace in { struct S { int k = 1; }; constexpr int v() { return 1; } int n = 10; } }
namespace b { namespace in { struct S { int k = 2; }; constexpr int v() { return 2; } int n = 20; } }
namespace fb = b::in;
namespace gb = fb;
namespace b { namespace rel = in; inline int viarel() { return rel::v(); } }
int one() { namespace x = a::in; x::S s; return s.k * 100 + x::v() * 10 + x::n / 10; }
int two() { namespace x = b::in; x::S s; return s.k * 100 + x::v() * 10 + x::n / 10; }
int three() { using namespace fb; return v() * 10 + n / 10; }
constexpr int blk() { namespace x = b::in; return x::v() * 10 + fb::v(); }
int run() { namespace y = a::in; namespace z = b::in; return y::v() * 100 + z::v() * 10 + fb::v(); }
int main() {
  static_assert(blk() == 22, "the block's alias");
  gb::S s;
  std::printf("%d %d %d %d %d %d\n", one(), two(), gb::v(), s.k, fb::n, b::viarel());
  std::printf("%d %d %d\n", three(), blk(), run());
  return 0;
}
