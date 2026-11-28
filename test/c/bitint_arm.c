/* a _BitInt past 128 bits, which x86-64 takes and both arm64 machines refuse, BITINT_MAXWIDTH 128 there (1.6.57) */
struct big { int k;
  unsigned _BitInt(129) v; };
int main(void) { struct big b = { 1, 2 }; return b.k - (int) b.v + 1; }
