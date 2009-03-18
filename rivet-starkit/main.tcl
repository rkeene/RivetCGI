#! /usr/bin/env tclsh


package require starkit
starkit::startup

package require tclrivet

# Determine if a sub-file has been requested
## Sanity check
set indexfiles [list index.rvt index.html index.htm __RIVETSTARKIT_INDEX__]
if {[info exists ::env(PATH_INFO)]} {
	if {[string match "*..*" $::env(PATH_INFO)]} {
		unset ::env(PATH_INFO)
	}
}
if {[info exists ::env(PATH_INFO)]} {
	set targetfile "$starkit::topdir/$::env(PATH_INFO)"
} else {
	foreach chk_indexfile $indexfiles {
		set targetfile [file join $starkit::topdir $chk_indexfile]
		if {[file exists $targetfile]} {
			break
		}
	}
}

# If the file specified is a directory, look for an index
if {[file isdirectory $targetfile]} {
	foreach chk_indexfile $indexfiles {
		set chk_targetfile [file join $targetfile $chk_indexfile]
		if {[file exists $chk_targetfile]} {
			break
		}
	}
	set targetfile $chk_targetfile
}

# Check the path to ensure that is inside the starkit
set targetfile [file normalize $targetfile]
set srcdir [file dirname [file normalize [info script]]]
if {![string match "$srcdir/*" $targetfile]} {
	set targetfile "__RIVETSTARKIT_FORBIDDEN__"
}

# Check every component of the pathname for a ".htaccess" file, and stop processing if one is found
set work [file split $targetfile]
set srcwork [file split $srcdir]
set work [lrange $work [llength $srcwork] end]
foreach component $work {
	set chk_htaccess [file join $srcdir .htaccess]
	if {[file exists $chk_htaccess]} {
		set targetfile "__RIVETSTARKIT_FORBIDDEN__"
		break
	}
	set srcdir [file join $srcdir $component]
}

# Check for file existance
if {![file exists $targetfile]} {
	if {$targetfile == "__RIVETSTARKIT_FORBIDDEN__"} {
		# Return a 403 (Forbidden)
		headers numeric 403
		puts "<html><head><title>Forbidden</title></head><body><h1>File Access Forbidden</h1></body>"
	} elseif {[file tail $targetfile] == "__RIVETSTARKIT_INDEX__"} {
		# Return a 403 (Forbidden)
		headers numeric 403
		puts "<html><head><title>Directory Listing Forbidden</title></head><body><h1>Directory Listing Forbidden</h1></body>"
	} else {
		# Return a 404 (File Not Found)
		headers numeric 404
		puts "<html><head><title>File Not Found</title></head><body><h1>File Not Found</h1></body>"
	}

	rivet_flush
	exit 0
}

# Determine what to do with the file based on its filename
switch -glob -- [string tolower $targetfile] {
	"*.rvt" {
		cd [file dirname $targetfile]

		if {[catch {
			parse $targetfile	
		} err]} {
			rivet_error
			rivet_flush
			exit 0
		}
	}
	"*.htm" - "*.html" {
		set statictype "text/html"
	}
	"*.png" {
		set statictype "image/png"
	}
	"*.tcl" - "*.txt" - "*.text" - "*/readme" {
		set statictype "text/plain"
	}
	default {
		set statictype "application/octet-stream"
	}
}

# Dump static files
if {[info exists statictype]} {
	headers type $statictype
	set fd [open $targetfile r]
	fconfigure $fd -encoding binary -translation {binary binary}
	fconfigure stdout -encoding binary -translation {binary binary}
	while 1 {
		set data [read $fd 1024]
		if {[string length $data] == 0} {
			break
		}
		puts -nonewline $data
	}
	close $fd
}

# Flush the output stream
rivet_flush
