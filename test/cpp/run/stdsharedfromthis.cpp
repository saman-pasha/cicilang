#include <memory>
#include <cstdio>
struct Node : std::enable_shared_from_this<Node> {
    int v;
    Node(int v) : v(v) {}
    std::shared_ptr<Node> self() { return shared_from_this(); }
};
int main() {
    auto n = std::make_shared<Node>(4);
    auto m = n->self();
    printf("%d %ld %d\n", m->v, n.use_count(), (int) (m.get() == n.get()));
    std::weak_ptr<Node> w = n->weak_from_this();
    printf("%d\n", (int) w.expired());
    return 0;
}
