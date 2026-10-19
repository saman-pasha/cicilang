// std::current_exception and std::rethrow_exception over the program's own throw (0.181): over libc++ 21, whose
// libc++.so is the library itself and no linker script, the link through g++ bound the program's __cxa_throw and
// __cxa_begin_catch to libstdc++, and libc++'s current_exception, which asks libc++abi, captured nothing
#include <cstdio>
#include <exception>
#include <stdexcept>
struct E { int v; };
int main() {
    std::exception_ptr p;
    try { throw E{42}; } catch (...) { p = std::current_exception(); std::printf("in handler: uncaught %d\n", std::uncaught_exceptions()); }
    std::printf("captured %d\n", p ? 1 : 0);
    try { if (p) std::rethrow_exception(p); } catch (const E &e) { std::printf("rethrown %d\n", e.v); }
    try { throw std::runtime_error("boom"); } catch (const std::exception &e) { std::printf("what: %s\n", e.what()); }
    return 0;
}
