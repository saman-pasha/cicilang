// wide streams: std::wcout, std::wostringstream and std::wistringstream over wchar_t
#include <iostream>
#include <sstream>
#include <string>
int main() {
  std::wcout << L"wide " << 42 << L' ' << 2.5 << L'\n';
  std::wostringstream o;
  o << L"x=" << 7 << L", y=" << -3;
  std::wcout << o.str() << L" (" << o.str().size() << L")" << std::endl;
  std::wistringstream in(L"10 20 word");
  int a = 0, b = 0;
  std::wstring w;
  in >> a >> b >> w;
  std::wcout << a + b << L' ' << w << L'\n';
  return 0;
}
