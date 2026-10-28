// identifiers past ASCII in C++ (0.221; [lex.name]: UAX #31's XID_Start first and XID_Continue after): a Latin, a Greek and a
// CJK name, a combining acute and a middle dot after a letter, a name written with a universal character name, a macro named
// past ASCII, and a no-break space between two tokens a blank, as clang reads it
#include <cstdio>
#define ΔT 4
int café = 1;
int x́ = 2;
double π = 3.0;
int 変数 = 5;
int a·b = 6;
int main() {
  int n = 7;
  std::printf("%d %d %g %d %d %d %d %d\n", café, x́, π, 変数, a·b, ΔT, caf\u00e9, n);
  return 0;
}
