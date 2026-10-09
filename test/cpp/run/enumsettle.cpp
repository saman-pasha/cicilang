// an enum's underlying type named through a TYPEDEF of std::underlying_type<...>::type (0.117) -- libc++ 18's <atomic> writes
// `enum class memory_order : __memory_order_underlying_t' so; the typedef is settled where the enum is first named and output, since the lowering
// builds the table again and reads the enum's size through it
#include <type_traits>
#include <cstdio>
enum __legacy { __mo_a, __mo_b };
typedef std::underlying_type<__legacy>::type __under_t;
enum class MO : __under_t { a = __mo_a, b = __mo_b };
inline constexpr auto mo_b = MO::b;
int store(int *p, MO m = mo_b) { return (int)static_cast<__under_t>(m) + *p; }
int main() { int x = 1; std::printf("%d %d\n", store(&x), store(&x, MO::a)); return 0; }
