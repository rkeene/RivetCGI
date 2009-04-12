#! /usr/bin/env tclsh

package require starkit
package require tclrivet

starkit::startup

proc call_page {} {
	upvar ::env env

	# Determine if a sub-file has been requested
	## Sanity check
	set indexfiles [list index.rvt index.html index.htm __RIVETSTARKIT_INDEX__]
	if {[info exists env(PATH_INFO)]} {
		if {[string match "*..*" $env(PATH_INFO)]} {
			unset env(PATH_INFO)
		}
	}
	if {[info exists env(PATH_INFO)]} {
		set targetfile "$::starkit::topdir/$env(PATH_INFO)"
	} else {
		foreach chk_indexfile $indexfiles {
			set targetfile [file join $::starkit::topdir $chk_indexfile]
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
	set chk_srcdir $srcdir
	set work [file split $targetfile]
	set srcwork [file split $chk_srcdir]
	set work [lrange $work [llength $srcwork] end]
	foreach component $work {
		set chk_htaccess [file join $chk_srcdir .htaccess]
		if {[file exists $chk_htaccess]} {
			set targetfile "__RIVETSTARKIT_FORBIDDEN__"
			break
		}
		set chk_srcdir [file join $chk_srcdir $component]
	}
	
	# Deny forbidden files
	if {[file dirname $targetfile] == "$srcdir"} {
		switch -- [file tail $targetfile] {
			"main.tcl" - "boot.tcl" - "config.tcl" {
				set targetfile "__RIVETSTARKIT_FORBIDDEN__"
			}
		}
	}
	
	# Check for file existance
	if {![file exists $targetfile]} {
		tcl_puts "Content-type: text/html"
		if {$targetfile == "__RIVETSTARKIT_FORBIDDEN__"} {
			# Return a 403 (Forbidden)
			rivet_cgi_server_writehttpheader 403
			tcl_puts ""
			tcl_puts "<html><head><title>Forbidden</title></head><body><h1>File Access Forbidden</h1></body>"
		} elseif {[file tail $targetfile] == "__RIVETSTARKIT_INDEX__"} {
			# Return a 403 (Forbidden)
			rivet_cgi_server_writehttpheader 403
			tcl_puts ""
			tcl_puts "<html><head><title>Directory Listing Forbidden</title></head><body><h1>Directory Listing Forbidden</h1></body>"
		} else {
			# Return a 404 (File Not Found)
			rivet_cgi_server_writehttpheader 404
			tcl_puts ""
			tcl_puts "<html><head><title>File Not Found</title></head><body><h1>File Not Found</h1></body>"
		}

		return
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
				return
			}
	
			# Flush the output stream
			rivet_flush
			return
		}
		"*.ez" { set statictype "application/andrew-inset" }
		"*.atom" { set statictype "application/atom+xml" }
		"*.atomcat" { set statictype "application/atomcat+xml" }
		"*.atomsvc" { set statictype "application/atomsvc+xml" }
		"*.ccxml" { set statictype "application/ccxml+xml" }
		"*.davmount" { set statictype "application/davmount+xml" }
		"*.ecma" { set statictype "application/ecmascript" }
		"*.pfr" { set statictype "application/font-tdpfr" }
		"*.stk" { set statictype "application/hyperstudio" }
		"*.js" { set statictype "application/javascript" }
		"*.json" { set statictype "application/json" }
		"*.hqx" { set statictype "application/mac-binhex40" }
		"*.cpt" { set statictype "application/mac-compactpro" }
		"*.mrc" { set statictype "application/marc" }
		"*.ma" - "*.nb" - "*.mb" { set statictype "application/mathematica" }
		"*.mathml" { set statictype "application/mathml+xml" }
		"*.mbox" { set statictype "application/mbox" }
		"*.mscml" { set statictype "application/mediaservercontrol+xml" }
		"*.mp4s" { set statictype "application/mp4" }
		"*.doc" - "*.dot" { set statictype "application/msword" }
		"*.mxf" { set statictype "application/mxf" }
		"*.oda" { set statictype "application/oda" }
		"*.ogg" { set statictype "application/ogg" }
		"*.pdf" { set statictype "application/pdf" }
		"*.pgp" { set statictype "application/pgp-encrypted" }
		"*.asc" - "*.sig" { set statictype "application/pgp-signature" }
		"*.prf" { set statictype "application/pics-rules" }
		"*.p10" { set statictype "application/pkcs10" }
		"*.p7m" - "*.p7c" { set statictype "application/pkcs7-mime" }
		"*.p7s" { set statictype "application/pkcs7-signature" }
		"*.cer" { set statictype "application/pkix-cert" }
		"*.crl" { set statictype "application/pkix-crl" }
		"*.pkipath" { set statictype "application/pkix-pkipath" }
		"*.pki" { set statictype "application/pkixcmp" }
		"*.pls" { set statictype "application/pls+xml" }
		"*.ai" - "*.eps" - "*.ps" { set statictype "application/postscript" }
		"*.cww" { set statictype "application/prs.cww" }
		"*.rdf" { set statictype "application/rdf+xml" }
		"*.rif" { set statictype "application/reginfo+xml" }
		"*.rnc" { set statictype "application/relax-ng-compact-syntax" }
		"*.rl" { set statictype "application/resource-lists+xml" }
		"*.rs" { set statictype "application/rls-services+xml" }
		"*.rsd" { set statictype "application/rsd+xml" }
		"*.rss" { set statictype "application/rss+xml" }
		"*.rtf" { set statictype "application/rtf" }
		"*.sbml" { set statictype "application/sbml+xml" }
		"*.scq" { set statictype "application/scvp-cv-request" }
		"*.scs" { set statictype "application/scvp-cv-response" }
		"*.spq" { set statictype "application/scvp-vp-request" }
		"*.spp" { set statictype "application/scvp-vp-response" }
		"*.sdp" { set statictype "application/sdp" }
		"*.setpay" { set statictype "application/set-payment-initiation" }
		"*.setreg" { set statictype "application/set-registration-initiation" }
		"*.shf" { set statictype "application/shf+xml" }
		"*.smi" - "*.smil" { set statictype "application/smil+xml" }
		"*.rq" { set statictype "application/sparql-query" }
		"*.srx" { set statictype "application/sparql-results+xml" }
		"*.gram" { set statictype "application/srgs" }
		"*.grxml" { set statictype "application/srgs+xml" }
		"*.ssml" { set statictype "application/ssml+xml" }
		"*.plb" { set statictype "application/vnd.3gpp.pic-bw-large" }
		"*.psb" { set statictype "application/vnd.3gpp.pic-bw-small" }
		"*.pvb" { set statictype "application/vnd.3gpp.pic-bw-var" }
		"*.tcap" { set statictype "application/vnd.3gpp2.tcap" }
		"*.pwn" { set statictype "application/vnd.3m.post-it-notes" }
		"*.aso" { set statictype "application/vnd.accpac.simply.aso" }
		"*.imp" { set statictype "application/vnd.accpac.simply.imp" }
		"*.acu" { set statictype "application/vnd.acucobol" }
		"*.atc" - "*.acutc" { set statictype "application/vnd.acucorp" }
		"*.xdp" { set statictype "application/vnd.adobe.xdp+xml" }
		"*.xfdf" { set statictype "application/vnd.adobe.xfdf" }
		"*.ami" { set statictype "application/vnd.amiga.ami" }
		"*.cii" { set statictype "application/vnd.anser-web-certificate-issue-initiation" }
		"*.fti" { set statictype "application/vnd.anser-web-funds-transfer-initiation" }
		"*.atx" { set statictype "application/vnd.antix.game-component" }
		"*.mpkg" { set statictype "application/vnd.apple.installer+xml" }
		"*.aep" { set statictype "application/vnd.audiograph" }
		"*.mpm" { set statictype "application/vnd.blueice.multipass" }
		"*.bmi" { set statictype "application/vnd.bmi" }
		"*.rep" { set statictype "application/vnd.businessobjects" }
		"*.cdxml" { set statictype "application/vnd.chemdraw+xml" }
		"*.mmd" { set statictype "application/vnd.chipnuts.karaoke-mmd" }
		"*.cdy" { set statictype "application/vnd.cinderella" }
		"*.cla" { set statictype "application/vnd.claymore" }
		"*.c4g" - "*.c4d" - "*.c4f" - "*.c4p" - "*.c4u" { set statictype "application/vnd.clonk.c4group" }
		"*.csp" - "*.cst" { set statictype "application/vnd.commonspace" }
		"*.cdbcmsg" { set statictype "application/vnd.contact.cmsg" }
		"*.cmc" { set statictype "application/vnd.cosmocaller" }
		"*.clkx" { set statictype "application/vnd.crick.clicker" }
		"*.clkk" { set statictype "application/vnd.crick.clicker.keyboard" }
		"*.clkp" { set statictype "application/vnd.crick.clicker.palette" }
		"*.clkt" { set statictype "application/vnd.crick.clicker.template" }
		"*.clkw" { set statictype "application/vnd.crick.clicker.wordbank" }
		"*.wbs" { set statictype "application/vnd.criticaltools.wbs+xml" }
		"*.pml" { set statictype "application/vnd.ctc-posml" }
		"*.ppd" { set statictype "application/vnd.cups-ppd" }
		"*.curl" { set statictype "application/vnd.curl" }
		"*.rdz" { set statictype "application/vnd.data-vision.rdz" }
		"*.fe_launch" { set statictype "application/vnd.denovo.fcselayout-link" }
		"*.dna" { set statictype "application/vnd.dna" }
		"*.mlp" { set statictype "application/vnd.dolby.mlp" }
		"*.dpg" { set statictype "application/vnd.dpgraph" }
		"*.dfac" { set statictype "application/vnd.dreamfactory" }
		"*.mag" { set statictype "application/vnd.ecowin.chart" }
		"*.nml" { set statictype "application/vnd.enliven" }
		"*.esf" { set statictype "application/vnd.epson.esf" }
		"*.msf" { set statictype "application/vnd.epson.msf" }
		"*.qam" { set statictype "application/vnd.epson.quickanime" }
		"*.slt" { set statictype "application/vnd.epson.salt" }
		"*.ssf" { set statictype "application/vnd.epson.ssf" }
		"*.es3" - "*.et3" { set statictype "application/vnd.eszigno3+xml" }
		"*.ez2" { set statictype "application/vnd.ezpix-album" }
		"*.ez3" { set statictype "application/vnd.ezpix-package" }
		"*.fdf" { set statictype "application/vnd.fdf" }
		"*.gph" { set statictype "application/vnd.flographit" }
		"*.ftc" { set statictype "application/vnd.fluxtime.clip" }
		"*.fm" - "*.frame" - "*.maker" { set statictype "application/vnd.framemaker" }
		"*.fnc" { set statictype "application/vnd.frogans.fnc" }
		"*.ltf" { set statictype "application/vnd.frogans.ltf" }
		"*.fsc" { set statictype "application/vnd.fsc.weblaunch" }
		"*.oas" { set statictype "application/vnd.fujitsu.oasys" }
		"*.oa2" { set statictype "application/vnd.fujitsu.oasys2" }
		"*.oa3" { set statictype "application/vnd.fujitsu.oasys3" }
		"*.fg5" { set statictype "application/vnd.fujitsu.oasysgp" }
		"*.bh2" { set statictype "application/vnd.fujitsu.oasysprs" }
		"*.ddd" { set statictype "application/vnd.fujixerox.ddd" }
		"*.xdw" { set statictype "application/vnd.fujixerox.docuworks" }
		"*.xbd" { set statictype "application/vnd.fujixerox.docuworks.binder" }
		"*.fzs" { set statictype "application/vnd.fuzzysheet" }
		"*.txd" { set statictype "application/vnd.genomatix.tuxedo" }
		"*.kml" { set statictype "application/vnd.google-earth.kml+xml" }
		"*.kmz" { set statictype "application/vnd.google-earth.kmz" }
		"*.gqf" - "*.gqs" { set statictype "application/vnd.grafeq" }
		"*.gac" { set statictype "application/vnd.groove-account" }
		"*.ghf" { set statictype "application/vnd.groove-help" }
		"*.gim" { set statictype "application/vnd.groove-identity-message" }
		"*.grv" { set statictype "application/vnd.groove-injector" }
		"*.gtm" { set statictype "application/vnd.groove-tool-message" }
		"*.tpl" { set statictype "application/vnd.groove-tool-template" }
		"*.vcg" { set statictype "application/vnd.groove-vcard" }
		"*.zmm" { set statictype "application/vnd.handheld-entertainment+xml" }
		"*.hbci" { set statictype "application/vnd.hbci" }
		"*.les" { set statictype "application/vnd.hhe.lesson-player" }
		"*.hpgl" { set statictype "application/vnd.hp-hpgl" }
		"*.hpid" { set statictype "application/vnd.hp-hpid" }
		"*.hps" { set statictype "application/vnd.hp-hps" }
		"*.jlt" { set statictype "application/vnd.hp-jlyt" }
		"*.pcl" { set statictype "application/vnd.hp-pcl" }
		"*.pclxl" { set statictype "application/vnd.hp-pclxl" }
		"*.x3d" { set statictype "application/vnd.hzn-3d-crossword" }
		"*.mpy" { set statictype "application/vnd.ibm.minipay" }
		"*.afp" - "*.listafp" - "*.list3820" { set statictype "application/vnd.ibm.modcap" }
		"*.irm" { set statictype "application/vnd.ibm.rights-management" }
		"*.sc" { set statictype "application/vnd.ibm.secure-container" }
		"*.igl" { set statictype "application/vnd.igloader" }
		"*.ivp" { set statictype "application/vnd.immervision-ivp" }
		"*.ivu" { set statictype "application/vnd.immervision-ivu" }
		"*.xpw" - "*.xpx" { set statictype "application/vnd.intercon.formnet" }
		"*.qbo" { set statictype "application/vnd.intu.qbo" }
		"*.qfx" { set statictype "application/vnd.intu.qfx" }
		"*.rcprofile" { set statictype "application/vnd.ipunplugged.rcprofile" }
		"*.irp" { set statictype "application/vnd.irepository.package+xml" }
		"*.xpr" { set statictype "application/vnd.is-xpr" }
		"*.jam" { set statictype "application/vnd.jam" }
		"*.rms" { set statictype "application/vnd.jcp.javame.midlet-rms" }
		"*.jisp" { set statictype "application/vnd.jisp" }
		"*.joda" { set statictype "application/vnd.joost.joda-archive" }
		"*.ktz" - "*.ktr" { set statictype "application/vnd.kahootz" }
		"*.karbon" { set statictype "application/vnd.kde.karbon" }
		"*.chrt" { set statictype "application/vnd.kde.kchart" }
		"*.kfo" { set statictype "application/vnd.kde.kformula" }
		"*.flw" { set statictype "application/vnd.kde.kivio" }
		"*.kon" { set statictype "application/vnd.kde.kontour" }
		"*.kpr" - "*.kpt" { set statictype "application/vnd.kde.kpresenter" }
		"*.ksp" { set statictype "application/vnd.kde.kspread" }
		"*.kwd" - "*.kwt" { set statictype "application/vnd.kde.kword" }
		"*.htke" { set statictype "application/vnd.kenameaapp" }
		"*.kia" { set statictype "application/vnd.kidspiration" }
		"*.kne" - "*.knp" { set statictype "application/vnd.kinar" }
		"*.skp" - "*.skd" - "*.skt" - "*.skm" { set statictype "application/vnd.koan" }
		"*.lbd" { set statictype "application/vnd.llamagraphics.life-balance.desktop" }
		"*.lbe" { set statictype "application/vnd.llamagraphics.life-balance.exchange+xml" }
		"*.123" { set statictype "application/vnd.lotus-1-2-3" }
		"*.apr" { set statictype "application/vnd.lotus-approach" }
		"*.pre" { set statictype "application/vnd.lotus-freelance" }
		"*.nsf" { set statictype "application/vnd.lotus-notes" }
		"*.org" { set statictype "application/vnd.lotus-organizer" }
		"*.scm" { set statictype "application/vnd.lotus-screencam" }
		"*.lwp" { set statictype "application/vnd.lotus-wordpro" }
		"*.portpkg" { set statictype "application/vnd.macports.portpkg" }
		"*.mcd" { set statictype "application/vnd.mcd" }
		"*.mc1" { set statictype "application/vnd.medcalcdata" }
		"*.cdkey" { set statictype "application/vnd.mediastation.cdkey" }
		"*.mwf" { set statictype "application/vnd.mfer" }
		"*.mfm" { set statictype "application/vnd.mfmp" }
		"*.flo" { set statictype "application/vnd.micrografx.flo" }
		"*.igx" { set statictype "application/vnd.micrografx.igx" }
		"*.mif" { set statictype "application/vnd.mif" }
		"*.daf" { set statictype "application/vnd.mobius.daf" }
		"*.dis" { set statictype "application/vnd.mobius.dis" }
		"*.mbk" { set statictype "application/vnd.mobius.mbk" }
		"*.mqy" { set statictype "application/vnd.mobius.mqy" }
		"*.msl" { set statictype "application/vnd.mobius.msl" }
		"*.plc" { set statictype "application/vnd.mobius.plc" }
		"*.txf" { set statictype "application/vnd.mobius.txf" }
		"*.mpn" { set statictype "application/vnd.mophun.application" }
		"*.mpc" { set statictype "application/vnd.mophun.certificate" }
		"*.xul" { set statictype "application/vnd.mozilla.xul+xml" }
		"*.cil" { set statictype "application/vnd.ms-artgalry" }
		"*.asf" { set statictype "application/vnd.ms-asf" }
		"*.cab" { set statictype "application/vnd.ms-cab-compressed" }
		"*.xls" - "*.xlm" - "*.xla" - "*.xlc" - "*.xlt" - "*.xlw" { set statictype "application/vnd.ms-excel" }
		"*.eot" { set statictype "application/vnd.ms-fontobject" }
		"*.chm" { set statictype "application/vnd.ms-htmlhelp" }
		"*.ims" { set statictype "application/vnd.ms-ims" }
		"*.lrm" { set statictype "application/vnd.ms-lrm" }
		"*.ppt" - "*.pps" - "*.pot" { set statictype "application/vnd.ms-powerpoint" }
		"*.mpp" - "*.mpt" { set statictype "application/vnd.ms-project" }
		"*.wps" - "*.wks" - "*.wcm" - "*.wdb" { set statictype "application/vnd.ms-works" }
		"*.wpl" { set statictype "application/vnd.ms-wpl" }
		"*.xps" { set statictype "application/vnd.ms-xpsdocument" }
		"*.mseq" { set statictype "application/vnd.mseq" }
		"*.mus" { set statictype "application/vnd.musician" }
		"*.msty" { set statictype "application/vnd.muvee.style" }
		"*.nlu" { set statictype "application/vnd.neurolanguage.nlu" }
		"*.nnd" { set statictype "application/vnd.noblenet-directory" }
		"*.nns" { set statictype "application/vnd.noblenet-sealer" }
		"*.nnw" { set statictype "application/vnd.noblenet-web" }
		"*.ngdat" { set statictype "application/vnd.nokia.n-gage.data" }
		"*.n-gage" { set statictype "application/vnd.nokia.n-gage.symbian.install" }
		"*.rpst" { set statictype "application/vnd.nokia.radio-preset" }
		"*.rpss" { set statictype "application/vnd.nokia.radio-presets" }
		"*.edm" { set statictype "application/vnd.novadigm.edm" }
		"*.edx" { set statictype "application/vnd.novadigm.edx" }
		"*.ext" { set statictype "application/vnd.novadigm.ext" }
		"*.odc" { set statictype "application/vnd.oasis.opendocument.chart" }
		"*.otc" { set statictype "application/vnd.oasis.opendocument.chart-template" }
		"*.odf" { set statictype "application/vnd.oasis.opendocument.formula" }
		"*.otf" { set statictype "application/vnd.oasis.opendocument.formula-template" }
		"*.odg" { set statictype "application/vnd.oasis.opendocument.graphics" }
		"*.otg" { set statictype "application/vnd.oasis.opendocument.graphics-template" }
		"*.odi" { set statictype "application/vnd.oasis.opendocument.image" }
		"*.oti" { set statictype "application/vnd.oasis.opendocument.image-template" }
		"*.odp" { set statictype "application/vnd.oasis.opendocument.presentation" }
		"*.otp" { set statictype "application/vnd.oasis.opendocument.presentation-template" }
		"*.ods" { set statictype "application/vnd.oasis.opendocument.spreadsheet" }
		"*.ots" { set statictype "application/vnd.oasis.opendocument.spreadsheet-template" }
		"*.odt" { set statictype "application/vnd.oasis.opendocument.text" }
		"*.otm" { set statictype "application/vnd.oasis.opendocument.text-master" }
		"*.ott" { set statictype "application/vnd.oasis.opendocument.text-template" }
		"*.oth" { set statictype "application/vnd.oasis.opendocument.text-web" }
		"*.xo" { set statictype "application/vnd.olpc-sugar" }
		"*.dd2" { set statictype "application/vnd.oma.dd2+xml" }
		"*.oxt" { set statictype "application/vnd.openofficeorg.extension" }
		"*.dp" { set statictype "application/vnd.osgi.dp" }
		"*.prc" - "*.pdb" - "*.pqa" - "*.oprc" { set statictype "application/vnd.palm" }
		"*.str" { set statictype "application/vnd.pg.format" }
		"*.ei6" { set statictype "application/vnd.pg.osasli" }
		"*.efif" { set statictype "application/vnd.picsel" }
		"*.plf" { set statictype "application/vnd.pocketlearn" }
		"*.pbd" { set statictype "application/vnd.powerbuilder6" }
		"*.box" { set statictype "application/vnd.previewsystems.box" }
		"*.mgz" { set statictype "application/vnd.proteus.magazine" }
		"*.qps" { set statictype "application/vnd.publishare-delta-tree" }
		"*.ptid" { set statictype "application/vnd.pvi.ptid1" }
		"*.qxd" - "*.qxt" - "*.qwd" - "*.qwt" - "*.qxl" - "*.qxb" { set statictype "application/vnd.quark.quarkxpress" }
		"*.mxl" { set statictype "application/vnd.recordare.musicxml" }
		"*.rm" { set statictype "application/vnd.rn-realmedia" }
		"*.see" { set statictype "application/vnd.seemail" }
		"*.sema" { set statictype "application/vnd.sema" }
		"*.semd" { set statictype "application/vnd.semd" }
		"*.semf" { set statictype "application/vnd.semf" }
		"*.ifm" { set statictype "application/vnd.shana.informed.formdata" }
		"*.itp" { set statictype "application/vnd.shana.informed.formtemplate" }
		"*.iif" { set statictype "application/vnd.shana.informed.interchange" }
		"*.ipk" { set statictype "application/vnd.shana.informed.package" }
		"*.twd" - "*.twds" { set statictype "application/vnd.simtech-mindmapper" }
		"*.mmf" { set statictype "application/vnd.smaf" }
		"*.sdkm" - "*.sdkd" { set statictype "application/vnd.solent.sdkm+xml" }
		"*.dxp" { set statictype "application/vnd.spotfire.dxp" }
		"*.sfs" { set statictype "application/vnd.spotfire.sfs" }
		"*.sus" - "*.susp" { set statictype "application/vnd.sus-calendar" }
		"*.svd" { set statictype "application/vnd.svd" }
		"*.xsm" { set statictype "application/vnd.syncml+xml" }
		"*.bdm" { set statictype "application/vnd.syncml.dm+wbxml" }
		"*.xdm" { set statictype "application/vnd.syncml.dm+xml" }
		"*.tao" { set statictype "application/vnd.tao.intent-module-archive" }
		"*.tmo" { set statictype "application/vnd.tmobile-livetv" }
		"*.tpt" { set statictype "application/vnd.trid.tpt" }
		"*.mxs" { set statictype "application/vnd.triscape.mxs" }
		"*.tra" { set statictype "application/vnd.trueapp" }
		"*.ufd" - "*.ufdl" { set statictype "application/vnd.ufdl" }
		"*.utz" { set statictype "application/vnd.uiq.theme" }
		"*.umj" { set statictype "application/vnd.umajin" }
		"*.unityweb" { set statictype "application/vnd.unity" }
		"*.uoml" { set statictype "application/vnd.uoml+xml" }
		"*.vcx" { set statictype "application/vnd.vcx" }
		"*.vsd" - "*.vst" - "*.vss" - "*.vsw" { set statictype "application/vnd.visio" }
		"*.vis" { set statictype "application/vnd.visionary" }
		"*.vsf" { set statictype "application/vnd.vsf" }
		"*.wbxml" { set statictype "application/vnd.wap.wbxml" }
		"*.wmlc" { set statictype "application/vnd.wap.wmlc" }
		"*.wmlsc" { set statictype "application/vnd.wap.wmlscriptc" }
		"*.wtb" { set statictype "application/vnd.webturbo" }
		"*.wpd" { set statictype "application/vnd.wordperfect" }
		"*.wqd" { set statictype "application/vnd.wqd" }
		"*.stf" { set statictype "application/vnd.wt.stf" }
		"*.xar" { set statictype "application/vnd.xara" }
		"*.xfdl" { set statictype "application/vnd.xfdl" }
		"*.hvd" { set statictype "application/vnd.yamaha.hv-dic" }
		"*.hvs" { set statictype "application/vnd.yamaha.hv-script" }
		"*.hvp" { set statictype "application/vnd.yamaha.hv-voice" }
		"*.saf" { set statictype "application/vnd.yamaha.smaf-audio" }
		"*.spf" { set statictype "application/vnd.yamaha.smaf-phrase" }
		"*.cmp" { set statictype "application/vnd.yellowriver-custom-menu" }
		"*.zaz" { set statictype "application/vnd.zzazz.deck+xml" }
		"*.vxml" { set statictype "application/voicexml+xml" }
		"*.hlp" { set statictype "application/winhlp" }
		"*.wsdl" { set statictype "application/wsdl+xml" }
		"*.wspolicy" { set statictype "application/wspolicy+xml" }
		"*.ace" { set statictype "application/x-ace-compressed" }
		"*.bcpio" { set statictype "application/x-bcpio" }
		"*.torrent" { set statictype "application/x-bittorrent" }
		"*.bz" { set statictype "application/x-bzip" }
		"*.bz2" - "*.boz" { set statictype "application/x-bzip2" }
		"*.vcd" { set statictype "application/x-cdlink" }
		"*.chat" { set statictype "application/x-chat" }
		"*.pgn" { set statictype "application/x-chess-pgn" }
		"*.cpio" { set statictype "application/x-cpio" }
		"*.csh" { set statictype "application/x-csh" }
		"*.dcr" - "*.dir" - "*.dxr" - "*.fgd" { set statictype "application/x-director" }
		"*.dvi" { set statictype "application/x-dvi" }
		"*.spl" { set statictype "application/x-futuresplash" }
		"*.gtar" { set statictype "application/x-gtar" }
		"*.hdf" { set statictype "application/x-hdf" }
		"*.latex" { set statictype "application/x-latex" }
		"*.wmd" { set statictype "application/x-ms-wmd" }
		"*.wmz" { set statictype "application/x-ms-wmz" }
		"*.mdb" { set statictype "application/x-msaccess" }
		"*.obd" { set statictype "application/x-msbinder" }
		"*.crd" { set statictype "application/x-mscardfile" }
		"*.clp" { set statictype "application/x-msclip" }
		"*.exe" - "*.dll" - "*.com" - "*.bat" - "*.msi" { set statictype "application/x-msdownload" }
		"*.mvb" - "*.m13" - "*.m14" { set statictype "application/x-msmediaview" }
		"*.wmf" { set statictype "application/x-msmetafile" }
		"*.mny" { set statictype "application/x-msmoney" }
		"*.pub" { set statictype "application/x-mspublisher" }
		"*.scd" { set statictype "application/x-msschedule" }
		"*.trm" { set statictype "application/x-msterminal" }
		"*.wri" { set statictype "application/x-mswrite" }
		"*.nc" - "*.cdf" { set statictype "application/x-netcdf" }
		"*.p12" - "*.pfx" { set statictype "application/x-pkcs12" }
		"*.p7b" - "*.spc" { set statictype "application/x-pkcs7-certificates" }
		"*.p7r" { set statictype "application/x-pkcs7-certreqresp" }
		"*.rar" { set statictype "application/x-rar-compressed" }
		"*.sh" { set statictype "application/x-sh" }
		"*.shar" { set statictype "application/x-shar" }
		"*.swf" { set statictype "application/x-shockwave-flash" }
		"*.sit" { set statictype "application/x-stuffit" }
		"*.sitx" { set statictype "application/x-stuffitx" }
		"*.sv4cpio" { set statictype "application/x-sv4cpio" }
		"*.sv4crc" { set statictype "application/x-sv4crc" }
		"*.tar" { set statictype "application/x-tar" }
		"*.tcl" { set statictype "application/x-tcl" }
		"*.tex" { set statictype "application/x-tex" }
		"*.texinfo" - "*.texi" { set statictype "application/x-texinfo" }
		"*.ustar" { set statictype "application/x-ustar" }
		"*.src" { set statictype "application/x-wais-source" }
		"*.der" - "*.crt" { set statictype "application/x-x509-ca-cert" }
		"*.xenc" { set statictype "application/xenc+xml" }
		"*.xhtml" - "*.xht" { set statictype "application/xhtml+xml" }
		"*.xml" - "*.xsl" { set statictype "application/xml" }
		"*.dtd" { set statictype "application/xml-dtd" }
		"*.xop" { set statictype "application/xop+xml" }
		"*.xslt" { set statictype "application/xslt+xml" }
		"*.xspf" { set statictype "application/xspf+xml" }
		"*.mxml" - "*.xhvml" - "*.xvml" - "*.xvm" { set statictype "application/xv+xml" }
		"*.zip" { set statictype "application/zip" }
		"*.au" - "*.snd" { set statictype "audio/basic" }
		"*.mid" - "*.midi" - "*.kar" - "*.rmi" { set statictype "audio/midi" }
		"*.mp4a" { set statictype "audio/mp4" }
		"*.mpga" - "*.mp2" - "*.mp2a" - "*.mp3" - "*.m2a" - "*.m3a" { set statictype "audio/mpeg" }
		"*.eol" { set statictype "audio/vnd.digital-winds" }
		"*.lvp" { set statictype "audio/vnd.lucent.voice" }
		"*.ecelp4800" { set statictype "audio/vnd.nuera.ecelp4800" }
		"*.ecelp7470" { set statictype "audio/vnd.nuera.ecelp7470" }
		"*.ecelp9600" { set statictype "audio/vnd.nuera.ecelp9600" }
		"*.wav" { set statictype "audio/wav" }
		"*.aif" - "*.aiff" - "*.aifc" { set statictype "audio/x-aiff" }
		"*.m3u" { set statictype "audio/x-mpegurl" }
		"*.wax" { set statictype "audio/x-ms-wax" }
		"*.wma" { set statictype "audio/x-ms-wma" }
		"*.ram" - "*.ra" { set statictype "audio/x-pn-realaudio" }
		"*.rmp" { set statictype "audio/x-pn-realaudio-plugin" }
		"*.wav" { set statictype "audio/x-wav" }
		"*.cdx" { set statictype "chemical/x-cdx" }
		"*.cif" { set statictype "chemical/x-cif" }
		"*.cmdf" { set statictype "chemical/x-cmdf" }
		"*.cml" { set statictype "chemical/x-cml" }
		"*.csml" { set statictype "chemical/x-csml" }
		"*.pdb" { set statictype "chemical/x-pdb" }
		"*.xyz" { set statictype "chemical/x-xyz" }
		"*.bmp" { set statictype "image/bmp" }
		"*.cgm" { set statictype "image/cgm" }
		"*.g3" { set statictype "image/g3fax" }
		"*.gif" { set statictype "image/gif" }
		"*.ief" { set statictype "image/ief" }
		"*.jpeg" - "*.jpg" - "*.jpe" { set statictype "image/jpeg" }
		"*.png" { set statictype "image/png" }
		"*.btif" { set statictype "image/prs.btif" }
		"*.svg" - "*.svgz" { set statictype "image/svg+xml" }
		"*.tiff" - "*.tif" { set statictype "image/tiff" }
		"*.psd" { set statictype "image/vnd.adobe.photoshop" }
		"*.djvu" - "*.djv" { set statictype "image/vnd.djvu" }
		"*.dwg" { set statictype "image/vnd.dwg" }
		"*.dxf" { set statictype "image/vnd.dxf" }
		"*.fbs" { set statictype "image/vnd.fastbidsheet" }
		"*.fpx" { set statictype "image/vnd.fpx" }
		"*.fst" { set statictype "image/vnd.fst" }
		"*.mmr" { set statictype "image/vnd.fujixerox.edmics-mmr" }
		"*.rlc" { set statictype "image/vnd.fujixerox.edmics-rlc" }
		"*.mdi" { set statictype "image/vnd.ms-modi" }
		"*.npx" { set statictype "image/vnd.net-fpx" }
		"*.wbmp" { set statictype "image/vnd.wap.wbmp" }
		"*.xif" { set statictype "image/vnd.xiff" }
		"*.ras" { set statictype "image/x-cmu-raster" }
		"*.cmx" { set statictype "image/x-cmx" }
		"*.ico" { set statictype "image/x-icon" }
		"*.pcx" { set statictype "image/x-pcx" }
		"*.pic" - "*.pct" { set statictype "image/x-pict" }
		"*.pnm" { set statictype "image/x-portable-anymap" }
		"*.pbm" { set statictype "image/x-portable-bitmap" }
		"*.pgm" { set statictype "image/x-portable-graymap" }
		"*.ppm" { set statictype "image/x-portable-pixmap" }
		"*.rgb" { set statictype "image/x-rgb" }
		"*.xbm" { set statictype "image/x-xbitmap" }
		"*.xpm" { set statictype "image/x-xpixmap" }
		"*.xwd" { set statictype "image/x-xwindowdump" }
		"*.eml" - "*.mime" { set statictype "message/rfc822" }
		"*.igs" - "*.iges" { set statictype "model/iges" }
		"*.msh" - "*.mesh" - "*.silo" { set statictype "model/mesh" }
		"*.dwf" { set statictype "model/vnd.dwf" }
		"*.gdl" { set statictype "model/vnd.gdl" }
		"*.gtw" { set statictype "model/vnd.gtw" }
		"*.mts" { set statictype "model/vnd.mts" }
		"*.vtu" { set statictype "model/vnd.vtu" }
		"*.wrl" - "*.vrml" { set statictype "model/vrml" }
		"*.ics" - "*.ifb" { set statictype "text/calendar" }
		"*.css" { set statictype "text/css" }
		"*.csv" { set statictype "text/csv" }
		"*.html" - "*.htm" { set statictype "text/html" }
		"*.txt" - "*.text" - "*.conf" - "*.def" - "*.list" - "*.log" - "*.in" { set statictype "text/plain" }
		"*.dsc" { set statictype "text/prs.lines.tag" }
		"*.rtx" { set statictype "text/richtext" }
		"*.sgml" - "*.sgm" { set statictype "text/sgml" }
		"*.tsv" { set statictype "text/tab-separated-values" }
		"*.t" - "*.tr" - "*.roff" - "*.man" - "*.me" - "*.ms" { set statictype "text/troff" }
		"*.uri" - "*.uris" - "*.urls" { set statictype "text/uri-list" }
		"*.fly" { set statictype "text/vnd.fly" }
		"*.flx" { set statictype "text/vnd.fmi.flexstor" }
		"*.3dml" { set statictype "text/vnd.in3d.3dml" }
		"*.spot" { set statictype "text/vnd.in3d.spot" }
		"*.jad" { set statictype "text/vnd.sun.j2me.app-descriptor" }
		"*.wml" { set statictype "text/vnd.wap.wml" }
		"*.wmls" { set statictype "text/vnd.wap.wmlscript" }
		"*.s" - "*.asm" { set statictype "text/x-asm" }
		"*.c" - "*.cc" - "*.cxx" - "*.cpp" - "*.h" - "*.hh" - "*.dic" { set statictype "text/x-c" }
		"*.f" - "*.for" - "*.f77" - "*.f90" { set statictype "text/x-fortran" }
		"*.p" - "*.pas" { set statictype "text/x-pascal" }
		"*.java" { set statictype "text/x-java-source" }
		"*.etx" { set statictype "text/x-setext" }
		"*.uu" { set statictype "text/x-uuencode" }
		"*.vcs" { set statictype "text/x-vcalendar" }
		"*.vcf" { set statictype "text/x-vcard" }
		"*.3gp" { set statictype "video/3gpp" }
		"*.3g2" { set statictype "video/3gpp2" }
		"*.h261" { set statictype "video/h261" }
		"*.h263" { set statictype "video/h263" }
		"*.h264" { set statictype "video/h264" }
		"*.jpgv" { set statictype "video/jpeg" }
		"*.jpm" - "*.jpgm" { set statictype "video/jpm" }
		"*.mj2" - "*.mjp2" { set statictype "video/mj2" }
		"*.mp4" - "*.mp4v" - "*.mpg4" { set statictype "video/mp4" }
		"*.mpeg" - "*.mpg" - "*.mpe" - "*.m1v" - "*.m2v" { set statictype "video/mpeg" }
		"*.qt" - "*.mov" { set statictype "video/quicktime" }
		"*.fvt" { set statictype "video/vnd.fvt" }
		"*.mxu" - "*.m4u" { set statictype "video/vnd.mpegurl" }
		"*.viv" { set statictype "video/vnd.vivo" }
		"*.fli" { set statictype "video/x-fli" }
		"*.asf" - "*.asx" { set statictype "video/x-ms-asf" }
		"*.wm" { set statictype "video/x-ms-wm" }
		"*.wmv" { set statictype "video/x-ms-wmv" }
		"*.wmx" { set statictype "video/x-ms-wmx" }
		"*.wvx" { set statictype "video/x-ms-wvx" }
		"*.avi" { set statictype "video/x-msvideo" }
		"*.movie" { set statictype "video/x-sgi-movie" }
		"*.ice" { set statictype "x-conference/x-cooltalk" }
		default {
			set statictype "application/octet-stream"
		}
	}
	
	# Dump static files
	if {[info exists statictype]} {
		rivet_cgi_server_writehttpheader 200
		tcl_puts "Content-type: $statictype"
		catch {
			tcl_puts "Last-Modified: [clock format [file mtime $targetfile] -format {%a, %d %b %Y %H:%M:%S GMT} -gmt 1]"
			tcl_puts "Expires: Tue, 19 Jan 2038 03:14:07 GMT"
		}
		catch {
			tcl_puts "Content-Length: [file size $targetfile]"
		}
		tcl_puts ""
	
		set fd [open $targetfile r]
		fconfigure $fd -encoding binary -translation {binary binary}
		fconfigure stdout -encoding binary -translation {binary binary}
		fcopy $fd stdout
		close $fd
	}
}

proc print_help {} {
	tcl_puts "Usage: [file tail [info nameofexecutable]] {--server \[--address <address>\] \[--port <port>\]"
	tcl_puts "       \[--foreground {yes|no}\] \[--init <scp>\]|--cgi|--help|--version}"
	tcl_puts "   --server           Run in standalone server mode"
	tcl_puts "   --address address  Listen on address for HTTP requests (server mode, default is \"ALL\")"
	tcl_puts "   --port portno      Listen on port for HTTP requests (server mode, default is \"80\")"
	tcl_puts "   --foreground fg    Run in foreground (server mode, default is \"no\")"
	tcl_puts "   --init script      Run script prior to accepting connections (server mode)"
	tcl_puts "   --cgi              Execute as a CGI"
	tcl_puts "   --help             This help"
	tcl_puts "   --version          Print version and exit"
}

proc rivet_cgi_server {addr port foreground init} {
	package require Tclx

	set canfork 0
	catch {
		set canfork [infox have_waitpid]
	}

	if {!$canfork} {
		tcl_puts stderr "Error: fork() is not supported on this platform, aborting..."
		return
	}

	if {$init != ""} {
		uplevel #0 $init
	}

	if {!$foreground} {
		# XXX: Todo, become daemon.
	}

	if {$addr == "ALL"} {
		socket -server [list rivet_cgi_server_request $port] $port
	} else {
		socket -server [list rivet_cgi_server_request $port] -myaddr $addr $port
	}

	vwait __FOREVER__
}

proc rivet_cgi_server_request {hostport sock addr port} {
	# Fork off a child to handle the request
	set mypid [fork]
	if {$mypid != 0} {
		catch {
			close $sock
		}
		return
	}

	# Cleanup socket information
	unset -nocomplain ::rivetstarkit::sockinfo($sock)
	set ::rivetstarkit::sockinfo($sock) [list state NEW]

	# Handle connection from data
	fileevent $sock readable [list rivet_cgi_server_request_data $hostport $sock $addr]
}

proc rivet_cgi_server_request_data {hostport sock addr} {
	array set sockinfo $::rivetstarkit::sockinfo($sock)

	gets $sock line

	if {$line == "" && [eof $sock]} {
		catch {
			close $sock
		}
		return
	}

	switch -- $sockinfo(state) {
		"NEW" {
			set work [split $line " "]
			set sockinfo(method) [string toupper [lindex $work 0]]
			set sockinfo(httpproto) [string toupper [lindex $work end]]
			set sockinfo(state) HEADERS

			set sockinfo(url) [join [lrange $work 1 end-1] " "]

			set work [split $sockinfo(url) ?]
			set sockinfo(path) [lindex $work 0]
			if {[llength $work] > 1} {
				set sockinfo(query) [join [lrange $work 1 end] ?]
			}

			# We only support GET and POST, everyone else we just close on.
			if {$sockinfo(method) != "GET" && $sockinfo(method) != "POST"} {
				close $sock
			}
		}
		"HEADERS" {
			if {$line == ""} {
				set sockinfo(state) HANDLEREQUEST
			} else {
				set work [split $line :]
				set headervar [string toupper [lindex $work 0]]
				set headerval [string trim [join [lrange $work 1 end] :]]
				lappend sockinfo(headers) $headervar $headerval
			}
		}
	}

	if {$sockinfo(state) == "HANDLEREQUEST"} {
		array set headers $sockinfo(headers)
		if {![info exists headers(CONNECTION)]} {
			set headers(CONNECTION) "close"
		}
		if {![info exists headers(HOST)]} {
			set localinfo [fconfigure $sock -sockname]
			set headers(HOST) [lindex $localinfo 1]
		}

		set myenv(GATEWAY_INTERFACE) "CGI/1.1"
		set myenv(SERVER_SOFTWARE) "Rivet Starkit"
		set myenv(SERVER_NAME) [lindex [split $headers(HOST) :] 0]
		set myenv(SERVER_PROTOCOL) $sockinfo(httpproto)
		set myenv(SERVER_PORT) $hostport
		set myenv(REQUEST_METHOD) $sockinfo(method)
		set myenv(REMOTE_ADDR) $addr
		set myenv(PATH_INFO) $sockinfo(path)
		set myenv(RIVET_INTERFACE) "FULLHEADERS"
		if {[info exists sockinfo(query)]} {
			set myenv(QUERY_STRING) $sockinfo(query)
		}

		catch {
			tcl_puts stderr "($sock/$addr/[pid]) Debug: call_page [array get myenv]; headers = [array get headers]"
		}

		set origstdout [dup stdout]
		set origstdin [dup stdin]

		dup $sock stdout
		dup $sock stdin

		unset -nocomplain ::env
		array set ::env [array get myenv]

		if {[catch {
			call_page
		} err]} {
			tcl_puts stderr "($sock/$addr/[pid]) Error: $err"
		}

		dup $origstdout stdout
		dup $origstdin stdin

		catch {
			close $sock
		}
	}

	set ::rivetstarkit::sockinfo($sock) [array get sockinfo]
}

namespace eval ::rivetstarkit { }

# Determine if we are being called as a CGI, or from the command line
if {![info exists ::env(GATEWAY_INTERFACE)]} {
	set cmd [lindex $argv 0]
	set argv [lrange $argv 1 end]

	switch -- $cmd {
		"--server" {
			set options(--address) "ALL"
			set options(--port) 80
			set options(--foreground) no
			set options(--init) ""
			array set options $argv

			set rivet_cgi_server_addr $options(--address)
			set rivet_cgi_server_port $options(--port)
			set rivet_cgi_server_fg [expr !!($options(--foreground))]
			set rivet_cgi_server_init $options(--init)

			rivet_cgi_server $rivet_cgi_server_addr $rivet_cgi_server_port $rivet_cgi_server_fg $rivet_cgi_server_init

			# If rivet_cgi_server returns, something went wrong...
			exit 1
		}
		"--cgi" {
			call_page
			exit 0
		}
		"--help" {
			print_help
			exit 0
		}
		"--version" {
			tcl_puts "RivetStarkit version @@VERS@@"
			exit 0
		}
		default {
			print_help
			exit 1
		}
	}
} else {
	call_page
}

