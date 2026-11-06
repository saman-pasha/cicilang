// A DEFAULTED COPY CONSTRUCTOR WHOSE PART DOES NOT COPY IS DEFINED AS DELETED (0.257; [class.copy.ctor]/10): its call is refused, in clang's words
#include <memory>
struct DefCopy { std::unique_ptr<int> p; DefCopy() = default; DefCopy(const DefCopy &) = default; DefCopy(DefCopy &&) = default; };
int main() {
  DefCopy a;
  DefCopy b = a;
  return b.p ? 1 : 0;
}
