/* `own' WHERE ONLY A NAME CAN STAND (0.306; the Ambitious session's finding 37): a template's value parameter, refused
   at its use in a parameter's words, refused at line 3 (reader k169) */
template <int own> int val() { return 0; }
int main() { return val<0>(); }
