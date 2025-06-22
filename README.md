## Concept
We are editing a series of files, for each file we have some command(s) that we run over and over again for that particular file. Some pythonic examples would be:
1. Building/Running a file directly: `python some_file.py`.
2. Running a specific suite of unit tests: `pytest test.py:test_some_file`.

This plugin aims to alleviate the burden of running the same commands over and over again for the same files, whilst also doing this within neovim.
