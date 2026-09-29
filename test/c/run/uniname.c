/* \N{NAME} (C++23, C23; 0.103): the code point by its Unicode name in a string (UTF-8), a char and a wide char; the
   hex-suffixed CJK family computed, a Hangul syllable from the table; clang's bytes and numbers */
#include <stdio.h>
#include <stddef.h>
int main(void) {
    const char *s = "\N{LATIN SMALL LETTER A}\N{GREEK SMALL LETTER ALPHA}\N{CJK UNIFIED IDEOGRAPH-4E00}\N{HANGUL SYLLABLE GA}\N{SNOWMAN}";
    for (int i = 0; s[i]; i++) printf("%02x ", (unsigned char) s[i]);
    printf("\n%d %d %d\n", '\N{LATIN CAPITAL LETTER B}', (int) L'\N{SNOWMAN}', (int) sizeof(L"\N{HANGUL SYLLABLE GA}x") / (int) sizeof(wchar_t));
    printf("%d %d %d %d\n", '\N{NULL}', (int) L'\N{LATIN CAPITAL LETTER GHA}', (int) L'\N{BYTE ORDER MARK}', '\N{ALERT}');   /* the name aliases: a control, a correction, an alternate, a figment-class one */
    return 0;
}
