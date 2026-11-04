/*
 * SplitFile: cuts a file into numbered parts of at most SIZE bytes
 * (FILE.000, FILE.001, ...), so a lab's tools that read a file whole up to
 * a limit (Cradle's lab_get) can fetch a bigger one, e.g. the game's
 * screenshots. Not part of the port.
 *
 *   SplitFile FILE/A,SIZE/N
 *
 * MIT, Copyright (c) 2026 AmiCradle Team.
 */
#include <exec/types.h>
#include <dos/dos.h>
#include <proto/exec.h>
#include <proto/dos.h>
#include <stdio.h>

int main(void)
{
	LONG args[2] = { 0 };
	struct RDArgs *rd = ReadArgs("FILE/A,SIZE/N", args, NULL);
	if (rd == NULL)
	{
		PrintFault(IoErr(), "SplitFile");
		return RETURN_FAIL;
	}
	const char *name = (const char *)args[0];
	LONG size = args[1] ? *(LONG *)args[1] : 40000;
	int rc = RETURN_FAIL;
	static UBYTE buf[65536];
	if (size < 1 || size > (LONG)sizeof(buf))
		size = 40000;
	BPTR in = Open((STRPTR)name, MODE_OLDFILE);
	if (in)
	{
		rc = RETURN_OK;
		for (int part = 0; part < 1000; ++part)
		{
			LONG got = Read(in, buf, size);
			if (got <= 0)
				break;
			char out[256];
			snprintf(out, sizeof(out), "%s.%03d", name, part);
			BPTR fh = Open((STRPTR)out, MODE_NEWFILE);
			if (!fh || Write(fh, buf, got) != got)
				rc = RETURN_FAIL;
			if (fh)
				Close(fh);
			printf("%s %ld\n", out, (long)got);
		}
		Close(in);
	}
	else
		PrintFault(IoErr(), (STRPTR)name);
	FreeArgs(rd);
	return rc;
}
