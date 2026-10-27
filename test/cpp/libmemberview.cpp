// a struct whose view member is given a local string, returned: refused (0.217)
#include <string>
#include <string_view>
struct S { std::string_view sv; };
S mk() { std::string str = "a string long enough to live on the heap"; S s; s.sv = str; return s; }
int main() { return mk().sv.size() > 3 ? 0 : 1; }
