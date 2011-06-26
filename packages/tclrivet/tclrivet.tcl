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

namespace eval rivet {}
namespace eval rivet {
	proc ::rivet::reset {} {
		unset -nocomplain ::rivet::header_pairs ::rivet::statuscode ::rivet::header_redirect ::rivet::cache_vars ::rivet::cache_vars_qs ::rivet::cache_vars_post ::rivet::cache_vars_contenttype ::rivet::cache_vars_contenttype_var ::rivet::cache_tmpdir ::rivet::transfer_encoding ::rivet::sent_final_chunk ::rivet::connection

		if {[info exists ::rivet::cache_uploads]} {
			foreach {var namefd} [array get ::rivet::cache_uploads] {
				set fd [lindex $namefd 1]

				catch {
					close $fd
				}
			}

			unset ::rivet::cache_uploads
		}

		array set ::rivet::header_pairs {}
		set ::rivet::header_type "text/html"
		set ::rivet::header_sent 0
		set ::rivet::output_buffer ""
		set ::rivet::send_no_content 0

		catch {
			namespace delete ::request
		}

		namespace eval ::request {}

		proc ::request::global args {
			foreach var $args {
				namespace eval request "upvar #0 ::request::$var $var"
			}
		}
	}

	proc statuscode_to_str {sc} {
		switch -- $sc {
			100 { set retval "Continue" }
			101 { set retval "Switching Protocols" }
			200 { set retval "OK" }
			201 { set retval "Created" }
			202 { set retval "Accepted" }
			203 { set retval "Non-Authoritative Information" }
			204 { set retval "No Content" }
			205 { set retval "Reset Content" }
			206 { set retval "Partial Content" }
			300 { set retval "Multiple Choices" }
			301 { set retval "Moved Permanently" }
			302 { set retval "Found" }
			303 { set retval "See Other" }
			304 { set retval "Not Modified" }
			305 { set retval "Use Proxy" }
			307 { set retval "Temporary Redirect" }
			400 { set retval "Bad Request" }
			401 { set retval "Unauthorized" }
			402 { set retval "Payment Required" }
			403 { set retval "Forbidden" }
			404 { set retval "Not Found" }
			405 { set retval "Method Not Allowed" }
			406 { set retval "Not Acceptable" }
			407 { set retval "Proxy Authentication Required" }
			408 { set retval "Request Timeout" }
			409 { set retval "Conflict" }
			410 { set retval "Gone" }
			411 { set retval "Length Required" }
			412 { set retval "Precondition Failed" }
			413 { set retval "Request Entity Too Large" }
			414 { set retval "Request-URI Too Long" }
			415 { set retval "Unsupported Media Type" }
			416 { set retval "Requested Range Not Satisfiable" }
			417 { set retval "Expectation Failed" }
			500 { set retval "Internal Server Error" }
			501 { set retval "Not Implemented" }
			502 { set retval "Bad Gateway" }
			503 { set retval "Service Unavailable" }
			504 { set retval "Gateway Timeout" }
			505 { set retval "HTTP Version Not Supported" }
			default {
				set retval "Unknown"
			}
		}

		return $retval
	}

	::rivet::reset
}

proc rivet_flush args {
	set final_flush 0
	if {[lsearch -exact $args "-final"] != "-1"} {
		set final_flush 1
	}

	set outchan stdout
	if {[info exists ::env(RIVET_INTERFACE)]} {
		set outchan [lindex $::env(RIVET_INTERFACE) 2]
		array set headers [lindex $::env(RIVET_INTERFACE) 4]
	}

	if {!$::rivet::header_sent} {
		set ::rivet::header_sent 1

		if {![info exists ::rivet::statuscode]} {
			set ::rivet::statuscode 200
		}

		::rivet::cgi_server_writehttpheader $::rivet::statuscode

		if {![info exists ::rivet::header_redirect]} {
			tcl_puts $outchan "Content-type: $::rivet::header_type"
			foreach {var val} [array get ::rivet::header_pairs] {
				tcl_puts $outchan "$var: $val"
			}
		} else {
			tcl_puts $outchan "Location: $::rivet::header_redirect"
			tcl_puts $outchan ""
			abort_page
		}
		tcl_puts $outchan ""

		unset -nocomplain ::rivet::statuscode ::rivet::header_redirect ::rivet::header_pairs
	}

	if {!$::rivet::send_no_content && [string length $::rivet::output_buffer] != "0"} {
		if {[info exists ::rivet::transfer_encoding] && $::rivet::transfer_encoding == "chunked"} {
			fconfigure $outchan -translation "crlf"

			tcl_puts $outchan [format %x [string length $::rivet::output_buffer]]
		}

		fconfigure $outchan -translation binary
		tcl_puts -nonewline $outchan $::rivet::output_buffer

		if {[info exists ::rivet::transfer_encoding] && $::rivet::transfer_encoding == "chunked"} {
			fconfigure $outchan -translation "crlf"

			tcl_puts $outchan ""

			fconfigure $outchan -translation binary
		}
	}

	if {$final_flush == "1"} {
		if {[info exists ::rivet::transfer_encoding] && $::rivet::transfer_encoding == "chunked" && ![info exists ::rivet::sent_final_chunk]} {
			fconfigure $outchan -translation "crlf"

			tcl_puts $outchan "0"
			tcl_puts $outchan ""

			fconfigure $outchan -translation binary

			set ::rivet::sent_final_chunk 1
			set ::rivet::send_no_content 1
		}
	}

	set ::rivet::output_buffer ""
}

proc rivet_error {} {
	set outchan stdout
	set errchan stderr
	if {[info exists ::env(RIVET_INTERFACE)]} {
		set outchan [lindex $::env(RIVET_INTERFACE) 2]
		set errchan [lindex $::env(RIVET_INTERFACE) 3]
	}

	global errorInfo
	if {[info exists errorInfo]} {
		set incoming_errorInfo $errorInfo
	} else {
		set incoming_errorInfo "<<NO ERROR>>"
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

	tcl_puts $errchan "BEGIN_CASENUMBER=$caseid"
	tcl_puts $errchan "GLOBALS: [info globals]"
	tcl_puts $errchan "***********************"
	tcl_puts $errchan "$incoming_errorInfo"
	tcl_puts $errchan "END_CASENUMBER=$caseid"

	append errmsg {<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">} "\n"
	append errmsg {<html><head>} "\n"
	append errmsg {<title>Application Error</title>} "\n"
	append errmsg {</head><body>} "\n"
	append errmsg {<h1>Application Error</h1>} "\n"
	append errmsg {<p>An error has occured while processing your request.</p>} "\n"
	append errmsg "<p>This error has been assigned the case number <tt>$caseid</tt>.</p>" "\n"
	append errmsg "<p>Please reference this case number if you chose to contact the <a href=\"mailto:$::env(SERVER_ADMIN)?subject=case $caseid\">webmaster</a>" "\n"
	append errmsg {</body></html>} "\n"

	if {!$::rivet::header_sent} {
		set ::rivet::header_sent 1
		::rivet::cgi_server_writehttpheader 200 [string length $errmsg]
		tcl_puts $outchan "Content-type: text/html"
		tcl_puts $outchan ""
		tcl_puts -nonewline $outchan $errmsg
	}

}

proc rivet_puts args {
	set outchan stdout
	if {[info exists ::env(RIVET_INTERFACE)]} {
		set outchan [lindex $::env(RIVET_INTERFACE) 2]
	}

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

		if {[string length $::rivet::output_buffer] >= 16384} {
			rivet_flush
		}
	} else {
		if {$fd == "stdout"} {
			append ::rivet::output_buffer [lindex $args 0]$appendchar

			rivet_flush
		} else {
			tcl_puts -nonewline $fd [lindex $args 0]$appendchar
		}
	}
}

rename puts tcl_puts
rename rivet_puts puts

proc ::rivet::dehexcode {val} {
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

	return [::rivet::_var get $cmd $var $defval]
}

proc var_post args {
	set cmd [lindex $args 0]
	set var [lindex $args 1]
	set defval [lindex $args 2]

	return [::rivet::_var post $cmd $var $defval]
}

proc var args {
	set cmd [lindex $args 0]
	set var [lindex $args 1]
	set defval [lindex $args 2]

	return [::rivet::_var all $cmd $var $defval]
}

proc ::rivet::_var args {
	set inchan stdin
	if {[info exists ::env(RIVET_INTERFACE)]} {
		set inchan [lindex $::env(RIVET_INTERFACE) 1]
	}

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
				set work [split $env(CONTENT_TYPE) {;}]
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
				if {[info exists env(CONTENT_LENGTH)]} {
					fconfigure $inchan -blocking 1
					set vars_post [read $inchan $env(CONTENT_LENGTH)]
				} else {
					set vars_post [read $inchan]
				}
			} else {
				set vars_post ""

				if {[info exists ::rivet::cache_vars_contenttype_var(boundary)]} {
					# Create temporary directory
					if {[info exists env(TMPDIR)]} {
						set tmpdir $env(TMPDIR)
					} else {
						set tmpdir "/tmp"
					}
					set cache_tmpdir [file join $tmpdir rivet-upload-[pid][expr rand()]]
					catch {
						file mkdir $cache_tmpdir
						file attributes $cache_tmpdir -permissions 0700
					}

					if {[info exists env(CONTENT_LENGTH)]} {
						set content_length $env(CONTENT_LENGTH)
					} else {
						set content_length -1
					}

					set vals_and_fds_arr [::rivet::handle_upload $inchan $cache_tmpdir $::rivet::cache_vars_contenttype_var(boundary) $content_length]
					array set vals [lindex $vals_and_fds_arr 0]
					array set fds [lindex $vals_and_fds_arr 1]

					foreach var [array names vals] {
						if {[info exists fds($var)]} {
							set fd [lindex $fds($var) 0]
							set contenttype [lindex $fds($var) 1]
							set size [lindex $fds($var) 2]

							set ::rivet::cache_uploads($var) [list $vals($var) $fd $contenttype $size]
						} else {
							set value $vals($var)
							lappend ::rivet::cache_vars_post($var) $value
							lappend ::rivet::cache_vars($var) $value
						}
					}

					# Cleanup temporary directory
					catch {
						file delete -force -- $cache_tmpdir
					}
				}
			}
		} else {
			set vars_post ""
		}

		foreach varpair [split $vars_qs &] {
			set varpair [split $varpair =]
			set var [lindex $varpair 0]
			set value [::rivet::dehexcode [lindex $varpair 1]]
			lappend ::rivet::cache_vars_qs($var) $value
			lappend ::rivet::cache_vars($var) $value
		}
		foreach varpair [split $vars_post &] {
			set varpair [split $varpair =]
			set var [lindex $varpair 0]
			set value [::rivet::dehexcode [lindex $varpair 1]]
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

proc ::rivet::handle_upload {fd workdir seperator content_length} {
	array set args {}
	array set argsfd {}

	set seperator "--${seperator}"

	# Select random base name for temporary files
	set basename_tmpfile [file join "$workdir" "upload-[expr rand()][expr rand()][expr rand()]"]

	# Configure fd
	fconfigure $fd -translation binary

	# Process fd into files or arguments
	if {$content_length == -1 || $content_length > 1024} {
		set bytes_to_read 1024
	} else {
		set bytes_to_read $content_length
	}

	if {$content_length != -1} {
		incr content_length -${bytes_to_read}
	}

	set nextblock "\015\012[read $fd $bytes_to_read]"
	set line_oriented 0
	set next_line_oriented 0
	set idx 0
	while 1 {
		if {[string length $nextblock] == 0} {
			if {$content_length == -1 && [eof $fd]} {
				break
			}
			if {$content_length == 0} {
				break
			}
		}


		if {$content_length == -1 || $content_length > 1024} {
			set bytes_to_read 1024
		} else {
			set bytes_to_read $content_length
		}

		if {$content_length != -1} {
			incr content_length -${bytes_to_read}
		}

		set block $nextblock
		if {$bytes_to_read > 0} {
			set nextblock [read $fd $bytes_to_read]
		} else {
			set nextblock ""
		}
		set bigblock "${block}${nextblock}"

		if {$next_line_oriented} {
			set line_oriented 1

			set next_line_oriented 0
		}

		set blockend -1
		while 1 {
			set blockend [string first "\015\012$seperator\015\012" $bigblock [expr {$blockend + 1}]]

			if {$blockend == -1} {
				set blockend [string first "\015\012${seperator}--\015\012" $bigblock [expr {$blockend + 1}]]
			}

			if {$blockend == -1} {
				break
			}

			if {($blockend + [string length $seperator] + 4) >= [string length $block]} {
				break
			}

			set nextblockstart_idx [expr {$blockend + [string length $seperator] + 4}]
			set nextblockstart [string range $block $nextblockstart_idx end]

			set nextblock "$nextblockstart$nextblock"
			set block [string range $block 0 [expr {$blockend-1}]]

			set next_line_oriented 1
		}

		while {$line_oriented} {
			set line_end [string first "\015\012" $block 0]
			if {$line_end == -1} {
				append line $block

				break
			}

			append line [string range $block 0 [expr {$line_end - 1}]]
			set block "[string range $block [expr {$line_end + 2}] end]"

			if {$line == ""} {
				unset -nocomplain name tmpfile filename

				if {[info exists lineinfo([list content-disposition name])]} {
					set name $lineinfo([list content-disposition name])
				}

				if {[info exists lineinfo([list content-disposition filename])]} {
					set filename $lineinfo([list content-disposition filename])
				}

				if {[info exists outfd]} {
					close $outfd

					unset outfd
				}

				set appendmode "var"
				if {[info exists lineinfo(content-type)]} {
					# We have data that should be stored in a file
					set tmpfile "${basename_tmpfile}-${idx}"
					incr idx

					set outfd [open $tmpfile "w"]
					fconfigure $outfd -translation binary

					set contenttype $lineinfo(content-type)

					if {[info exists name]} {
						set tmpfd [open $tmpfile "r"]
						fconfigure $tmpfd -translation binary

						set argsfd($name) [list $tmpfd $contenttype]

						if {![info exists filename]} {
							set args($name) ""
						} else {
							set args($name) $filename
						}

						set appendmode "file"
					}
				}

				if {[info exists tmpfile]} {
					file delete -- $tmpfile
				}

				unset -nocomplain lineinfo

				set line_oriented 0

				continue
			}

			set work [split $line ":"]

			set cmd [lindex $work 0]
			set cmd [string trim [string tolower $cmd]]

			set value [string trim [join [lrange $work 1 end] ":"]]

			set work [split $value ";"]
			set value [lindex $work 0]

			set lineinfo([list $cmd]) $value

			foreach part [lrange $work 1 end] {
				set part [string trim $part]

				set partwork [split $part "="]

				set partvar [lindex $partwork 0]
				set partval [join [lrange $partwork 1 end] "="]

				if {[string index $partval 0] == "\"" && [string index $partval end] == "\""} {
					set partval [string range $partval 1 end-1]
				}

				set lineinfo([list $cmd $partvar]) $partval
			}

			set line ""
		}

		if {![info exists appendmode]} {
			continue
		}

		switch -- $appendmode {
			"file" {
				puts -nonewline $outfd $block
			}
			"var" {
				if {[info exists name]} {
					append args($name) $block
				}
			}
		}
	}

	foreach var [array names argsfd] {
		set fd [lindex $argsfd($var) 0]
		seek $fd 0 end

		lappend argsfd($var) [tell $fd]

		seek $fd 0 start
	}

	return [list [array get args] [array get argsfd]]
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
			set val [lindex $args 1]
			set ::rivet::statuscode $val
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
 
proc ::rivet::cgi_server_writehttpheader {statuscode {useenv ""} {length -1}} {
	if {$useenv eq ""} {
		upvar ::env env
	} else {
		array set env $useenv
	}

	set outchan stdout

	if {[info exists env(RIVET_INTERFACE)]} {
		set outchan [lindex $env(RIVET_INTERFACE) 2]
		array set headers [lindex $env(RIVET_INTERFACE) 4]

		if {[lindex $env(RIVET_INTERFACE) 0] == "FULLHEADERS"} {
			fconfigure $outchan -translation crlf

			tcl_puts $outchan "HTTP/1.1 $statuscode [::rivet::statuscode_to_str $statuscode]"
			tcl_puts $outchan "Date: [clock format [clock seconds] -format {%a, %d %b %Y %H:%M:%S GMT} -gmt 1]"
			tcl_puts $outchan "Server: Default"

			unset -nocomplain ::rivet::transfer_encoding

			if {$headers(CONNECTION) == "keep-alive"} {
				if {$length != -1} {
					tcl_puts $outchan "Content-Length: $length"
					tcl_puts $outchan "Connection: keep-alive"
					set ::rivet::connection "keep-alive"
				} else {
					if {$statuscode == "200"} {
						tcl_puts $outchan "Transfer-Encoding: chunked"
						tcl_puts $outchan "Connection: keep-alive"
						set ::rivet::transfer_encoding "chunked"
						set ::rivet::connection "keep-alive"
					} else {
						tcl_puts $outchan "Connection: close"
						set ::rivet::connection "close"
					}
				}
			} else {
				tcl_puts $outchan "Connection: close"
				set ::rivet::connection "close"
			}

			fconfigure $outchan -translation binary

			return
		}
	}

	tcl_puts $outchan "Status: $statuscode [::rivet::statuscode_to_str $statuscode]"
}

proc load_headers args { }

proc upload args {
	set cmd [lindex $args 0]
	set name [lindex $args 1]
	set filename [lindex $args 2]

	# Ensure that we have processed arguments
	::rivet::_var post number

	switch -- $cmd {
		channel {
			set fd [lindex $::rivet::cache_uploads($name) 1]

			return $fd
		}
		save {
			set fd [lindex $::rivet::cache_uploads($name) 1]
			set ofd [open $filename "w"]
			fconfigure $ofd -translation binary

			set start [tell $fd]
			seek $fd 0 start

			fcopy $fd $ofd

			seek $fd $start start

			close $ofd
		}
		data {
			set fd [lindex $::rivet::cache_uploads($name) 1]

			set start [tell $fd]
			seek $fd 0 start

			set retval [read $fd]

			seek $fd $start start

			return $fd
		}
		exists {
			return [info exists ::rivet::cache_uploads($name)]
		}
		size {
			set size [lindex $::rivet::cache_uploads($name) 3]

			return $size
		}
		type {
			set type [lindex $::rivet::cache_uploads($name) 2]

			return $type
		}
		filename {
			set remote_filename [lindex $::rivet::cache_uploads($name) 0]

			return $remote_filename
		}
		tempname {
			return -code error "\"upload tempname\" not implemented"
		}
		names {
			return [array names ::rivet::cache_uploads]
		}
	}
}

# We need to fill these in, of course.

proc makeurl args { return -code error "makeurl not implemented yet"}
proc virtual_filename args { return -code error "virtual_filename not implemented yet" }
