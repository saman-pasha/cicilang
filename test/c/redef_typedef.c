/* A TYPEDEF OF ANOTHER TYPE (1.6.7; C17 6.7/3): refused at the second one's line, the new type first */
typedef int T;
typedef long T;
int main(void) { T t = 1; return (int)t; }
