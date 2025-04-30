#! /usr/bin/env tclsh
## -----------------------------------------------------------------------------
## HEADER_MSG  Lynx Design System: Baseline Flow
## HEADER_MSG  Version 2019.12-SP4
## HEADER_MSG  Copyright (c) 2020 Synopsys
## -----------------------------------------------------------------------------

## -----------------------------------------------------------------------------
## Parse arguments
## -----------------------------------------------------------------------------

set garg(config_list) ""
set garg(config_file) ""
set garg(report_file) ""
set garg(category)    "DEFAULT"
set garg(message)     0
set garg(debug)       0

set error 0

for { set i 0 } { $i < [llength $argv] } { incr i } {
  set arg [lindex $argv $i]
  switch -- $arg {
    -config_list {
      incr i
      set garg(config_list) [lindex $argv $i]
    }
    -config_file {
      incr i
      set garg(config_file) [lindex $argv $i]
    }
    -report_file {
      incr i
      set garg(report_file) [lindex $argv $i]
    }
    -category {
      incr i
      set garg(category) [lindex $argv $i]
    }
    -message {
      set garg(message) 1
    }
    -debug {
      set garg(debug) 1
    }
    default {
      puts "Error: Unrecognized option: $arg"
      set error 1
    }
  }
}

if { ($garg(config_file) != "") && ![file exists $garg(config_file)] } {
  incr error
  puts "Error: File specified by -config_file does not exist: '$garg(config_file)'"
}

if { $error } {
  puts "Usage: gen_app_option_compare.tcl"
  puts "         \[-config_list <config_list>\]"
  puts "         \[-config_file <config_file>\]"
  puts "         \[-report_file <report_file>\]"
  puts "         \[-message\]"
  puts "         \[-debug\]"

  exit
}

## -----------------------------------------------------------------------------
## Global variables
## -----------------------------------------------------------------------------

set gvar(prog_path) [file dirname [file normalize $argv0]]
source $gvar(prog_path)/procs.tcl

## These are set by sproc_config
set gvar(build_item_list) [list]
set gvar(report_file) ""
set gvar(message_file) ""

set gvar(template_dir) $gvar(prog_path)/compare_template
set gvar(data_dir)     $gvar(prog_path)/gen_app_option_compare.data

## -----------------------------------------------------------------------------
## sproc_gather_data:
## -----------------------------------------------------------------------------

proc sproc_gather_data {} {

  global garg gvar
  global misc_status

  array set misc_status {}

  foreach build_item $gvar(build_item_list) {
    lassign $build_item build_label build_dir
    sproc_gather_build_data $build_label $build_dir
  }

}

## -----------------------------------------------------------------------------
## sproc_gather_build_data:
## -----------------------------------------------------------------------------

proc sproc_gather_build_data { build_label build_dir } {

  global env garg gvar
  global misc_status

  ## -------------------------------------
  ## Get tasks and reports
  ## -------------------------------------

  set reports [list]
  lappend reports "report_app_options"

  sproc_build_info -cmd init -build_label $build_label -build_dir $build_dir -reports $reports

  if { $garg(debug) } {
    sproc_debug $build_label $build_dir
  }

  ## -------------------------------------
  ## Gather metrics for each task
  ## -------------------------------------

  set task_info_list [sproc_build_info -build_label $build_label -cmd get]
  foreach task_info $task_info_list {
    lassign $task_info task_flow_order task_step task_dst task_name task_id task_tool task_report_list

    ## -------------------------------------
    ## Parse the reports for this task
    ## -------------------------------------

    unset -nocomplain app_options

    foreach file $task_report_list {

      if { [file extension $file] == ".report_app_options" } {
        array set app_options [sproc_parse_report_app_options -file $file]
        set app_options_file $file
      }

    }

    ## -------------------------------------
    ## Stuff results into misc_status
    ## -------------------------------------
    if { [info exists app_options] } {
      foreach app_option $app_options(app_option_list) {

        if { [info exists app_options(value,$app_option)] } {
          set metric_display $app_option
          set metric_name $app_option
          set data $app_options(value,$app_option)
          set link $app_options_file:$app_options(value,$app_option,line_number)
          if { $data != "--" } {
            set misc_status($build_label,$task_id,$metric_name,value) $data
            set misc_status($build_label,$task_id,$metric_name,link) $link
	  
	    sproc_metric -cmd add -metric_name $metric_name -display_name $metric_display
          }
        }
      }
    }
  }
}


## -----------------------------------------------------------------------------
## sproc_create_final_report:
## -----------------------------------------------------------------------------

proc sproc_create_final_report {} {

  global garg gvar
  global misc_status
  global argv0

  ## Note: garg(report_file) is a directory. Using report_dir for clarity.

  ## Create report_dir

  set report_dir $gvar(report_file)

  if { [file exists $report_dir] } {
    if { [file exists      $report_dir/index.html] &&
         [file isdirectory $report_dir/include] &&
         [file isdirectory $report_dir/data]
    } {
      puts "Using existing report directory: $report_dir"
    } else {
      puts "Error: Invalid report directory: $report_dir"
      exit
    }
  } else {
    puts "Creating new report directory: $report_dir"
    file copy $gvar(template_dir) $report_dir
    file copy $gvar(data_dir)/data $report_dir/data
  }

  if { ![file exists $report_dir] } {
    puts "Error: Unable to create report directory: $report_dir"
    exit
  }

  ## Polulate report_dir

  ## Create list of file(s): data/category/*.tbl

  set list_file $report_dir/data/tbl.cfg
  set fid [open $list_file w]
  foreach build_item $gvar(build_item_list) {
    lassign $build_item build_label build_dir
    set build_file $garg(category)/$build_label.tbl
    puts $fid $build_file
  }
  close $fid

  ## Create file(s): data/category/*.tbl

  foreach build_item $gvar(build_item_list) {
    lassign $build_item build_label build_dir

    set build_file $report_dir/data/$garg(category)/$build_label.tbl

    file mkdir [file dirname $build_file]
    set fid [open $build_file w]

    ## Create HEADER line

    set header_line "HEADER"
    foreach metric_name [lsort [sproc_metric -cmd metrics]] {
      set header_line "$header_line|[sproc_metric -cmd display -metric_name $metric_name]"
    }
    puts $fid $header_line

    ## Create VALUE lines

    foreach task_info [sproc_build_info -build_label $build_label -cmd get] {
      lassign $task_info task_flow_order task_step task_dst task_name task_id task_tool task_report_list

      set value_line "$task_id"

      foreach metric_name [lsort [sproc_metric -cmd metrics]] {
        if { [info exists misc_status($build_label,$task_id,$metric_name,value)] } {
          set value $misc_status($build_label,$task_id,$metric_name,value)
        } else {
          set value ""
        }
        set value_line "$value_line|$value"
      }

      puts $fid $value_line
    }

    close $fid

  }

  ## configure format.cfg
  set format_config_file $report_dir/data/format.cfg
  exec chmod u+w $format_config_file
  file delete -force $format_config_file.orig
  file copy $format_config_file $format_config_file.orig
  set in_id [open $format_config_file.orig r]
  set out_id [open $format_config_file w]
  while { [gets $in_id line] >= 0 } {
    puts $out_id $line
  }
  # add line to format.cfg to apply default rule to each metric
  foreach metric_name [lsort [sproc_metric -cmd metrics]] {
    puts $out_id "FORMAT|[sproc_metric -cmd display -metric_name $metric_name]|STD_RULE_D"
  }
  close $in_id
  file delete -force $format_config_file.orig
  close $out_id

}

## -----------------------------------------------------------------------------
## MAIN
## -----------------------------------------------------------------------------

sproc_config

sproc_gather_data

sproc_create_final_report

sproc_create_message_file

puts "Done!"

## -----------------------------------------------------------------------------
## End Of File
## -----------------------------------------------------------------------------
