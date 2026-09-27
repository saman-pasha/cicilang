#include <unordered_set>
#include <cstdio>
int main() {
    std::unordered_set<int> s{1, 2, 3, 4, 5, 6};
    auto n = std::erase_if(s, [](int x) { return x % 2 == 0; });
    int sum = 0; for (int x : s) sum += x;
    printf("%d %d %d\n", (int) n, (int) s.size(), sum);
    return 0;
}
