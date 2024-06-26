# gpgedit

`gpgedit` asks for a passphrase, uses it to decrypt the contents of a file encrypted with GPG2 symmetric encryption to a temporary file, and runs an editor program on the temporary file (`$EDITOR` by default but it can be, e.g., LibreOffice).
Once the editor exits, it has GPG2 put the contents of the temporary file in the original file encrypted with the original passphrase and deletes the temporary file.
In other words, it implements [a](https://wiki.tcl-lang.org/39218) "[with](https://www.python.org/dev/peps/pep-0343/)" [pattern](https://clojuredocs.org/clojure.core/with-open).

`gpgedit` is beta-quality software.

## Usage

```
gpgedit [options] filename ...
options:
 -editor value        the editor to use <>
 -ro                  read-only mode -- all changes will be discarded
 -u                   change the passphrase for the file
 -warn value          warn if the editor exits after less than X seconds <0>
 --                   Forcibly stop option processing
 -help                Print this message
 -?                   Print this message
```

## Dependencies

Tcl 8.6.x or 9, Tcllib, and GPG2.

### Debian/Ubuntu

```shell
sudo apt install tcl8.6 tcllib gnupg2
```

### Fedora

```shell
sudo dnf install tcl tcllib gpg2
```

### FreeBSD

```shell
sudo pkg install tcl86 tcllib gnupg
```

### openSUSE Tumbleweed

```shell
sudo zypper in tcl tcllib gpg2
```

### macOS

```shell
brew install tcl-tk gnupg2
```

```shell
sudo port install tcllib gpg2
```

## Security and other considerations

The passphrase is kept in the memory of the program's Tcl process in plain text while the file is edited.
The passphrase can be extracted from the process's memory or the swap partition/file if it is swapped out.
The decrypted contents of the file is stored in the default temporary directory (e.g., `/tmp`), where at minimum other programs run by the same user can access it while it is being edited.
If your temporary directory is stored on disk and isn't encrypted, the contents of the deleted temporary file could be recovered.

`gpgedit` doesn't work with multi-document editors.

## License

MIT.
