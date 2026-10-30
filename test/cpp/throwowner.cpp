// refused (0.237, the defer rule): an owner live where a call may throw, outside every try, with no defer to free it --
// the string's constructor may throw std::bad_alloc, and p would leak
#include <string>
int main() {
  own int *p = new int(4);
  std::string s(1000, 'x');
  delete p;
  return (int) s.size() - 1000;
}
