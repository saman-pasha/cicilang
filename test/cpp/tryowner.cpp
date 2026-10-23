// A handler is entered from any point of its try's body (0.193): `use' may throw after the body freed the owner, and
// the handler's free of it would free it twice -- refused (a defer frees it once on every exit, unwinding included)
#include <cstdlib>
#include <vector>

int use(const std::vector<int> &v, int i) { return v.at(i); }

int main() {
    std::vector<int> v{1, 2, 3};
    own int *p = (own int *) malloc(sizeof(int));
    *p = 1;
    try {
        int k = use(v, *p);
        free(p);
        return use(v, k) - 3;
    } catch (...) {
        free(p);
    }
    return 1;
}
