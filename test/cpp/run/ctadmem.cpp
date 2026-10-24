#include <cstdio>
#include <map>
#include <mutex>
#include <shared_mutex>
// class template argument deduction from a data member declared after the member function that names it
class W {
  W() = default;
public:
  int get(int k) {
    std::shared_lock lock{m_};
    std::lock_guard g{lut_[k].mu};
    return lut_[k].count;
  }
  void put(int k) {
    std::unique_lock lock{m_};
    ++lut_[k].count;
  }
  static W &instance() {
    static W w;
    return w;
  }
private:
  struct V {
    std::mutex mu;
    int count{0};
  };
  std::shared_mutex m_;
  std::map<int, V> lut_;
};
int main() {
  W::instance().put(3);
  W::instance().put(3);
  std::printf("%d %d\n", W::instance().get(3), W::instance().get(4));
  return 0;
}
