# gpgedit

`gpgedit` asks for a passphrase, uses it to decrypt the contents of a file encrypted with GPG2 symmetric encryption to a temporary file and runs an editor program on the temporary file (`$EDITOR` by default but it can be, e.g., LibreOffice). Once the editor exits it has GPG2 put the contents of the temporary file in the original file encrypted with the original passphrase and deletes the temporary file. In other words, it implements [a](https://tcl.wiki/39218) "[with](https://www.python.org/dev/peps/pep-0343/)" [pattern](https://clojuredocs.org/clojure.core/with-open).

`gpgedit` is pre-alpha software.

# Usage

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

# Dependencies

Tcl 8.6.x, Tcllib and GPG2.

## Debian/Ubuntu

```shell
sudo apt-get install tcl8.6 tcllib gnupg2
```

## Fedora/RHEL

```shell
sudo dnf install tcl tcllib gpg2
```

### FreeBSD

```shell
sudo pkg install tcl86 tcllib gnupg
```

## OS X

```shell
sudo brew install tcl-tk gnupg2
```

```shell
sudo port install tcllib gpg2

```

# Security and other considerations

The passphrase is kept in the memory of the program's Tcl process in plain text while the file is edited. The password can be extracted from the process's memory or the swap partition/file if it is swapped out. The decrypted contents of the file is stored in the default temporary directory (e.g., `/tmp`) where it can be accessed at least by other programs run by the same user while it is being edited. If your temporary directory is stored on disk and isn't encrypted the contents of the deleted temporary file could be restored.

`gpgedit` doesn't work with multi-document editors.

# License

MIT.

