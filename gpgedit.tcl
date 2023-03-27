#!/usr/bin/env tclsh
# Copyright (c) 2016-2017, 2019-2021, 2023 D. Bohdan
# License: MIT

package require Tcl 8.6-10
package require cmdline

namespace eval ::gpgedit {
    variable version 0.1.3

    variable gpgPath gpg2
    variable commandPrefix [list \
        -ignorestderr \
        -- \
        $gpgPath \
        --batch \
        --yes \
        --passphrase-fd 0 \
    ]
}

proc ::gpgedit::decrypt {in out passphrase} {
    variable commandPrefix
    exec {*}$commandPrefix --decrypt \
                           -o $out \
                           $in \
         << $passphrase
}

proc ::gpgedit::encrypt {in out passphrase} {
    variable commandPrefix
    exec {*}$commandPrefix --symmetric \
                           --armor \
                           --cipher-algo AES256 \
                           -o $out \
                           $in \
         << $passphrase
}

# Read a line from stdin without echo and return it.
proc ::gpgedit::input prompt {
    puts -nonewline $prompt

    if {$::tcl_platform(platform) eq {unix}} {
        set oldMode [exec stty -g <@ stdin]
        exec stty -echo <@ stdin
    }

    gets stdin input

    if {$::tcl_platform(platform) eq {unix}} {
        puts {}
        exec stty {*}$oldMode <@ stdin
    }

    return $input
}

# Ask the user for a passphrase. Decrypt the file $encrypted to a temporary
# file with the passphrase and open it in the editor $editor. Once the editor
# exits unless $readOnly is true encrypt the updated content of the temporary
# file and save the it in $encrypted. If $changePassphrase is true, ask the user
# for two passphrases; decrypt the file with the first passphrase and encrypt it
# with the second.
proc ::gpgedit::edit {encrypted editor {readOnly 0} {changePassphrase 0}} {
    set buffering [chan configure stdout -buffering]
    chan configure stdout -buffering none

    # Command return code and result.
    set code ok
    set result {}

    try {
        if {[file exists $encrypted]} {
            if {![file readable $encrypted]} {
                error "can't read from file \"$encrypted\""
            }

            # Try to prevent situations when the user loses work or has to
            # recover it from the temporary file.
            if {!$readOnly && ![file writable $encrypted]} {
                error "can't write to file \"$encrypted\""
            }
        } elseif {$readOnly} {
            error "\"$encrypted\" doesn't exist;\
                   won't attempt to create it in read-only mode"
        }

        set passphrase [input {Passphrase: }]
        if {$changePassphrase} {
            set newPassphrase [input {New passphrase: }]
        }

        set rootname [
            if {[file extension $encrypted] in {.asc .gpg}} {
                file rootname $encrypted
            } else {
                set encrypted
            }
        ]
        set extension [file extension $rootname]
        close [file tempfile temporary $extension]

        if {$::tcl_platform(platform) eq {unix}
            && [file attributes $temporary -permissions] != 00600} {
            error "wrong permissions on the temporary file."
        }

        if {[file exists $encrypted]} {
            decrypt $encrypted $temporary $passphrase
        }

        exec {*}$editor $temporary <@ stdin >@ stdout 2>@ stderr

        if {!$readOnly} {
            if {$changePassphrase} {
                set passphrase $newPassphrase
            }
            encrypt $temporary $encrypted $passphrase
        }
    } on error message {
        puts "Error: $message."
        puts "Press <enter> to delete the temporary file $temporary."

        gets stdin

        set code error
        set result $message
    } finally {
        chan configure stdout -buffering $buffering
        file delete $temporary
    }

    return -code $code $result
}

proc ::gpgedit::main {argv0 argv} {
    set options {
        {editor.arg  {}  {the editor to use}}
        {ro              {read-only mode -- all changes will be discarded}}
        {u               {change the passphrase for the file}}
        {v               {report the program version and exit}}
        {warn.arg    0   {warn if the editor exits after less than X\
                          seconds}}
    }

    set usage "$argv0 \[options] filename ...\noptions:"

    if {[catch {set opts [::cmdline::getoptions argv $options $usage]}] ||
        [set filename [lindex $argv 0]] eq {}} {

        if {[info exists opts] && [dict get $opts v]} {
            puts $::gpgedit::version
            exit 0
        } else {
            puts -nonewline [::cmdline::usage $options $usage]
            exit 1
        }
    }

    if {[dict get $opts v]} {
        puts "Error: can't use -v with a filename."
        exit 1
    }

    # Process the argument -editor.
    set editor [
        if {[dict get $opts editor] ne {}} {
            dict get $opts editor
        } elseif {[info exists ::env(VISUAL)]} {
            set ::env(VISUAL)
        } elseif {[info exists ::env(EDITOR)]} {
            set ::env(EDITOR)
        } else {
            lindex vi
        }
    ]

    # Process the argument -warn.
    set warn [dict get $opts warn]
    if {![string is double -strict $warn]} {
        puts "Error: the argument to -warn must be a number."
        exit 1
    }
    if {$warn < 0} {
        puts "Error: the argument to -warn can't be negative."
        exit 1
    }
    if {$warn > 0} {
        set t [clock seconds]
    }

    try {
        edit $filename $editor [dict get $opts ro] [dict get $opts u]
    } on error _ {
        # Do nothing.
    } on ok _ {
        if {($warn > 0) && ([clock seconds] - $t <= $warn)} {
            puts "Warning: the editor exited after less than $warn second(s)."
        }
    }
}

# If this is the main script...
if {[info exists argv0] && ([file tail [info script]] eq [file tail $argv0])} {
    ::gpgedit::main $argv0 $argv
}
