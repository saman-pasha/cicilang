// An operator the program writes for an unscoped enum serves two enumerators too ([over.match.oper]/3; 0.112): an
// enumerator's type is its enum, so `Red | Green' calls the program's operator| where the built-in would answer 3
#include <cstdio>
enum Color { Red = 1, Green = 2, Blue = 4 };
Color operator|(Color a, Color b) { return Color(int(a) | int(b) | 8); }
bool operator==(Color a, int b) { return (int) a + 100 == b; }
enum Size { Small, Large };
int main() {
  Color c = Red | Green;
  Color d = c | Blue;
  Color e = Blue | c;
  int plain = Small + Large;
  std::printf("%d %d %d %d %d\n", (int) c, (int) d, (int) e, plain, (int) (Red == 101));
  return 0;
}
