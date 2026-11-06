// AN IMPLICITLY DELETED COPY ASSIGNMENT (0.257): a = b of two unique_ptrs moved from b
#include <memory>
int main() { std::unique_ptr<int> a, b; a = b; return 0; }
