#!/usr/bin/perl
# gen-xid.pl: writes library/ccl_xid.pl, THE IDENTIFIER'S CHARACTERS PAST ASCII by the language and its level (0.221), as clang
# 18 and 21 take them -- probed character by character, both compilers alike -- and the white space past ASCII that clang reads:
#   xs, xc     C23 and every C++ level (C23 6.4.2.1, [lex.name]): UAX #31's XID_Start, and XID_Continue with XID_Start, from Perl's
#              Unicode::UCD, with Unicode 15.1's additions that clang's tables have (U+200C and U+200D, the two katakana middle
#              dots, CJK Extension I) and clang's mathematical notation profile (UAX #31's, its extension: U+2202, U+2207, U+221E
#              and their mathematical alphanumeric forms begin one, the superscript and subscript digits and signs follow)
#   c11, c11n  C11 and C17 (C11 Annex D: D.1 the characters allowed, D.2 those allowed but not initially)
#   c99, c99n  C99 (C99 Annex D, and 6.4.2.1/3: no digit of it initially)
#   ws         the white space past ASCII (U+0085, U+00A0, U+1680, U+180E, U+2000 to U+200A, U+2028, U+2029, U+202F, U+205F,
#              U+3000), which clang reads as white space in both languages at every level
#     perl module/gen-xid.pl > library/ccl_xid.pl
# module/build.sh spells the same facts into module/ccl_xid.h for the native lexer, so the tables are written once.
use strict; use warnings;
use Unicode::UCD qw(prop_invlist);
my $ver = Unicode::UCD::UnicodeVersion();
# a set as ranges, merged and sorted
sub set_of { my %in; for my $r (@_) { my ($lo, $hi) = @$r; $in{$_} = 1 for ($lo < 0x80 ? 0x80 : $lo) .. $hi } return ranges(sort { $a <=> $b } keys %in) }   # past ASCII only
sub ranges { my @l = @_; my @out; while (@l) { my $lo = shift @l; my $hi = $lo; $hi = shift @l while @l && $l[0] == $hi + 1; push @out, [$lo, $hi] } return @out }
sub inv { my @l = prop_invlist($_[0]); my @r; for (my $i = 0; $i < @l; $i += 2) { push @r, [$l[$i], ($i + 1 < @l ? $l[$i + 1] : 0x110000) - 1] } return @r }
sub hexr { map { my ($a, $b) = split /-/; [hex $a, hex($b // $a)] } split ' ', $_[0] }
my @math_start = hexr('2202 2207 221E 1D6C1 1D6DB 1D6FB 1D715 1D735 1D74F 1D76F 1D789 1D7A9 1D7C3');
my @math_cont = hexr('00B2-00B3 00B9 2070 2074-207E 2080-208E');
my @u151_start = hexr('2EBF0-2EE5D');
my @u151_cont = hexr('200C-200D 30FB FF65');
my @xs = set_of(inv('XID_Start'), @u151_start, @math_start);
my @xc = set_of(inv('XID_Start'), inv('XID_Continue'), @u151_start, @u151_cont, @math_start, @math_cont);
my @c11 = set_of(hexr('00A8 00AA 00AD 00AF 00B2-00B5 00B7-00BA 00BC-00BE 00C0-00D6 00D8-00F6 00F8-00FF 0100-167F 1681-180D
    180F-1FFF 200B-200D 202A-202E 203F-2040 2054 2060-206F 2070-218F 2460-24FF 2776-2793 2C00-2DFF 2E80-2FFF 3004-3007
    3021-302F 3031-303F 3040-D7FF F900-FD3D FD40-FDCF FDF0-FE44 FE47-FFFD 10000-1FFFD 20000-2FFFD 30000-3FFFD 40000-4FFFD
    50000-5FFFD 60000-6FFFD 70000-7FFFD 80000-8FFFD 90000-9FFFD A0000-AFFFD B0000-BFFFD C0000-CFFFD D0000-DFFFD E0000-EFFFD'));
my @c11n = set_of(hexr('0300-036F 1DC0-1DFF 20D0-20FF FE20-FE2F'));
my @c99 = set_of(hexr('
    00AA 00B5 00B7 00BA 00C0-00D6 00D8-00F6 00F8-01F5 01FA-0217 0250-02A8 02B0-02B8 02BB 02BD-02C1 02D0-02D1
    02E0-02E4 037A 0386 0388-038A 038C 038E-03A1 03A3-03CE 03D0-03D6 03DA 03DC 03DE 03E0 03E2-03F3 0401-040C
    040E-044F 0451-045C 045E-0481 0490-04C4 04C7-04C8 04CB-04CC 04D0-04EB 04EE-04F5 04F8-04F9 0531-0556 0559
    0561-0587 05B0-05B9 05BB-05BD 05BF 05C1-05C2 05D0-05EA 05F0-05F2 0621-063A 0640-0652 0660-0669 0670-06B7
    06BA-06BE 06C0-06CE 06D0-06DC 06E5-06E8 06EA-06ED 06F0-06F9 0901-0903 0905-0939 093D-094D 0950-0952 0958-0963
    0966-096F 0981-0983 0985-098C 098F-0990 0993-09A8 09AA-09B0 09B2 09B6-09B9 09BE-09C4 09C7-09C8 09CB-09CD
    09DC-09DD 09DF-09E3 09E6-09F1 0A02 0A05-0A0A 0A0F-0A10 0A13-0A28 0A2A-0A30 0A32-0A33 0A35-0A36 0A38-0A39
    0A3E-0A42 0A47-0A48 0A4B-0A4D 0A59-0A5C 0A5E 0A66-0A6F 0A74 0A81-0A83 0A85-0A8B 0A8D 0A8F-0A91 0A93-0AA8
    0AAA-0AB0 0AB2-0AB3 0AB5-0AB9 0ABD-0AC5 0AC7-0AC9 0ACB-0ACD 0AD0 0AE0 0AE6-0AEF 0B01-0B03 0B05-0B0C 0B0F-0B10
    0B13-0B28 0B2A-0B30 0B32-0B33 0B36-0B39 0B3D-0B43 0B47-0B48 0B4B-0B4D 0B5C-0B5D 0B5F-0B61 0B66-0B6F 0B82-0B83
    0B85-0B8A 0B8E-0B90 0B92-0B95 0B99-0B9A 0B9C 0B9E-0B9F 0BA3-0BA4 0BA8-0BAA 0BAE-0BB5 0BB7-0BB9 0BBE-0BC2
    0BC6-0BC8 0BCA-0BCD 0BE7-0BEF 0C01-0C03 0C05-0C0C 0C0E-0C10 0C12-0C28 0C2A-0C33 0C35-0C39 0C3E-0C44 0C46-0C48
    0C4A-0C4D 0C60-0C61 0C66-0C6F 0C82-0C83 0C85-0C8C 0C8E-0C90 0C92-0CA8 0CAA-0CB3 0CB5-0CB9 0CBE-0CC4 0CC6-0CC8
    0CCA-0CCD 0CDE 0CE0-0CE1 0CE6-0CEF 0D02-0D03 0D05-0D0C 0D0E-0D10 0D12-0D28 0D2A-0D39 0D3E-0D43 0D46-0D48
    0D4A-0D4D 0D60-0D61 0D66-0D6F 0E01-0E3A 0E40-0E5B 0E81-0E82 0E84 0E87-0E88 0E8A 0E8D 0E94-0E97 0E99-0E9F
    0EA1-0EA3 0EA5 0EA7 0EAA-0EAB 0EAD-0EAE 0EB0-0EB9 0EBB-0EBD 0EC0-0EC4 0EC6 0EC8-0ECD 0ED0-0ED9 0EDC-0EDD 0F00
    0F18-0F19 0F20-0F33 0F35 0F37 0F39 0F3E-0F47 0F49-0F69 0F71-0F84 0F86-0F8B 0F90-0F95 0F97 0F99-0FAD 0FB1-0FB7
    0FB9 10A0-10C5 10D0-10F6 1E00-1E9B 1EA0-1EF9 1F00-1F15 1F18-1F1D 1F20-1F45 1F48-1F4D 1F50-1F57 1F59 1F5B 1F5D
    1F5F-1F7D 1F80-1FB4 1FB6-1FBC 1FBE 1FC2-1FC4 1FC6-1FCC 1FD0-1FD3 1FD6-1FDB 1FE0-1FEC 1FF2-1FF4 1FF6-1FFC
    203F-2040 207F 2102 2107 210A-2113 2115 2118-211D 2124 2126 2128 212A-2131 2133-2138 2160-2182 3005-3007
    3021-3029 3041-3093 309B-309C 30A1-30F6 30FB-30FC 3105-312C 4E00-9FA5 AC00-D7A3
'));
my @c99n = set_of(hexr('
    0660-0669 06F0-06F9 0966-096F 09E6-09EF 0A66-0A6F 0AE6-0AEF 0B66-0B6F 0BE7-0BEF 0C66-0C6F 0CE6-0CEF 0D66-0D6F
    0E50-0E59 0ED0-0ED9 0F20-0F33
'));
my @ws = set_of(hexr('0085 00A0 1680 180E 2000-200A 2028-2029 202F 205F 3000'));
my %sets = (xs => \@xs, xc => \@xc, c11 => \@c11, c11n => \@c11n, c99 => \@c99, c99n => \@c99n, ws => \@ws);
my @order = qw(xs xc c11 c11n c99 c99n ws);
my $n = 0; $n += @{$sets{$_}} for @order;
print "%% ccl_xid.pl -- THE IDENTIFIER'S CHARACTERS PAST ASCII by the language and its level, and the white space past ASCII\n";
print "%% (0.221): `ccl_xid(Set, Lo, Hi)', the code points Lo to Hi in Set, each set's ranges ascending ($n facts) -- xs and xc\n";
print "%% C23's and C++'s (UAX #31's XID_Start, and XID_Continue with it, Unicode $ver as Perl's Unicode::UCD gives it, with\n";
print "%% Unicode 15.1's additions and clang's mathematical notation profile), c11 and c11n C11's and C17's (C11 Annex D, D.1\n";
print "%% and D.2: allowed, and allowed but not initially), c99 and c99n C99's (Annex D, and no digit initially), ws the white\n";
print "%% space clang reads -- GENERATED by module/gen-xid.pl, never edited by hand. The DCG loads this file on the first\n";
print "%% character past ASCII it meets (ccl_xid_ready in ccl_syntax); module/build.sh spells the same facts into\n";
print "%% module/ccl_xid.h for the native lexer, so the tables are written once.\n";
for my $s (@order) { printf "ccl_xid(%s, %d, %d).\n", $s, @$_ for @{$sets{$s}} }
