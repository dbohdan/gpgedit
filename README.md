# gpgedit

**This project has been retired in favor of [age-edit](https://github.com/dbohdan/age-edit).**

gpgedit is an editor wrapper for GPG2-encrypted files made primarily for Linux.

How it works:

1. First, gpgedit asks for a passphrase.
2. It uses the passphrase to decrypt the contents of a file encrypted with GPG2 symmetric encryption to a temporary file.
3. It runs an editor on the temporary file
  ([`VISUAL` or `EDITOR`](https://unix.stackexchange.com/questions/4859/visual-vs-editor-what-s-the-difference) by default, but it can be, e.g., LibreOffice).
4. It waits for the editor to exit.
5. It runs GPG2 to replace the original file with the contents of the temporary file encrypted using the same passphrase.
6. Finally, gpgedit deletes the temporary file.

In other words, gpgedit implements
[a](https://wiki.tcl-lang.org/39218)
"[with](https://www.python.org/dev/peps/pep-0343/)"
[pattern](https://clojuredocs.org/clojure.core/with-open).

gpgedit is beta-quality software.

## Dependencies

### Build

- Go 1.21

### Runtime

- GPG2
- A temporary filesystem mounted on `/dev/shm/`.
  It is present by default on Linux with glibc.

## Installation

```shell
go install github.com/dbohdan/gpgedit@master
```

## Usage

```
Usage of gpgedit:
  -editor string
    	the editor to use
  -ro
    	read-only mode -- all changes will be discarded
  -u	change the passphrase for the file
  -v	report the program version and exit
  -warn int
    	warn if the editor exits after less than X seconds
```

## Security and other considerations

The passphrase is kept in the memory of the gpgedit process in plain text while the file is being edited.
The passphrase can be extracted from the process's memory or from swap if it is swapped out.
The decrypted contents of the file is stored on a temporary filesystem in RAM (`/dev/shm/${USER}-gpgedit`).
Other programs run by the same user can access it there, and it can also be swapped out.

gpgedit doesn't work with multi-document editors.

## License

MIT.
