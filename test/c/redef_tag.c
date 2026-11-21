/* A STRUCT DEFINED AGAIN AT C17 (1.6.7; C17 6.7.2.3/1): refused at the second one's line, the same content or not */
struct s { int a; };
struct s { int a; };
int main(void) { struct s v = { 5 }; return v.a; }
