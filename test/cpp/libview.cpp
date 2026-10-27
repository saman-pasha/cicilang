// a view of a local string leaves the function: refused (borrow_escapes, 0.216)
#include <string>
#include <string_view>
std::string_view k() { std::string s = "a string long enough to live on the heap"; return s; }
int main() { return k().size() > 3 ? 0 : 1; }
