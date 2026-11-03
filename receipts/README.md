# Build receipts

Each file is a `receipt.json` (or `data-receipt.json`) exactly as the build
wrote it, byte for byte (its SHA-256 is in the table), kept here because the
build output itself is not committed. `repository_commit` is the commit that
was built; the receipt is committed after it.

| File | Build | Where | Receipt SHA-256 |
|---|---|---|---|
| `1-build-open5-stove_build.json` | Cradle `stove_build` of `a882322`, target `.` (job `j20261103T084602-4a24e8`) | Cradle's `os32-gcc16` stove (open5) | `ae71fa72969e25cfcbc21f8dd595dd127ff27552e3d56b1d9ee08f884a512c0d` |
| `1-data.json` | Cradle `stove_build` of `eadcf6e`, target `runtime-data` (job `j20261103T084048-ea0612`) | Cradle (open5) | `c9fdd39aa791f8336ce39937e9ed918cc61edcdde9e291ebbc2275465c8d8e0e` |
| `2-presentation-open5-stove_build.json` | Cradle `stove_build` of `3783f4d`, target `.` (job `j20261103T092616-2d5f5e`) | Cradle's `os32-gcc16` stove (open5) | `a3e0a1a79514f8f0ba920652d7fbbc2bf62369bf44e8d1177341e4ea8baa67d9` |
| `3-input-open5-stove_build.json` | Cradle `stove_build` of `03cfbba`, target `.` (job `j20261103T093747-df4d02`) | Cradle's `os32-gcc16` stove (open5) | `e2cb04e99cdf7f69b61b07309c3d75437b45c13913fa593cfeaec8c8396ef48d` |
