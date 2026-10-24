#include <barrier>
#include <cstdio>
#include <latch>
#include <semaphore>
#include <thread>
#include <vector>
#include <atomic>
// std::latch, std::barrier, std::counting_semaphore (C++20)
int main() {
  std::latch done(3);
  std::atomic<int> sum{0};
  std::vector<std::thread> ts;
  for (int i = 1; i <= 3; i++) ts.emplace_back([&, i] { sum += i; done.count_down(); });
  done.wait();
  for (auto &t : ts) t.join();
  std::printf("%d\n", sum.load());
  std::barrier sync(2);
  int phase = 0;
  std::thread t([&] { sync.arrive_and_wait(); phase++; sync.arrive_and_wait(); });
  sync.arrive_and_wait();
  sync.arrive_and_wait();
  t.join();
  std::printf("%d\n", phase);
  std::counting_semaphore<4> sem(2);
  sem.acquire();
  std::printf("%d\n", (int) sem.try_acquire());
  std::printf("%d\n", (int) sem.try_acquire());
  sem.release(2);
  std::printf("%d\n", (int) sem.try_acquire());
  std::binary_semaphore b(0);
  std::thread u([&] { b.release(); });
  b.acquire();
  u.join();
  std::printf("ok\n");
  return 0;
}
