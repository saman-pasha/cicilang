// a virtual base named twice (0.172): directly and through a path, Q : P, virtual A over P : virtual A; a virtual
// first base that a later dynamic base also holds, R : virtual A, P; and a plain first base before both, S : B, P, virtual A
#include <cstdio>
struct A { int a = 1; virtual int f() { return 10 + a; } virtual ~A() {} };
struct P : virtual A { int p = 2; int f() override { return 20 + p; } };
struct Q : P, virtual A { int q = 3; };
struct R : virtual A, P { int r = 4; };
struct B { int b = 5; };
struct S : B, P, virtual A { int s = 6; };
static long off(const void *p, const void *b) { return (const char *) p - (const char *) b; }
int main() {
    Q q; R r; S s;
    std::printf("%zu %zu %zu %zu\n", sizeof(P), sizeof(Q), sizeof(R), sizeof(S));
    A *qa = &q, *ra = &r, *sa = &s;
    P *qp = &q, *rp = &r, *sp = &s;
    std::printf("%ld %ld %ld | %ld %ld %ld | %ld %ld %ld %ld\n", off(qa, &q), off(qp, &q), off(&q.q, &q), off(ra, &r), off(rp, &r),
                off(&r.r, &r), off(sa, &s), off(sp, &s), off(static_cast<B *>(&s), &s), off(&s.s, &s));
    std::printf("%d %d %d %d %d %d\n", qa->f(), ra->f(), sa->f(), q.a, r.a, s.a);
    qp->a = 31; rp->a = 32; sp->a = 33;
    std::printf("%d %d %d %d %d %d\n", q.a, r.a, s.a, qa->a, ra->a, sa->a);
    std::printf("%d %d %d\n", dynamic_cast<Q *>(qa) == &q, dynamic_cast<R *>(ra) == &r, dynamic_cast<S *>(sa) == &s);
    Q q2 = q; R r2 = r; S s2 = s;
    std::printf("%d %d %d %d %d %d\n", q2.a, r2.a, s2.a, q2.q, r2.r, s2.s);
    return 0;
}
