// A class still being registered is a scope: its typedefs are known before its members, and a member's class
// template may ask for one -- libc++'s basic_format_context holds basic_format_args<basic_format_context>, whose
// __basic_format_arg_value reads `typename _Context::char_type'.
#include <cstdio>
template <class X> struct Args;
template <class O, class C> struct Ctx {
  using char_type = C;
  O out;
  Args<Ctx> args;
};
template <class X> struct Val {
  using CT = typename X::char_type;
  union { bool b; CT c; int i; };
};
template <class X> struct Args { Val<X> v; int kind; };
int main() {
  Ctx<int, char> c;
  c.args.v.c = 'q';
  c.args.kind = 2;
  std::printf("%d %d %d\n", (int) c.args.v.c, (int) sizeof(c.args.v.c), (int) sizeof(c.args.v));
  return 0;
}
