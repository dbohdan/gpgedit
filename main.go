package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"path"
	"strings"
	"syscall"
	"time"

	"golang.org/x/term"
)

const (
	filePerm    = 0o600
	tempDirPerm = 0o700
	tempDirPrefix = "/dev/shm"

	gpgPath = "gpg2"
	version = "0.3.0"
)

type EncryptError struct {
	err      error
	tempFile string
}

func (e *EncryptError) Error() string {
	return fmt.Sprintf("encryption failed: %v", e.err)
}

var commandPrefix = []string{
	"--batch",
	"--yes",
	"--passphrase-fd", "0",
}

func decrypt(in, out, passphrase string) error {
	cmd := exec.Command(gpgPath, append(commandPrefix, "--decrypt", "-o", out, in)...)
	cmd.Stdin = strings.NewReader(passphrase)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}

func encrypt(in, out, passphrase string) error {
	cmd := exec.Command(gpgPath, append(commandPrefix, "--symmetric", "--armor", "--cipher-algo", "AES256", "-o", out, in)...)
	cmd.Stdin = strings.NewReader(passphrase)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}

func input(prompt string) (string, error) {
	fmt.Print(prompt)

	bytePassword, err := term.ReadPassword(int(syscall.Stdin))
	if err != nil {
		return "", err
	}
	fmt.Println()

	return string(bytePassword), nil
}

func edit(encrypted, editor string, readOnly, changePassphrase bool) (tempDir string, err error) {
	var exists bool
	exists, err = checkAccess(encrypted, readOnly)
	if err != nil {
		return
	}

	var passphrase string
	passphrase, err = input("Passphrase: ")
	if err != nil {
		return
	}

	var newPassphrase string
	if changePassphrase {
		if newPassphrase, err = input("New passphrase: "); err != nil {
			return
		}
	}

	currentUser, err := user.Current()
	if err != nil {
		return
	}

	tempDir = path.Join(tempDirPrefix, currentUser.Username+"-gpgedit")
	err = os.MkdirAll(tempDir, tempDirPerm)
	if err != nil {
		return
	}

	rootname := getRoot(encrypted)
	var tempFile *os.File
	tempFile, err = os.CreateTemp(tempDir, "*"+path.Base(rootname))
	if err != nil {
		return
	}
	tempFile.Close()

	// This check from the Tcl version is probably unnecessary.
	if err = checkPermissions(tempDir, tempDirPerm); err != nil {
		return
	}
	if err = checkPermissions(tempFile.Name(), filePerm); err != nil {
		return
	}

	if exists {
		if err = decrypt(encrypted, tempFile.Name(), passphrase); err != nil {
			return
		}
	}

	cmd := exec.Command(editor, tempFile.Name())
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err = cmd.Run(); err != nil {
		return
	}

	if !readOnly {
		if changePassphrase {
			passphrase = newPassphrase
		}

		if err = encrypt(tempFile.Name(), encrypted, passphrase); err != nil {
			err = &EncryptError{err: err, tempFile: tempFile.Name()}
			return
		}
	}

	return
}

func cli() int {
	editorFlag := flag.String("editor", "", "the editor to use")
	readOnly := flag.Bool("ro", false, "read-only mode -- all changes will be discarded")
	changePassphrase := flag.Bool("u", false, "change the passphrase for the file")
	showVersion := flag.Bool("v", false, "report the program version and exit")
	warn := flag.Int("warn", 0, "warn if the editor exits after less than X seconds")

	flag.Parse()

	editor := *editorFlag
	if editor == "" {
		editor = os.Getenv("VISUAL")
	}
	if editor == "" {
		editor = os.Getenv("EDITOR")
	}
	if editor == "" {
		editor = "vi"
	}

	if *showVersion {
		fmt.Println(version)
		return 0
	}

	if flag.NArg() < 1 {
		flag.PrintDefaults()
		return 2
	}

	filename := flag.Arg(0)

	if *warn < 0 {
		fmt.Fprintln(os.Stderr, "Error: the argument to -warn can't be negative")
		return 2
	}

	start := int(time.Now().Unix())

	tempDir, err := edit(filename, editor, *readOnly, *changePassphrase)
	if tempDir != "" {
		defer os.RemoveAll(tempDir)
	}

	if *warn > 0 && int(time.Now().Unix())-start <= int(*warn) {
		fmt.Fprintf(os.Stderr, "Warning: editor exited after less than %d second(s)\n", *warn)
	}

	if err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)

		if encErr, ok := err.(*EncryptError); ok {
			fmt.Printf("Press <enter> to delete the temporary file %q\n", encErr.tempFile)
			fmt.Scanln()
		}

		return 1
	}

	return 0
}

func main() {
	os.Exit(cli())
}

func checkPermissions(filename string, perm os.FileMode) error {
	info, err := os.Stat(filename)
	if err != nil {
		return err
	}

	actualPerm := info.Mode().Perm()
	if actualPerm != perm {
		return fmt.Errorf("wrong permissions on %q: %o instead of %o", filename, actualPerm, perm)
	}

	return nil
}

func getRoot(encrypted string) string {
	ext := path.Ext(encrypted)

	if ext == ".asc" || ext == ".gpg" {
		return strings.TrimSuffix(encrypted, ext)
	}

	return encrypted
}

func checkAccess(encrypted string, readOnly bool) (bool, error) {
	_, err := os.Stat(encrypted)

	if err != nil && os.IsNotExist(err) {
		if readOnly {
			return false, fmt.Errorf("%q doesn't exist; won't attempt to create it in read-only mode", encrypted)
		}

		return false, nil
	}

	f, err := os.Open(encrypted)
	if err != nil {
		return true, fmt.Errorf("can't read from file %q", encrypted)
	}
	f.Close()

	// If not in read-only mode, try to open for writing.
	// We don't want writing to fail later, after the user edits the file.
	if !readOnly {
		f, err := os.OpenFile(encrypted, os.O_RDWR, 0600)

		if err != nil {
			return true, fmt.Errorf("can't write to file %q", encrypted)
		}

		f.Close()
	}

	return true, nil
}
