#include <iostream>
#include <sstream>
#include <syncstream>
// C++20's <syncstream>: an osyncstream's output reaches the wrapped stream when it is destroyed or emits, a temporary's
// at the end of its statement; get_wrapped; a wide one
int main() {
  std::ostringstream os;
  {
    std::osyncstream s(os);
    s << "one " << 1 << '\n';
    s << "two " << 2.5 << '\n';
    std::cout << "before: [" << os.str() << "] " << (s.get_wrapped() == os.rdbuf()) << '\n';
  }
  std::cout << "after: [" << os.str() << "]\n";
  {
    std::osyncstream s(std::cout);
    s << "synced " << 42 << '\n';
    s.emit();
    s << "tail\n";
  }
  std::osyncstream(std::cout) << "temporary " << 7 << '\n';
  std::wostringstream ws;
  {
    std::wosyncstream w(ws);
    w << L"wide " << 3;
  }
  std::cout << ws.str().size() << '\n';
  return 0;
}
