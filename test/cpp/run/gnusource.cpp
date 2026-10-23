// C++ ON LINUX, AS clang++ PREDEFINES IT (0.194): _GNU_SOURCE, so glibc declares its GNU functions -- libc++'s
// condition_variable::wait_until needs pthread_cond_clockwait -- and its C23 redirects (strtol is __isoc23_strtol by an asm
// label, which reads `0b'); no __STDC_VERSION__; wint_t unsigned, as the shipped wistringstream::ignore is mangled
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <pthread.h>
#include <condition_variable>
#include <mutex>
#include <chrono>
#include <sstream>
#include <string>
extern "C" int twice(int) __asm__("my_twice");
extern "C" int my_twice(int x) { return 2 * x; }
int main() {
#ifdef __STDC_VERSION__
    std::puts("stdc version");
#endif
#ifdef _GNU_SOURCE
    std::puts("gnu source");
#endif
    std::printf("nce %ld\n", (long) __cpp_named_character_escapes);
    std::printf("wint %d %s\n", (int) sizeof(wint_t), (wint_t) -1 > 0 ? "unsigned" : "signed");
    std::mutex m; std::condition_variable cv; bool ready = false;
    std::unique_lock<std::mutex> lk(m);
    bool r = cv.wait_until(lk, std::chrono::steady_clock::now() + std::chrono::milliseconds(5), [&] { return ready; });
    std::printf("waited %d\n", (int) r);
    std::wistringstream in(L"abc def");
    in.ignore(4);
    std::wstring w; in >> w;
    std::printf("ignore %d\n", (int) w.size());
    char *end;
    long v = std::strtol("0b101", &end, 0);
    const char *s = "key=value";
    std::printf("%d %ld [%s] %d\n", twice(21), v, end, (int) (strchrnul(s, '#') - s));
    return 0;
}
