#!/usr/bin/env tclsh
package require Tcl 8.5
package require fileutil

proc edit encrypted {
    set commandPrefix {-ignorestderr -- gpg2 --batch --yes --passphrase-fd 0}
    puts Passphrase:
    gets stdin passphrase
    set temporary [::fileutil::tempfile]
    file attributes $temporary -permissions 0600
    exec {*}$commandPrefix --decrypt -o $temporary $encrypted << $passphrase
    exec $::env(EDITOR) $temporary <@ stdin >@ stdout 2>@ stderr
    exec {*}$commandPrefix --symmetric --armor -o $encrypted $temporary << $passphrase
    file delete $temporary
}

edit [lindex $argv 0]
