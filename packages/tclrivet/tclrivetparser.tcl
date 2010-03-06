# tclrivetparser.tcl -- parse Rivet files in pure Tcl.

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

# $Id: tclrivetparser.tcl,v 1.3 2004/02/24 10:24:34 davidw Exp $

package provide tclrivetparser 0.1

namespace eval rivet {
    set starttag <?
    set endtag   ?>
    set outputcmd {puts -nonewline}
    namespace export parserivetdata
}

# rivet::setoutputcmd --
#
#	Set the output command used.  In regular Rivet scripts, we use
#	puts, but that might not be ideal if you want to parse Rivet
#	pages in a Tcl script.
#
# Arguments:
#	newcmd - if empty, return the current command, if not, set the
#	command.
#
# Side Effects:
#	May set the output command used.
#
# Results:
#	The current output command.

proc rivet::setoutputcmd { {newcmd ""} } {
    variable outputcmd

    if { $outputcmd == "" } {
	return $outputcmd
    }
    set outputcmd $newcmd
}

# rivet::parse --
#
#	Parse a buffer, transforming <? and ?> into the appropriate
#	Tcl strings.  Note that initial 'puts "' is not performed
#	here.
#
# Arguments:
#	data - data to scan.
#	outbufvar - name of the output buffer.
#
# Side Effects:
#	None.
#
# Results:
#	Returns the $inside variable - 1 if we are inside a <? ?>
#	section, 0 if we outside.

proc rivet::parse { data outbufvar } {
    variable outputcmd
    variable starttag
    variable endtag
    set inside 0

    upvar $outbufvar outbuf

    set i 0
    set p 0
    set len [expr {[string length $data] + 1}]
    set next [string index $data 0]
    while {$i < $len} {
	incr i
	set cur $next
	set next [string index $data $i]
	if { $inside == 0 } {
	    # Outside the delimiting tags.
	    if { $cur == [string index $starttag $p] } {
		incr p
		if { $p == [string length $starttag] } {
		    append outbuf "\"\n"
		    set inside 1
		    set p 0
		    continue
		}
	    } else {
		if { $p > 0 } {
		    append outbuf [string range $starttag 0 [expr {$p - 1}]]
		    set p 0
		}
		switch -exact -- $cur {
		    "\{" {
			append outbuf "\\{"
		    }
		    "\}" {
			append outbuf "\\}"
		    }
		    "\$" {
			append outbuf "\\$"
		    }
		    "\[" {
			append outbuf "\\\["
		    }
		    "\]" {
			append outbuf "\\\]"
		    }
		    "\"" {
			append outbuf "\\\""
		    }
		    "\\" {
			append outbuf "\\\\"
		    }
		    default {
			append outbuf $cur
		    }
		}
		continue
	    }
	} else {
	    # Inside the delimiting tags.
	    if { $cur == [string index $endtag $p] } {
		incr p
		if { $p == [string length $endtag] } {
		    append outbuf "\n$outputcmd \""
		    set inside 0
		    set p 0
		}
	    } else {
		if { $p > 0 } {
		    append outbuf [string range $endtag 0 [expr $p - 1]]
		    set p 0
		}
		append outbuf $cur
	    }
	}
    }
    return $inside
}


# rivet::parserivetdata --
#
#	Parse a rivet script, and add the relavant opening and closing
#	bits.
#
# Arguments:
#	data - data to parse.
#
# Side Effects:
#	None.
#
# Results:
#	Returns the parsed script.

proc rivet::parserivetdata { data } {
    variable outputcmd
    set outbuf "namespace eval request {\n"
    append outbuf "$outputcmd \""
    if { [parse $data outbuf] == 0 } {
	append outbuf "\"\n"
    }

    append outbuf "\n}"
    return $outbuf
}

proc rivet::parserivet {file} {

	lappend ::rivet::parsestack $file

	set buffer ""
	catch {
		set fd [open $file]
		while {1} {
			set data [read $fd 16384]
			if {$data == ""} {
				break
			}

			append buffer $data
		}
		close $fd
	}

	set ret [parserivetdata $buffer]

	set ::rivet::parsestack [lrange $rivet::parsestack 0 end-1]

	return $ret
}

rename info __tcl_rivet_info
proc info args {
	if {[lindex $args 0] == "script"} {
		set ret [__tcl_rivet_info script]
		if {$ret == "" && [info exists ::rivet::parsestack]} {
			set ret [lindex $::rivet::parsestack end]
		}
	} else {
		set cmd [linsert $args 0 __tcl_rivet_info]
		set ret [uplevel $cmd]
	}

	return $ret
}
