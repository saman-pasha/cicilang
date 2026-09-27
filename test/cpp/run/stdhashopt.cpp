#include <cstdio>
#include <optional>
int main() {
    std::optional<int> o = 5, e;
    std::hash<std::optional<int>> h;
    printf("%d %d\n", (int) (h(o) == std::hash<int>{}(5)), (int) (h(e) != 0 || h(e) == 0));
    return 0;
}
