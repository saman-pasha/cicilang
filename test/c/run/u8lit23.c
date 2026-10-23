/* C23's u8 literals (6.4.4.5/12, 6.4.5/6): u8'c' an unsigned char, u8"..." char8_t's, the typedef of unsigned char; a
   prefixed character literal one character, its UTF-8 its code point; a multi-character constant an int, its bytes in
   order; adjacent string literals one, the prefix the kind (0.196) */
#include <stdio.h>
#include <uchar.h>
#include <wchar.h>
int main(void) {
    char8_t c = u8'a';
    printf("%d %zu %d %d\n", c, sizeof(u8'a'), _Generic(u8'a', unsigned char: 1, char: 2, int: 3, default: 4), u8'\x7f' > 0);
    printf("%zu %d %d %d\n", sizeof(u8"é"), u8"é"[0], u8"é"[1], u8"é"[2]);
    char8_t a[] = u8"hé";
    const char8_t *p = u8"x" "y" u8"z";
    printf("%zu %d %d %d %d %d\n", sizeof a, a[0], a[1], a[2], p[1], p[2]);
    wchar_t w = L'é'; char16_t s16 = u'€'; char32_t s32 = U'😀';
    printf("%d %d %u %d\n", (int) w, (int) s16, (unsigned) s32, (int) U'é');
    printf("%d %d %d %d %d\n", 'ab', 'abcd', '\x41\x42', 'a' == 97, (int) sizeof('ab'));
    const wchar_t *ws = L"ab" "cd"; const char16_t *u16 = "x" u"y"; const char32_t *u32 = U"é" "😀";
    printf("%d %d %u %u %zu %zu %zu\n", (int) ws[3], (int) u16[1], (unsigned) u32[0], (unsigned) u32[1], sizeof(L"ab" "cd"), sizeof("x" u"y"), sizeof(U"é" "😀"));
    return 0;
}
