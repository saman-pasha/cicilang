// a member that keeps a view parameter in a view member; the object, given a local string, returned: refused (0.217)
#include <string>
#include <string_view>
struct V { std::string_view sv; void set(std::string_view v) { sv = v; } };
V mk() { std::string s = "a string long enough to live on the heap"; V w; w.set(s); return w; }
int main() { return mk().sv.size() > 3 ? 0 : 1; }
