// a header two units include (0.192): its inline variables and its class's inline static members are one object each,
// constructed once and destroyed once; its inline function's static local is one object
#include <cstdio>
struct UCnt { int n; UCnt(int k) : n(k) {} ~UCnt() { std::printf("~UCnt %d\n", n); } };
struct ULoud { int n; ULoud(int k) : n(k) { std::printf("ULoud %d\n", n); } ~ULoud() { std::printf("~ULoud %d\n", n); } };
inline ULoud gl(5);
inline UCnt gc(6);
struct UA { static inline UCnt sc{7}; static inline ULoud sl{8}; };
inline int iv = 10;
inline int bump() { static int calls = 0; return ++calls; }
