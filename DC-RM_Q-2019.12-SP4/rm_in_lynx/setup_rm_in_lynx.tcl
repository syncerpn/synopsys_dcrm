#! /usr/bin/env tclsh
################################################################################
## Running RM in Lynx Installation Utility script
## Script:  setup_rm_in_lynx.tcl
## Version: Q-2019.12-SP4
## Copyright (C) 2020 Synopsys, Inc.  All rights reserved.
################################################################################
## DESCRIPTION:
## * This TCL-based utility is designed to setup RM scripts and run it in 
## * Lynx-RTM environment.  
## *  - Setup RM scripts as normal - (ie. all files in rm_setup/ directory)
## *  - Run this utility on the UNIX command line
## *  - Run the flow with Lynx-RTM
## *
## * The utility runs on the UNIX command line.
## * Use -help for more details.
## -----------------------------------------------------------------------------

## -----------------------------------------------------------------------------
## Parse arguments
## -----------------------------------------------------------------------------

set gvar(build) ""
set gvar(flow_xml) ""
set gvar(mb) ""
set gvar(help) 0
set gvar(error) 0

for {set i 0} { $i < [llength $argv] } { incr i } {
  set arg [lindex $argv $i]
  switch -exact -- $arg {
    -build {
      incr i
      set gvar(build) [lindex $argv $i]
    }
    -flow_xml {
      incr i
      set gvar(flow_xml) [lindex $argv $i]
    }
    -mb {
      set gvar(mb) "rtm"
    }
    -help {
      set gvar(help) 1
    }
    default {
      puts "ERROR: Unrecognized option: $arg"
      set gvar(error) 1
    }
  }
}

## -----------------------------------------------------------------------------
## Some Checking
## -----------------------------------------------------------------------------

## Check to see what RM is installed in the cwd
set check(RM_INSTALL) ""
proc check_RM_install {dir} {
  set RM_install [glob -nocomplain rm_*scripts]
  if {[llength $RM_install] != 0} {
    foreach ind_RM $RM_install {
      lappend check(RM_INSTALL) [lindex [split $ind_RM _] 1]
    }
    set check(RM_INSTALL) [lsort -unique $check(RM_INSTALL)]
    return $check(RM_INSTALL)
  } else {
    return 0
  }
}

## Check to see if scripts_global is installed in this directory
set check(SG) "0"
proc check_SG_install {dir} {
  set check(SG) [file isdirectory scripts_global]
  return $check(SG)
}

## Check to see if the build_name is already used in this directory
set check(BUILD) ""
proc check_build_install {dir} {
  if {[file isdirectory builds]} { 
    set build_names [glob -nocomplain -type d builds/*]    
    if {[llength $build_names] != 0} {
      foreach build $build_names {
        lappend check(BUILD) [string range $build 7 end]
      }
      return $check(BUILD)
    } else {
      return 0
    }
  }
}

## -----------------------------------------------------------------------------
## Help Info
## -----------------------------------------------------------------------------

proc setup_rm_in_lynx_help {} {
  global env argv0
  puts stderr \n[string repeat # 90]
  puts stderr "## This script will setup RM scripts and run it in Lynx Environment"
  puts stderr "## Steps to setup RM-in-Lynx"
  puts stderr "##---------------------------"
  puts stderr "## (1) Make sure Lynx is loaded in your environment"
  puts stderr "## (2) cd to your RM workarea"
  puts stderr "## (3) Run RM-in-Lynx Setup utility"
  puts stderr "##     Unix% ./rm_in_lynx/setup_rm_in_lynx.tcl \\"
  puts stderr "##            -build \<my_build\> \\"
  puts stderr "##            -flow_xml \<top_flow\> \\"
  puts stderr "##            \[-mb\]"
  puts stderr "##     where:"    
  puts stderr "##       <my_build> as \"top-level block name\".  Eg. dhm"
  puts stderr "##       <top_flow> can be your own flow or use one of the flow_xml listed below:-"
  ## When environment variable DISABLE_VER_CHECK is present - Display all flows
  ## Otherwise, only display Flow XML that were installed
  if [info exists env(DISABLE_VER_CHECK)] {
    foreach ind_xml [glob rm_in_lynx/flows/*] {
      puts stderr "##          o $ind_xml"
    }
  } else {
    foreach rm_dir [check_RM_install .] {
      foreach ind_xml [glob -nocomplain rm_in_lynx/flows/rm_${rm_dir}*.xml] {
        puts stderr "##          o $ind_xml"
      }
    }
  }
  puts stderr "##       -mb is optional for ICC2/FC only"
  puts stderr "##          o mb = Multi-build in wkarea -> override with TPE"
  puts stderr "## (4) Launch Lynx Automation GUI"
  puts stderr "##     Unix% rtm_shell -gui"
  puts stderr [string repeat # 90]\n
}

## -----------------------------------------------------------------------------
## Custom printing proc
## -----------------------------------------------------------------------------
proc cprint {arg} {
  puts \n[string repeat # 90]
  puts "$arg"  
  puts [string repeat # 90]
}

## -----------------------------------------------------------------------------
## Main Script
## -----------------------------------------------------------------------------
if { $argv == "" || $gvar(help) == 1 || $gvar(error) == 1 } {
  setup_rm_in_lynx_help
  return
}

proc setup_rm_in_lynx {arg} {
    global env gvar check
    set build $gvar(build)

    ## Lynx_dir is cwd for now
    set Lynx_dir .

    if {[info exists env(LYNX_HOME)] == 0} { 
      cprint "Error:  Need to make sure Lynx is loaded in your environment first"
      return
    } 

    if {$build == ""} {
      cprint "Error:  Must specify -build \<my_build\>"
      return
    } elseif {[lsearch -exact [check_build_install $Lynx_dir] $build] != -1 } {
      puts \n[string repeat # 90]
      puts "Error:  Build $build already exists, please use another name."
      puts "See https://solvnetplus.synopsys.com/s/article/Running-the-Reference-Methodology-in-Lynx-1577116078130 for more details on running multiple RMs"
      puts [string repeat # 90]
      return
    }

    if {$gvar(flow_xml) == ""} {
      cprint "Error:  Must specify -flow_xml \<default_flow\> \[Note: Use -help to see available flow_xml\]"
      return
    } elseif {![string equal xml [string range [file ext $gvar(flow_xml)] 1 end]] } {
      cprint "Error:  $gvar(flow_xml) is not an xml file. \[Note: Use -help to see available flow_xml\]"
      return
    } elseif {![file exists $gvar(flow_xml)]} {
      cprint "Error: $gvar(flow_xml) does not exists"
      return
    }

    if {$gvar(mb) == "rtm"} {
      set rm_dir [check_RM_install .]
      if {$rm_dir != "icc2" && $rm_dir != "fc"} { 
        cprint "Error: mb support for ICC2 and FC only!"
        return
      }
    }

    ## Perform actual work
    puts \n[string repeat # 90]
    set Lynx_ver [file tail [file dir [file dir [exec which rtm_shell]]]]
    regsub -all "rtm" $Lynx_ver "flow" Lynx_ver

    puts "## Setting up RM scripts to run in Lynx Automation GUI"
    puts "## ..."
    ## Only copy three directories from Intallation - demo, conf, procs
    if {[check_SG_install $Lynx_dir]} {
      puts "## scripts_global already exists - not copying from \$LYNX_HOME"
    } else {
      puts "## Copying scripts_global from $Lynx_ver"
      file mkdir $Lynx_dir/scripts_global
      set dlist [list demo conf procs]
      foreach dir $dlist {
        file copy $env(LYNX_HOME)/flow/$Lynx_ver/scripts_global/$dir $Lynx_dir/scripts_global
      }
      ## remove config_flow.xml from scripts_global/conf
      ## use config_flow.xml in build dir instead
      file delete $Lynx_dir/scripts_global/conf/config_flow.xml
      cd scripts_global
      exec ln -s ../rm_in_lynx/scripts/dt_shell
      exec ln -s ../rm_in_lynx/scripts/view
      cd ../
    }
    ## Check to see if directory $Lynx_dir/scripts_global/rm_in_lynx exists or not.
    ## If not exists - then copy it, otherwise skip 
    if {![file isdirectory $Lynx_dir/scripts_global/rm_in_lynx]} {
      set grm_dir $Lynx_dir/scripts_global/rm_in_lynx
      file mkdir $grm_dir; cd $grm_dir
      exec ln -s ../../rm_in_lynx/flows
      file mkdir scripts; cd scripts
      foreach ind_tcl [glob ../../../rm_in_lynx/scripts/*tcl] {
        exec ln -s $ind_tcl
      }
      cd ../../..
    }
    ## Modify some SEV variables
    set sevfile $Lynx_dir/scripts_global/conf/sev_values.tcl
    file delete -force $sevfile.org
    file copy $sevfile $sevfile.org
    set fin  [open $sevfile.org r]
    set fout [open $sevfile w]
    while {[gets $fin line] >= 0} {
      if {[regexp {^set} $line] && [regexp {rc_method} [lindex $line 1]]} {
	  puts $fout "set SEV(config,rc_method) none"
      } elseif {[regexp {^set} $line] && [regexp {tv_method} [lindex $line 1]]} {
	  puts $fout "set SEV(config,tv_method) none"
      } elseif {[regexp {^set} $line] && [regexp {enable,job} [lindex $line 1]]} {
	  puts $fout "set SEV(enable,job) 0"
      } elseif {[regexp {^set} $line] && [regexp {enable,aro} [lindex $line 1]]} {
	  puts $fout "set SEV(enable,aro) 0"
      } elseif {[regexp {^set} $line] && [regexp {enable,metrics} [lindex $line 1]]} {
	  puts $fout "set SEV(enable,metrics) 0"
      } elseif {[regexp {^set} $line] && [regexp {verbosity} [lindex $line 1]]} {
	  puts $fout "set SEV(config,verbosity) min"
      } elseif {[regexp {^set} $line] && [regexp {techlib} [lindex $line 1]]} {
      } else {
	  puts $fout $line
      }
    }
    close $fin
    close $fout

    ## Create dummy files
    puts "## Creating scripts_build for $build"
    set bconf_dir $Lynx_dir/builds/$build/scripts_build/conf 
    file mkdir $bconf_dir
    foreach indfile "setup.tcl sev_values.tcl svar_values.tcl" {exec touch $bconf_dir/$indfile}

    ## create BSCRIPT-config_flow.xml
    ## Setup Top_flow and Flow_goal in config_flow.xml according to specified flow_xml
    puts "## Setting up config_flow.xml"
    set fout [open $bconf_dir/config_flow.xml w]
    puts $fout "\<file type=\"flow_config\"\>"
    if {[lsearch -exact [glob rm_in_lynx/flows/*] $gvar(flow_xml)] || \
        [lsearch -exact [glob ./rm_in_lynx/flows/*] $gvar(flow_xml)]} {
      set top_flow "\$SEV(gscript_dir)/$gvar(flow_xml)"
      set flow_goal [file root [file tail $gvar(flow_xml)]]
      puts "##   Top_flow  = $gvar(flow_xml)" 
      puts "##   Flow_goal = $flow_goal/all"
      puts $fout "  \<attribute name=\"top_flow\" value=\"$top_flow\"/\>"
      puts $fout "  \<attribute name=\"flow_goal\" value=\"$flow_goal/all\"/\>"
    } else {
      set top_flow $gvar(flow_xml)
      puts "##   Top_flow  = Custom flow - $gvar(flow_xml)" 
      puts "##   Flow_goal = Not set"
      puts $fout "  \<attribute name=\"top_flow\" value=\"$top_flow\"/\>"
    }

    ## For multi-build ##
    if {$gvar(mb) == "rtm"} {
	puts "##   -mb is detected.  Run multiple-builds with RTM override approch"
	set tev_mb "mb_rtm"
	set xml_org [open $gvar(flow_xml) r]
	set all_tasks ""
	while {[gets $xml_org line] >= 0} {
	  if {[regexp {tool_task} $line]} {
	    gets $xml_org line
	    set task_name [lindex [split $line {\"}] 3] 
	    lappend all_tasks $task_name
	  }
	  if {[regexp {flow_name} $line]} {
	    set flow_name [lindex [split $line {\"}] 3]
	  }
	}
	close $xml_org
	switch -glob $flow_goal {
	    rm_fc_dp*    {set setup_script ./rm_setup/fc_dp_setup_mb.tcl}
	    rm_fc_pnr*   {set setup_script ./rm_setup/fc_setup_mb.tcl}
	    rm_icc2_dp*  {set setup_script ./rm_setup/icc2_dp_setup_mb.tcl}
	    rm_icc2_pnr* {set setup_script ./rm_setup/icc2_pnr_setup_mb.tcl}
	}

        foreach task $all_tasks {
	    puts $fout "  <package type=\"override\"\>"
	    puts $fout "    <attribute name=\"type\" value=\"tool_task\"/\>"
	    puts $fout "    <attribute name=\"flow\" value=\"$flow_name\"/\>"
	    puts $fout "    <attribute name=\"name\" value=\"$task\"/\>"
	    puts $fout "    <attribute name=\"variable\" value=\"|TEV(RM_DIR_STRUCTURE)|$tev_mb\"/>"
	    puts $fout "    <attribute name=\"variable\" value=\"|TEV(RM_SETUP_SCRIPT)|$setup_script\"/>"
	    puts $fout "  </package>"
	}

	## Update icc2_dp_setup.tcl/icc2_pnr_setup.tcl (for ICC2) and fc_dp_setup.tcl/fc_setup.tcl (for FC)
	#set rm_dir [check_RM_install .]
        puts "##     Note: To run multiple_build - a different setup will be used "
        puts "##       - Update design_setup.tcl"
        set des_setup [open rm_setup/design_setup.tcl r]
        set tmp [open rm_setup/design_setup_tmp.tcl w]
        while {[gets $des_setup line] >= 0} {
	  if {[regexp {^set search_path} $line]} {
	    if {[regexp {\./} $line]} {
	      regsub -all "\./" $line "\$SEV(workarea_dir)/" line
            }
	  } elseif {[regexp {^set OUTPUTS_DIR} $line]} {
	    regsub -all "./outputs_icc2" $line "\$SEV(dst_dir)" line
	    regsub -all "./outputs_fc" $line "\$SEV(dst_dir)" line
	  } elseif {[regexp {^set REPORTS_DIR} $line]} {
	    regsub -all "./rpts_icc2" $line "\$SEV(rpt_dir)" line
	    regsub -all "./rpts_fc" $line "\$SEV(rpt_dir)" line
	  }
          puts $tmp $line
	}
        close $des_setup  
        close $tmp
	file rename -force "rm_setup/design_setup_tmp.tcl" "rm_setup/design_setup.tcl"

	if {$rm_dir == "icc2"} { set setup_file [glob -nocomplain rm_setup/icc2*setup.tcl] }
	if {$rm_dir == "fc"}   { set setup_file [glob -nocomplain rm_setup/fc*setup.tcl] }
        foreach ind_file $setup_file {
	  set rootname [file root $ind_file]
	  set newfile ${rootname}_mb.tcl  
	  puts "##       - create $newfile"
	  set org_setup [open $ind_file r]
	  set mb_setup [open $newfile w]
	  while {[gets $org_setup line] >= 0} {
	    puts $mb_setup $line
	  }
	  set mb_add [open rm_in_lynx/scripts/mb_add.txt r]
	  while {[gets $mb_add line] >= 0} {
	    puts $mb_setup $line
	  } 
	}
	close $org_setup
	close $mb_add
	close $mb_setup
    }
    puts $fout "</file\>"
    close $fout
    puts "## Done!"
    puts "## User can invoke rtm_shell and run RM flow with Lynx Automation"
    puts "##"
    puts "## Unix% rtm_shell -gui"
    puts [string repeat # 90]\n
}

setup_rm_in_lynx $argv

