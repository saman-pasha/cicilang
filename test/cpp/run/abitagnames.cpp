// 0.236: GCC's `abi_tag' on a class is spelled after its name, `B <len><tag>' sorted -- a nested class, a template's
// instance, a pointer to one, libc++'s views (`B10llvm18_nua'); a template argument that is an address `XadL_Z ... EE',
// a reference's object `L_Z ... E', a function by its encoding, a null pointer `L <type> 0E'
#include <cstdio>
#include <ranges>
#include <typeinfo>
#define P(x) std::printf("%s\n", typeid(x).name())
struct [[gnu::abi_tag("x")]] Outer { struct In {}; };
template <class T> struct [[gnu::abi_tag("t")]] Tg {};
namespace ns { struct __attribute__((abi_tag("q", "a"))) Q2 { int v; }; int h; }
template <int *Pt> struct Q {};
template <int &R> struct QR {};
template <void (*F)()> struct W {};
int g;
void fn() {}
int main() {
  P(Outer); P(Outer::In); P(Tg<int>); P(ns::Q2); P(std::ranges::single_view<int>); P(Tg<Outer> *);
  P(Q<&g>); P(Q<&ns::h>); P(QR<g>); P(W<fn>); P(W<&fn>); P(Q<nullptr>);
  return 0;
}
