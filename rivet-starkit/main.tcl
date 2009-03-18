#! /usr/bin/env tclsh


package require starkit
starkit::startup

set mytopdir $starkit::topdir

package require tclrivet

# Determine if a sub-file has been requested
## Sanity check
set indexfiles [list index.rvt index.html index.htm __INDEX__]
if {[info exists ::env(PATH_INFO)]} {
	if {[string match "*..*" $::env(PATH_INFO)]} {
		unset ::env(PATH_INFO)
	}
}
if {[info exists ::env(PATH_INFO)]} {
	set targetfile "$mytopdir/$::env(PATH_INFO)"
} else {
	foreach chk_indexfile $indexfiles {
		set targetfile [file join $mytopdir $chk_indexfile]
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

# Check for file existance
if {![file exists $targetfile]} {
	if {[file tail $targetfile] == "__INDEX__"} {
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
switch -glob -- $targetfile {
	"*.rvt" {
		cd [file dirname $targetfile]
		parse $targetfile	
	}
	"*.png" {
	}
}

rivet_flush
