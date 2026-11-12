/* `own' WHERE ONLY A NAME CAN STAND (0.306; the Ambitious session's finding 37): a pattern's name, `{ own, b } := p',
   which was taken until a use, refused at line 6 (reader k168) */
typedef struct pr { int x; int y; } pr;
int main(void) {
    pr p = {1, 2};
    { own, b } := p;
    return b - 2;
}
