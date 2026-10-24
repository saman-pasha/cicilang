#include <cstdio>
#include <future>
#include <thread>
// std::future, std::promise, std::packaged_task, std::async
int square(int x) { return x * x; }
int main() {
  std::promise<int> p;
  std::future<int> f = p.get_future();
  std::thread t([&p] { p.set_value(42); });
  std::printf("%d\n", f.get());
  t.join();
  std::packaged_task<int(int)> task(square);
  std::future<int> g = task.get_future();
  std::thread t2(std::move(task), 7);
  std::printf("%d\n", g.get());
  t2.join();
  std::future<int> h = std::async(std::launch::async, square, 9);
  std::printf("%d\n", h.get());
  std::promise<void> pv;
  std::future<void> fv = pv.get_future();
  pv.set_value();
  fv.wait();
  std::printf("%d\n", (int) fv.valid());
  std::promise<int> pe;
  std::future<int> fe = pe.get_future();
  try { throw 5; } catch (...) { pe.set_exception(std::current_exception()); }
  try { fe.get(); } catch (int e) { std::printf("caught %d\n", e); }
  return 0;
}
