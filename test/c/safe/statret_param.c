/* A FUNCTION THAT RETURNS A PARAMETER'S POINTER answers new memory to the safe part (0.294): its result is the
   caller's to give back, or the function's to tie to the parameter (`tie s') */
static const char *skip(const char *s) { return s + 1; }
int main(void) { char buf[4] = "abc"; const char *p = skip(buf); return p[0]; }
