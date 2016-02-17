#!/usr/bin/env tclsh
package require Tcl 8.5
package require cmdline
package require fileutil

set GPG2_PATH gpg2

proc edit {encrypted editor} {
    set commandPrefix [list -ignorestderr -- \
            $::GPG2_PATH --batch --yes --passphrase-fd 0]
    puts Passphrase:

    if {$::tcl_platform(platform) eq {unix}} {
        set oldMode [exec stty -g <@ stdin]
        exec stty -echo <@ stdin
    }
    gets stdin passphrase
    if {$::tcl_platform(platform) eq {unix}} {
        exec stty {*}$oldMode <@ stdin
    }

    set temporary [::fileutil::tempfile]
    file attributes $temporary -permissions 0600
    exec {*}$commandPrefix --decrypt -o $temporary $encrypted \
            << $passphrase
    exec $editor $temporary <@ stdin >@ stdout 2>@ stderr
    exec {*}$commandPrefix --symmetric --armor -o $encrypted $temporary \
            << $passphrase
    file delete $temporary
}

proc main {argv0 argv} {
    set options {
        {editor.arg  {}  {editor to use}}
    }
    set usage "$argv0 \[options] filename ...\noptions:"
    set opts [::cmdline::getoptions argv $options $usage]

    set editor $::env(EDITOR)
    if {[dict exists $opts editor]} {
        set editor [dict get $opts editor]
    }
    edit [lindex $argv 0] $editor
}

main $argv0 $argv
