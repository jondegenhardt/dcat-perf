# dcat

`dcat` is a very simple tool for examing some aspects of I/O performance using constructs available in the D programming language ecosystem. `dcat` reads input from a file or standard input and writes results to standard output. Most tests focus on reading and writing line-by-line.

Clone this repo and build with LDC 1.9.0+ using the command:
```
$ dub build --build=release-lto --combined
```
