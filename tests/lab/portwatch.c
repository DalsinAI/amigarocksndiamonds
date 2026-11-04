/*
 * PortWatch: prints what a joystick port reports while it changes, for
 * proving a lab's joystick input (the keyboard's joystick that Cradle's
 * keypad keys drive, or a real stick) reaches the Amiga. Not part of the
 * port.
 *
 *   PortWatch SECONDS/N/A,PORT/N
 *
 * PORT is lowlevel.library's port number (default 1, the joystick port,
 * "Amiga joystick port (2)" to SDL). Every tick (1/50 s) it reads
 * ReadJoyPort(PORT) and the port's own registers (JOY1DAT or JOY0DAT, and
 * the fire button in CIA-A), and prints a line when either changes. Ctrl-C
 * stops early.
 *
 * MIT, Copyright (c) 2026 AmiCradle Team.
 */
#include <exec/types.h>
#include <dos/dos.h>
#include <libraries/lowlevel.h>
#include <proto/exec.h>
#include <proto/dos.h>
#include <proto/lowlevel.h>
#include <stdio.h>

struct Library *LowLevelBase;

static const char *dirs(ULONG s)
{
	static char b[64];
	snprintf(b, sizeof(b), "%s%s%s%s%s%s", s & JPF_JOY_UP ? " up" : "", s & JPF_JOY_DOWN ? " down" : "",
		 s & JPF_JOY_LEFT ? " left" : "", s & JPF_JOY_RIGHT ? " right" : "",
		 s & JPF_BUTTON_RED ? " red/fire" : "", s & JPF_BUTTON_BLUE ? " blue/fire2" : "");
	return b;
}

int main(void)
{
	LONG args[2] = { 0 };
	struct RDArgs *rd = ReadArgs((STRPTR)"SECONDS/N/A,PORT/N", args, NULL);
	if (rd == NULL)
	{
		PrintFault(IoErr(), (STRPTR)"PortWatch");
		return RETURN_FAIL;
	}
	LONG ticks = *(LONG *)args[0] * 50;
	LONG port = args[1] ? *(LONG *)args[1] : 1;
	volatile UWORD *joydat = (volatile UWORD *)(port == 1 ? 0xDFF00C : 0xDFF00A);
	volatile UBYTE *ciaapra = (volatile UBYTE *)0xBFE001;
	UBYTE firebit = port == 1 ? 0x80 : 0x40;
	LowLevelBase = OpenLibrary((STRPTR)"lowlevel.library", 40);
	if (LowLevelBase == NULL)
		printf("PortWatch: no lowlevel.library; the registers only\n");
	ULONG last = 0xFFFFFFFF;
	UWORD lastdat = 0xFFFF;
	int lastfire = -1;
	LONG changes = 0;
	for (LONG t = 0; t < ticks; ++t)
	{
		if (SetSignal(0, 0) & SIGBREAKF_CTRL_C)
			break;
		ULONG s = LowLevelBase ? ReadJoyPort(port) : 0;
		UWORD dat = *joydat;
		int fire = (*ciaapra & firebit) == 0;
		if (s != last || dat != lastdat || fire != lastfire)
		{
			printf("%3ld.%02ld s: ReadJoyPort(%ld) %08lx type %s%s; JOY%ldDAT %04x, fire %s\n", (long)(t / 50),
			       (long)(t % 50 * 2), (long)port,
			       (unsigned long)s,
			       (s & JP_TYPE_MASK) == JP_TYPE_JOYSTK ? "joystick" :
			       (s & JP_TYPE_MASK) == JP_TYPE_GAMECTLR ? "game controller" :
			       (s & JP_TYPE_MASK) == JP_TYPE_MOUSE ? "mouse" :
			       (s & JP_TYPE_MASK) == JP_TYPE_NOTAVAIL ? "not available" : "unknown",
			       dirs(s), (long)port, dat, fire ? "down" : "up");
			last = s;
			lastdat = dat;
			lastfire = fire;
			++changes;
		}
		Delay(1);
	}
	printf("%ld changes\n", (long)changes);
	if (LowLevelBase)
		CloseLibrary(LowLevelBase);
	FreeArgs(rd);
	return RETURN_OK;
}
