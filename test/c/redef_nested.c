/* A STRUCT DEFINED IN A MEMBER IS THE FILE'S (1.6.7; C17 6.2.1/4), so its definition again at file scope is refused
   at C17, at the second one's line */
struct o { struct in { int a; } i; };
struct in { int a; };
int main(void) { return 0; }
