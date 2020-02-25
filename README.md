# dcat &nbsp; [![Travis (.com)](https://img.shields.io/travis/com/jondegenhardt/dcat-perf)](https://travis-ci.com/jondegenhardt/dcat-perf)

`dcat` is a very simple tool for examining performance of I/O facilities available in the D programming language ecosystem. `dcat` reads input from a file or standard input and writes results to standard output. The I/O methods to test are specified on the command line. Most tests focus on reading and writing line-by-line. Use Unix `time` or similar to get timing data.

Clone this repo and build with LDC using the command:
```
$ dub build --compiler=ldc2 --build=release-lto-pgo --combined
```

The above builds with LTO and PGO. To skip PGO and use LTO only:
```
$ dub build --compiler=ldc2 --build=release-lto --combined
```

The executable is written to `./bin/dcat`. Run `dcat --help` to see a list of tests available, or simply look at the [code](source/app.d#L11).

**Build Notes**:
* The dub.json file works with dub-1.15.0 and later but not dub-1.14.0 and earlier. To use with dub-1.14.0 changing `$$?` to `$?` in the `dub.json` file, in the `cli-test` section. See [dub issue #1709](https://github.com/dlang/dub/issues/1709).
* This project does not build with dmd-2.088.0. This is due to an issue in the [io package version 0.2.2](https://github.com/MartinNowak/io) library triggered by regression in DMD. See [druntime PR #2853](https://github.com/dlang/druntime/pull/2853). Other compiler versions are fine.

Tests available are based on components from:
* [D Standard Library](https://dlang.org/phobos/index.html)
* Steven Schveighoffer's [iopipe](https://github.com/schveiguy/iopipe) library
* Martin Nowak's [std.io](https://github.com/MartinNowak/io) library
* [eBay's TSV Utilities](https://github.com/eBay/tsv-utils)

Some benchmarks generated with this tool can be found on the [issues](https://github.com/jondegenhardt/dcat-perf/issues) page.

## Example timing run

The example below performs runs on the google one-gram file for the letter 's', available from the [Google Books ngram datasets](http://storage.googleapis.com/books/ngrams/books/datasetsv2.html). It has been downloaded as `googlebooks-eng-all-1gram-20120701-s.tsv`. The command below was run on MacOS and uses the GNU versions of `time` and `wc`, which are installed as `gtime` and `gwc` by Homebrew.

This command runs several of the available `dcat` tests five time each and writes the results to the file perf-results.tsv. The [g]wc` command is used to load the file into disk cache so every run starts from the same basis with respect to caches.

```
$ echo $'test\telapsed\tuser\tsystem\tcpu_pct\tmem' > perf-results.tsv; \
  gwc -l googlebooks-eng-all-1gram-20120701-s.tsv; \
  for i in 1 2 3 4 5; \
      do echo "---> Run ${i}"; \
      for t in byLineInRawOut byLineInBufOut bufferedByLineInBufOut iopipeByLineInRawOut iopipeByLineInBufOut; \
          do gtime -p --format="${t}\t%e\t%U\t%S\t%P\t%M" -a -o perf-results.tsv \
              ./bin/dcat -t ${t}  googlebooks-eng-all-1gram-20120701-s.tsv  > /dev/null; \
      done; \
  done
```

The results are written to `perf-results.tsv`.

```
$ head perf-results.tsv
test	elapsed	user	system	cpu_pct	mem
byLineInRawOut	22.50	21.63	0.84	99%	1832
byLineInBufOut	9.32	8.46	0.85	99%	1816
bufferedByLineInBufOut	6.41	5.98	0.42	99%	1976
iopipeByLineInRawOut	19.74	19.26	0.47	99%	1816
iopipeByLineInBufOut	2.95	2.48	0.46	99%	1836
byLineInRawOut	22.39	21.53	0.84	99%	1800
byLineInBufOut	9.31	8.45	0.85	99%	1828
bufferedByLineInBufOut	6.41	5.98	0.42	99%	1976
iopipeByLineInRawOut	19.86	19.35	0.48	99%	1816
```

Median timing values can be calculated using [tsv-utils](https://github.com/eBay/tsv-utils) as follows:

```
$ tsv-summarize -H --group-by 1 --median 2-4,6 perf-results.tsv | tsv-pretty -p 2
test                    elapsed_median  user_median  system_median  mem_median
byLineInRawOut                   22.41        21.56           0.84        1812
byLineInBufOut                    9.32         8.45           0.85        1816
bufferedByLineInBufOut            6.41         5.98           0.42        1976
iopipeByLineInRawOut             19.75        19.26           0.47        1828
iopipeByLineInBufOut              2.96         2.49           0.46        1836
```
