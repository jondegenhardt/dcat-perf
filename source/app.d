/**
A simple version of the unix 'cat' program. It is used for performance testing.

Copyright (c) 2019, Jon Degenhardt
*/
module dcat;

import std.typecons : Flag, No, Yes, tuple;

auto helpText = q"EOS
Synopsis: dcat -t <test> [file]

dcat reads from a file or standard input and writes each line to standard
output. This program is used for performance testing.

Tests available (with input and output methods):

* byLineInRawOut
  - Input:  std.stdio.File.byLine
  - Output: std.stdio.File.write

* byLineInBufOut
  - Input:  std.stdio.File.byLine
  - Output: tsv_utils.common.utils.BufferedOutputRange

* bufferedByLineInBufOut
  - Input:  tsv_utils.common.utils.bufferedByLine
  - Output: tsv_utils.common.utils.BufferedOutputRange

* iopipeByLineInRawOut
  - Input:  iopipe.byLine
  - Output: std.stdio.File.write

* iopipeByLineInBufOut
  - Input:  iopipe.byLine
  - Output: tsv_utils.common.utils.BufferedOutputRange

* iopipeByLineInIOOut
  - Input:  iopipe.byLine
  - Output: std.io.file.File.write

* iopipeByLineInBufIOOut
  - Input:  iopipe.byLine
  - Output: std.io.file.File.write (buffered)

* byChunkInRawOut
  - Input:  std.stdio.File.byChunk
  - Output: std.stdio.File.rawWrite

* byChunkInBufOut
  - Input:  std.stdio.File.byChunk
  - Output: tsv_utils.common.utils.BufferedOutputRange

* byChunkByLine
  - Read chunk at a time, write line at a time, ignoring line boundaries
  - Input:  std.stdio.File.byChunk
  - Output: tsv_utils.common.utils.BufferedOutputRange

Options:
EOS";

enum DCatTest
    {
     byLineInRawOut,
     byLineInBufOut,
     bufferedByLineInBufOut,
     iopipeByLineInRawOut,
     iopipeByLineInBufOut,
     iopipeByLineInIOOut,
     iopipeByLineInBufIOOut,
     byChunkInBufOut,
     byChunkInRawOut,
     byChunkInByLineBufOut,
    };

/** Container for command line options.
 */
struct CmdOptions
{
    enum defaultHeaderString = "line";

    string programName;
    DCatTest dcatTest;

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
            import std.traits : EnumMembers;
            import std.conv : to;

            auto dcatTestNames = [EnumMembers!DCatTest];
            auto testOptionDescription = "One of: " ~ dcatTestNames.to!string;
            auto r = getopt(
                cmdArgs,
                std.getopt.config.caseSensitive,
                std.getopt.config.required,
                "t|test", testOptionDescription, &dcatTest,
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

    version(LDC_Profile)
    {
        /* LDC profile build - reset data collection after command line arg processing. */
        import ldc.profile : resetAll;
        resetAll();
    }

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
    case DCatTest.byLineInRawOut:
        useByLineInRawOut(cmdopt, filename);
        break;

    case DCatTest.byLineInBufOut:
        useByLineInBufOut(cmdopt, filename, bufferedOutput);
        break;

    case DCatTest.bufferedByLineInBufOut:
        useBufferedByLineInBufOut(cmdopt, filename, bufferedOutput);
        break;

    case DCatTest.iopipeByLineInRawOut:
        useIopipeByLineInRawOut(cmdopt, filename);
        break;

    case DCatTest.iopipeByLineInBufOut:
        useIopipeByLineInBufOut(cmdopt, filename, bufferedOutput);
        break;

    case DCatTest.iopipeByLineInIOOut:
        useIopipeByLineInIOOut(cmdopt, filename);
        break;

    case DCatTest.iopipeByLineInBufIOOut:
        useIopipeByLineInBufIOOut(cmdopt, filename);
        break;

    case DCatTest.byChunkInRawOut:
        useByChunkInRawOut(cmdopt, filename);
        break;

    case DCatTest.byChunkInBufOut:
        useByChunkInBufOut(cmdopt, filename, bufferedOutput);
        break;

    case DCatTest.byChunkInByLineBufOut:
        useByChunkInByLineBufOut(cmdopt, filename, bufferedOutput);
        break;
    }
}

void useByLineInRawOut(CmdOptions cmdopt, string filename)
{
    import std.stdio;

    auto inputStream = (filename == "-") ? stdin : filename.File();
    foreach (line; inputStream.byLine(Yes.keepTerminator))
    {
        stdout.write(line);
    }
}

void useByLineInBufOut(OutputRange)(CmdOptions cmdopt, string filename, auto ref OutputRange outputStream)
{
    import std.range;
    import std.stdio;

    auto inputStream = (filename == "-") ? stdin : filename.File();
    foreach (line; inputStream.byLine(Yes.keepTerminator))
    {
        outputStream.put(line);
    }
}

void useBufferedByLineInBufOut(OutputRange)(CmdOptions cmdopt, string filename, auto ref OutputRange outputStream)
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

void useIopipeByLineInRawOut(CmdOptions cmdopt, string filename)
{
    import iopipe.textpipe;
    import iopipe.bufpipe;
    import std.stdio : writeln;
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
            throw new Exception("useIoPipeByLineInBufOut supports reading from stdin only on Posix.");
        }

        auto inputStream = filename.File().refCounted;
    }

    foreach (ref line; inputStream.bufd.assumeText.byLineRange)
    {
        writeln(line);
    }
}

void useIopipeByLineInBufOut(OutputRange)(CmdOptions cmdopt, string filename, auto ref OutputRange outputStream)
{
    import std.range;
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
            throw new Exception("useIoPipeByLineInBufOut supports reading from stdin only on Posix.");
        }

        auto inputStream = filename.File().refCounted;
    }

    foreach (ref line; inputStream.bufd.assumeText.byLineRange)
    {
        outputStream.put(line);
        outputStream.put('\n');
    }
}

void useIopipeByLineInIOOut(CmdOptions cmdopt, string filename)
{
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
        auto ioStdout = 1.File().refCounted;
    }
    else
    {
        import std.exception;
        throw new Exception("useIoPipeByLineInIOOut is available only on Posix.");
    }

    foreach (ref line; inputStream.bufd.assumeText.byLineRange)
    {
        ioStdout.write(cast(ubyte[])line, cast(ubyte[])"\n");
    }
}

void useIopipeByLineInBufIOOut(CmdOptions cmdopt, string filename)
{
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
        auto outputStream = BufferedIOStdout!ubyte();
    }
    else
    {
        import std.exception;
        throw new Exception("useIoPipeByLineInIOOut is available only on Posix.");
    }

    foreach (ref line; inputStream.bufd.assumeText.byLineRange)
    {
        outputStream.put(line);
        outputStream.put('\n');
    }
}

void useByChunkInRawOut(CmdOptions cmdopt, string filename)
{
    import std.stdio;

    auto ifile = (filename == "-") ? stdin : filename.File;
    foreach (ref c; ifile.byChunk(1024 * 128)) stdout.rawWrite(c);
}

void useByChunkInBufOut(BufferedOutputRange)(CmdOptions cmdopt, string filename, auto ref BufferedOutputRange outputStream)
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

void useByChunkInByLineBufOut(OutputRange)(CmdOptions cmdopt, string filename, auto ref OutputRange outputStream)
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

/* Simple buffering of standard output using std.io. */
struct BufferedIOStdout(C = char)
if (is(C == char) || is(C == ubyte))
{
    import std.array : appender;
    import std.io;

    private enum _reserveSize = 11264;
    private enum _flushSize = 10240;

    private File _ioStdout;
    private auto _buffer = appender!(C[]);

    static BufferedIOStdout opCall()
    {
        BufferedIOStdout x;

        x._ioStdout = 1.File();
        x._buffer.reserve(_reserveSize);
        return x;
    }

    ~this()
    {
        flush();
    }

    private void flush()
    {
        if (_buffer.data.length > 0)
        {
            _ioStdout.write(_buffer.data);
            _buffer.clear;
        }
    }

    private void appendFlush(T)(auto ref T stuff)
    if (is(T : char[]) || is(T : ubyte[]))
    {
        if (_buffer.data.length > 0)
        {
            _ioStdout.write(cast(ubyte[]) _buffer.data, cast(ubyte[]) stuff);
            _buffer.clear;
        }
        else
        {
            _ioStdout.write(cast(ubyte[]) stuff);
        }
    }

    private void append(T)(auto ref T stuff)
    {
        import std.range : rangePut = put;

        static if (is(T : char[]))
        {
            rangePut(_buffer, cast(ubyte[]) stuff);
        }
        else static if (is(T == char))
        {
            rangePut(_buffer, cast(ubyte) stuff);
        }
        else
        {
            rangePut(_buffer, stuff);
        }
    }

    void put(T)(auto ref T stuff)
    if (is(T : char[]) || is(T : ubyte[]) || is(T : char) || is(T : ubyte))
    {
          import std.traits;

          static if (is(T : char[]) || is(T : ubyte[]))
          {
              if (_buffer.data.length + stuff.length > _reserveSize)
              {
                  appendFlush(stuff);
              }
              else
              {
                  append(stuff);
                  if (_buffer.data.length >= _flushSize) flush;
              }
          }
          else
          {
              append(stuff);
              if (_buffer.data.length >= _flushSize) flush;
          }
    }
}
