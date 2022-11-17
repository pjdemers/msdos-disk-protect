
## Make protect.com : 

protect.obj: protect.asm
	masm /DMAKING_PROTECT protect;

protect.com:  protect.obj
	link protect;
	erase protect.com
	exe2bin protect
	rename protect.bin protect.com
        erase protect.exe

## Make unprot.com : 

unprot.obj: protect.asm
	masm /DMAKING_UNPROT protect, unprot;

unprot.com:  unprot.obj
	link unprot;
	erase unprot.com
	exe2bin unprot
	rename unprot.bin unprot.com
        erase unprot.exe

