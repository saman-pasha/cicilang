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
// a file stream's basic_filebuf holds two mbstate_t, the C library's: 8 bytes on glibc, 128 on macOS -- what is past glibc's
// is taken off its size and offsets, so the layout reads the same on both (0.250)
static const long MB = 2 * (long) sizeof(std::mbstate_t) - 16;
int main() {
  std::ofstream of; std::ifstream inf; std::fstream f; std::ostringstream os; std::istringstream is; std::stringstream ss;
  Log lg; File fl;
  std::printf("ofstream %ld %ld\n", (long) sizeof of - MB, ios_at(of) - MB);
  std::printf("ifstream %ld %ld\n", (long) sizeof inf - MB, ios_at(inf) - MB);
  std::printf("fstream %ld %ld %ld\n", (long) sizeof f - MB, ios_at(f) - MB, os_at(f));
  std::printf("ostringstream %zu %ld\n", sizeof os, ios_at(os));
  std::printf("istringstream %zu %ld\n", sizeof is, ios_at(is));
  std::printf("stringstream %zu %ld %ld\n", sizeof ss, ios_at(ss), os_at(ss));
  std::printf("Log %zu %ld %ld\n", sizeof lg, (long) ((const char *) &lg.n - (const char *) &lg), ios_at(lg));
  std::printf("File %ld %ld %ld\n", (long) sizeof fl - MB, (long) ((const char *) &fl.k - (const char *) &fl) - MB, ios_at(fl) - MB);
  lg << "log " << lg.n; ss << 5 << ' ' << 6; int a, b; ss >> a >> b;
  std::printf("use %s %d %d %d\n", lg.str().c_str(), a, b, (int) f.is_open());
  return 0;
}
