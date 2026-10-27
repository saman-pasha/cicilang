// the address of a local view of a static string, returned: refused (0.217; it answered what the view views)
#include <string>
#include <string_view>
static std::string gs = "a string long enough to live on the heap";
std::string_view *f() { std::string_view sv = gs; return &sv; }
int main() { return f() != nullptr ? 0 : 1; }
