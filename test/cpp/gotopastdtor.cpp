// A goto over the declaration of a local with a destructor (0.138): ill-formed C++ ([stmt.dcl]/3), and refused as clang++
// refuses it -- the destructor, a defer of the desugaring, would run at the block's end over a string never built.
#include <string>
int f(int k) {
  {
    if (k) goto out;
    std::string s = "x";
  out:
    ;
  }
  return 0;
}
int main() { return f(0); }
