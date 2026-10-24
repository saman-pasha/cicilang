#include <cstdio>
#include <locale>
// a library facet the program makes, installed in a locale and deleted by the library: locale's constructor template
// reads the facet's shipped static `id' (0.202: a global of no type) and the facet's deleting destructor frees it
int main() {
  std::locale loc(std::locale::classic(), new std::numpunct<char>);
  std::printf("%c\n", std::use_facet<std::numpunct<char>>(loc).decimal_point());
  return 0;
}
