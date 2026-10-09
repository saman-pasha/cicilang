// the C library through the C++ headers (0.117): <cstring> (strcpy, strcat, strlen, strcmp, strchr), <cstdlib> (qsort with a comparison
// function, atoi, strtol), <cctype> and <cstdint> -- the calls name the C functions under std::, which the headers declare in the global space too
#include <cstring>
#include <cstdlib>
#include <cctype>
#include <cstdio>
#include <cstdint>
static int cmp(const void *a, const void *b) { return *(const int *)a - *(const int *)b; }
int main() {
  char buf[32]; std::strcpy(buf, "Hello"); std::strcat(buf, ", World");
  std::printf("%zu %d %s\n", std::strlen(buf), std::strcmp(buf, "Hello"), std::strchr(buf, 'W'));
  int a[5] = {5, 3, 4, 1, 2}; std::qsort(a, 5, sizeof(int), cmp);
  std::printf("%d %d %d\n", a[0], a[4], std::atoi("123") + (int)std::strtol("77", nullptr, 10));
  std::printf("%d %d %c\n", std::isdigit('7') != 0, std::isalpha('1') != 0, std::toupper('q'));
  std::int64_t big = INT64_MAX; std::uint8_t u = 250; std::printf("%lld %d\n", (long long)big, u + 10);
  return 0;
}
