#include <condition_variable>
#include <cstdio>
#include <mutex>
#include <shared_mutex>
#include <thread>
// std::shared_mutex, shared_lock, condition_variable, call_once
int main() {
  std::shared_mutex sm;
  int v = 0;
  { std::unique_lock<std::shared_mutex> w(sm); v = 5; }
  { std::shared_lock<std::shared_mutex> r1(sm); std::shared_lock<std::shared_mutex> r2(sm); std::printf("%d %d\n", v, (int) r2.owns_lock()); }
  std::mutex m;
  std::condition_variable cv;
  bool ready = false;
  std::thread t([&] { { std::lock_guard<std::mutex> g(m); ready = true; } cv.notify_one(); });
  { std::unique_lock<std::mutex> l(m); cv.wait(l, [&] { return ready; }); }
  t.join();
  std::printf("%d\n", (int) ready);
  std::once_flag once;
  int calls = 0;
  for (int i = 0; i < 3; i++) std::call_once(once, [&] { calls++; });
  std::printf("%d\n", calls);
  std::recursive_mutex rm;
  rm.lock(); rm.lock(); rm.unlock(); rm.unlock();
  std::timed_mutex tm;
  std::printf("%d\n", (int) tm.try_lock());
  tm.unlock();
  return 0;
}
