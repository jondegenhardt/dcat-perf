/**
A simple version of the unix 'cat' program. It is used for performance testing,
*/
module dcat;

import std.typecons : Flag, No, Yes, tuple;

auto helpText = q"EOS
Synopsis: dcat -t <test> [options] [file]

dcat reads from a file or standard input and writes each line to standard
output. This program is used for performance testing.

Tests available (with input and output methods):

* byLineRaw
  - Input:  std.stdio.File.byLine
  - Output: std.stdio.File.write

* byLine
  - Input:  std.stdio.File.byLine
  - Output: tsv_utils.common.utils.BufferedOutputRange

* bufferedByLine
  - Input:  tsv_utils.common.utils.bufferedByLine
  - Output: tsv_utils.common.utils.BufferedOutputRange

* iopipeByLine
  - Input:  iopipe.byLine
  - Output: tsv_utils.common.utils.BufferedOutputRange

* byChunkRaw
  - Input:  std.stdio.File.byChunk
  - Output: std.stdio.File.rawWrite

* byChunk
  - Input:  std.stdio.File.byChunk
  - Output: tsv_utils.common.utils.BufferedOutputRange

* byChunkByLine
  - Read chunk at a time, write line at a time, ignoring line boundaries
  - Input:  std.stdio.File.byChunk
  - Output: tsv_utils.common.utils.BufferedOutputRange

Options:
EOS";

enum DCatTestType
    {
     byLineRaw,
     byLine,
     bufferedByLine,
     iopipeByLine,
     byChunk,
     byChunkRaw,
     byChunkByLine,
    };

/** Container for command line options.
 */
struct CmdOptions
{
    enum defaultHeaderString = "line";

    string programName;
    DCatTestType dcatTest;

    /* Returns a tuple. First value is true if command line arguments were successfully
     * processed and execution should continue, or false if an error occurred or the user
     * asked for help. If false, the second value is the appropriate exit code (0 or 1).
     */
    auto processArgs (ref string[] cmdArgs)
    {
        import std.algorithm : any, each;
        import std.getopt;
        import std.path : baseName, stripExtension;
        import std.stdio;

        programName = (cmdArgs.length > 0) ? cmdArgs[0].stripExtension.baseName : "Unknown_program_name";

        try
        {
            auto r = getopt(
                cmdArgs,
                std.getopt.config.caseSensitive,
                std.getopt.config.required,
                "t|test", "byLine, chunkByLine, chunkByChunk, chunkByChunkDirect, bufferedByLine", &dcatTest,
            );

            if (r.helpWanted)
            {
                defaultGetoptPrinter(helpText, r.options);
                return tuple(false, 0);
            }
        }
        catch (Exception e)
        {
            stderr.writefln("[%s] Error processing command line arguments: %s", programName, e.msg);
            return tuple(false, 1);
        }
        return tuple(true, 0);
    }
}

static if (__VERSION__ >= 2085) extern(C) __gshared string[] rt_options = [ "gcopt=cleanup:none" ];

/** Main program. */
int main(string[] cmdArgs)
{
    /* When running in DMD code coverage mode, turn on report merging. */
    version(D_Coverage) version(DigitalMars)
    {
        import core.runtime : dmd_coverSetMerge;
        dmd_coverSetMerge(true);
    }

    CmdOptions cmdopt;
    auto r = cmdopt.processArgs(cmdArgs);
    if (!r[0]) return r[1];
    try dcat(cmdopt, cmdArgs[1..$]);
    catch (Exception exc)
    {
        import std.stdio;
        stderr.writefln("Error [%s]: %s", cmdopt.programName, exc.msg);
        return 1;
    }

    return 0;
}

/** Primary routine, select the dcat test to run.
 */
void dcat(in CmdOptions cmdopt, in string[] inputFiles)
{
    import std.stdio;
    import std.conv : to;
    import std.range;
    import tsv_utils.common.utils : BufferedOutputRange;

    auto bufferedOutput = BufferedOutputRange!(typeof(stdout))(stdout);
    auto filename = inputFiles.length > 0 ? inputFiles[0] : "-";

    final switch(cmdopt.dcatTest)
    {
    case DCatTestType.byLineRaw:
        testByLineRaw(cmdopt, filename);
        break;

    case DCatTestType.byLine:
        testByLine(cmdopt, filename, bufferedOutput);
        break;

    case DCatTestType.bufferedByLine:
        testBufferedByLine(cmdopt, filename, bufferedOutput);
        break;

    case DCatTestType.iopipeByLine:
        testIopipeByLine(cmdopt, filename, bufferedOutput);
        break;

    case DCatTestType.byChunkRaw:
        testByChunkRaw(cmdopt, filename);
        break;

    case DCatTestType.byChunk:
        testByChunk(cmdopt, filename, bufferedOutput);
        break;

    case DCatTestType.byChunkByLine:
        testByChunkByLine(cmdopt, filename, bufferedOutput);
        break;
    }
}

void testByLineRaw(CmdOptions cmdopt, string filename)
{
    import std.range;
    import std.stdio;

    auto inputStream = (filename == "-") ? stdin : filename.File();
    foreach (line; inputStream.byLine(Yes.keepTerminator))
    {
        stdout.write(line);
    }
}

void testByLine(OutputRange)(CmdOptions cmdopt, string filename, auto ref OutputRange outputStream)
{
    import std.range;
    import std.stdio;

    auto inputStream = (filename == "-") ? stdin : filename.File();
    foreach (line; inputStream.byLine(Yes.keepTerminator))
    {
        outputStream.put(line);
    }
}

void testBufferedByLine(OutputRange)(CmdOptions cmdopt, string filename, auto ref OutputRange outputStream)
{
    import std.range;
    import std.stdio;
    import tsv_utils.common.utils : bufferedByLine;

    auto inputStream = (filename == "-") ? stdin : filename.File();
    foreach (ref line; inputStream.bufferedByLine!(Yes.keepTerminator))
    {
        outputStream.put(line);
    }
}

void testIopipeByLine(OutputRange)(CmdOptions cmdopt, string filename, auto ref OutputRange outputStream)
{
    import std.range;
    import tsv_utils.common.utils : bufferedByLine;

    import iopipe.textpipe;
    import iopipe.bufpipe;
    import std.io;
    import std.typecons : refCounted;

    version(Posix)
    {
        /* At present (std.io 0.2.2) supports access to stdin/stdout/stderr only via
         * native handles. See: https://github.com/MartinNowak/io/issues/14
         */
        auto inputStream = (filename == "-") ? 0.File().refCounted : filename.File().refCounted;
    }
    else
    {
        if (filename == "-")
        {
            import std.exception;
            throw new Exception("testIoPipeByLine supports reading from stdin only on Posix.");
        }

        auto inputStream = filename.File().refCounted;
    }

    foreach (ref line; inputStream.bufd.assumeText.byLineRange)
    {
        outputStream.put(line);
        outputStream.put('\n');
    }
}

void testByChunkRaw(CmdOptions cmdopt, string filename)
{
    import std.stdio;

    auto ifile = (filename == "-") ? stdin : filename.File;
    foreach (ref c; ifile.byChunk(1024 * 128)) stdout.rawWrite(c);
}

void testByChunk(BufferedOutputRange)(CmdOptions cmdopt, string filename, auto ref BufferedOutputRange outputStream)
{
    import std.stdio;
    import tsv_utils.common.utils : bufferedByLine;

    ubyte[1024 * 128] fileRawBuf;
    auto ifile = (filename == "-") ? stdin : filename.File;

    foreach (ref ubyte[] buffer; ifile.byChunk(fileRawBuf))
    {
        outputStream.append(buffer);
        outputStream.flushIfFull;
    }
    outputStream.flush;
}

void testByChunkByLine(OutputRange)(CmdOptions cmdopt, string filename, auto ref OutputRange outputStream)
{
    import std.algorithm : splitter;
    import std.stdio;

    ubyte[1024 * 128] fileRawBuf;
    auto ifile = (filename == "-") ? stdin : filename.File;

    foreach (ref ubyte[] buffer; ifile.byChunk(fileRawBuf))
    {
        bool first = true;
        foreach (ref line; buffer.splitter('\n'))
        {
            if (first) first = false;
            else outputStream.put('\n');
            outputStream.put(line);
        }
    }
}
