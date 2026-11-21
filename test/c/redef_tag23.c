/* A STRUCT DEFINED AGAIN AT C23 WITH OTHER CONTENT (1.6.7; C23 6.7.2.3/1 takes the same content only): refused at
   the second one's line */
struct s { int a; };
struct s { long a; };
int main(void) { struct s v = { 5 }; return (int)v.a; }
