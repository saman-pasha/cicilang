// std::vector's insert, erase and resize from libc++ 18's own bodies (0.62's not-done): the range insert through
// __split_buffer::__construct_at_end, the initializer-list insert, an erase of one and of a range, resize up and down,
// a fill insert.
#include <vector>
#include <cstdio>
int main() {
    std::vector<int> v{1, 2, 3};
    v.insert(v.begin() + 1, 9);
    v.insert(v.end(), {7, 8});
    v.erase(v.begin());
    v.resize(6);
    v.resize(3);
    v.erase(v.begin(), v.begin() + 1);
    v.insert(v.begin(), 2, 4);
    for (int x : v) printf("%d ", x);
    printf("| %d\n", (int) v.size());
    return 0;
}
