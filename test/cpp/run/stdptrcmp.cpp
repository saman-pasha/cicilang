#include <cstdio>
#include <memory>
int main() {
    std::unique_ptr<int> a(new int(1)), b(new int(2)), e;
    printf("%d %d %d %d\n", (int) (a == b), (int) (a != b), (int) (e == nullptr), (int) (a != nullptr));
    printf("%d\n", (int) ((a < b) != (b < a)));
    std::shared_ptr<int> s = std::make_shared<int>(3), t = s;
    printf("%d %d %d\n", (int) (s == t), (int) (s != nullptr), (int) s.owner_before(t));
    std::weak_ptr<int> w = s;
    printf("%d %d\n", (int) w.owner_before(t), (int) t.owner_before(w));
    return 0;
}
