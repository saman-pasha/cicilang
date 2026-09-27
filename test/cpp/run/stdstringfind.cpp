#include <string>
#include <cstdio>
int main() {
    std::string s = "hello, world";
    printf("%d %d %d %d\n", (int) s.find_first_of("aeiou"), (int) s.find_first_not_of("hel"), (int) s.find_last_of("lo"), (int) s.find_last_not_of("dlr"));
    printf("%d\n", (int) (s.find_first_of('z') == std::string::npos));
    return 0;
}
