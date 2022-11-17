# msdos-disk-protect

## Example MS-DOS assembly language: A hard disk write protect utility.

Write protects fixed disks on MS-DOS. See [PROTECT.TXT](PROTECT.TXT) for details.

It is a terminate-and-stay-resident (TSR) program. TSR was a common technique in the MS-DOS days.

It is posted here for historical reference. If you are interested in MS-DOS assembly language, this is a well commented and well tested example.

## Contents

[PROTECT.TXT](PROTECT.TXT) - Documentation and instructions.

[PROTECT.ASM](PROTECT.ASM) - The source code, x86 assembler, with lots of comments. Works with multiple assemblers of the era. We used Microsoft's for production.

[PROTECT.MAK](PROTECT.MAK) - The Makefile. Works with multiple make tools of the era. We used Microsoft's for production.

PROTECT.COM - The protect utility, as built in 1992, a binary MS-DOS command file.

UNPROT.COM - The unprotect utility, as built in 1992 a binary MS-DOS command file.

## History

I wrote this in early 1990 for use by my employer, a US government contractor. It was based on an earlier version that we copied from a technical magazine. The magazine's version didn't handle the case where some drives were removable, and therefore didn’t need to be protected. My version allows protection on some disks but not all. The original version also included the function to turn protection off in the same binary that turned protection on, which didn't meet our customer's security requirements. My version separates the protect and unprotect functions into different files.

It was obsolete by late 1992 because the price of disks fell so much. We no longer had PCs where one disk was fixed and the other removable. One big removable disk handled both the system and the data.  

