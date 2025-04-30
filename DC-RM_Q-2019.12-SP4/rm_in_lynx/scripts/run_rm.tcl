source ../../../../../scripts_global/conf/header_start.tcl

## NAME: TEV(RM_SCRIPT)
## TYPE: file
## INFO:
## * RM script for this task 
## * <task_Name>.tcl
set TEV(RM_SCRIPT) ""

## NAME: TEV(RM_DIR_STRUCTURE)
## TYPE: oos
## OOS_LIST: default mb_rtm
## INFO:
## * Default = Single build (same as RM)
## * mb_rtm  = Multi-build (use RTM-TPE to override)
set TEV(RM_DIR_STRUCTURE) "default"

## NAME: TEV(RM_SETUP_SCRIPT)
## TYPE: file
## INFO:
## * Only use for Multi-Build in ICC2 / FC RM Flow 
## * By Default 
## *   ICC2-DP   -> rm_setup/icc2_dp_setup.tcl
## *   ICC2-PNR  -> rm_setup/icc2_pnr_setup.tcl
## *   FC-DP     -> rm_setup/fc_dp_setup.tcl
## *   FC-PNR    -> rm_setup/fc_setup.tcl
## * When RM_DIR_STRUCTURE is set to mb_rtm (ie. Multi-build in same workarea),
## * it is necessary to modify the setup script
## *   - reports, database saved in builds directory
## * This variable TEV(RM_SETUP_SCRIPT) indicated the files that will be used for
## * multi-build environment.
set TEV(RM_SETUP_SCRIPT) ""

source ../../../../../scripts_global/conf/header_stop.tcl

## SECTION_START: initial
## SECTION_STOP: initial

## SECTION_START: setup
set cwd [pwd]
cd ../../../../../
## SECTION_STOP: setup

## SECTION_START: body
## Source RM script - bypass exit and quit
# Default to get it from TEV variable
set source [open $TEV(RM_SCRIPT)]
if { $synopsys_program_name == "tcl" } {
  set content [read $source]
  set lines_split [split $content \n]
} else {
  redirect /dev/null {set content [read $source]}
  redirect /dev/null {set lines_split [split $content \n]}
}
close $source
set trim_exit ""

if {$TEV(RM_DIR_STRUCTURE) == "mb_rtm"} {
  foreach line $lines_split {
    if {[regexp {source -echo ./rm_setup/} $line]} {
      set line "source -echo $TEV(RM_SETUP_SCRIPT)"
    } elseif {([regexp {^quit} $line] || [regexp {^exit} $line])} {
      set line ""
    }
    lappend trim_exit $line
  }
} else {
  foreach line $lines_split {
    if {!([regexp {^quit} $line] || [regexp {^exit} $line])} {
      lappend trim_exit $line
    }
  }
}

if { $synopsys_program_name == "tcl" } {
  set mod_content [join $trim_exit \n]
} else {
  redirect /dev/null {set mod_content [join $trim_exit \n]}
}

puts "SNPS_INFO   : SCRIPT_START : [file normalize $TEV(RM_SCRIPT)] : $date"
eval $mod_content
puts "SNPS_INFO   : SCRIPT_STOP : [file normalize $TEV(RM_SCRIPT)] : $date"
## SECTION_STOP: body

## SECTION_START: post
if {$TEV(RM_DIR_STRUCTURE) == "default"} {
  ## Copy log file
  if {$synopsys_program_name == "icc2_shell" || $synopsys_program_name == "fc_shell" } {
    if {$synopsys_program_name == "icc2_shell"} {set LOGS_DIR logs_icc2} else {set LOGS_DIR logs_fc}
    file mkdir $LOGS_DIR
    file delete -force $LOGS_DIR/$SEV(task).log
    file link $LOGS_DIR/$SEV(task).log $SEV(log_file)
  } else {
    file delete $SEV(task).log
    file link $SEV(task).log $SEV(log_file)
  }
} else {
  ## Go back to RM directory after the task has run
  puts "Changing directory to $SEV(workarea_dir) after the current task:  $SEV(step_name), finished."
  cd $SEV(workarea_dir)
}

## Link report files for DT
if {$synopsys_program_name == "icc2_shell" || $synopsys_program_name == "fc_shell" } {
  foreach ind_file [glob [file normalize $REPORTS_DIR]/$SEV(task).*] {
    if {[regexp report_app_options.end $ind_file]} {
      file delete -force $SEV(rpt_dir)/$SEV(task)/$SEV(task).report_app_options
      file link $SEV(rpt_dir)/$SEV(task)/$SEV(task).report_app_options $ind_file
    } 
    file delete -force $SEV(rpt_dir)/$SEV(task)/[file tail $ind_file]
    file link $SEV(rpt_dir)/$SEV(task)/[file tail $ind_file] $ind_file
  }
} elseif {$synopsys_program_name == "dc_shell"} {
  foreach ind_file [glob [file normalize $REPORTS_DIR/*]] {
    if {[regexp mapped.qor.rpt $ind_file]} {
      file delete -force $SEV(rpt_dir)/$SEV(task)/dc.report_qor
      file link $SEV(rpt_dir)/$SEV(task)/dc.report_qor $ind_file
    } elseif {[regexp mapped.power.rpt $ind_file]} {
      file delete -force $SEV(rpt_dir)/$SEV(task)/dc.report_power
      file link $SEV(rpt_dir)/$SEV(task)/dc.report_power $ind_file
    }
    file delete -force $SEV(rpt_dir)/$SEV(task)/[file tail $ind_file]
    file link $SEV(rpt_dir)/$SEV(task)/[file tail $ind_file] $ind_file
  }
}
## SECTION_STOP: post

sproc_script_stop
