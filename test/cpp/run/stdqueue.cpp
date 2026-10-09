// <queue> and <stack> (0.117): queue and stack are adaptors over deque, priority_queue over vector with the heap algorithms
#include <cstdio>
#include <functional>
#include <queue>
#include <stack>
#include <vector>
int main() {
  std::queue<int> q;
  q.push(1);
  q.push(2);
  q.push(3);
  std::printf("%d %d %zu\n", q.front(), q.back(), q.size());
  q.pop();
  std::stack<int> s;
  s.push(7);
  s.push(8);
  std::printf("%d %zu\n", s.top(), s.size());
  s.pop();
  std::priority_queue<int> pq;
  for (int x : {5, 1, 9, 3}) pq.push(x);
  std::printf("%d", pq.top());
  pq.pop();
  std::printf(" %d\n", pq.top());
  std::priority_queue<int, std::vector<int>, std::greater<int>> mn;
  for (int x : {5, 1, 9, 3}) mn.push(x);
  std::printf("%d %zu\n", mn.top(), mn.size());
  return 0;
}
