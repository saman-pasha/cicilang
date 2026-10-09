// placement new[] ([expr.new]): n objects made in the storage the placement argument names, no cookie
#include <cstdio>
#include <new>
struct T { int id; T() : id(7) { printf("ctor\n"); } ~T() { printf("dtor %d\n", id); } };
struct V { int v; V(int x = 3) : v(x) {} };
struct D { int k; ~D() { printf("D dtor\n"); } };
int main(int argc, char **) {
  alignas(T) unsigned char buf[4 * sizeof(T)];
  T *p = new (buf) T[3];
  printf("%d %d %d\n", p[0].id, p[1].id, p[2].id);
  for (int i = 2; i >= 0; i--) p[i].~T();
  int n = argc + 2;
  alignas(V) unsigned char vb[4 * sizeof(V)];
  V *vs = new (vb) V[n]{V(10), 20};
  printf("%d %d %d\n", vs[0].v, vs[1].v, vs[2].v);
  alignas(D) unsigned char db[2 * sizeof(D)];
  D *d = new (db) D[2]();
  printf("%d %d\n", d[0].k, d[1].k);
  d[1].~D(); d[0].~D();
  int *q = new (buf) int[3]();
  printf("%d %d %d\n", q[0], q[1], q[2]);
  int *r = new (buf) int[4]{1, 2};
  printf("%d %d %d %d\n", r[0], r[1], r[2], r[3]);
  return 0;
}
