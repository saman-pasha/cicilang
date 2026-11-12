/* THE RELATIONS OF EVERY MODULE ARE C++20'S (0.304): the synthesized three-way order of the elements, in which the
   first pair that is not equal decides, and a pair that is neither `<' nor `==' either way -- a NaN -- is unordered and
   ends the comparison, so that `<', `>', `<=' and `>=' are all false; an optional's by the values' own relations. Each
   module over ordered pairs, over pairs that a NaN makes unordered, and instances in instances. Its twin relations.cpp
   prints relations.expect */
#include <stdio.h>
#include <math.h>
#include <vector.pl>
#include <array.pl>
#include <deque.pl>
#include <list.pl>
#include <forward_list.pl>
#include <stack.pl>
#include <queue.pl>
#include <set.pl>
#include <map.pl>
#include <optional.pl>
#include <pair.pl>
static void line(const char *what, int lt, int gt, int le, int ge, int eq) {
    printf("%-34s < %d  > %d  <= %d  >= %d  == %d\n", what, lt, gt, le, ge, eq);
}
#define REL(w, a, b) line(w, (a) < (b), (a) > (b), (a) <= (b), (a) >= (b), (a) == (b))
int main(void) {
    double n = NAN;
    vector<double> v1 = [1, 2], v2 = [1, 2], v3 = [1, 3], v4 = [1], v5 = [n, 1], v6 = [n, 2], v7 = [1, n], v8 = [2, 0];
    REL("vector equal", v1, v2);
    REL("vector less", v1, v3);
    REL("vector prefix", v4, v1);
    REL("vector NaN first", v5, v6);
    REL("vector NaN after equal", v7, v7);
    REL("vector decided before NaN", v7, v8);
    array<double, 2> a1 = {{1, 2}}, a2 = {{1, 3}}, a3 = {{n, 1}}, a4 = {{n, 2}};
    REL("array less", a1, a2);
    REL("array NaN first", a3, a4);
    REL("array equal", a1, a1);
    deque<double> d1 = [1, 2], d2 = [1], d3 = [n, 1], d4 = [n, 2];
    REL("deque prefix", d2, d1);
    REL("deque NaN first", d3, d4);
    list<double> l1 = [1, 2], l2 = [1, 2, 0], l3 = [n], l4 = [n];
    REL("list prefix", l1, l2);
    REL("list NaN", l3, l4);
    list<double> l5 = [n, 1], l6 = [n, 2];
    REL("list NaN first", l5, l6);
    forward_list<double> f1 = [2], f2 = [1, 5], f3 = [n, 1], f4 = [n, 1];
    REL("forward_list greater", f1, f2);
    REL("forward_list NaN", f3, f4);
    forward_list<double> f5 = [n, 1], f6 = [n, 2];
    REL("forward_list NaN first", f5, f6);
    stack<double> s1 = [1, 2], s2 = [1, 2], s3 = [1, n], s4 = [1, n];
    REL("stack equal", s1, s2);
    REL("stack NaN", s3, s4);
    stack<double> s5 = [n, 1], s6 = [n, 2];
    REL("stack NaN first", s5, s6);
    queue<double> q1 = [0, 2], q2 = [1], q3 = [n], q4 = [0];
    REL("queue less", q1, q2);
    REL("queue NaN", q3, q4);
    queue<double> q5 = [n, 1], q6 = [n, 2];
    REL("queue NaN first", q5, q6);
    set<double> e1 = [1, 2], e2 = [1, 3], e3 = [1];
    REL("set less", e1, e2);
    REL("set prefix", e3, e1);
    map<int, double> m1 = [int:double; 1: n], m2 = [int:double; 1: n];
    map<int, double> m3 = [int:double; 1: 0, 2: 1], m4 = [int:double; 1: 0, 2: 2];
    map<int, double> m5 = [int:double; 1: n], m6 = [int:double; 2: 0];
    REL("map NaN value", m1, m2);
    REL("map less value", m3, m4);
    REL("map key decides before NaN", m5, m6);
    map<int, double> m7 = [int:double; 1: n, 2: 0], m8 = [int:double; 1: n, 2: 1];
    REL("map NaN value first", m7, m8);
    optional<double> o1 = 1.0, o2 = 2.0, o3 = n, o4 = n, o5;
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
    REL("optional and nullopt", o1, nullopt);
    REL("nullopt and optional", nullopt, o1);
    REL("none and nullopt", o5, nullopt);
    pair<double, int> p1 = {1, 2}, p2 = {1, 3}, p3 = {n, 1}, p4 = {n, 2};
    pair<double, double> p5 = {1, n}, p6 = {1, n};
    REL("pair less", p1, p2);
    REL("pair NaN first", p3, p4);
    REL("pair NaN second", p5, p6);
    vector<pair<double, int>> w1 = [], w2 = [];
    push_back(w1, p3);
    push_back(w2, p3);
    REL("vector of pairs, NaN", w1, w2);
    vector<pair<double, int>> w3 = [], w4 = [];
    push_back(w3, p1);
    push_back(w4, p2);
    REL("vector of pairs, less", w3, w4);
    optional<pair<double, double>> u1 = p5, u2 = p6;
    REL("optional of a pair, NaN", u1, u2);
    deque<optional<double>> g1 = [], g2 = [];
    push_back(g1, o3);
    push_back(g2, o4);
    REL("deque of optionals, NaN", g1, g2);
    deque<optional<double>> g3 = [], g4 = [];
    push_back(g3, o5);
    push_back(g4, o1);
    REL("deque of optionals, none first", g3, g4);
    return 0;
}
