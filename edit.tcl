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

proc ::gpgedit::edit {encrypted editor {readOnly 0}} {
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
        if {[file extension $encrypted] in {.asc .gpg}} {
            set rootname [file rootname $encrypted]
        } else {
            set rootname $encrypted
        }
        set extension [file extension $rootname]
        close [file tempfile temporary $extension]

        file attributes $temporary -permissions 0600
        if {[file exists $encrypted]} {
            decrypt $encrypted $temporary $passphrase
        }
        exec $editor $temporary <@ stdin >@ stdout 2>@ stderr
        if {!$readOnly} {
            encrypt $temporary $encrypted $passphrase
        }
    } on error code {
        puts "Error: $code"
        puts "Press <enter> to delete the temporary file $temporary."
        gets stdin
    } finally {
        file delete $temporary
    }
}

proc ::gpgedit::main {argv0 argv} {
    set options {
        {editor.arg  {}  {editor to use}}
        {ro              {read-only mode -- all changes will be lost}}
    }
    set usage "$argv0 \[options] filename ...\noptions:"
    if {[catch {set opts [::cmdline::getoptions argv $options $usage]}] \
            || ([set filename [lindex $argv 0]] eq {})} {
        puts -nonewline [::cmdline::usage $options $usage]
        exit 1
    }

    if {[dict get $opts editor] ne {}} {
        set editor [dict get $opts editor]
    } else {
        set editor $::env(EDITOR)
    }
    edit $filename $editor [dict get $opts ro]
}

# If this is the main script...
if {[info exists argv0] && ([file tail [info script]] eq [file tail $argv0])} {
    ::gpgedit::main $argv0 $argv
}
