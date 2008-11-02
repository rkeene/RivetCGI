# Tcl versions of Rivet commands.

# Copyright 2003-2004 The Apache Software Foundation

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#	http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# $Id: tclrivet.tcl,v 1.2 2004/02/24 10:24:34 davidw Exp $


package provide tclrivet 0.1

if {[catch {
	load [file join [file dirname [info script]] .. .. lib [string tolower $::tcl_platform(os)] [string tolower $::tcl_platform(machine)] librivetparser[info sharedlibextension]]
	set ::librivetparser_loaded 1
} tclRivetLoadError]} {
	if {![info exists ::tclrivetparser_loaded]} {
		set ::tclrivetparser_loaded 1
		source [file join [file dirname [info script]] tclrivetparser.tcl]
	}
}

lappend auto_path [file join [file dirname [info script]] .. .. rivet-tcl]

proc include { filename } {
    set fl [ open $filename ]
    fconfigure $fl -translation binary
    puts -nonewline [ read $fl ]
    close $fl
}

namespace eval rivet {
	array set header_pairs {}
	set header_type "text/html"
	set header_sent 0
	set output_buffer ""
	set send_no_content 0
}

proc rivet_flush {} {
	if {!$::rivet::header_sent} {
		set ::rivet::header_sent 1
		if {![info exists ::rivet::header_redirect]} {
			tcl_puts "Content-type: $::rivet::header_type"
			foreach {var val} [array get ::rivet::header_pairs] {
				tcl_puts "$var: $val"
			}
		} else {
			tcl_puts "Location: $::rivet::header_redirect"
			tcl_puts ""
			abort_page
		}
		tcl_puts ""
	}

	if {!$::rivet::send_no_content} {
		tcl_puts -nonewline $::rivet::output_buffer
	}
	set ::rivet::output_buffer ""
}

proc rivet_error {} {
	global errorInfo
	if {!$::rivet::header_sent} {
		set ::rivet::header_sent 1
		tcl_puts "Content-type: text/html"
		tcl_puts ""
	}

	set uidprefix ""
	catch {
		package require Tclx
		set uidprefix "[id userid]-"
	}

	set caseid {ERROR}
	catch {
		set caseid $uidprefix[clock seconds]-[pid][expr abs([clock clicks])]
	}

	if {![info exists ::env(SERVER_ADMIN)]} {
		set ::env(SERVER_ADMIN) ""
	}

	tcl_puts stderr "BEGIN_CASENUMBER=$caseid"
	tcl_puts stderr "GLOBALS: [info globals]"
	tcl_puts stderr "***********************"
	tcl_puts stderr "$errorInfo"
	tcl_puts stderr "END_CASENUMBER=$caseid"

	tcl_puts {<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">}
	tcl_puts {<html><head>}
	tcl_puts {<title>Application Error</title>}
	tcl_puts {</head><body>}
	tcl_puts {<h1>Application Error</h1>}
	tcl_puts {<p>An error has occured while processing your request.</p>}
	tcl_puts "<p>This error has been assigned the case number <tt>$caseid</tt>.</p>"
	tcl_puts "<p>Please reference this case number if you chose to contact the <a href=\"mailto:$::env(SERVER_ADMIN)?subject=case $caseid\">webmaster</a>"
	tcl_puts {</body></html>}

}

proc rivet_puts args {
	if {[lindex $args 0] == "-nonewline"} {
		set appendchar ""
		set args [lrange $args 1 end]
	} else {
		set appendchar "\n"
	}

	if {[llength $args] == 2} {
		set fd [lindex $args 0]
		set args [lrange $args 1 end]
	} else {
		set fd stdout
	}

	if {!$::rivet::header_sent && $fd == "stdout"} {
		append ::rivet::output_buffer [lindex $args 0]$appendchar

		if {[string length $::rivet::output_buffer] >= 1024} {
			rivet_flush
		}
	} else {
		if {$fd == "stdout"} {
			if {!$::rivet::send_no_content} {
				tcl_puts -nonewline $fd [lindex $args 0]$appendchar
			}
		} else {
			tcl_puts -nonewline $fd [lindex $args 0]$appendchar
		}
	}
}

rename puts tcl_puts
rename rivet_puts puts

proc dehexcode {val} {
        set val [string map [list "+" " "] $val]
        foreach pt [split $val %] {
                if {![info exists rval]} { set rval $pt; continue }
		set char [binary format c 0x[string range $pt 0 1]]
                append rval "$char[string range $pt 2 end]"
        }
        if {![info exists rval]} { set rval "" }
        return $rval
}

proc var_qs args {
	set cmd [lindex $args 0]
	set var [lindex $args 1]
	set defval [lindex $args 2]

	return [_var get $cmd $var $defval]
}

proc var_post args {
	set cmd [lindex $args 0]
	set var [lindex $args 1]
	set defval [lindex $args 2]

	return [_var post $cmd $var $defval]
}

proc var args {
	set cmd [lindex $args 0]
	set var [lindex $args 1]
	set defval [lindex $args 2]

	return [_var all $cmd $var $defval]
}

proc _var args {
	if {![info exists ::rivet::cache_vars]} {
		global env
		array set ::rivet::cache_vars {}
		array set ::rivet::cache_vars_qs {}
		array set ::rivet::cache_vars_post {}

		if {[info exists env(QUERY_STRING)]} {
			set vars_qs $env(QUERY_STRING)
		} else {
			set vars_qs ""
		}

		set use_post 0
		if {[info exists env(REQUEST_METHOD)]} {
			if {$env(REQUEST_METHOD) == "POST"} {
				set use_post 1
			}
		}

		if {$use_post} {
			if {[info exists env(CONTENT_TYPE)]} {
				set work [split $::env(CONTENT_TYPE) {;}]
				set contenttype [lindex $work 0]
				set vars [lrange $work 1 end]

				set ::rivet::cache_vars_contenttype [string trim $contenttype]
				foreach varval $vars {
					set work [split $varval {=}]
					set var [string trim [lindex $work 0]]
					set val [string trim [join [lrange $work 1 end] =]]
					set ::rivet::cache_vars_contenttype_var($var) $val
				}
			} else {
				set ::rivet::cache_vars_contenttype "application/form-data"
				array set ::rivet::cache_vars_contenttype_var {}
			}

			if {$::rivet::cache_vars_contenttype != "multipart/form-data"} {
				set vars_post [read stdin]
			} else {
				set vars_post ""

				if {[info exists ::rivet::cache_vars_contenttype_var(boundary)]} {
					# Create temporary directory
					if {[info exists ::env(TMPDIR)]} {
						set tmpdir $::env(TMPDIR)
					} else {
						set tmpdir "/tmp"
					}
					set ::rivet::cache_tmpdir [file join $tmpdir rivet-upload-[pid][expr rand()]]
					catch {
						file mkdir $::rivet::cache_tmpdir
						file attributes $::rivet::cache_tmpdir -permissions 0700
					}

					# Copy stdin to file in temporary directory
					set tmpfile [file join $::rivet::cache_tmpdir stdin]
					set tmpfd [open $tmpfile w]
					fconfigure $tmpfd -translation [list binary binary]
					fconfigure stdin -translation [list binary binary]
					fcopy stdin $tmpfd
					close $tmpfd

					# Split out everything with a content-type into a seperate file, noting this for "upload" to handle
					# Everything else put in "vars_post"
					set tmpfd [open $tmpfile r]
					while 1 {
						gets $tmpfd line
						if {[eof $tmpfd]} {
							break
						}
					}
					close $tmpfd

					# Cleanup temporary directory if no files have been saved there, otherwise schedule this cleanup atexit
					catch {
#						file delete -force -- $::rivet::cache_tmpdir
					}
				}
			}
		} else {
			set vars_post ""
		}

		foreach varpair [split $vars_qs &] {
			set varpair [split $varpair =]
			set var [lindex $varpair 0]
			set value [dehexcode [lindex $varpair 1]]
			lappend ::rivet::cache_vars_qs($var) $value
			lappend ::rivet::cache_vars($var) $value
		}
		foreach varpair [split $vars_post &] {
			set varpair [split $varpair =]
			set var [lindex $varpair 0]
			set value [dehexcode [lindex $varpair 1]]
			lappend ::rivet::cache_vars_post($var) $value
			lappend ::rivet::cache_vars($var) $value
		}
	}

	set type [lindex $args 0]
	set cmd [lindex $args 1]

	switch -- $type {
		"get" {
			upvar #0 ::rivet::cache_vars_qs cachevar
		}
		"post" {
			upvar #0 ::rivet::cache_vars_post cachevar
		}
		default {
			upvar #0 ::rivet::cache_vars cachevar
		}
	}

	switch -- $cmd {
		"get" {
			set var [lindex $args 2]
			set defval [lindex $args 3]
			if {[info exists cachevar($var)]} {
				set retval [join $cachevar($var)]
			} else {
				set retval $defval
			}
		}
		"list" {
			set var [lindex $args 2]
			if {[info exists cachevar($var)]} {
				set retval $cachevar($var)
			} else {
				set retval [list]
			}
		}
		"number" {
			set retval [llength [array names cachevar]]
		}
		"exists" {
			set var [lindex $args 2]
			set retval [info exists cachevar($var)]
		}
		"all" {
			foreach var [array names cachevar] {
				lappend retval $var [join $cachevar($var)]
			}
		}
		default {
			return -code error "bad option \"$cmd\": must be get, list, number, exists, or all"
		}
	}

	if {![info exists retval]} {
		return ""
	}

	return $retval
}

proc parse {file} {
	return [eval [rivet::parserivet $file]]
}

proc headers args {
	set cmd [lindex $args 0]
	switch -- $cmd {
		"set" {
			set var [lindex $args 1]
			set val [lindex $args 2]
			set ::rivet::header_pairs($var) $val
		}
		"add" {
			set var [lindex $args 1]
			set val [lindex $args 2]
			append ::rivet::header_pairs($var) $val
		}
		"type" {
			set val [lindex $args 1]
			set ::rivet::header_type $val
		}
		"redirect" {
			set val [lindex $args 1]
			set ::rivet::header_redirect $val
			rivet_flush
		}
		"numeric" {
		}
		default {
			return -code error "bad option \"$cmd\": must be set, add, type, redirect, or numeric"
		}
	}
}

proc abort_page {} {
	exit 0
}

proc no_body {} {
	set ::rivet::send_no_content 1
}

proc load_env {{var ::request::env}} {
	upvar 1 $var envArray

	array set envArray [array get ::env]
}

proc env {var} {
	if {![info exists ::env($var)]} {
		return ""
	}

	return $::env($var)
}

proc load_headers args { }

# Maybe this should go somewhere else ?
namespace eval request {
	proc global args {
		foreach var $args {
			namespace eval request "upvar #0 ::request::$var $var"
		}
	}
}


# We need to fill these in, of course.

proc makeurl args { return -code error "makeurl not implemented yet"}
proc upload args { return -code error "upload not implemented yet" }
proc virtual_filename args { return -code error "virtual_filename not implemented yet" }
