// C++20's constrained algorithms on libc++: ranges::sort over a vector, ranges::find, ranges::count_if with a lambda.
#include <algorithm>
#include <cstdio>
#include <ranges>
#include <vector>
int main() {
    std::vector<int> v = {5, 3, 8, 1, 9, 2};
    std::ranges::sort(v);
    for (int x : v) std::printf("%d ", x);
    std::printf("\n");
    auto it = std::ranges::find(v, 8);
    std::printf("%d %d\n", (int)(it - v.begin()), (int) std::ranges::count_if(v, [](int x) { return x > 4; }));
    return 0;
}
