#!/usr/bin/env tclsh
package require Tcl 8.6
package require cmdline
package require fileutil

namespace eval ::gpgedit {
    variable gpgPath gpg2
    variable commandPrefix [list -ignorestderr -- \
            $gpgPath --batch --yes --passphrase-fd 0]
}

proc ::gpgedit::decrypt {in out passphrase} {
    variable commandPrefix
    exec {*}$commandPrefix --decrypt -o $out $in << $passphrase
}

proc ::gpgedit::encrypt {in out passphrase} {
    variable commandPrefix
    exec {*}$commandPrefix --symmetric --armor -o $out $in << $passphrase
}

proc ::gpgedit::edit {encrypted editor} {
    puts Passphrase:

    if {$::tcl_platform(platform) eq {unix}} {
        set oldMode [exec stty -g <@ stdin]
        exec stty -echo <@ stdin
    }
    gets stdin passphrase
    if {$::tcl_platform(platform) eq {unix}} {
        exec stty {*}$oldMode <@ stdin
    }

    try {
        set temporary [::fileutil::tempfile]
        file attributes $temporary -permissions 0600
        if {[file exists $encrypted]} {
            decrypt $encrypted $temporary $passphrase
        }
        exec $editor $temporary <@ stdin >@ stdout 2>@ stderr
        encrypt $temporary $encrypted $passphrase
    } finally {
        file delete $temporary
    }
}

proc ::gpgedit::main {argv0 argv} {
    set options {
        {editor.arg  {}  {editor to use}}
    }
    set usage "$argv0 \[options] filename ...\noptions:"
    set opts [::cmdline::getoptions argv $options $usage]

    set editor $::env(EDITOR)
    if {[dict get $opts editor] ne {}} {
        set editor [dict get $opts editor]
    }
    edit [lindex $argv 0] $editor
}

::gpgedit::main $argv0 $argv
