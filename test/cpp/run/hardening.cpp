// LIBC++'S FAST HARDENING MODE (1.6.10, .flags: -D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST): each assertion is
// `__builtin_verbose_trap("libc++", message)' in libc++ 21 and 22 and `((void)message, __builtin_trap())' in libc++ 18,
// and both were `undeclared': every program that indexed a vector was refused. An access in bounds works as it did; one
// out of bounds stops a child of its own, whose handler of the trap's signal leaves with a status of its own.
#include <array>
#include <csignal>
#include <cstdio>
#include <list>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

static void on_trap(int) { _exit(7); }

static int stopped(int k) {
  pid_t c = fork();
  if (c == 0) {
    std::signal(SIGILL, on_trap); std::signal(SIGTRAP, on_trap);
    std::vector<int> v{1, 2, 3}; std::vector<int> e; std::string s = "abc"; std::string_view sv = s;
    std::array<int, 3> a{4, 5, 6}; std::list<int> l; std::optional<int> o; std::span<int> sp(v);
    volatile int i = 5; int r = 0;
    switch (k) {
    case 0: r = v[i]; break;
    case 1: r = s[i + 20]; break;
    case 2: r = sv[i]; break;
    case 3: r = a[i]; break;
    case 4: r = e.front(); break;
    case 5: r = l.back(); break;
    case 6: e.pop_back(); break;
    case 7: r = *o; break;
    case 8: r = sp[i]; break;
    default: r = v[2] + a[0]; break;
    }
    std::printf("not stopped %d\n", r);
    _exit(0);
  }
  int st = 0;
  waitpid(c, &st, 0);
  return WIFEXITED(st) && WEXITSTATUS(st) == 7;
}

int main() {
  std::vector<int> v{1, 2, 3};
  v.reserve(16);
  std::string s = "hardened";
  std::array<int, 3> a{4, 5, 6};
  std::optional<int> o = 9;
  std::span<int> sp(v);
  std::printf("%d %c %d %d %d %zu\n", v[1], s[2], a[2], *o, sp[0], std::string_view(s).substr(1, 3).size());
  for (int k = 0; k < 10; k++) std::printf("%d", stopped(k));
  std::printf("\n");
  return 0;
}
