/* A STRUCT OF NO TAG IS A TYPE OF ITS OWN AT EACH DEFINITION (1.6.7; C17 6.7.2.3/5), so a typedef of a second one is
   of another type: refused at its line, in clang's words that spell each one by the typedef's name */
typedef struct { int a; } S;
typedef struct { int a; } S;
int main(void) { S v = { 1 }; return v.a; }
