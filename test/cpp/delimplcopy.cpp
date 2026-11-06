// AN IMPLICITLY DELETED COPY CONSTRUCTOR (0.257): a unique_ptr copied, where the class declares a move constructor
#include <memory>
int main() { auto p = std::make_unique<int>(42); auto q = p; return *q; }
