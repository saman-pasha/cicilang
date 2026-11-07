// two members whose deduced results need the class's hidden friend: both wait for the friends, and both are declared
#include <cstdio>
struct It {
  int v;
  int operator*() const { return v * 2; }
  friend It operator+(It a, int n) { return It{a.v + n}; }
  decltype(auto) operator[](int n) const { return *(*this + n); }
  auto at(int n) const { return *(*this + n) * 10; }
  auto both(int n) const { return (*this)[n] + at(n); }
};
int main() { It i{1}; std::printf("%d %d %d\n", i[2], i.at(1), i.both(0)); return 0; }
