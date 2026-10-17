// the layout of libc++'s streams over their virtual base basic_ios (0.163): each stream's size and where its basic_ios lies,
// as clang lays them; a program class over a stream, its member after the stream's own and before the virtual base
#include <cstdio>
#include <fstream>
#include <sstream>
#include <iostream>
template <class S> static long ios_at(S &s) { return (const char *) static_cast<std::ios *>(&s) - (const char *) &s; }
template <class S> static long os_at(S &s) { return (const char *) static_cast<std::ostream *>(&s) - (const char *) &s; }
struct Log : std::ostringstream { int n = 7; };
struct File : std::ofstream { long k = 9; File() : std::ofstream() {} };
int main() {
  std::ofstream of; std::ifstream inf; std::fstream f; std::ostringstream os; std::istringstream is; std::stringstream ss;
  Log lg; File fl;
  std::printf("ofstream %zu %ld\n", sizeof of, ios_at(of));
  std::printf("ifstream %zu %ld\n", sizeof inf, ios_at(inf));
  std::printf("fstream %zu %ld %ld\n", sizeof f, ios_at(f), os_at(f));
  std::printf("ostringstream %zu %ld\n", sizeof os, ios_at(os));
  std::printf("istringstream %zu %ld\n", sizeof is, ios_at(is));
  std::printf("stringstream %zu %ld %ld\n", sizeof ss, ios_at(ss), os_at(ss));
  std::printf("Log %zu %ld %ld\n", sizeof lg, (long) ((const char *) &lg.n - (const char *) &lg), ios_at(lg));
  std::printf("File %zu %ld %ld\n", sizeof fl, (long) ((const char *) &fl.k - (const char *) &fl), ios_at(fl));
  lg << "log " << lg.n; ss << 5 << ' ' << 6; int a, b; ss >> a >> b;
  std::printf("use %s %d %d %d\n", lg.str().c_str(), a, b, (int) f.is_open());
  return 0;
}
