// the twin of relations.c over std:: (0.304): it prints relations.expect
#include <cstdio>
#include <cmath>
#include <vector>
#include <array>
#include <deque>
#include <list>
#include <forward_list>
#include <stack>
#include <queue>
#include <set>
#include <map>
#include <optional>
#include <utility>
static void line(const char *what, int lt, int gt, int le, int ge, int eq) {
    std::printf("%-34s < %d  > %d  <= %d  >= %d  == %d\n", what, lt, gt, le, ge, eq);
}
#define REL(w, a, b) line(w, (a) < (b), (a) > (b), (a) <= (b), (a) >= (b), (a) == (b))
int main() {
    double n = NAN;
    std::vector<double> v1 = {1, 2}, v2 = {1, 2}, v3 = {1, 3}, v4 = {1}, v5 = {n, 1}, v6 = {n, 2}, v7 = {1, n}, v8 = {2, 0};
    REL("vector equal", v1, v2);
    REL("vector less", v1, v3);
    REL("vector prefix", v4, v1);
    REL("vector NaN first", v5, v6);
    REL("vector NaN after equal", v7, v7);
    REL("vector decided before NaN", v7, v8);
    std::array<double, 2> a1 = {{1, 2}}, a2 = {{1, 3}}, a3 = {{n, 1}}, a4 = {{n, 2}};
    REL("array less", a1, a2);
    REL("array NaN first", a3, a4);
    REL("array equal", a1, a1);
    std::deque<double> d1 = {1, 2}, d2 = {1}, d3 = {n, 1}, d4 = {n, 2};
    REL("deque prefix", d2, d1);
    REL("deque NaN first", d3, d4);
    std::list<double> l1 = {1, 2}, l2 = {1, 2, 0}, l3 = {n}, l4 = {n};
    REL("list prefix", l1, l2);
    REL("list NaN", l3, l4);
    std::list<double> l5 = {n, 1}, l6 = {n, 2};
    REL("list NaN first", l5, l6);
    std::forward_list<double> f1 = {2}, f2 = {1, 5}, f3 = {n, 1}, f4 = {n, 1};
    REL("forward_list greater", f1, f2);
    REL("forward_list NaN", f3, f4);
    std::forward_list<double> f5 = {n, 1}, f6 = {n, 2};
    REL("forward_list NaN first", f5, f6);
    std::stack<double> s1, s2, s3, s4;
    s1.push(1); s1.push(2); s2.push(1); s2.push(2); s3.push(1); s3.push(n); s4.push(1); s4.push(n);
    REL("stack equal", s1, s2);
    REL("stack NaN", s3, s4);
    std::stack<double> s5, s6;
    s5.push(n); s5.push(1); s6.push(n); s6.push(2);
    REL("stack NaN first", s5, s6);
    std::queue<double> q1, q2, q3, q4;
    q1.push(0); q1.push(2); q2.push(1); q3.push(n); q4.push(0);
    REL("queue less", q1, q2);
    REL("queue NaN", q3, q4);
    std::queue<double> q5, q6;
    q5.push(n); q5.push(1); q6.push(n); q6.push(2);
    REL("queue NaN first", q5, q6);
    std::set<double> e1 = {1, 2}, e2 = {1, 3}, e3 = {1};
    REL("set less", e1, e2);
    REL("set prefix", e3, e1);
    std::map<int, double> m1 = {{1, n}}, m2 = {{1, n}};
    std::map<int, double> m3 = {{1, 0}, {2, 1}}, m4 = {{1, 0}, {2, 2}};
    std::map<int, double> m5 = {{1, n}}, m6 = {{2, 0}};
    REL("map NaN value", m1, m2);
    REL("map less value", m3, m4);
    REL("map key decides before NaN", m5, m6);
    std::map<int, double> m7 = {{1, n}, {2, 0}}, m8 = {{1, n}, {2, 1}};
    REL("map NaN value first", m7, m8);
    std::optional<double> o1 = 1.0, o2 = 2.0, o3 = n, o4 = n, o5;
    REL("optional less", o1, o2);
    REL("optional NaN", o3, o4);
    REL("optional NaN and a value", o3, o1);
    REL("optional none and NaN", o5, o3);
    REL("optional NaN and none", o3, o5);
    REL("optional and a value", o1, 1.0);
    REL("optional NaN and a value", o3, 1.0);
    REL("a value and optional NaN", 1.0, o3);
    REL("none and a value", o5, 1.0);
    REL("a value and none", 1.0, o5);
    REL("optional and nullopt", o1, std::nullopt);
    REL("nullopt and optional", std::nullopt, o1);
    REL("none and nullopt", o5, std::nullopt);
    std::pair<double, int> p1 = {1, 2}, p2 = {1, 3}, p3 = {n, 1}, p4 = {n, 2};
    std::pair<double, double> p5 = {1, n}, p6 = {1, n};
    REL("pair less", p1, p2);
    REL("pair NaN first", p3, p4);
    REL("pair NaN second", p5, p6);
    std::vector<std::pair<double, int>> w1, w2;
    w1.push_back(p3);
    w2.push_back(p3);
    REL("vector of pairs, NaN", w1, w2);
    std::vector<std::pair<double, int>> w3, w4;
    w3.push_back(p1);
    w4.push_back(p2);
    REL("vector of pairs, less", w3, w4);
    std::optional<std::pair<double, double>> u1 = p5, u2 = p6;
    REL("optional of a pair, NaN", u1, u2);
    std::deque<std::optional<double>> g1, g2;
    g1.push_back(o3);
    g2.push_back(o4);
    REL("deque of optionals, NaN", g1, g2);
    std::deque<std::optional<double>> g3, g4;
    g3.push_back(o5);
    g4.push_back(o1);
    REL("deque of optionals, none first", g3, g4);
    return 0;
}
