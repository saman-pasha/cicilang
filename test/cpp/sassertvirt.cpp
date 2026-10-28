// a class template instance's false static assertion is an error, though a probe made the instance and caught the throw (0.221):
// the instance was left half made, and its destructor, emitted later, read a vtable nothing declared
#include <cstdio>
template <class T> struct B { static_assert(sizeof(T) == 1, "B needs a char"); virtual ~B() {} };
template <class C, class T> struct O : B<T> { };
int main() {
  O<wchar_t, wchar_t> o;
  std::printf("%d\n", (int) sizeof o);
}
