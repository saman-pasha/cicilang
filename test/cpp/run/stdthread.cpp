// <thread> and <mutex> (0.117): a vector of std::threads that take a function, a reference through std::ref and an int; two threads that share an atomic
// counter through lambdas; a thread with arguments and a join; std::thread::id compared. Six defects stood between libc++'s std::thread and a run:
// `(T())' read as a cast, a braced default initializer of a plain union member (std::mutex), a member template of a plain class defined out of it
// (the constructors), `&__thread_proxy<_Gp>' (the address of a function template-id), a free `operator==' of a class that a header defines
// (thread::id), a shipped function's prototype declared in the frame of the first instance that called it -- the second kind of thread met a call
// of no type -- and the thread's call of `bump(Counter &, int)' through a function reference, which gave the callee the std::ref wrapper's address
// as the Counter (the four threads then waited on four mutexes of their own; fnptrargs.cpp). The output is the main thread's alone, after the joins
#include <atomic>
#include <cstdio>
#include <mutex>
#include <thread>
#include <vector>

struct Counter {
  std::mutex m;
  long total = 0;
  void add(long n) {
    std::lock_guard<std::mutex> g(m);
    total += n;
  }
};

void bump(Counter &c, int times) {
  for (int i = 0; i < times; i++) c.add(2);
}

int main() {
  Counter c;
  std::vector<std::thread> pool;
  for (int k = 0; k < 4; k++) pool.emplace_back(bump, std::ref(c), 500);
  for (auto &t : pool) t.join();
  std::printf("total %ld\n", c.total);

  std::atomic<int> hits(0);
  std::thread a([&hits] { for (int i = 0; i < 300; i++) hits.fetch_add(1); });
  std::thread b([&hits] { for (int i = 0; i < 700; i++) hits.fetch_add(1); });
  a.join();
  b.join();
  std::printf("hits %d\n", hits.load());

  int sum = 0;
  std::thread t([&sum](int x, int y) { sum = x + y; }, 20, 22);
  std::printf("joinable %d\n", (int)t.joinable());
  t.join();
  std::printf("sum %d joinable %d\n", sum, (int)t.joinable());
  std::thread::id none;
  std::printf("same %d\n", (int)(none == std::thread::id()));
  return 0;
}
