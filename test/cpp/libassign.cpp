// a view assigned a local string leaves the function: refused (borrow_escapes, 0.216)
#include <string>
#include <string_view>
std::string_view f() { std::string s = "a string long enough to live on the heap"; std::string_view sv; sv = s; return sv; }
int main() { return f().size() > 3 ? 0 : 1; }
