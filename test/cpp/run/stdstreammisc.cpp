// the rvalue-stream getline (libc++'s `getline(basic_istream &&, basic_string &)' over a temporary istringstream), getline with a delimiter
// over an istringstream, and sync_with_stdio(false) before the first output: untried until 0.117, all three run
#include <iostream>
#include <sstream>
#include <string>
#include <cstdio>
int main() {
  std::string line;
  std::getline(std::istringstream("alpha beta\ngamma"), line);
  std::printf("[%s]\n", line.c_str());
  std::istringstream in("one,two,three");
  std::string part; int n = 0;
  while (std::getline(in, part, ',')) { std::printf("%d:%s ", ++n, part.c_str()); }
  std::printf("\n");
  std::ios::sync_with_stdio(false);
  std::cout << "synced " << 42 << "\n";
  std::cout.flush();
  return 0;
}
