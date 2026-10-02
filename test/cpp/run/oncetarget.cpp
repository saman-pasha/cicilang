// a compound assignment evaluates its left operand once ([expr.ass]/6): a call returning a reference, counted
#include <cstdio>
static int calls = 0;
static int cell = 10;
int &slot() { calls++; return cell; }
struct Acc { int v = 0; Acc &self() { calls++; return *this; } };
int main() {
  slot() += 5;
  slot() *= 2;
  ++slot();
  slot()++;
  Acc a; a.self().v += 3;
  std::printf("%d %d %d\n", cell, a.v, calls);
  return 0;
}
