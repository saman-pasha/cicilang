#include <cstdio>
#include <cstddef>
struct Msg { constexpr std::size_t size() const { return 3; } constexpr const char *data() const { return "msg"; } };
static_assert(true, Msg{});
int main() { std::puts("ok"); }
