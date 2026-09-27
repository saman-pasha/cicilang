#include <cstdio>
#include <unordered_map>
int main() {
    std::unordered_map<int, int> m = {{1, 10}, {2, 20}, {3, 30}, {4, 40}};
    std::erase_if(m, [](const auto &kv) { return kv.first % 2 == 0; });
    printf("%d %d %d\n", (int) m.size(), (int) m.count(1), (int) m.count(2));
    return 0;
}
