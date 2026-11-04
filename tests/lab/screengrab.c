/*
 * ScreenGrab: saves what the front screen shows as an 8-bit PCX file, small
 * enough for a lab's tools that read a file whole up to a limit (Cradle's
 * lab_get), for the play tests' screenshots. Not part of the port.
 *
 *   ScreenGrab FILE/A,X/N,Y/N,W/N,H/N,SCALE/N
 *
 * X, Y, W and H choose a part of the screen (default all of it); SCALE N
 * averages each N x N block into one pixel (default 1). A picture with 256
 * colours or fewer (a game's 8-bit frame) keeps its colours exactly; any
 * other gets a 6 x 7 x 6 colour cube. The pixels are read with
 * cybergraphics.library's ReadPixelArray.
 *
 * MIT, Copyright (c) 2026 AmiCradle Team.
 */
#include <exec/types.h>
#include <exec/memory.h>
#include <dos/dos.h>
#include <intuition/intuition.h>
#include <intuition/intuitionbase.h>
#include <graphics/rastport.h>
#include <proto/exec.h>
#include <proto/dos.h>
#include <proto/intuition.h>
#include <stdio.h>
#include <string.h>

struct Library *CyberGfxBase;

/* cybergraphics.library ReadPixelArray (LVO -120): destRect a0, destX d0,
 * destY d1, destMod d2, rp a1, srcX d3, srcY d4, w d5, h d6, format d7;
 * called with the arguments on the stack as C passes them. */
ULONG CGXReadPixelArray(APTR dest, ULONG dx, ULONG dy, ULONG dmod, struct RastPort *rp,
			ULONG sx, ULONG sy, ULONG w, ULONG h, ULONG fmt);
__asm__(
	"	.text\n"
	"	.even\n"
	"	.globl	_CGXReadPixelArray\n"
	"_CGXReadPixelArray:\n"
	"	moveml	d2-d7/a6,sp@-\n"
	"	movel	sp@(32),a0\n"
	"	movel	sp@(36),d0\n"
	"	movel	sp@(40),d1\n"
	"	movel	sp@(44),d2\n"
	"	movel	sp@(48),a1\n"
	"	movel	sp@(52),d3\n"
	"	movel	sp@(56),d4\n"
	"	movel	sp@(60),d5\n"
	"	movel	sp@(64),d6\n"
	"	movel	sp@(68),d7\n"
	"	movel	_CyberGfxBase,a6\n"
	"	jsr	a6@(-120:W)\n"
	"	moveml	sp@+,d2-d7/a6\n"
	"	rts\n");

#define RECTFMT_RGB 0

static ULONG palette[256];
static int ncolours;

/* the index of an exact colour, adding it while there is room; -1 when full */
static int exact(ULONG rgb, UWORD *hash)
{
	ULONG h = ((rgb >> 12) ^ (rgb * 2654435761UL)) & 4095;
	for (;;)
	{
		UWORD e = hash[h];
		if (e == 0)
		{
			if (ncolours == 256)
				return -1;
			palette[ncolours] = rgb;
			hash[h] = (UWORD)(ncolours + 1);
			return ncolours++;
		}
		if (palette[e - 1] == rgb)
			return e - 1;
		h = (h + 1) & 4095;
	}
}

static int cube(ULONG rgb)
{
	int r = (int)((rgb >> 16) & 255), g = (int)((rgb >> 8) & 255), b = (int)(rgb & 255);
	return ((r * 5 + 127) / 255) * 42 + ((g * 6 + 127) / 255) * 6 + (b * 5 + 127) / 255;
}

static int put(BPTR fh, const UBYTE *p, LONG n)
{
	return Write(fh, (APTR)p, n) == n;
}

int main(void)
{
	LONG args[6] = { 0 };
	struct RDArgs *rd = ReadArgs((STRPTR)"FILE/A,X/N,Y/N,W/N,H/N,SCALE/N", args, NULL);
	if (rd == NULL)
	{
		PrintFault(IoErr(), (STRPTR)"ScreenGrab");
		return RETURN_FAIL;
	}
	int rc = RETURN_FAIL;
	CyberGfxBase = OpenLibrary((STRPTR)"cybergraphics.library", 40);
	if (CyberGfxBase == NULL)
	{
		printf("ScreenGrab: no cybergraphics.library\n");
		FreeArgs(rd);
		return RETURN_FAIL;
	}
	ULONG lock = LockIBase(0);
	struct Screen *scr = ((struct IntuitionBase *)IntuitionBase)->FirstScreen;
	LONG sw = scr ? scr->Width : 0, sh = scr ? scr->Height : 0;
	char title[80] = "";
	if (scr && scr->DefaultTitle)
		strncpy(title, (const char *)scr->DefaultTitle, sizeof(title) - 1);
	UnlockIBase(lock);

	LONG x = args[1] ? *(LONG *)args[1] : 0, y = args[2] ? *(LONG *)args[2] : 0;
	LONG w = args[3] ? *(LONG *)args[3] : sw - x, h = args[4] ? *(LONG *)args[4] : sh - y;
	LONG n = args[5] ? *(LONG *)args[5] : 1;
	if (n < 1)
		n = 1;
	if (x < 0 || y < 0 || w < 1 || h < 1 || x + w > sw || y + h > sh)
	{
		printf("ScreenGrab: %ldx%ld+%ld+%ld is not on the %ldx%ld screen\n", (long)w, (long)h, (long)x, (long)y,
		       (long)sw, (long)sh);
		goto out;
	}
	LONG ow = w / n, oh = h / n;
	ULONG *rgb = AllocVec((ULONG)ow * oh * 4, MEMF_ANY);
	UBYTE *band = AllocVec((ULONG)w * n * 3, MEMF_ANY);
	UBYTE *pix = AllocVec((ULONG)ow * oh, MEMF_ANY);
	UWORD *hash = AllocVec(4096 * sizeof(UWORD), MEMF_ANY | MEMF_CLEAR);
	ULONG *sum = AllocVec((ULONG)ow * 3 * sizeof(ULONG), MEMF_ANY);
	if (rgb && band && pix && hash && sum)
	{
		/* the front screen, read again here: it is used only while it shows */
		lock = LockIBase(0);
		struct Screen *now = ((struct IntuitionBase *)IntuitionBase)->FirstScreen;
		UnlockIBase(lock);
		if (now != scr)
		{
			printf("ScreenGrab: the front screen changed\n");
			goto freeall;
		}
		for (LONG oy = 0; oy < oh; ++oy)
		{
			CGXReadPixelArray(band, 0, 0, (ULONG)w * 3, &scr->RastPort, (ULONG)x, (ULONG)(y + oy * n),
					  (ULONG)w, (ULONG)n, RECTFMT_RGB);
			memset(sum, 0, (ULONG)ow * 3 * sizeof(ULONG));
			for (LONG r = 0; r < n; ++r)
			{
				const UBYTE *p = band + r * w * 3;
				for (LONG ox = 0; ox < ow; ++ox)
					for (LONG c = 0; c < n; ++c, p += 3)
					{
						sum[ox * 3] += p[0];
						sum[ox * 3 + 1] += p[1];
						sum[ox * 3 + 2] += p[2];
					}
			}
			for (LONG ox = 0; ox < ow; ++ox)
				rgb[oy * ow + ox] = (sum[ox * 3] / (n * n)) << 16 | (sum[ox * 3 + 1] / (n * n)) << 8 |
						    sum[ox * 3 + 2] / (n * n);
		}
		BOOL exactly = TRUE;
		for (LONG i = 0; i < ow * oh; ++i)
		{
			int k = exact(rgb[i], hash);
			if (k < 0)
			{
				exactly = FALSE;
				break;
			}
			pix[i] = (UBYTE)k;
		}
		if (!exactly)
		{
			for (int i = 0; i < 252; ++i)
				palette[i] = (ULONG)((i / 42) * 255 / 5) << 16 | (ULONG)((i / 6 % 7) * 255 / 6) << 8 |
					     (ULONG)((i % 6) * 255 / 5);
			ncolours = 252;
			for (LONG i = 0; i < ow * oh; ++i)
				pix[i] = (UBYTE)cube(rgb[i]);
		}
		/* PCX: version 5, 8 bits, one plane, run-length lines, palette after */
		LONG bpl = (ow + 1) & ~1;
		UBYTE head[128];
		memset(head, 0, sizeof(head));
		head[0] = 10; head[1] = 5; head[2] = 1; head[3] = 8;
		head[8] = (UBYTE)((ow - 1) & 255); head[9] = (UBYTE)((ow - 1) >> 8);
		head[10] = (UBYTE)((oh - 1) & 255); head[11] = (UBYTE)((oh - 1) >> 8);
		head[12] = 72; head[14] = 72;
		head[65] = 1; head[66] = (UBYTE)(bpl & 255); head[67] = (UBYTE)(bpl >> 8); head[68] = 1;
		BPTR fh = Open((STRPTR)args[0], MODE_NEWFILE);
		BOOL ok = fh != 0 && put(fh, head, 128);
		static UBYTE line[8192];
		for (LONG oy = 0; ok && oy < oh; ++oy)
		{
			const UBYTE *s = pix + oy * ow;
			LONG o = 0;
			for (LONG i = 0; i < bpl;)
			{
				UBYTE v = i < ow ? s[i] : 0;
				LONG run = 1;
				while (i + run < bpl && run < 63 && (i + run < ow ? s[i + run] : 0) == v)
					++run;
				if (run > 1 || v >= 0xC0)
					line[o++] = (UBYTE)(0xC0 | run);
				line[o++] = v;
				i += run;
			}
			ok = put(fh, line, o);
		}
		if (ok)
		{
			UBYTE pal[769];
			pal[0] = 12;
			for (int i = 0; i < 256; ++i)
			{
				ULONG c = i < ncolours ? palette[i] : 0;
				pal[1 + i * 3] = (UBYTE)(c >> 16);
				pal[2 + i * 3] = (UBYTE)(c >> 8);
				pal[3 + i * 3] = (UBYTE)c;
			}
			ok = put(fh, pal, 769);
		}
		if (fh)
			Close(fh);
		if (ok)
		{
			printf("%s: %ldx%ld from %ldx%ld+%ld+%ld of the %ldx%ld screen \"%s\", %s colours (%d)\n",
			       (const char *)args[0], (long)ow, (long)oh, (long)w, (long)h, (long)x, (long)y, (long)sw,
			       (long)sh, title, exactly ? "exact" : "cube", ncolours);
			rc = RETURN_OK;
		}
		else
			printf("ScreenGrab: could not write %s\n", (const char *)args[0]);
	}
	else
		printf("ScreenGrab: not enough memory\n");
freeall:
	FreeVec(sum);
	FreeVec(hash);
	FreeVec(pix);
	FreeVec(band);
	FreeVec(rgb);
out:
	CloseLibrary(CyberGfxBase);
	FreeArgs(rd);
	return rc;
}
