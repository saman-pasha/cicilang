/* a row of a static array given to an owner (0.297): `borrow_stored', as `own int *o = &g;' is -- it was `owner leaked' */
static unsigned char table[2][3] = { { 1, 2, 3 }, { 4, 5, 6 } };
int main(void) { own unsigned char *o = table[1]; return o[0]; }
