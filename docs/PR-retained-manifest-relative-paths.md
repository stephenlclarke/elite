# fix(test): enumerate retained manifest paths relative to their directory

The diagnostic's file-map helper now uses `FileManager.enumerator(atPath:)` and takes its returned relative pathname directly as the manifest key. Appending that pathname to the base URL supplies the existing resource checks and file read. It no longer subtracts one URL string's length from a differently represented absolute file URL.

Foundation documents the enumeration as directory-relative and recursive, without resolving or traversing symbolic-link directories. The explicit symlink rejection, regular-file filtering, 25-file bound and 4 MiB file bound remain unchanged. SHA-256, sorted key order, UTF-8/NUL/hash/newline encoding, the exact expected digest and the input guard are unchanged. No original test method, continuation method, loader, copy, work loop, output protocol, assertion, production code or authority changes.

## Evidence and verification

Pure preflight 549 retained the exact old paths, 25 maps, encoded bytes and digest in `/tmp/elite-foundation-manifest-preflight-549/stdout.json` and its qualification. Offline byte replay reproduces the old digest and shows that the directory-relative expected map yields the unchanged required digest. This is existing-data analysis; it is not another game run. A source inverse recovers the complete previous test file by restoring only the former enumeration block and character trim.

G1 must run one pure Foundation preflight using the exact corrected helper before any package build or continuation retry. It must report all 25 keys and hashes exactly equal to the retained provenance and digest `977264133e75c7900694f7f3b5ca206a943c3be90fd79c3db57dfb7fddad066d`, with source bytes unchanged. Only that actual pass permits the independently reviewed incremental build and one conditional 330-second continuation. Run 548 supplied no gameplay evidence, and no blind runtime input retry is justified.

The author prepared the corrected helper/preflight source, source correspondence, byte replay, strict Swift formatting and Markdown/whitespace checks. The author ran no compiler, runtime or test job. The original 542 test and its acceptance status remain unchanged; this leaf fixes only diagnostic manifest calculation.
