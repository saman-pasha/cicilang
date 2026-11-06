// A DEFAULTED COPY ASSIGNMENT WHOSE PART DOES NOT ASSIGN IS DEFINED AS DELETED (0.257; [class.copy.assign]/7): its call is refused, in clang's words
#include <memory>
struct DA { std::unique_ptr<int> p; DA() = default; DA &operator=(const DA &) = default; };
int main() {
  DA a, b;
  a = b;
  return a.p ? 1 : 0;
}
