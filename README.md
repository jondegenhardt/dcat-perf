# dcat

`dcat` is a very simple tool for examing some aspects of I/O performance using constructs available in the D programming language ecosystem. `dcat` reads input from a file or standard input and writes results to standard output. Most tests focus on reading and writing line-by-line. Use Unix `time` or similar to get timing data.

Clone this repo and build with LDC using the command:
```
$ dub build --compiler=ldc2 --build=release-lto --combined
```

The executable is written to `./bin/dcat`. Run `dcat --help` to see a list of tests available, or simply look at the code.

Some benchmarks generated with this tool can be found on the [issues](https://github.com/jondegenhardt/dcat-perf/issues) page.

## Example timing run

The example below performs runs on the google one-gram file for the letter 's', available from the[Google Books ngram datasets](http://storage.googleapis.com/books/ngrams/books/datasetsv2.html). It has been downloaded as `googlebooks-eng-all-1gram-20120701-s.tsv`. The command below was run on OS X and uses the GNU versions of `time` and `wc`, which are installed as `gtime` and `gwc` by Homebrew.

This command runs several of the available dcat tests five time each and writes the results to the file perf-results.tsv. The `g|wc` command is used to load the file into disk cache so every run starts from the same basis wrt caches.

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

The results are written `perf-results.tsv`.

```
$ head -n 5 perf-results.tsv
test	elapsed	user	system	cpu_pct	mem
byLineInRawOut	22.78	21.86	0.87	99%	1968
byLineInBufOut	9.66	8.75	0.88	99%	1952
bufferedByLineInBufOut	6.89	6.43	0.44	99%	2096
iopipeByLineInRawOut	21.46	20.80	0.56	99%	1940
```

If [tsv-utils](https://github.com/eBay/tsv-utils) are installed ([download page](https://github.com/eBay/tsv-utils/releases)) you can calculate the median timing data as follows:

```
$ tsv-summarize -H --group-by 1 --median 2-4,6 perf-results.tsv | tsv-pretty -p 2
test                    elapsed_median  user_median  system_median  mem_median
byLineInRawOut                   22.53        21.64           0.86        1940
byLineInBufOut                    9.49         8.61           0.87        1952
bufferedByLineInBufOut            6.85         6.40           0.44        2084
iopipeByLineInRawOut             20.45        19.92           0.50        1952
iopipeByLineInBufOut              3.55         3.05           0.48        1956
```
