#! /usr/bin/env tclsh

package require starkit
starkit::startup

set mytopdir $starkit::topdir

package require tclrivet

catch {
	foreach {var val} [array get ::env] {
		puts "$var = \"$val\"<br>"
	}
}

rivet_flush
