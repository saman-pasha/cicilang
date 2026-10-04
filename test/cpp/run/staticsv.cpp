// a member function called on a static data member of a library class type, Words::yes.size()
#include <cstdio>
#include <string_view>
struct Words { static constexpr std::string_view yes{"true"}; };
int main() { std::printf("%zu\n", Words::yes.size()); return 0; }
