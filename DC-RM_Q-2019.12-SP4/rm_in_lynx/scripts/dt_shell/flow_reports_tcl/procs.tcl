## -----------------------------------------------------------------------------
## HEADER_MSG  Lynx Design System: Baseline Flow
## HEADER_MSG  Version 2019.12-SP4
## HEADER_MSG  Copyright (c) 2020 Synopsys
## -----------------------------------------------------------------------------
## DESCRIPTION:
## * This file contains Lynx procedure definitions.
## -----------------------------------------------------------------------------

## -----------------------------------------------------------------------------
## Define some base variables & procedures
## -----------------------------------------------------------------------------

if { [info command parse_proc_arguments] != "parse_proc_arguments" } {

  proc parse_proc_arguments { required_switch args options_ref } {

    global define_proc_attributes_booleans
    global define_proc_attributes_args

    upvar $options_ref options

    set parent_level [expr [info level] - 1]
    set parent_name [lindex [info level $parent_level] 0]
    set parent_name [regsub {^::} $parent_name {}]

    if { $required_switch == "-args" } {
      for { set i 0 } { $i < [llength $args] } { incr i } {
        set arg [lindex $args $i]
        if { [lsearch $define_proc_attributes_args($parent_name) $arg] >= 0 } {
          ## This is a defined option
          if { [lsearch $define_proc_attributes_booleans($parent_name) $arg] >= 0 } {
            ## This is a boolean switch
            set options($arg) 1
          } else {
            ## This is not a boolean switch
            incr i
            set options($arg) [lindex $args $i]
          }
        } else {
          return -code error "Error: unknown option '$arg'"
        }
      }
    }
  }

}

if { [info command define_proc_attributes] != "define_proc_attributes" } {

  unset -nocomplain define_proc_attributes_booleans
  unset -nocomplain define_proc_attributes_args

  proc define_proc_attributes args {

    global define_proc_attributes_booleans
    global define_proc_attributes_args

    set proc_name ""
    set proc_args [list]

    for { set i 0 } { $i < [llength $args] } { incr i } {
      set arg [lindex $args $i]
      if { $i == 0 } {
        set proc_name $arg
        continue
      }
      switch -- $arg {
        -info {
          incr i
          continue
        }
        -hidden {
          continue
        }
        -define_args {
          incr i
          set proc_args [lindex $args $i]
        }
        default {
          puts stderr "Error: define_proc_attributes: Unrecognized argument: $arg"
        }
      }
    }

    if { $proc_name != "" } {
      set define_proc_attributes_booleans($proc_name) [list]
      set define_proc_attributes_args($proc_name) [list]
      foreach proc_arg $proc_args {
        set switch_name [lindex $proc_arg 0]
        set switch_type [lindex $proc_arg end-1]
        if { $switch_type == "boolean" } {
          lappend define_proc_attributes_booleans($proc_name) $switch_name
        }
        lappend define_proc_attributes_args($proc_name) $switch_name
      }
    } else {
      puts stderr "Error: define_proc_attributes: Procedure name not defined."
    }

  }

}

## -----------------------------------------------------------------------------
## sproc_msg:
## -----------------------------------------------------------------------------

proc sproc_msg { args } {

  ## Assigning default value of "bell" since that is never used.

  set options(-info)    "\b"
  set options(-warning) "\b"
  set options(-error)   "\b"
  set options(-setup)   "\b"
  set options(-issue)   "\b"
  set options(-note)    "\b"
  set options(-header)  0
  parse_proc_arguments -args $args options

  if       { $options(-info)   != "\b" } {
    puts "SNPS_INFO   : $options(-info)"
  } elseif { $options(-warning) != "\b" } {
    puts "SNPS_WARNING: $options(-warning)"
  } elseif { $options(-error)  != "\b" } {
    puts "SNPS_ERROR  : $options(-error)"
  } elseif { $options(-setup)  != "\b" } {
    puts "SNPS_SETUP  : $options(-setup)"
  } elseif { $options(-issue)  != "\b" } {
    puts "SNPS_ISSUE  : $options(-issue)"
  } elseif { $options(-note)  != "\b" } {
    puts "SNPS_NOTE  : $options(-note)"
  } elseif { $options(-header) } {
    puts "SNPS_HEADER : ## ------------------------------------- "
  } else {
    puts "SNPS_ERROR  : Unrecognized arguments for sproc_msg : $args"
  }
}

define_proc_attributes sproc_msg \
  -info "Standard message printing procedure." \
  -define_args {
  {-info    "Info message"    AString string optional}
  {-warning "Warning message" AString string optional}
  {-error   "Error message"   AString string optional}
  {-setup   "Setup message"   AString string optional}
  {-issue   "Issue message"   AString string optional}
  {-note    "Note  message"   AString string optional}
  {-header  "Header flag"     ""      boolean optional}
}

## -----------------------------------------------------------------------------
## sproc_date:
## -----------------------------------------------------------------------------

proc sproc_date {} {
  return [clock format [clock seconds] -format {%a %b %e %H:%M:%S %Y}]
}

## -----------------------------------------------------------------------------
## sproc_config:
## -----------------------------------------------------------------------------

proc sproc_config { args } {

  global argv0
  global env garg gvar

  ## -------------------------------------
  ## Read config_common
  ## -------------------------------------

  set prog_path [file dirname [file normalize $argv0]]
  set prog_name [file rootname [file tail [file normalize $argv0]]]

  set config_common $prog_path/config_common.txt

  if { ![file exists $config_common] } {
    puts "Error: Config file is missing: $config_common"
    exit
  }

  set fid [open $config_common r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  foreach line $lines {
    if { [regexp {^\s*$} $line] || [regexp {^\s*#} $line] } {
      continue
    }

    set fields [split $line "|"]
    set name  [string trim [lindex $fields 0]]
    set value [string trim [lindex $fields 1]]

    switch $name {
      publish_dir {
        set publish_dir $value
      }
      default {
        puts "Error: Undefined name in $config_common: $name"
        exit
      }
    }
  }

  if { ![info exists publish_dir] } {
    puts "Error: publish_dir not defined in $config_common"
    exit
  }

  ## -------------------------------------
  ## Develop gvar(build_item_list)
  ## -------------------------------------

  set config_list_length [llength $garg(config_list)]
  if { $config_list_length != 0 } {
    if { [expr $config_list_length % 2] != 0 } {
      puts "Error: The argument for -config_list must contain a even number of entries"
    } else {
      for { set i 0 } { $i < $config_list_length } { set i [expr $i + 2] } {
        set j [expr $i + 1]
        set build_label [lindex $garg(config_list) $i]
        set build_dir   [lindex $garg(config_list) $j]
        set build_item [list $build_label $build_dir]
        lappend gvar(build_item_list) $build_item
      }
    }
  }

  set config_build $garg(config_file)

  if { [file exists $config_build] } {

    set fid [open $config_build r]
    set string_file [read $fid]
    close $fid
    set lines [split $string_file \n]

    foreach line $lines {
      if { [regexp {^\s*$} $line] || [regexp {^\s*#} $line] } {
        continue
      }

      set fields [split $line "|"]
      set build_label [string trim [lindex $fields 0]]
      set build_dir   [string trim [lindex $fields 1]]
      set build_item [list $build_label $build_dir]
      lappend gvar(build_item_list) $build_item
    }

  }

  foreach build_item $gvar(build_item_list) {
    set build_label [lindex $build_item 0]
    set build_dir   [lindex $build_item 1]
    puts "Build item : $build_label : $build_dir"
    if { ![file exists $build_dir] || ![file isdirectory $build_dir] } {
      puts "Error: Build directory does not exist: $build_dir"
    }
  }

  ## -------------------------------------
  ## Develop gvar(report_file) & gvar(message_file)
  ## -------------------------------------

  set lynx_date [clock format [clock seconds] -format "%Y_%m_%d"]

  if { [info exists env(LYNX_CRON)] } {
    set lynx_cron $env(LYNX_CRON)
  } else {
    set lynx_cron 0
  }

  if { $lynx_cron } {
    set lynx_user CRON
  } else {
    if { [info exists env(LYNX_USER)] } {
      set lynx_user $env(LYNX_USER)
    } else {
      set lynx_user [exec whoami]
    }
  }

  if { $garg(report_file) == "" } {

    ## Default report directory & report name
    if { ($prog_name=="gen_design_summary_compare") || ($prog_name=="gen_resource_compare") || ($prog_name=="gen_app_option_compare")} {
      set gvar(report_file) $publish_dir/users/$lynx_user/$lynx_date/$prog_name
    } else {
      set gvar(report_file) $publish_dir/users/$lynx_user/$lynx_date/$prog_name.lynx_dt
    }

  } else {

    if { [regexp {^/} $garg(report_file)] } {
      ## Absolute file specified; No defaults used
      set gvar(report_file) $garg(report_file)
    } else {
      ## Relative path specified; Default report directory
      set gvar(report_file) $publish_dir/users/$lynx_user/$lynx_date/$garg(report_file)
    }

  }

  if { $garg(message) } {
    set file_part_org [file tail $gvar(report_file)]
    set dir_part_org  [file dirname $gvar(report_file)]
    set file_part_new .[file rootname $file_part_org].message
    set gvar(message_file) $dir_part_org/$file_part_new
  }

  puts "Report file  : $gvar(report_file)"
  puts "Message file : $gvar(message_file)"

  file mkdir [file dirname $gvar(report_file)]

}

## -----------------------------------------------------------------------------
## sproc_build_info:
## -----------------------------------------------------------------------------

proc sproc_build_info { args } {
  global _task_info_list

  set options(-cmd)         ""
  set options(-build_label) ""
  set options(-build_dir)   ""
  set options(-reports)     ""
  set options(-task_id)     ""
  parse_proc_arguments -args $args options

  if { ![info exists _task_info_list($options(-build_label))] } {
    set _task_info_list($options(-build_label)) [list]
  }

  switch $options(-cmd) {

    init {

      set resourceFileList [glob -nocomplain $options(-build_dir)/*/*/rpts/*/.*.lynx_task]

      foreach resourceFile $resourceFileList {

        set task_step [lindex [split $resourceFile /] end-4]
        set task_dst  [lindex [split $resourceFile /] end-3]
        set task_name [string range [file rootname [file tail $resourceFile]] 1 end]


        ## Read resourceFile
        set fid [open $resourceFile r]
        set string_file [read $fid]
        close $fid
        set lines [split $string_file \n]

        ## Develop task_id
        set task_id $task_step/$task_dst/$task_name

        ## Develop task_flow_order & task_tool
        set task_flow_order 0
        set task_tool "UNDEFINED"
        foreach line $lines {
          if { [regexp {^flow_order\|(\d+)} $line match value] } { set task_flow_order $value }
          if { [regexp {^Tool\|(\S+)}       $line match value] } { set task_tool       $value }
        }

        ## Develop task_report_list

        set task_report_list [list]

        set reportFileList [glob -nocomplain -types { f } $options(-build_dir)/$task_step/$task_dst/rpts/$task_name/*]
        set reportFileList [lsort $reportFileList]

        unset -nocomplain reportTypeFound

        foreach reportFile $reportFileList {
          set reportType [file extension $reportFile]
          set reportType [string range $reportType 1 end]
          if { [lsearch $options(-reports) $reportType] >= 0 } {
            if { ![info exists reportTypeFound($reportType)] } {
              set reportTypeFound($reportType) true
              lappend task_report_list $reportFile
            }
          }
        }

        ## Save task_info
        set task_info [list $task_flow_order $task_step $task_dst $task_name $task_id $task_tool $task_report_list]
        lappend _task_info_list($options(-build_label)) $task_info
      }

      ## Sort task_flow_order
      set _task_info_list($options(-build_label)) [lsort -index 0 -increasing -integer $_task_info_list($options(-build_label))]

      ## Sort task_name
      ## set _task_info_list($options(-build_label)) [lsort -index 3 -increasing -ascii   $_task_info_list($options(-build_label))]

      ## Sort task_dst
      #set _task_info_list($options(-build_label)) [lsort -index 2 -increasing -ascii   $_task_info_list($options(-build_label))]

      ## Sort task_step
      #set _task_info_list($options(-build_label)) [lsort -index 1 -increasing -ascii   $_task_info_list($options(-build_label))]

    }

    get {
      set tmp_task_info_list [list]
      foreach task_info $_task_info_list($options(-build_label)) {
        lassign $task_info task_flow_order task_step task_dst task_name task_id task_tool task_report_list
        if { [llength $task_report_list] > 0 } {
          lappend tmp_task_info_list $task_info
        }
      }
      return $tmp_task_info_list
    }

    get_all {
      set tmp_task_info_list $_task_info_list($options(-build_label))
      return $tmp_task_info_list
    }

    del {
      set tmp_task_info_list [list]
      foreach task_info $_task_info_list($options(-build_label)) {
        lassign $task_info task_flow_order task_step task_dst task_name task_id task_tool task_report_list
        if { $task_id == $options(-task_id) } {
          continue
        } else {
          lappend tmp_task_info_list $task_info
        }
      }
      set _task_info_list($options(-build_label)) $tmp_task_info_list
    }

  }

}

define_proc_attributes sproc_build_info \
  -info "Interact with task definitions" \
  -define_args {
  {-cmd "Task info command" AnOos one_of_string
    {required value_help {values {init get get_all del}}}
  }
  {-build_label "Build label"     AString string required}
  {-build_dir   "Build dir"       AString string optional}
  {-reports     "Report suffixes" AString string optional}
  {-task_id     "Task ID"         AString string optional}
}

## -----------------------------------------------------------------------------
## sproc_debug:
## -----------------------------------------------------------------------------

proc sproc_debug { build_label build_dir } {

  global env garg gvar

  if { $garg(debug) } {
    puts "DEBUG: $build_label : $build_dir"
    foreach task_info [sproc_build_info -build_label $build_label -cmd get_all] {
      lassign $task_info task_flow_order task_step task_dst task_name task_id task_tool task_report_list
      puts "DEBUG:   $task_id"
      foreach task_report $task_report_list {
        set remove_dir [file dirname $build_dir]/
        set display_report [regsub $remove_dir $task_report {}]
        puts "DEBUG:     $display_report"
      }
    }
  }

}

## -----------------------------------------------------------------------------
## sproc_create_message_file:
## -----------------------------------------------------------------------------

proc sproc_create_message_file {} {

  global env garg gvar

  if { $gvar(message_file) == "" } {
    return
  }

  set fid [open $gvar(message_file) w]

  puts $fid "<html>"
  puts $fid "<body>"
  puts $fid "<h1>New Report Available</h1>"
  puts $fid "<a href=\"%%DT%%:[file normalize $gvar(report_file)]\">The New Report</a>"
  puts $fid "</body>"
  puts $fid "</html>"

  close $fid

  puts "Information: Message file created"

}

## -----------------------------------------------------------------------------
## sproc_metric:
## -----------------------------------------------------------------------------

proc sproc_metric { args } {
  global misc_metric_name_list
  global misc_metric_name2display

  set options(-cmd) ""
  set options(-metric_name) ""
  set options(-display_name) ""
  parse_proc_arguments -args $args options

  if { ![info exists misc_metric_name_list] } {
    set misc_metric_name_list [list]
    array set misc_metric_name2display {}
  }

  switch $options(-cmd) {
    add {
      if { [lsearch $misc_metric_name_list $options(-metric_name)] == -1 } {
        lappend misc_metric_name_list $options(-metric_name)
      }
      set misc_metric_name2display($options(-metric_name)) $options(-display_name)
    }
    metrics {
      return $misc_metric_name_list
    }
    display {
      if { [lsearch $misc_metric_name_list $options(-metric_name)] == -1 } {
        puts "Error: sproc_metric: Metric not defined for -metric_name: '$options(-metric_name)'"
        return "UNDEFINED"
      } else {
        return $misc_metric_name2display($options(-metric_name))
      }
    }
  }
}

define_proc_attributes sproc_metric \
  -info "Interact with metric definitions" \
  -define_args {
  {-cmd "Metric command" AnOos one_of_string
    {required value_help {values {add metrics display}}}
  }
  {-metric_name  "Metric name"   AString string optional}
  {-display_name "Dispplay name" AString string optional}
}

## -----------------------------------------------------------------------------
## sproc_filevar:
## -----------------------------------------------------------------------------

proc sproc_filevar { args } {
  global misc_file2var_hash
  global misc_file2var_counter

  set options(-cmd) ""
  set options(-file_name) ""
  parse_proc_arguments -args $args options

  if { ![info exists misc_file2var_hash] } {
    array set misc_file2var_hash {}
    set misc_file2var_counter 0
  }

  switch $options(-cmd) {
    add_file {
      if { ![info exists misc_file2var_hash($options(-file_name))] } {
        incr misc_file2var_counter
        set var "f$misc_file2var_counter"
        set misc_file2var_hash($options(-file_name)) $var
      }
    }
    get_var {
      if { [info exists misc_file2var_hash($options(-file_name))] } {
        return $misc_file2var_hash($options(-file_name))
      } else {
        puts "Error: sproc_filevar: Var not defined for -file_name: '$options(-file_name)'"
        return "UNDEFINED"
      }
    }
    get_files {
      return [array names misc_file2var_hash]
    }
  }
}

define_proc_attributes sproc_filevar \
  -info "Interact with file variable definitions" \
  -define_args {
  {-cmd "File variable command" AnOos one_of_string
    {required value_help {values {add_file get_var get_files}}}
  }
  {-file_name  "File name"   AString string optional}
}

## -----------------------------------------------------------------------------
## format_value:
## -----------------------------------------------------------------------------

proc format_value { formatString potentialNumber } {

  if { [string is double -strict $potentialNumber] } {
    return [format $formatString $potentialNumber]
  } else {
    return $potentialNumber
  }

}

## -----------------------------------------------------------------------------
## sproc_unicode:
## -----------------------------------------------------------------------------

proc sproc_unicode {} {
  global gvar

  if { $gvar(unicode) } {
    set str " [encoding convertfrom utf-8 "\xe5\xae\x9f\xe8\xa1\x8c\xe7\x9b\xae\xe7\x9a\x84"]"
  } else {
    set str ""
  }

  return $str
}

## -----------------------------------------------------------------------------
## sproc_parse_report_qor:
## -----------------------------------------------------------------------------

proc sproc_parse_report_qor { args } {

  global env SVAR

  set options(-file) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report for path group information.
  ## -------------------------------------

  set rval(path_group_data,scenario_name_list) [list]

  set scenario_name None/non-MCMM

  set path_group_name NO_PATH_GROUP

  set line_number 0
  set path_group_type undefined
  foreach line $lines {
    incr line_number

    regexp {^\s*Scenario\s+\'(.*)\'} $line matchVar scenario_name
    
    # for pt_concat.report_qor.pba which cats together multiple native PT report_qor files, there are some differences to account for
    # 1. uses LYNX_SCENARIO line to capture scenario_name because the native PT report_qor does not include scenario name along with
    #    each path group like ICC2 does
    # 2. splits data by path group type: for min_delay/hold capture hold data only, for max_delay/setup capture setup only
    #    if the path_group_type is detected at the end of "Timing Path Group", use the value to determine what data to capture.
    #    If path_group_type = "undefined", capture all data because that means it is an icc2 report_qor OR the Lynx-created non-native pt report_qor
    regexp {^\s*LYNX_SCENARIO:\s+(.*)} $line matchVar scenario_name
    regexp {^\s*Timing Path Group\s+'(\S+)'\s+\((.*)\)} $line matchVar path_group_name path_group_type
    #puts "DEBUG - path_group_type is $path_group_type" 
    
    if { [regexp {^\s*Timing Path Group\s+'(\S+)'} $line matchVar path_group_name] } {

      lappend rval(path_group_data,scenario_name_list) $scenario_name
      lappend rval(path_group_data,path_group_name_list,$scenario_name) $path_group_name

      # define setup metrics if path_group_type is undefined or max_delay/setup
      if {$path_group_type != "min_delay/hold"} {
        set rval(path_group_data,$scenario_name,$path_group_name,setup,logic_levels) NA
        set rval(path_group_data,$scenario_name,$path_group_name,setup,path_length)  NA
        set rval(path_group_data,$scenario_name,$path_group_name,setup,path_slack)   NA
        set rval(path_group_data,$scenario_name,$path_group_name,setup,path_period)  NA
        set rval(path_group_data,$scenario_name,$path_group_name,setup,tns)          NA
        set rval(path_group_data,$scenario_name,$path_group_name,setup,nvp)          NA
      }
      # define hold metrics if path_group_type is undefined or min_delay/hold
      if {$path_group_type != "max_delay/setup"} {
        set rval(path_group_data,$scenario_name,$path_group_name,hold,path_slack)    NA
        set rval(path_group_data,$scenario_name,$path_group_name,hold,tns)           NA
        set rval(path_group_data,$scenario_name,$path_group_name,hold,nvp)           NA
      }
      set rval(path_group_data,$scenario_name,$path_group_name,line_number) $line_number
      # define setup metrics if path_group_type is undefined or max_delay/setup
      if {$path_group_type != "min_delay/hold"} {
        set rval(path_group_data,$scenario_name,$path_group_name,setup,logic_levels,line_number) 1
        set rval(path_group_data,$scenario_name,$path_group_name,setup,path_length,line_number)  1
        set rval(path_group_data,$scenario_name,$path_group_name,setup,path_slack,line_number)   1
        set rval(path_group_data,$scenario_name,$path_group_name,setup,path_period,line_number)  1
        set rval(path_group_data,$scenario_name,$path_group_name,setup,tns,line_number)          1
        set rval(path_group_data,$scenario_name,$path_group_name,setup,nvp,line_number)          1
      }
      # define hold metrics if path_group_type is undefined or min_delay/hold
      if {$path_group_type != "max_delay/setup"} {
        set rval(path_group_data,$scenario_name,$path_group_name,hold,path_slack,line_number)    1
        set rval(path_group_data,$scenario_name,$path_group_name,hold,tns,line_number)           1
        set rval(path_group_data,$scenario_name,$path_group_name,hold,nvp,line_number)           1
      }
    }

    # capture setup metrics if path_group_type is undefined or max_delay/setup
    if {$path_group_type != "min_delay/hold"} {
      if { [regexp {^\s*Levels of Logic:\s+([\-\d\.]+)} $line matchVar data] } {
        set rval(path_group_data,$scenario_name,$path_group_name,setup,logic_levels) $data
        set rval(path_group_data,$scenario_name,$path_group_name,setup,logic_levels,line_number) $line_number
      }
      if { [regexp {^\s*Critical Path Length:\s+([\-\d\.]+)} $line matchVar data] } {
        set rval(path_group_data,$scenario_name,$path_group_name,setup,path_length) $data
        set rval(path_group_data,$scenario_name,$path_group_name,setup,path_length,line_number) $line_number
      }
      if { [regexp {^\s*Critical Path Slack:\s+([\-\d\.]+)} $line matchVar data] } {
        set rval(path_group_data,$scenario_name,$path_group_name,setup,path_slack) $data
        set rval(path_group_data,$scenario_name,$path_group_name,setup,path_slack,line_number) $line_number
      }
      if { [regexp {^\s*Critical Path Clk Period:\s+(\S+)} $line matchVar data] } {
        set rval(path_group_data,$scenario_name,$path_group_name,setup,path_period) $data
        set rval(path_group_data,$scenario_name,$path_group_name,setup,path_period,line_number) $line_number
      }
      if { [regexp {^\s*Total Negative Slack:\s+([\-\d\.]+)} $line matchVar data] } {
        set rval(path_group_data,$scenario_name,$path_group_name,setup,tns) $data
        set rval(path_group_data,$scenario_name,$path_group_name,setup,tns,line_number) $line_number
      }
      if { [regexp {^\s*No. of Violating Paths:\s+([\-\d\.]+)} $line matchVar data] } {
        set rval(path_group_data,$scenario_name,$path_group_name,setup,nvp) $data
        set rval(path_group_data,$scenario_name,$path_group_name,setup,nvp,line_number) $line_number
      }
    }
    # capture hold metrics if path_group_type is undefined (icc2 style)
    if {$path_group_type == "undefined"} {
      if { [regexp {^\s*Worst Hold Violation:\s+([\-\d\.]+)} $line matchVar data] } {
        set rval(path_group_data,$scenario_name,$path_group_name,hold,path_slack) $data
        set rval(path_group_data,$scenario_name,$path_group_name,hold,path_slack,line_number) $line_number
      }
      if { [regexp {^\s*Total Hold Violation:\s+([\-\d\.]+)} $line matchVar data] } {
        set rval(path_group_data,$scenario_name,$path_group_name,hold,tns) $data
        set rval(path_group_data,$scenario_name,$path_group_name,hold,tns,line_number) $line_number
      }
      if { [regexp {^\s*No. of Hold Violations:\s+([\-\d\.]+)} $line matchVar data] } {
        set rval(path_group_data,$scenario_name,$path_group_name,hold,nvp) $data
        set rval(path_group_data,$scenario_name,$path_group_name,hold,nvp,line_number) $line_number
      }
    }
    # capture hold metrics if path_group_type is min_delay/hold (native pt report_qor style)
    if {$path_group_type == "min_delay/hold"} {
      if { [regexp {^\s*Critical Path Slack:\s+([\-\d\.]+)} $line matchVar data] } {
        set rval(path_group_data,$scenario_name,$path_group_name,hold,path_slack) $data
        set rval(path_group_data,$scenario_name,$path_group_name,hold,path_slack,line_number) $line_number
      }
      if { [regexp {^\s*Total Negative Slack:\s+([\-\d\.]+)} $line matchVar data] } {
        set rval(path_group_data,$scenario_name,$path_group_name,hold,tns) $data
        set rval(path_group_data,$scenario_name,$path_group_name,hold,tns,line_number) $line_number
      }
      if { [regexp {^\s*No. of Violating Paths:\s+([\-\d\.]+)} $line matchVar data] } {
        set rval(path_group_data,$scenario_name,$path_group_name,hold,nvp) $data
        set rval(path_group_data,$scenario_name,$path_group_name,hold,nvp,line_number) $line_number
      }
    }
  }

  set rval(path_group_data,scenario_name_list) [lsort -unique $rval(path_group_data,scenario_name_list)]
  foreach scenario_name $rval(path_group_data,scenario_name_list) {
    set rval(path_group_data,path_group_name_list,$scenario_name) [lsort -unique $rval(path_group_data,path_group_name_list,$scenario_name)]
  }

  ## -------------------------------------
  ## Parse the report for summary information.
  ## -------------------------------------

  set rval(summary_data,_ss,scenario_name_list) [list]
  ## rval(summary_data,_ss,$scenario_name,setup,path_slack)
  ## rval(summary_data,_ss,$scenario_name,setup,tns)
  ## rval(summary_data,_ss,$scenario_name,setup,nvp)
  ## rval(summary_data,_ss,$scenario_name,hold,path_slack)
  ## rval(summary_data,_ss,$scenario_name,hold,tns)
  ## rval(summary_data,_ss,$scenario_name,hold,nvp)

  ## rval(summary_data,_ms,setup,path_slack)
  ## rval(summary_data,_ms,setup,tns)
  ## rval(summary_data,_ms,setup,nvp)
  ## rval(summary_data,_ms,hold,path_slack)
  ## rval(summary_data,_ms,hold,tns)
  ## rval(summary_data,_ms,hold,nvp)

  set line_number 0
  foreach line $lines {
    incr line_number

    ## -------------------------------------
    ## Per-scenario / Per-design setup (ICC2)
    ## -------------------------------------

    if { [regexp {^(\S+)\s+\(Setup\)\s+(\S+)\s+(\S+)\s+(\S+)} $line matchVar scenario_name wns tns nvp] } {

      if { $scenario_name != "Design" } {
        lappend rval(summary_data,_ss,scenario_name_list) $scenario_name
        set rval(summary_data,_ss,$scenario_name,setup,path_slack)             $wns
        set rval(summary_data,_ss,$scenario_name,setup,tns)                    $tns
        set rval(summary_data,_ss,$scenario_name,setup,nvp)                    $nvp

        set rval(summary_data,_ss,$scenario_name,setup,path_slack,line_number) $line_number
        set rval(summary_data,_ss,$scenario_name,setup,tns,line_number)        $line_number
        set rval(summary_data,_ss,$scenario_name,setup,nvp,line_number)        $line_number
      } else {
        set rval(summary_data,_ms,setup,path_slack)             $wns
        set rval(summary_data,_ms,setup,tns)                    $tns
        set rval(summary_data,_ms,setup,nvp)                    $nvp

        set rval(summary_data,_ms,setup,path_slack,line_number) $line_number
        set rval(summary_data,_ms,setup,tns,line_number)        $line_number
        set rval(summary_data,_ms,setup,nvp,line_number)        $line_number
      }
    }

    ## -------------------------------------
    ## Per-scenario setup (not ICC2)
    ## -------------------------------------

    if { [regexp {^\s*Scenario:\s+(\S+)\s+WNS:\s+(\S+)\s+TNS:\s+(\S+)\s+Number of Violating Paths:\s+(\S+)} $line matchVar scenario_name wns tns nvp] } {
      lappend rval(summary_data,_ss,scenario_name_list) $scenario_name
      set rval(summary_data,_ss,$scenario_name,setup,path_slack)             $wns
      set rval(summary_data,_ss,$scenario_name,setup,tns)                    $tns
      set rval(summary_data,_ss,$scenario_name,setup,nvp)                    $nvp

      set rval(summary_data,_ss,$scenario_name,setup,path_slack,line_number) $line_number
      set rval(summary_data,_ss,$scenario_name,setup,tns,line_number)        $line_number
      set rval(summary_data,_ss,$scenario_name,setup,nvp,line_number)        $line_number
    }

    ## -------------------------------------
    ## Per-design setup (not ICC2)
    ## -------------------------------------

    if { [regexp {^\s*Design\s+WNS:\s+(\S+)\s+TNS:\s+(\S+)\s+Number of Violating Paths:\s+(\S+)} $line matchVar wns tns nvp] } {
      set rval(summary_data,_ms,setup,path_slack)             $wns
      set rval(summary_data,_ms,setup,tns)                    $tns
      set rval(summary_data,_ms,setup,nvp)                    $nvp

      set rval(summary_data,_ms,setup,path_slack,line_number) $line_number
      set rval(summary_data,_ms,setup,tns,line_number)        $line_number
      set rval(summary_data,_ms,setup,nvp,line_number)        $line_number
    }

    ## -------------------------------------
    ## Per-scenario / Per-design hold (ICC2)
    ## -------------------------------------

    if { [regexp {^(\S+)\s+\(Hold\)\s+(\S+)\s+(\S+)\s+(\S+)} $line matchVar scenario_name wns tns nvp] } {
      if { $scenario_name != "Design" } {
        lappend rval(summary_data,_ss,scenario_name_list) $scenario_name
        set rval(summary_data,_ss,$scenario_name,hold,path_slack)             $wns
        set rval(summary_data,_ss,$scenario_name,hold,tns)                    $tns
        set rval(summary_data,_ss,$scenario_name,hold,nvp)                    $nvp

        set rval(summary_data,_ss,$scenario_name,hold,path_slack,line_number) $line_number
        set rval(summary_data,_ss,$scenario_name,hold,tns,line_number)        $line_number
        set rval(summary_data,_ss,$scenario_name,hold,nvp,line_number)        $line_number
      } else {
        set rval(summary_data,_ms,hold,path_slack)             $wns
        set rval(summary_data,_ms,hold,tns)                    $tns
        set rval(summary_data,_ms,hold,nvp)                    $nvp

        set rval(summary_data,_ms,hold,path_slack,line_number) $line_number
        set rval(summary_data,_ms,hold,tns,line_number)        $line_number
        set rval(summary_data,_ms,hold,nvp,line_number)        $line_number
      }
    }

    ## -------------------------------------
    ## Per-scenario hold (not ICC2)
    ## -------------------------------------

    if { [regexp {^\s*Scenario:\s+\s+\(Hold\)\s+(\S+)\s+WNS:\s+(\S+)\s+TNS:\s+(\S+)\s+Number of Violating Paths:\s+(\S+)} $line matchVar scenario_name wns tns nvp] } {
      lappend rval(summary_data,_ss,scenario_name_list) $scenario_name
      set rval(summary_data,_ss,$scenario_name,hold,path_slack)             $wns
      set rval(summary_data,_ss,$scenario_name,hold,tns)                    $tns
      set rval(summary_data,_ss,$scenario_name,hold,nvp)                    $nvp

      set rval(summary_data,_ss,$scenario_name,hold,path_slack,line_number) $line_number
      set rval(summary_data,_ss,$scenario_name,hold,tns,line_number)        $line_number
      set rval(summary_data,_ss,$scenario_name,hold,nvp,line_number)        $line_number
    }

    ## -------------------------------------
    ## Per-design hold (not ICC2)
    ## -------------------------------------

    if { [regexp {^\s*Design\s+\(Hold\)\s+WNS:\s+(\S+)\s+TNS:\s+(\S+)\s+Number of Violating Paths:\s+(\S+)} $line matchVar wns tns nvp] } {
      set rval(summary_data,_ms,hold,path_slack)             $wns
      set rval(summary_data,_ms,hold,tns)                    $tns
      set rval(summary_data,_ms,hold,nvp)                    $nvp

      set rval(summary_data,_ms,hold,path_slack,line_number) $line_number
      set rval(summary_data,_ms,hold,tns,line_number)        $line_number
      set rval(summary_data,_ms,hold,nvp,line_number)        $line_number
    }

  }

  set rval(summary_data,_ss,scenario_name_list) [lsort -unique $rval(summary_data,_ss,scenario_name_list)]

  ## -------------------------------------
  ## A "pt_concat.report_qor" file is generated after DMSA processing and is simply
  ## a concatenation of the "report_qor" files for each scenario (generated by the PT slaves),
  ## and the "pt_master.report_global_timing" file (generated by the PT master).
  ## The per-design metrics are extracted from the "pt_master.report_global_timing" content.
  ## -------------------------------------

  if { [file tail $options(-file)] == "pt_concat.report_qor" } {

    unset -nocomplain rval(summary_data,_ms,setup,path_slack)
    unset -nocomplain rval(summary_data,_ms,setup,tns)
    unset -nocomplain rval(summary_data,_ms,setup,nvp)
    unset -nocomplain rval(summary_data,_ms,setup,path_slack,line_number)
    unset -nocomplain rval(summary_data,_ms,setup,tns,line_number)
    unset -nocomplain rval(summary_data,_ms,setup,nvp,line_number)

    unset -nocomplain rval(summary_data,_ms,hold,path_slack)
    unset -nocomplain rval(summary_data,_ms,hold,tns)
    unset -nocomplain rval(summary_data,_ms,hold,nvp)
    unset -nocomplain rval(summary_data,_ms,hold,path_slack,line_number)
    unset -nocomplain rval(summary_data,_ms,hold,tns,line_number)
    unset -nocomplain rval(summary_data,_ms,hold,nvp,line_number)

    set line_number 0
    foreach line $lines {
      incr line_number

      if { [regexp {^Setup violations} $line] } {
        set type setup
      }
      if { [regexp {^Hold violations} $line] } {
        set type hold
      }

      if { [regexp {^WNS} $line] } {
        set rval(summary_data,_ms,$type,path_slack) [lindex $line 1]
        set rval(summary_data,_ms,$type,path_slack,line_number) $line_number
      }
      if { [regexp {^TNS} $line] } {
        set rval(summary_data,_ms,$type,tns)        [lindex $line 1]
        set rval(summary_data,_ms,$type,tns,line_number)        $line_number
      }
      if { [regexp {^NUM} $line] } {
        set rval(summary_data,_ms,$type,nvp)        [lindex $line 1]
        set rval(summary_data,_ms,$type,nvp,line_number)        $line_number
      }

      if { [regexp {^No setup violations found} $line] } {
        set type setup
        set rval(summary_data,_ms,$type,path_slack) 0.0
        set rval(summary_data,_ms,$type,tns)        0.0
        set rval(summary_data,_ms,$type,nvp)        0
        set rval(summary_data,_ms,$type,tns,line_number)        $line_number
        set rval(summary_data,_ms,$type,path_slack,line_number) $line_number
        set rval(summary_data,_ms,$type,nvp,line_number)        $line_number
      }
      if { [regexp {^No hold violations found} $line] } {
        set type hold
        set rval(summary_data,_ms,$type,path_slack) 0.0
        set rval(summary_data,_ms,$type,tns)        0.0
        set rval(summary_data,_ms,$type,nvp)        0
        set rval(summary_data,_ms,$type,tns,line_number)        $line_number
        set rval(summary_data,_ms,$type,path_slack,line_number) $line_number
        set rval(summary_data,_ms,$type,nvp,line_number)        $line_number
      }

    }

  }

  ## -------------------------------------
  ## Parse the report for design information.
  ## -------------------------------------

  ## set rval(design_data,leaf_cell_count)     ""
  ## set rval(design_data,bufinv_cell_count)   ""
  ## set rval(design_data,ctbufinv_cell_count) ""

  ## set rval(design_data,comb_cell_count)     ""
  ## set rval(design_data,seq_cell_count)      ""
  ## set rval(design_data,macro_cell_count)    ""

  ## set rval(design_data,cell_area)           ""
  ## set rval(design_data,design_area)         ""
  ## set rval(design_data,net_length)          ""

  ## set rval(design_data,net_count)           ""
  ## set rval(design_data,ldrc_total)          ""
  ## set rval(design_data,ldrc_trans)          ""
  ## set rval(design_data,ldrc_cap)            ""
  ## set rval(design_data,ldrc_fanout)         ""

  ## -------------------------------------

  ## set rval(design_data,leaf_cell_count,line_number)     1
  ## set rval(design_data,bufinv_cell_count,line_number)   1
  ## set rval(design_data,ctbufinv_cell_count,line_number) 1

  ## set rval(design_data,comb_cell_count,line_number)     1
  ## set rval(design_data,seq_cell_count,line_number)      1
  ## set rval(design_data,macro_cell_count,line_number)    1

  ## set rval(design_data,cell_area,line_number)           1
  ## set rval(design_data,design_area,line_number)         1
  ## set rval(design_data,net_length,line_number)          1

  ## set rval(design_data,net_count,line_number)           1
  ## set rval(design_data,ldrc_total,line_number)          1
  ## set rval(design_data,ldrc_trans,line_number)          1
  ## set rval(design_data,ldrc_cap,line_number)            1
  ## set rval(design_data,ldrc_fanout,line_number)         1

  ## -------------------------------------

  set line_number 0
  foreach line $lines {
    incr line_number

    if { [regexp {^Design\s*:\s*(\S+)} $line matchVar data] } {
      # For PT, pt_concat.report_qor has report_global_timing appended
      # which includes a line like this that needs to be ignore for design_name - Design : multi-scenario design
      if {$data != "multi-scenario"} {
        set rval(design_data,design_name) $data
        set rval(design_data,design_name,line_number) $line_number
      }
    }
    # This is for pt_concat.report_qor
    if { [regexp {^## Design\s*:\s*(\S+)} $line matchVar data] } {
      set rval(design_data,design_name) $data
      set rval(design_data,design_name,line_number) $line_number
    }
    if { [regexp {Leaf Cell Count:\s+([\d\.]+)} $line matchVar data] } {
      set rval(design_data,leaf_cell_count) $data
      set rval(design_data,leaf_cell_count,line_number) $line_number
    }
    if { [regexp {^\s*Buf/Inv Cell Count:\s+([\d\.]+)} $line matchVar data] } {
      set rval(design_data,bufinv_cell_count) $data
      set rval(design_data,bufinv_cell_count,line_number) $line_number
    }
    if { [regexp {^\s*CT Buf/Inv Cell Count:\s+([\d\.]+)} $line matchVar data] } {
      set rval(design_data,ctbufinv_cell_count) $data
      set rval(design_data,ctbufinv_cell_count,line_number) $line_number
    }

    if { [regexp {Combinational Cell Count:\s+([\d\.]+)} $line matchVar data] } {
      set rval(design_data,comb_cell_count) $data
      set rval(design_data,comb_cell_count,line_number) $line_number
    }
    if { [regexp {^\s*Sequential Cell Count:\s+([\d\.]+)} $line matchVar data] } {
      set rval(design_data,seq_cell_count) $data
      set rval(design_data,seq_cell_count,line_number) $line_number
    }
    if { [regexp {Macro Count:\s+([\d\.]+)} $line matchVar data] } {
      set rval(design_data,macro_cell_count) $data
      set rval(design_data,macro_cell_count,line_number) $line_number
    }

    if { [regexp {Cell Area:\s+([\d\.]+)} $line matchVar data] } {
      set rval(design_data,cell_area) $data
      set rval(design_data,cell_area,line_number) $line_number
    }
    if { [regexp {Cell Area\s+\(netlist\):\s+([\d\.]+)} $line matchVar data] } {
      set rval(design_data,cell_area) $data
      set rval(design_data,cell_area,line_number) $line_number
    }
    if { [regexp {Design Area:\s+([\d\.]+)} $line matchVar data] } {
      set rval(design_data,design_area) $data
      set rval(design_data,design_area,line_number) $line_number
    }
    if { [regexp {Cell Area\s+\(netlist and physical only\):\s+([\d\.]+)} $line matchVar data] } {
      set rval(design_data,design_area) $data
      set rval(design_data,design_area,line_number) $line_number
    }
    if { [regexp {Net Length\s*:\s+([\d\.]+)} $line matchVar data] } {
      set rval(design_data,net_length) $data
      set rval(design_data,net_length,line_number) $line_number
    }

    if { [regexp {Total Number of Nets:\s+([\d\.]+)} $line matchVar data] } {
      set rval(design_data,net_count) $data
      set rval(design_data,net_count,line_number) $line_number
    }
    if { [regexp {Nets With Violations:\s+([\d]+)} $line matchVar data] } {
      set rval(design_data,ldrc_total) $data
      set rval(design_data,ldrc_total,line_number) $line_number
    }
    if { [regexp {Nets with Violations:\s+([\d]+)} $line matchVar data] } {
      set rval(design_data,ldrc_total) $data
      set rval(design_data,ldrc_total,line_number) $line_number
    }
    if { [regexp {Max Trans Violations:\s+([\d]+)} $line matchVar data] } {
      set rval(design_data,ldrc_trans) $data
      set rval(design_data,ldrc_trans,line_number) $line_number
    }
    if { [regexp {Max Cap Violations:\s+([\d]+)} $line matchVar data] } {
      set rval(design_data,ldrc_cap) $data
      set rval(design_data,ldrc_cap,line_number) $line_number
    }
    if { [regexp {Max Fanout Violations:\s+([\d]+)} $line matchVar data] } {
      set rval(design_data,ldrc_fanout) $data
      set rval(design_data,ldrc_fanout,line_number) $line_number
    }
  }

  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_report_qor \
  -info "Parses information for report_qor." \
  -define_args {
  {-file "The report_qor file to parse." AString string required}
}

## -----------------------------------------------------------------------------
## sproc_parse_report_power:
## -----------------------------------------------------------------------------

proc sproc_parse_report_power { args } {

  global env SVAR

  set options(-file) ""
  set options(-scenario) ""
  set options(-synopsys_program_name) "NOT_DEFINED"
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0
  set rval(scenario_name_list) [list]

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------

  set rval(scenario_name_list) [list]

  if { $options(-scenario) == "" } {
    set scenario_name None/non-MCMM
  } else {
    set scenario_name $options(-scenario)
  }

  switch $options(-synopsys_program_name) {

    fc_shell -
    dc_shell -
    icc2_shell {

      set line_number 0
      foreach line $lines {
        incr line_number

        regexp {^Scenario(\(s\))?:\s+(\S+)} $line match optionalSubMatch scenario_name

        if { [regexp {^Total} $line] && ([lindex $line 1] != "Dynamic") } {

	  if { [lindex $line 1] == "N/A" } {
            set m1 N/A
	    set m2 N/A
            set m3 N/A
	    set m4 N/A
            set m5 [lindex $line 3]
	    set m6 [lindex $line 4]
            set m7 [lindex $line 5]
	    set m8 [lindex $line 6]
          } else {
            set m1 [lindex $line 1]
	    set m2 [lindex $line 2]
            set m3 [lindex $line 3]
	    set m4 [lindex $line 4]
            set m5 [lindex $line 5]
	    set m6 [lindex $line 6]
            set m7 [lindex $line 7]
	    set m8 [lindex $line 8]
	  }

          set rval($scenario_name,internal_power)        $m1
          set rval($scenario_name,internal_power_units)  $m2
          set rval($scenario_name,switching_power)       $m3
          set rval($scenario_name,switching_power_units) $m4
          set rval($scenario_name,leakage_power)         $m5
          set rval($scenario_name,leakage_power_units)   $m6
          set rval($scenario_name,total_power)           $m7
          set rval($scenario_name,total_power_units)     $m8

          set rval($scenario_name,internal_power,line_number)        $line_number
          set rval($scenario_name,internal_power_units,line_number)  $line_number
          set rval($scenario_name,switching_power,line_number)       $line_number
          set rval($scenario_name,switching_power_units,line_number) $line_number
          set rval($scenario_name,leakage_power,line_number)         $line_number
          set rval($scenario_name,leakage_power_units,line_number)   $line_number
          set rval($scenario_name,total_power,line_number)           $line_number
          set rval($scenario_name,total_power_units,line_number)     $line_number

          lappend rval(scenario_name_list) $scenario_name
        }
      }
      set rval(scenario_name_list) [lsort -unique $rval(scenario_name_list)]

    }

    pt_shell {

      set line_number 0
      foreach line $lines {
        incr line_number

        if { [regexp {^LYNX_SCENARIO:\s+(\S+)} $line match name] } {
          set scenario_name $name
        }

        if { [regexp {^\s*Net Switching Power\s+=\s+(\S+)} $line match value] } {
          set rval($scenario_name,switching_power)                   $value
          set rval($scenario_name,switching_power_units)             W

          set rval($scenario_name,switching_power,line_number)       $line_number
          set rval($scenario_name,switching_power_units,line_number) 1
        }
        if { [regexp {^\s*Cell Internal Power\s+=\s+(\S+)} $line match value] } {
          set rval($scenario_name,internal_power)                    $value
          set rval($scenario_name,internal_power_units)              W

          set rval($scenario_name,internal_power,line_number)        $line_number
          set rval($scenario_name,internal_power_units,line_number)  1
        }
        if { [regexp {^\s*Cell Leakage Power\s+=\s+(\S+)} $line match value] } {
          set rval($scenario_name,leakage_power)                     $value
          set rval($scenario_name,leakage_power_units)               W

          set rval($scenario_name,leakage_power,line_number)         $line_number
          set rval($scenario_name,leakage_power_units,line_number)   1
        }
        if { [regexp {^\s*Total Power\s+=\s+(\S+)} $line match value] } {
          set rval($scenario_name,total_power)                       $value
          set rval($scenario_name,total_power_units)                 W

          set rval($scenario_name,total_power,line_number)           $line_number
          set rval($scenario_name,total_power_units,line_number)     1

          lappend rval(scenario_name_list) $scenario_name
        }
      }
      set rval(scenario_name_list) [lsort -unique $rval(scenario_name_list)]

    }

    default {
      sproc_msg -error "Unrecognized value for options(-synopsys_program_name): '$options(-synopsys_program_name)'"
    }

  }

  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_report_power \
  -info "Parses information for report_power." \
  -define_args {
  {-file "The report_power file to parse." AString string required}
  {-scenario "The scenario name." AString string optional}
  {-synopsys_program_name "The program name." AString string required}
}

## -----------------------------------------------------------------------------
## sproc_parse_report_clock_qor:
## -----------------------------------------------------------------------------

proc sproc_parse_report_clock_qor { args } {

  global env SVAR

  set options(-file) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0
  set rval(scenario_list) [list]
  set rval(clock_list)    [list]

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------

  set rval(scenario_list) [list]
  set rval(clock_list) [list]
  ## set rval($scenario,$clock,<metric_name>,value)
  ## set rval($scenario,$clock,<metric_name>,line)

  set current_scenario ""

  set line_number 0
  foreach line $lines {
    incr line_number

    if { [regexp {^### Mode: (\S+), Scenario: (\S+)} $line match current_mode current_scenario] } {
      lappend rval(scenario_list) $current_scenario
    }
    if { [regexp {^--------} $line match] } {
      set current_scenario ""
    }

    if { $current_scenario != "" } {
      if { [scan $line {%s %s %s %s %s %s %s %s %s %s %s} clock Attrs Sinks Levels Clock_Repeater_Count Clock_Repeater_Area Clock_Stdcell_Area Max_Latency Global_Skew Trans_DRC_Count Cap_DRC_Count] == 11 } {
        lappend rval(clock_list) $clock
        set rval($current_scenario,$clock,Sinks,value)                $Sinks
        set rval($current_scenario,$clock,Sinks,line)                 $line_number
        set rval($current_scenario,$clock,Levels,value)               $Levels
        set rval($current_scenario,$clock,Levels,line)                $line_number
        set rval($current_scenario,$clock,Clock_Repeater_Count,value) $Clock_Repeater_Count
        set rval($current_scenario,$clock,Clock_Repeater_Count,line)  $line_number
        set rval($current_scenario,$clock,Clock_Repeater_Area,value)  $Clock_Repeater_Area
        set rval($current_scenario,$clock,Clock_Repeater_Area,line)   $line_number
        set rval($current_scenario,$clock,Clock_Stdcell_Area,value)   $Clock_Stdcell_Area
        set rval($current_scenario,$clock,Clock_Stdcell_Area,line)    $line_number
        set rval($current_scenario,$clock,Max_Latency,value)          $Max_Latency
        set rval($current_scenario,$clock,Max_Latency,line)           $line_number
        set rval($current_scenario,$clock,Global_Skew,value)          $Global_Skew
        set rval($current_scenario,$clock,Global_Skew,line)           $line_number
        set rval($current_scenario,$clock,Trans_DRC_Count,value)      $Trans_DRC_Count
        set rval($current_scenario,$clock,Trans_DRC_Count,line)       $line_number
        set rval($current_scenario,$clock,Cap_DRC_Count,value)        $Cap_DRC_Count
        set rval($current_scenario,$clock,Cap_DRC_Count,line)         $line_number
      }
    }

  }

  ## Clean up

  set rval(scenario_list) [lsort -unique $rval(scenario_list)]
  set rval(clock_list)    [lsort -unique $rval(clock_list)]

  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_report_clock_qor \
  -info "Parses information for report_clock_qor." \
  -define_args {
  {-file "The report_clock_qor file to parse." AString string required}
}

## -----------------------------------------------------------------------------
## sproc_parse_report_clock_tree:
## -----------------------------------------------------------------------------

proc sproc_parse_report_clock_tree { args } {

  global env SVAR

  set options(-file) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0
  set rval(scenario_name_list) [list]
  set rval(clk_name_list) [list]

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report (for Clock Tree Summary info)
  ## This information used for reporting
  ## -------------------------------------

  set in_section 0

  set index 0

  set line_number 0
  foreach line $lines {
    incr line_number

    if { [regexp {\=\=Report for scenario \((\S+)\)\=\=} $line match value] } {
      set scenario_name $value
      lappend rval(scenario_name_list) $scenario_name
      continue
    }

    if { [regexp {\=\= Clock Tree Summary =\=} $line] } {
      set in_section 1
      continue
    }

    if { $in_section } {
      if { [regexp {Clock\s+Sinks\s+CTBuffers\s+ClkCells\s+Skew\s+LongestPath\s+TotalDRC\s+BufferArea} $line] } {
        ## This is header line
        continue
      } elseif { [regexp {^----} $line] } {
        ## This is seperator line
        continue
      } elseif { [scan $line {%s %s %s %s %s %s %s %s} clock_name sinks buffers cells skew path drc area] == 8 } {
        ## This is data line
        set rval($scenario_name,$clock_name,sinks) $sinks
        set rval($scenario_name,$clock_name,skew)  $skew
        set rval($scenario_name,$clock_name,path)  $path
        set rval($scenario_name,$clock_name,drc)   $drc
        set rval($scenario_name,$clock_name,sinks,line_number) $line_number
        set rval($scenario_name,$clock_name,skew,line_number)  $line_number
        set rval($scenario_name,$clock_name,path,line_number)  $line_number
        set rval($scenario_name,$clock_name,drc,line_number)   $line_number
        continue
      } else {
        ## No longer in summary
        set in_section 0
        continue
      }
    }

  }

  ## -------------------------------------
  ## Parse the report (for Global Skew Report info)
  ## This information used for QOR JSON files
  ## -------------------------------------

  set rval(name_list) [list \
    "Clock Period" \
    "Number of Levels" \
    "Number of Sinks" \
    "Number of CT Buffers" \
    "Number of CTS added gates" \
    "Number of Preexisting Gates" \
    "Number of Preexisting Buf/Inv" \
    "Total Number of Clock Cells" \
    "Total Area of CT Buffers" \
    "Total Area of CT cells" \
    "Max Global Skew" \
    "Number of MaxTran Violators" \
    "Number of MaxCap Violators" \
    "Number of MaxFanout Violators" \
    "Clock global Skew" \
    "Longest path delay" \
    "Shortest path delay" \
    ]

  set in_section 0

  set index 0

  set line_number 0
  foreach line $lines {
    incr line_number

    if { [regexp {\=\=Report for scenario \((\S+)\)\=\=} $line match value] } {
      set scenario_name $value
      lappend rval(scenario_name_list) $scenario_name
      continue
    }

    if { [regexp {\=\= Global Skew Report =\=} $line] } {
      set in_section 1
      continue
    }

    if { $in_section } {

      if { [regexp "^Clock Tree Name" $line] } {
        set clk_name [lindex [split [string trim $line]] end]
        set clk_name [regsub -all {\"} $clk_name {}]
        lappend rval(clk_name_list) $clk_name
        lappend rval($scenario_name,clk_name_list) $clk_name
        foreach name $rval(name_list) {
          set rval($scenario_name,$clk_name,$name,value) unknown
          set rval($scenario_name,$clk_name,$name,line_number) 1
        }
        continue
      }

      foreach name $rval(name_list) {
        if { [regexp "^$name\s*\:*\s*" $line] } {
          set value [lindex [split [string trim $line]] end]
          set rval($scenario_name,$clk_name,$name,value) $value
          set rval($scenario_name,$clk_name,$name,line_number) $line_number

          ## set value_line [list $value $line_number]
          ## lappend rval($clk_name,$name,value_line_list) $value_line

          continue
        }
      }

      if { [regexp {^Report} $line] } {
        set in_section 0
        continue
      }

    }
  }

  ## Clean up

  set rval(scenario_name_list) [lsort -unique $rval(scenario_name_list)]
  set rval(clk_name_list)      [lsort -unique $rval(clk_name_list)]

  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_report_clock_tree \
  -info "Parses information for report_clock_tree." \
  -define_args {
  {-file "The report_clock_tree file to parse." AString string required}
}

## -----------------------------------------------------------------------------
## sproc_parse_report_clock_gating:
## -----------------------------------------------------------------------------

proc sproc_parse_report_clock_gating { args } {

  global env SEV SVAR pt_shell_mode

  set options(-file) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { [file exists $options(-file)] } {
    sproc_msg -info "The specified report file is: '$options(-file)'"
  } else {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report (for Clock Tree Summary info)
  ## This information used for reporting
  ## -------------------------------------

  set in_section 0

  set index 0
  set line_number 0
  foreach line $lines {
    incr line_number
   
    regexp -line {.*Number of Clock gating elements.* +[\|] +(\S+) .*::(\S+)} ${line}::$line_number \
      match rval(design_data,gating_elements) rval(design_data,gating_elements,line_number)
    regexp -line {.*Number of Gated registers +[\|] +(\S+) +\((\S+)%\) .*::(\S+)} ${line}::$line_number \
      match rval(design_data,gated_registers) rval(design_data,gated_register_percentage) rval(design_data,gated_register_percentage,line_number)
    regexp -line {.*Number of Ungated registers +[\|] +(\S+) +\((\S+)%\) .*::(\S+)} ${line}::$line_number \
      match rval(design_data,ungated_registers) rval(design_data,ungated_register_percentage) rval(design_data,ungated_register_percentage,line_number)
    regexp -line {.*Total number of registers +[\|] +(\S+) .*::(\S+)} ${line}::$line_number \
      match rval(design_data,num_regs) rval(design_data,num_regs,line_number)
  }

  set rval(design_data,gated_registers,line_number) $rval(design_data,gated_register_percentage,line_number)
  set rval(design_data,ungated_registers,line_number) $rval(design_data,ungated_register_percentage,line_number)
  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_report_clock_gating \
  -info "Parses information for report_clock_gating." \
  -define_args {
  {-file "The report_clock_gating file to parse." AString string required}
}

## -----------------------------------------------------------------------------
## sproc_parse_report_threshold_voltage_group:
## -----------------------------------------------------------------------------

proc sproc_parse_report_threshold_voltage_group { args } {

  global env SVAR

  set options(-file) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------

  set rval(vth,vth_names) [list]
  ## rval(cell_count,$vth_name)
  ## rval(cell_percentage,$vth_name)

  set line_number 0
  foreach line $lines {
    incr line_number

    if { [regexp {^Total} $line] } {
      break
    }

    ## stdcell_hvt 33747.84000 (68.76%) 0.00000 (0.00%) 33747.84000 (68.76%)

    if { [regexp {^(\S+)\s+(\S+)\s+\(\s*(\S+)\%\)\s+(\S+)\s+\(\s*(\S+)\%\)\s+(\S+)\s+\(\s*(\S+)\%\).*} $line match vth_name vth_count vth_percent n1 n2 n3 n4] } {

      lappend rval(vth,vth_names) $vth_name
      set rval(cell_count,$vth_name)                  $vth_count
      set rval(cell_percentage,$vth_name)             $vth_percent
      set rval(cell_count,$vth_name,line_number)      $line_number
      set rval(cell_percentage,$vth_name,line_number) $line_number
    }

  }

  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_report_threshold_voltage_group \
  -info "Parses information for report_threshold_voltage_group." \
  -define_args {
  {-file "The report_threshold_voltage_group file to parse." AString string required}
}

## -----------------------------------------------------------------------------
## sproc_parse_report_design:
## -----------------------------------------------------------------------------

proc sproc_parse_report_design { args } {

  global env SVAR

  set options(-file) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------

  set rval(num_drc_errors)                  -1
  set rval(num_drc_errors_types)            -1
  set rval(num_drc_errors,line_number)       1
  set rval(num_drc_errors_types,line_number) 1

  set rval(num_shorts)                      -1
  set rval(num_shorts,line_number)           1
  set rval(num_antenna)                     -1
  set rval(num_antenna,line_number)          1  
  
  set count_error_types 0
  set line_is_error_type false

  set line_number 0
  foreach line $lines {
    incr line_number

    if { [regexp {^.*TOTAL VIOLATIONS =\s+([\d]+)} $line match data] } {
      set rval(num_drc_errors)                   $data
      set rval(num_drc_errors,line_number)       $line_number
      set rval(num_drc_errors_types,line_number) $line_number
      set line_is_error_type true
      continue
    }

    if { [regexp {^Total number of nets =\s+([\d]+)} $line] } {
      set line_is_error_type false
      continue
    }

    if { [regexp {^.*Short :\s+([\d]+)} $line match data] } {
      set rval(num_shorts)                   $data
      set rval(num_shorts,line_number)       $line_number
    }
      
    if { [regexp {^Total number of antenna violations =\s+} $line] } {
      set rval(num_antenna)                   [regsub {^Total number of antenna violations =\s+} $line {}]
      set rval(num_antenna,line_number)       $line_number
    }

    if { [regexp {^Total number of DRCs =\s+([\d]+)} $line match data] } {
      if {$rval(num_drc_errors)== -1} {
        set rval(num_drc_errors)                   $data
        set rval(num_drc_errors,line_number)       $line_number
        set rval(num_drc_errors_types,line_number) $line_number
      }
    }

    if { $line_is_error_type } {
      incr count_error_types
    }
  }

  set rval(num_drc_errors_types) $count_error_types

  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_report_design \
  -info "Parses information for report_design." \
  -define_args {
  {-file "The report_design file to parse." AString string required}
}

## SS

## -----------------------------------------------------------------------------
## sproc_parse_report_drc:
## -----------------------------------------------------------------------------

proc sproc_parse_report_drc { args } {

  global env SVAR

  set options(-file) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------

  set rval(num_pv_drc_errors)                  -1
  set rval(num_pv_drc_errors_types)            -1
  set rval(icv_drc_run_time)                   -1

  set rval(num_pv_drc_errors,line_number)       1
  set rval(num_pv_drc_errors_types,line_number) 1
  set rval(icv_drc_run_time,line_number)        1

  set line_number 0 
  foreach line $lines {
    incr line_number

    if { [regexp {^Total number of violations:\s([\d]+)} $line match data1] } {
      set rval(num_pv_drc_errors)                   $data1
      set rval(num_pv_drc_errors,line_number)       $line_number
    }

    if { [regexp {^Total number of violation types:\s([\d]+)} $line match data2] } {
      set rval(num_pv_drc_errors_types)             $data2
      set rval(num_pv_drc_errors_types,line_number) $line_number
    }
    if { [regexp {^ICV DRC Run time:\s([\d]+):([\d]+):([\d]+)} $line match data5 data6 data7] } {
      set rval(icv_drc_run_time)             $data5:$data6:$data7
      set rval(icv_drc_run_time,line_number) $line_number
    }
  }

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------

  set rval(pv_drc_errors)                      -1
  set rval(pv_drc_errors,line_number)           1

  set line_number 0 
  set rval(pv_drc_errors) [list]
  set error_count 0
  foreach line $lines {
    incr line_number

    if { [regexp {^Violation:\s(...+)} $line match data3] } {
      # format of rval(pv_drc_errors) for TCL and PYTHON versions should be exactly the same
      #lappend rval(pv_drc_errors)            $data3
      set rval(pv_drc_errors)            "$rval(pv_drc_errors)\{$data3\}, "
      set rval(pv_drc_errors,line_number) $line_number

      ## Wanting to display upto only first 2 error codes
      incr error_count
      if { $error_count > "1" } {
        # format of rval(pv_drc_errors) for TCL and PYTHON versions should be exactly the same
        #lappend rval(pv_drc_errors)           "..."
        set rval(pv_drc_errors)           "$rval(pv_drc_errors)..."
        break
      }
    }
  }

  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_report_drc \
  -info "Parses information for report_drc." \
  -define_args {
  {-file "The report_drc file to parse." AString string required}
}

## -----------------------------------------------------------------------------
## sproc_parse_report_lvs_extract:
## -----------------------------------------------------------------------------

proc sproc_parse_report_lvs_extract { args } {

  global env SVAR

  set options(-file) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------

  set rval(pv_lvs_extraction_result)            -1
  set rval(pv_lvs_extraction_errors)            -1
  set rval(pv_lvs_extraction_result,line_number) 1
  set rval(pv_lvs_extraction_errors,line_number) 1
 
  set line_number 0   
  set rval(pv_lvs_extraction_errors) [list]
  set error_count 0
  foreach line $lines {
    incr line_number

    if { [regexp {^ICV LVS extraction result:\s([\w]+)} $line match data1] } {
      set rval(pv_lvs_extraction_result)                   $data1
      set rval(pv_lvs_extraction_result,line_number)       $line_number
    }
    if { [regexp {^Violation for design:\s(...+):\s(...+)} $line match data3 data4] } {
      lappend rval(pv_lvs_extraction_errors)    $data4
      set rval(pv_lvs_extraction_errors,line_number) $line_number

      ## Wanting to display upto only first 2 error codes
      incr error_count
      if { $error_count > "1" } {
        lappend rval(pv_lvs_extraction_errors)           "..."
        break
      }
    }
  }

  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_report_lvs_extract \
  -info "Parses information for report_lvs_extract." \
  -define_args {
  {-file "The report_lvs_extract file to parse." AString string required}
}

## -----------------------------------------------------------------------------
## sproc_parse_report_lvs_compare:
## -----------------------------------------------------------------------------

proc sproc_parse_report_lvs_compare { args } {

  global env SVAR

  set options(-file) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------

  set rval(pv_lvs_comparison_result)            -1
  set rval(pv_lvs_comparison_result,line_number) 1
 
  set line_number 0
  foreach line $lines {
    incr line_number

    if { [regexp {^ICV LVS compare result:\s([\w]+)} $line match data1] } {
      set rval(pv_lvs_comparison_result)             $data1
      set rval(pv_lvs_comparison_result,line_number) $line_number 
    }
    if { [regexp {^ICV LVS Run time:\s([\d]+):([\d]+):([\d]+)} $line match data5 data6 data7] } {
      set rval(icv_lvs_run_time)             $data5:$data6:$data7
      set rval(icv_lvs_run_time,line_number) $line_number
    }
  }

  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_report_lvs_compare \
  -info "Parses information for report_lvs_compare." \
  -define_args {
  {-file "The report_lvs_compare file to parse." AString string required}
}
## SS

## -----------------------------------------------------------------------------
## sproc_parse_report_utilization:
## -----------------------------------------------------------------------------

proc sproc_parse_report_utilization { args } {

  global env SVAR

  set options(-file) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------

  set rval(cell2core_ratio)                -1
  set rval(chip_area)                      -1

  ## -------------------------------------

  set rval(cell2core_ratio,line_number)      1
  set rval(chip_area,line_number)            1

  ## -------------------------------------

  set line_number 0
  foreach line $lines {
    incr line_number

    if { [regexp {^Utilization Ratio:\s+([\d\.]+)} $line match value] } {
      set rval(cell2core_ratio)             $value
      set rval(cell2core_ratio,line_number) $line_number
    }
    if { [regexp {^Total Area:\s+([\d\.]+)} $line match value] } {
      set rval(chip_area)             $value
      set rval(chip_area,line_number) $line_number
    }

  }

  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_report_utilization \
  -info "Parses information for report_utilization." \
  -define_args {
  {-file "The report_utilization file to parse." AString string required}
}

## -----------------------------------------------------------------------------
## sproc_parse_report_congestion:
## -----------------------------------------------------------------------------

proc sproc_parse_report_congestion { args } {

  global env SVAR

  set options(-file) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------

  set rval(grc_overflow) undefined

  foreach line $lines {
    regexp {Both Dirs: Overflow.*\(([\d\.]+)%\)} $line match rval(grc_overflow)
  }

  if { $rval(grc_overflow) == "undefined" } {
    sproc_msg -error "Unable to parse value for 'Both Dirs: Overflow'"
  }

  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_report_congestion \
  -info "Parses information for report_congestion." \
  -define_args {
  {-file "The report_congestion file to parse." AString string required}
}

## -----------------------------------------------------------------------------
## sproc_parse_report_units:
## -----------------------------------------------------------------------------

proc sproc_parse_report_units { args } {

  global env SVAR

  set options(-file) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag)       0
  set rval(time_unit)        "undefined"

  set rval(text_time)        "undefined"
  set rval(text_capacitance) "undefined"
  set rval(text_resistance)  "undefined"
  set rval(text_voltage)     "undefined"
  set rval(text_power)       "undefined"
  set rval(text_current)     "undefined"

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------

  set time_unit undefined
  foreach line $lines {
    regexp {(e\-\S\S)\s+Second} $line match time_unit

    regexp {^Time_unit\s+:\s+(.*)\s*$} $line match rval(text_time)
    regexp {^Capacitive_load_unit\s+:\s+(.*)\s*$} $line match rval(text_capacitance)
    regexp {^Resistance_unit\s+:\s+(.*)\s*$} $line match rval(text_resistance)
    regexp {^Voltage_unit\s+:\s+(.*)\s*$} $line match rval(text_voltage)
    regexp {^Power_unit\s+:\s+(.*)\s*$} $line match rval(text_power)
    regexp {^Current_unit\s+:\s+(.*)\s*$} $line match rval(text_current)
  }

  switch $time_unit {
    e-00 {
      set rval(time_unit) s
    }
    e-03 {
      set rval(time_unit) ms
    }
    e-06 {
      set rval(time_unit) us
    }
    e-09 {
      set rval(time_unit) ns
    }
    e-12 {
      set rval(time_unit) ps
    }
    e-15 {
      set rval(time_unit) fs
    }
    default {
      sproc_msg -error "Unrecognized value for time units: $time_unit"
      set rval(error_flag) 1
    }
  }

  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_report_units \
  -info "Parses information for report_units." \
  -define_args {
  {-file "The report_units file to parse." AString string required}
}

## -----------------------------------------------------------------------------
## sproc_parse_report_timing:
## -----------------------------------------------------------------------------

proc sproc_parse_report_timing { args } {

  global env SVAR

  set options(-file) ""
  set options(-scenario) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0
  set rval(items) [list]

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------

  if { $options(-scenario) == "" } {
    set scenario_name None/non-MCMM
  } else {
    set scenario_name $options(-scenario)
  }

  set line_number 0
  foreach line $lines {
    incr line_number

    regexp {^\s+Startpoint:\s+(\S+)} $line match start_point
    regexp {^\s+Endpoint:\s+(\S+)}   $line match end_point
    regexp {^\s+Scenario:\s+(\S+)}   $line match scenario_name
    regexp {^\s+Path Group:\s+(\S+)} $line match path_group
    regexp {^\s+Path Type:\s+(\S+)}  $line match path_type
    if { [regexp {^\s+slack\s+\(\S+\)\s+([\d\.\-]+)} $line match value] } {
      set slack $value
      set line $line_number
      set path_item "$scenario_name $start_point $end_point $path_group $path_type $slack $line"
      lappend rval(items) $path_item
    }

  }

  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_report_timing \
  -info "Parses information for report_timing." \
  -define_args {
  {-file     "The report_units file to parse." AString string required}
  {-scenario "The scenario name." AString string optional}
}

## -----------------------------------------------------------------------------
## sproc_parse_report_app_options:
## -----------------------------------------------------------------------------

proc sproc_parse_report_app_options { args } {

  global env SVAR

  set options(-file) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------
  set rval(app_option_list) [list]
  
  set line_number 0
  set inside_app_option_section 0
  set found_name 1
  set inside_rail_lib_file_line 0
  set inside_rail_lib_file_value 0
  
#  puts "DEBUG - Found [llength $lines] lines in $options(-file)"
  foreach line $lines {
    incr line_number

    ## lib.setting.compress_design_lib                bool       true                 true                       false          global     normal     /scripts_tech/icc2_global_nonpersistent_set_app_option.tcl:61

    if { ([regexp {^-----} $line]) && $found_name} {    
      set inside_app_option_section 1
      set found_name 0
      continue
    } elseif {([regexp {^-----} $line])} {
      set inside_app_option_section 0
      continue
    }

    if { ([regexp {^Name} $line])} {
      set found_name 1
    }
    
    #convert strange list_of types to a single string before processing line
    if {[regexp {^(\S+)\s+list_of\s+\{(\S+)\s+(\S+)\}} $line match app_option listof1 listof2]} {
      set new_string list_of_${listof1}_${listof2}
      regsub {list_of\s+\{(\S+)\s+(\S+)\}} $line $new_string line
    }

    if {[regexp {^(\S+)\s+list_of\s+(\S+)} $line match app_option listof1]} {
      set new_string list_of_${listof1}
      regsub {list_of\s+(\S+)} $line $new_string line
    }
                
    if {[regexp {^(\S+)\s+typed_value\s+typed_value} $line]} {
      set new_string typed_value_typed_value
      regsub {typed_value\s+typed_value} $line $new_string line
    }

    # -|- gets inserted after values in the table that exceed the normal column width.
    # Need to remove these because they cause parsing issues
    regsub {\-\|\-} $line "" line

    if { $inside_app_option_section} {
#      puts "DEBUG - I am looking at line number $line_number in $options(-file)"
#      puts "DEBUG - $line"
      if {!$inside_rail_lib_file_line} {

        if { [llength $line] > 3 } {
          # Get the name of the app_option
          set app_option [lindex $line 0]

          # Get the source file of the app_option if there is one and the value
          set app_option_src_file_link [lindex $line end]
          set app_option_src_file [lindex [split $app_option_src_file_link :] 0]
          if {[file exists $app_option_src_file]} {
            set app_option_src_file [file tail $app_option_src_file]
	    set app_option_value [lrange $line 2 end-5]
          } else {
            set app_option_src_file "--"
            set app_option_src_file_link ""
	    set app_option_value [lrange $line 2 end-4]
          }
	  
          # override above setting if the value is "--"
          if {([lindex $line 2] == "--")} {
	    set app_option_value "--"
          } 
          # special case for design.bus_delimiters to get it to display without curly brackets around it
          if {([lindex $line 2] == "\[\]")} {
	    set app_option_value "\[\]"
	    #puts "DEBUG $app_option = $app_option_value"
          } 
	  
          # if the value is long, truncate it to produce a better display in DT
          set value_length [string length $app_option_value]
          if {$value_length > 30} {
            set app_option_value "...[string range $app_option_value end-29 end]"
          }
      
          # if an app_option is found twice, that means it is non-default
          if { [lsearch -exact $rval(app_option_list) $app_option] == -1 } {
            lappend rval(app_option_list)               $app_option
#            set rval(value,$app_option)                        "$app_option_value (Y)"
            set rval(value,$app_option,default)              "Y"     
          } else {
#            set rval(value,$app_option)                        "$app_option_value (N)"
            set rval(value,$app_option,default)              "N"     
          }
          set rval(value,$app_option)                        "$app_option_value"
          set rval(value,$app_option,line_number)              $line_number      
          set rval(value,$app_option,app_option_src_file)      $app_option_src_file
          set rval(value,$app_option,app_option_src_file_link) $app_option_src_file_link    

	} else {
          if {[lindex $line 0]=="rail.lib_files"} {
            set inside_rail_lib_file_line 1
            set inside_rail_lib_file_value 1
            if {[llength $line] == 2} {
              set app_option_value ""
	    } else {
              set app_option_value [lindex $line end]
	    }
	  }
	}

      #rail analysis shows strange values for rail.lib_files app_option which is split over multiple lines, 
      #needs special processing which is handled in this else statement

      } else {
      
        # last character of open curly bracket means the end of the value, otherwise
        # add first element to the value of rail.lib_file
        # a line with more than 1 entry also means the end of the value has been found

        if {$inside_rail_lib_file_value} {
          if {[regexp {\{[ ]*$} $line]} {
            set inside_rail_lib_file_value 0
	  } else {
            lappend app_option_value [lindex $line 0]
            if {[llength $line] > 1} {
              set inside_rail_lib_file_value 0
	    }
	  }
          continue
	}
        
        # a line with more than 1 entry means it is the very last part of the rail.lib_files line
        if {[llength $line] > 1} {
          set app_option "rail.lib_files"
          # Get the source file of the app_option if there is one and the value
          set app_option_src_file_link [lindex $line end]
          set app_option_src_file [lindex [split $app_option_src_file_link :] 0]
          if {[file exists $app_option_src_file]} {
            set app_option_src_file [file tail $app_option_src_file]
          } else {
            set app_option_src_file "--"
            set app_option_src_file_link ""
          }

          # if the value is long, truncate it to produce a better display in DT
          set value_length [string length $app_option_value]
          if {$value_length > 30} {
            set app_option_value "...[string range $app_option_value end-29 end]"
          }
	
          # if an app_option is found twice, that means it is non-default
          if { [lsearch -exact $rval(app_option_list) $app_option] == -1 } {
            lappend rval(app_option_list)                    $app_option
#            set rval(value,$app_option)                        "$app_option_value (Y)"
            set rval(value,$app_option,default)              "Y"     
          } else {
#            set rval(value,$app_option)                        "$app_option_value (N)"
            set rval(value,$app_option,default)              "N"     
          }
          set rval(value,$app_option)                        "$app_option_value"
          set rval(value,$app_option,line_number)              $line_number      
          set rval(value,$app_option,app_option_src_file)      $app_option_src_file
          set rval(value,$app_option,app_option_src_file_link) $app_option_src_file_link    
	  set inside_rail_lib_file_line 0	  	  	  
        }
      }
    }
  }

  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
  
}

define_proc_attributes sproc_parse_report_app_options \
  -info "Parses information for report_app_options." \
  -define_args {
  {-file "The report_app_options file to parse." AString string required}
}

## -----------------------------------------------------------------------------
## sproc_parse_icc2_report_constraint:
## -----------------------------------------------------------------------------

proc sproc_parse_icc2_report_constraint { args } {


  global env SVAR

  set options(-file) ""
  set options(-clock_transition) 0.0500
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------
  set line_number 0
  set line_count_mode ""
  set net ""
  array unset net_violations
  array unset worst_violations
  foreach line $lines {
      incr line_number
      if {[regexp {^\s+Scenario: (\S+)} $line match scenario] }  {
	  set report_current_scenario $scenario
      } elseif {[regexp {sequential_clock_min_period} $line]}  {
	  set line_count_mode "min_period"
      } elseif {[regexp {max_capacitance} $line]}  {
	  set line_count_mode "max_capacitance"
      } elseif {[regexp {min_capacitance} $line]}  {
	  set line_count_mode "min_capacitance"
      } elseif {[regexp {max_transition} $line]}  {
	  set line_count_mode "max_transition"
      } elseif { $line_count_mode != ""} {
	  if {[regexp {^\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+\(VIOLATED\)} $line match net required actual slack] }  {
              # This if statement can optionally be used to try to identify clock nets but is overridden for now
	      if {$required <= $options(-clock_transition)} {
		  set net_mode clock 
	      } else {
		  set net_mode data
	      }
	      set net_mode data
	      if {$line_count_mode=="max_transition"} {
		  set tag "$line_count_mode,$net_mode"
	      } else {
		  set tag "$line_count_mode"
	      }		  
	      if {! [info exists net_violations($tag,$net,slack)]} {
		  set net_violations($tag,$net,slack) $slack
		  set net_violations($tag,$net,actual) $actual
		  set net_violations($tag,$net,scenario) $scenario
		  set net_violations($tag,$net,line_number) $line_number
	      } elseif {$slack < $net_violations($tag,$net,slack)} {
		  set net_violations($tag,$net,slack) $slack
		  set net_violations($tag,$net,actual) $actual
		  set net_violations($tag,$net,scenario) $scenario
		  set net_violations($tag,$net,line_number) $line_number
	      }
	      if {! [info exists worst_violations($tag,slack)]} {
		  set worst_violations($tag,slack) $slack
		  set worst_violations($tag,actual) $actual
		  set worst_violations($tag,scenario) $scenario
		  set worst_violations($tag,line_number) $line_number
	      } elseif {$slack < $worst_violations($tag,slack)} {
		  set worst_violations($tag,slack) $slack
		  set worst_violations($tag,actual) $actual
		  set worst_violations($tag,scenario) $scenario
		  set worst_violations($tag,line_number) $line_number
	      }
	  }
      }
  }
  foreach violation_type [list sequential_clock_min_period max_capacitance min_capacitance max_transition,clock max_transition,data] {
      set tag "${violation_type}*"
      set violation_count [llength [array names net_violations $tag,*,slack]]
      set rval($violation_type,count) $violation_count
      if {$violation_count>0} {
      set rval($violation_type,line_number) $worst_violations($violation_type,line_number)
      set rval($violation_type,slack) $worst_violations($violation_type,slack)
      set rval($violation_type,actual) $worst_violations($violation_type,actual)
      set rval($violation_type,scenario) $worst_violations($violation_type,scenario)
      } else {
      set rval($violation_type,line_number) 1
      set rval($violation_type,slack) 0
      set rval($violation_type,scenario) ""
      }	  
  }

  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_icc2_report_constraint \
  -info "Parses information from ICC2 report_constraint" \
  -define_args {
  {-file "The report_constraint file to check." AString string required}
  {-clock_transition "The required transition value distinguishing more tightly constrained clocks" Afloat float optional}
}

## -----------------------------------------------------------------------------
## sproc_parse_icc2_report_clock_timing:
## -----------------------------------------------------------------------------

proc sproc_parse_report_clock_timing { args } {

  global env SVAR

  set options(-file) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------
  set line_number 0
  set nextline ""

  foreach line $lines {
      incr line_number
      switch $nextline  {
	  "Maximum setup launch latency" -
	  "Minimum setup capture latency" -
	  "Minimum hold launch latency" -
	  "Maximum hold capture latency" -
	  "Maximum active transition" -
	  "Minimum active transition" {
              # this is for icc2
	      if {[regexp {(\S+)\s+(\S+)\s+(\S+)\s+(\S+)} $line match pin value transition corner]} {	      
		  set rval($current_clock_name,$current_clock_mode,$nextline,value) $value
		  set rval($current_clock_name,$current_clock_mode,$nextline,pin) $pin
		  set rval($current_clock_name,$current_clock_mode,$nextline,corner) $corner
		  set rval($current_clock_name,$current_clock_mode,$nextline,line_number) $line_number
		  set nextline ""
              # This is for the pt_concat format
	      } elseif {[regexp {(\S+)\s+(\S+)\s+(\S+)} $line match pin value transition] && ([file tail $options(-file)]=="pt_concat.report_clock_timing")} {
		  set rval($current_clock_name,$current_clock_mode,$nextline,value) $value
		  set rval($current_clock_name,$current_clock_mode,$nextline,pin) $pin
#		  set rval($current_clock_name,$current_clock_mode,$nextline,corner) $corner
		  set rval($current_clock_name,$current_clock_mode,$nextline,line_number) $line_number
		  set nextline ""
	      }
	  }
	  "Maximum setup skew" -
	  "Maximum hold skew" {
              # this is for icc2
	      if {[regexp {(\S+)\s+(\S+)\s+(\S+)\s+(\S+)} $line match pin value transition corner]} {	      
		  set rval($current_clock_name,$current_clock_mode,$nextline,value) $value
		  set rval($current_clock_name,$current_clock_mode,$nextline,pin) $pin
		  set rval($current_clock_name,$current_clock_mode,$nextline,corner) $corner
		  set rval($current_clock_name,$current_clock_mode,$nextline,line_number) $line_number
		  set nextline ""
              # This is for the pt_concat format
	      } elseif {[regexp {(\S+)\s+(\S+)\s+(\S+)} $line match pin value transition] && ([file tail $options(-file)]=="pt_concat.report_clock_timing")} {
		  set rval($current_clock_name,$current_clock_mode,$nextline,value) $value
		  set rval($current_clock_name,$current_clock_mode,$nextline,pin) $pin
#		  set rval($current_clock_name,$current_clock_mode,$nextline,corner) $corner
		  set rval($current_clock_name,$current_clock_mode,$nextline,line_number) $line_number
		  set nextline ""
	      }
	  }
	  default {
              if {  [regexp {^\s*LYNX_SCENARIO:\s+(.*)} $line match scenario] } {
		  set current_clock_mode $scenario
    	      } elseif {[regexp {Mode: (\S+)} $line match mode]} {
		  set current_clock_mode $mode
	      } elseif {[regexp {Clock: (\S+)} $line match clockname]} {
		  set current_clock_name $clockname
		  # reset nextline any time I find a Clock
                  #puts "resetting nextline because I found a Clock"
		  set nextline ""
	      } elseif {[regexp {(Maximum setup launch latency):} $line match nline]} {
		  set nextline $nline
	      } elseif {[regexp {(Minimum setup capture latency):} $line match nline]} {
		  set nextline $nline
	      } elseif {[regexp {(Minimum hold launch latency):} $line match nline]} {
		  set nextline $nline
	      } elseif {[regexp {(Maximum hold capture latency):} $line match nline]} {
		  set nextline $nline
	      } elseif {[regexp {(Maximum active transition):} $line match nline]} {
		  set nextline $nline
	      } elseif {[regexp {(Minimum active transition):} $line match nline]} {
		  set nextline $nline
	      } elseif {[regexp {(Maximum setup skew):} $line match nline]} {
		  set nextline $nline
	      } elseif {[regexp {(Maximum hold skew):} $line match nline]} {
		  set nextline $nline
	      }
	  }
      }
  }
	      
  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_report_clock_timing \
  -info "Parses information from ICC2 or PT report_clock_timing" \
  -define_args {
  {-file "The report_clock_timing file to check." AString string required}
}

## -----------------------------------------------------------------------------
## sproc_parse_pt_report_constraint:
## -----------------------------------------------------------------------------

proc sproc_parse_pt_report_constraint { args } {

  global env SVAR

  set options(-file) ""
  set options(-clock_transition) 0.120
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------
  set target_file $options(-file)
  set filelist [glob -nocomplain $target_file]
  if { [llength $filelist] < 1 } {
      sproc_msg -error "The specified report file does not exist: $options(-file)"
      set rval(error_flag) 1
      return 
  }
  array unset newviolation
  foreach afile $filelist {
      set base [split [file rootname [file tail $afile]] "."]
      set mode [lindex $base 1]
      set oc [lindex $base 2]
      set rc [lindex $base 3]
      ## -------------------------------------
      ## Read the report
      ## -------------------------------------
      
      set fid [open $afile r]
      set string_file [read $fid]
      close $fid
      set lines [split $string_file \n]
      set line_number 0
      set update_information 0
      foreach line $lines {
	  incr line_number
	  if {[regexp {sequential_clock_min_period} $line]}  {
	      set new_count_mode "sequential_clock_min_period"
	  } elseif {[regexp {removal} $line]}  {
	      set new_count_mode "removal"
	  } elseif {[regexp {min_delay/hold} $line]}  {
	      set new_count_mode "min_delay/hold"
	  } elseif {[regexp {max_delay/setup} $line]}  {
	      set new_count_mode "max_delay/setup"
	  } elseif {[regexp {sequential_clock_pulse_width} $line]}  {
	      set new_count_mode "sequential_clock_pulse_width"
	  } elseif {[regexp {max_capacitance} $line]}  {
	      set new_count_mode "max_capacitance"
	  } elseif {[regexp {min_capacitance} $line]}  {
	      set new_count_mode "min_capacitance"
	  } elseif {[regexp {max_transition} $line]}  {
	      set new_count_mode "max_transition"
	  } elseif {[regexp {\s+(\S+)\s+\((.*)\)\s+(\S+)\s+(\S+)\s+(\S+)\s+\(VIOLATED.*\)} $line match pin transition required actual slack] }  {
	      #if {$new_count_mode=="sequential_clock_min_period" } {puts "{$new_count_mode} $pin $transition $required $actual $slack"}
	      set update_information 1
#	      puts "DEBUG - $new_count_mode pin=$pin transition=$transition required=$required actual=$actual slack=$slack"
#              puts "DEBUG - FOUND TRANSITION"
	  } elseif {[regexp {\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+\((VIOLATED.*)\)} $line match pin scenario required actual slack] }  {
	      #puts "{$new_count_mode} $pin $required $actual $slack"
	      set update_information 1
#	      puts "DEBUG - $new_count_mode pin=$pin scenario=$scenario required=$required actual=$actual slack=$slack"
	  } elseif {[regexp {\s+(\S+)\s+(\S+)\s+(\S+)\s+\((VIOLATED.*)\)} $line match pin scenario slack] }  {
	      #puts "{$new_count_mode} $pin $slack"
	      set required ""
	      set actual ""
	      set update_information 1
#	      puts "DEBUG - $new_count_mode pin=$pin scenario=$scenario slack=$slack"
	  }
	  if {$update_information} {
	      if { [info exists newviolation($new_count_mode,$pin,slack)]} {
		  if { $slack < $newviolation($new_count_mode,$pin,slack)} {
#                      puts "DEBUG - pin=$pin slack=$slack old_worst_slack=$newviolation($new_count_mode,$pin,slack)"
		      set newviolation($new_count_mode,$pin,slack) $slack
		      set newviolation($new_count_mode,$pin,required) $required
		      set newviolation($new_count_mode,$pin,actual) $actual
		      set newviolation($new_count_mode,$pin,line_number) $line_number
		      set newviolation($new_count_mode,$pin,file) $afile
		      set newviolation($new_count_mode,count) [expr $newviolation($new_count_mode,count) + 1]
#                      puts "DEBUG - $new_count_mode count is $newviolation($new_count_mode,count)"
                     
		  }
	      } else {
		  set newviolation($new_count_mode,$pin,slack) $slack
		  set newviolation($new_count_mode,$pin,required) $required
		  set newviolation($new_count_mode,$pin,actual) $actual
		  set newviolation($new_count_mode,$pin,line_number) $line_number
		  set newviolation($new_count_mode,$pin,file) $afile
		  incr newviolation($new_count_mode,count) 
#                  puts "DEBUG - $new_count_mode count is $newviolation($new_count_mode,count)"
	      }
	      set update_information 0
	  }
      }
  }

  foreach vtype [list sequential_clock_min_period  sequential_clock_pulse_width min_delay/hold recovery max_delay/setup max_capacitance min_capacitance max_transition] {
      if {[info exists newviolation(${vtype},count)]} {
	  set rval(${vtype},count) $newviolation(${vtype},count)
	  set thisdata [get_smallest_value [array get newviolation "${vtype},*,slack"]]
	  set tag [lindex $thisdata 0]
	  set slack [lindex $thisdata 1]
	  set rval(${vtype},slack) $slack
	  set rval(${vtype},actual) $newviolation([string map {slack actual} $tag])
	  set rval(${vtype},file) $newviolation([string map {slack file} $tag])
	  set rval(${vtype},line_number) $newviolation([string map {slack line_number} $tag])
      } else {
	  set rval(${vtype},count) 0
      }
  }
  ## Also return split into clock and data
  ## clock will be all transitions measured to options(-clock_transition) or less
  set rval(max_transition_data,count) 0
  set rval(max_transition_clock,count) 0

  if {[info exists newviolation(max_transition,count)]} {
      array set alltran [array get newviolation "max_transition,*,required"]
      foreach item [array names alltran] {
	  set tokens [split $item ","]
	  set pin [lindex $tokens 1]
	  set oldtag "max_transition,${pin}"
	  if {$newviolation($item) > $options(-clock_transition)} {
	      set newtag "max_transition_data,${pin}"
	  } else {
	      set newtag "max_transition_clock,${pin}"
	  }
          # treat all max_tran as data violations
	  set newtag "max_transition_data,${pin}"
	  set newviolation($newtag,required) $newviolation($oldtag,required)
	  set newviolation($newtag,slack) $newviolation($oldtag,slack)
	  set newviolation($newtag,file) $newviolation($oldtag,file)
	  set newviolation($newtag,line_number) $newviolation($oldtag,line_number)
	  set newviolation($newtag,actual) $newviolation($oldtag,actual)
      }
      set rval(max_transition_data,count) [expr [llength [array get newviolation "max_transition_data,*,slack"]] / 2]
      if { $rval(max_transition_data,count) > 0} {
	  set thisdata [get_smallest_value [array get newviolation "max_transition_data,*,slack"]]
	  set tag [lindex $thisdata 0]
	  set slack [lindex $thisdata 1]
	  set rval(max_transition_data,slack) $slack
	  set rval(max_transition_data,file) $newviolation([string map {slack file} $tag])
	  set rval(max_transition_data,line_number) $newviolation([string map {slack line_number} $tag])
	  set rval(max_transition_data,required) $newviolation([string map {slack required} $tag])
	  set rval(max_transition_data,actual) $newviolation([string map {slack actual} $tag])
      }
      set rval(max_transition_clock,count) [expr [llength [array get newviolation "max_transition_clock,*,slack"]] / 2]
      if { $rval(max_transition_clock,count) > 0} {
	  set thisdata [get_smallest_value [array get newviolation "max_transition_clock,*,slack"]]
	  set tag [lindex $thisdata 0]
	  set slack [lindex $thisdata 1]
	  set rval(max_transition_clock,slack) $slack
	  set rval(max_transition_clock,file) $newviolation([string map {slack file} $tag])
	  set rval(max_transition_clock,line_number) $newviolation([string map {slack line_number} $tag])
	  set rval(max_transition_clock,required) $newviolation([string map {slack required} $tag])
	  set rval(max_transition_clock,actual) $newviolation([string map {slack actual} $tag])
      }
  }      
  set rval(file_count) [llength $filelist]
  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_pt_report_constraint \
  -info "Parses information from PrimeTime report_constraints -all_violators" \
  -define_args {
  {-file "Regexp of files to parse." AString string required}
  {-clock_transition "The required transition value distinguishing more tightly constrained clocks" Afloat float optional}
}

proc get_smallest_value {alist} {
    array set Darray $alist
    set smallest 9999999 
    set smallName None
    foreach aname [array names Darray] {
	set avalue $Darray($aname)
	if {[string is double -strict $avalue] &&  $avalue < $smallest } {
	    set smallest $avalue
	    set smallName $aname
	}
    }
    return [list $smallName $smallest]
}

## -----------------------------------------------------------------------------
## sproc_parse_pt_report_noise:
## -----------------------------------------------------------------------------

proc sproc_parse_pt_report_noise { args } {

  global env SVAR

  set options(-files) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------
  set files $options(-files)
  
  set noise_filelist [glob -nocomplain $files]
  
  if { [llength $noise_filelist] < 1 } { #
      sproc_msg -error "The specified report file(s) do not exist: $options(-files)"
      set rval(error_flag) 1
      return 
  }
  
  #
  # Find and count noise violations
  #
  set rval(noise_above_low) 0
  set rval(noise_below_high) 0
  set rval(files_checked) 0
  foreach noise_file $noise_filelist {
    ## -------------------------------------
    ## Parse the report
    ## -------------------------------------
    set fid [open $noise_file r]
    set string_file [read $fid]
    close $fid
    set rval(files_checked) [expr $rval(files_checked) + 1]
    set lines [split $string_file \n]
    set found_above_low_check 0
    set found_below_high_check 0
    set found_header 0
    set found_violation 0
    foreach line $lines {
      if {[regexp {noise_region: above_low} $line]} {
        set found_above_low_check 1
      } elseif {[regexp {noise_region: below_high} $line]} {
        set found_below_high_check 1
      } elseif {[regexp {pin name \(net name\)       width    height     slack} $line]} {
        set found_header 1
      } elseif {[regexp {\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*} $line]} {
        ## We're at the end of a section - reset everything
        set found_above_low_check 0
        set found_below_high_check 0
        set found_header 0
      } elseif {$found_header && [regexp {^\s*\S+\s+\(\S+\)\s+-?\d+(\.\d+)?\s+-?\d+(\.\d+)?\s+\S+\s*$} $line]} {
        # Ex: vl_wr_u_28_sms_sram_wr_st_dma_r4f_TS1N7MBLVTA8192X39M8QWBZHODCP/p_Q_r_reg_7_/D (BUF_net_653375)   0.1590   0.1464 POSITIVE
        if {$found_above_low_check} {
          set rval(noise_above_low) [expr $rval(noise_above_low) + 1]
          set found_violation 1
        } elseif {$found_below_high_check} {
          set rval(noise_below_high) [expr $rval(noise_below_high) + 1]
          set found_violation 1
        }
      }
    }
    if {$found_violation} {
      puts "$noise_file - Noise VIOLATION"
      set found_violation 0
    } else {
      # puts "$noise_file - MET"
    }
  }
  return [array get rval]
}
define_proc_attributes sproc_parse_pt_report_noise \
  -info "Returns a count of the total noise violations, both above_low and below_high, and the total files scanned" \
  -define_args {
  {-files "Regexp of  files to parse, e.g. \$block_dir/45_finish/rpts/930_outputs_sta/*.report_noise" AString string required}
}

## -----------------------------------------------------------------------------
## sproc_parse_report_icv_drc:
## -----------------------------------------------------------------------------

proc sproc_parse_report_icv_drc { args } {

  global env SVAR

  set options(-file) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------
  set line_number 0
  set starting_report 0
  foreach line $lines {
      incr line_number

      if {[regexp {^(\d+) total rules were run} $line match rules_run]}  {
	  set rval(rules_run)              $rules_run
	  set rval(rules_run,line_number)  $line_number
      } elseif {[regexp {^(\d+) rules have violations} $line match rules_violating]}  {
	  set rval(rules_violating)              $rules_violating
	  set rval(rules_violating,line_number)  $line_number
      } elseif {[regexp {^There are (\d+) total violations} $line match violation_count]}  {
	  set rval(violation_count)              $violation_count
	  set rval(violation_count,line_number)  $line_number
      }
  }


  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_report_icv_drc \
  -info "Parses information from ICV DRC run" \
  -define_args {
  {-file "The results file to check." AString string required}
}

## -----------------------------------------------------------------------------
## sproc_parse_report_icv_lvs:
## -----------------------------------------------------------------------------

proc sproc_parse_report_icv_lvs { args } {

  global env SVAR

  set options(-file) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------
  set line_number 0
  set starting_report 0
  foreach line $lines {
      incr line_number

      if {[regexp {^LVS Compare Result: (\S+)} $line match result]}  {
	  set rval(result)              $result
	  set rval(result,line_number)  $line_number
      } elseif {[regexp {^\s+(\d+) successful equivalencies} $line match equiv_pass]}  {
	  set rval(equiv_pass)              $equiv_pass
	  set rval(equiv_pass,line_number)  $line_number
      } elseif {[regexp {^\s+(\d+) failed equivalencies} $line match equiv_fail]}  {
	  set rval(equiv_fail)              $equiv_pass
	  set rval(equiv_fail,line_number)  $line_number
      }
  }


  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_report_icv_lvs \
  -info "Parses information from ICV LVS run" \
  -define_args {
  {-file "The result file to check." AString string required}
}

## -----------------------------------------------------------------------------
## sproc_parse_redhawk_log:
## -----------------------------------------------------------------------------

proc sproc_parse_redhawk_log { args } {

  global env SVAR

  set options(-file) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------

  set line_number 0
  set looking_for_static 0
  set looking_for_dynamic 0
  foreach line $lines {
    incr line_number

    if { [regexp {Choosing scenario (\S+) for analysis} $line match data] } {
	set rval(scenario)       [string trimright [string trimleft $data "'"] "'"]
      set rval(scenario,line_number)       $line_number
    } elseif { [regexp {^Corner:\s+(\S+)\s+Parasitic Technology Model:\s+(\S+)\s+Temperature:\s+(\S+)} $line match data rc temp] } {
	set rval(corner)                   [string trimright $data ","]
	set rval(rc)             $rc
	set rval(temperature)             $temp
	set rval(corner,line_number)   $line_number
    } elseif { [regexp {^Total Dynamic Power\s+=\s+(\S+) (\S+)} $line match data units] } {
      set rval(icc2_dynamic_power)                   $data
      set rval(icc2_dynamic_power_units)             $units
      set rval(icc2_dynamic_power,line_number)       $line_number
    } elseif { [regexp {^Cell Leakage Power\s+=\s+(\S+) (\S+)} $line match data units] } {
      set rval(icc2_leakage_power)                   $data
      set rval(icc2_leakage_power_units)                   $units
      set rval(icc2_leakage_power,line_number)       $line_number
    } elseif { [regexp {Total power calculated:\s+(\S+) (\S+)} $line match data units] } {
      set rval(redhawk_total_power)                   $data
      set rval(redhawk_total_power_units)                   $units
      set rval(redhawk_total_power,line_number)       $line_number
    } elseif { [regexp {Start EM check} $line] } {
      set rval(redhawk_em_metal_errors)                   "setup_problem"
      set rval(redhawk_em_metal_errors,line_number)       $line_number
    } elseif { [regexp {^\s+Total number of metal EM violations:\s+(\S+)} $line match data] } {
      set rval(redhawk_em_metal_errors)                   $data
      set rval(redhawk_em_metal_errors,line_number)       $line_number
    } elseif { [regexp {^\s+Total number of via\s+ EM violations:\s+(\S+)} $line match data] } {
      set rval(redhawk_em_via_errors)                   $data
      set rval(redhawk_em_via_errors,line_number)       $line_number
    } elseif { [regexp {Worst Static IR Drop:} $line] } {
      set looking_for_static 1
    } elseif { [regexp {^\s+Worst Static EM:} $line] } {
      set looking_for_em_wire 1
      set looking_for_em_via 1
    } elseif { [regexp {^\s+Worst Dynamic Voltage Drop:} $line] } {
      set looking_for_dynamic 1
    } elseif { [regexp {INST\s+(\S+)} $line match data] } {
	if {$looking_for_static} {
	    set rval(redhawk_static_irdrop)                   $data
	    set rval(redhawk_static_irdrop,line_number)       $line_number
	    set looking_for_static 0
	} elseif { $looking_for_dynamic } {
	    set rval(redhawk_dynamic_irdrop)                   $data
	    set rval(redhawk_dynamic_irdrop,line_number)       $line_number
	    set looking_for_dynamic 0
	}
    } elseif { [regexp {WIRE\s+(\S+)} $line match data] } {
	if {$looking_for_static} {
	    set rval(redhawk_static_irdrop)                   $data
	    set rval(redhawk_static_irdrop,line_number)       $line_number
	    set looking_for_static 0
	} elseif { $looking_for_dynamic } {
	    set rval(redhawk_dynamic_irdrop)                   $data
	    set rval(redhawk_dynamic_irdrop,line_number)       $line_number
	    set looking_for_dynamic 0
	} elseif { [info exists looking_for_em_wire] && $looking_for_em_wire } {
	    regexp {^\s+WIRE\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)} $line match data net limit location name
	    set rval(redhawk_em_wire)                   $data
	    set rval(redhawk_em_wire_net)                   $net
	    set rval(redhawk_em_wire_limit)                   $limit
	    set rval(redhawk_em_wire,line_number)       $line_number
	    set looking_for_em_wire 0
	}
    } elseif { [regexp {^\s+avgTW\s+(\S+)} $line match data] } {
	if { $looking_for_dynamic } {
	    set rval(redhawk_dynamic_irdrop_avgTW)                   $data
	    set rval(redhawk_dynamic_irdrop_avgTW,line_number)       $line_number
	}
    } elseif { [regexp {^\s+maxTW\s+(\S+)} $line match data] } {
	if { $looking_for_dynamic } {
	    set rval(redhawk_dynamic_irdrop_maxTW)                   $data
	    set rval(redhawk_dynamic_irdrop_maxTW,line_number)       $line_number
	}
    } elseif { [regexp {^\s+minTW\s+(\S+)} $line match data] } {
	if { $looking_for_dynamic } {
	    set rval(redhawk_dynamic_irdrop_minTW)                   $data
	    set rval(redhawk_dynamic_irdrop_minTW,line_number)       $line_number
	}
    } elseif { [regexp {^\s+minWC\s+(\S+)} $line match data] } {
	if { $looking_for_dynamic } {
	    set rval(redhawk_dynamic_irdrop_minWC)                   $data
	    set rval(redhawk_dynamic_irdrop_minWC,line_number)       $line_number
	    set looking_for_dynamic 0
	}
    } elseif { [regexp {^\s+WIRE\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)} $line match data net limit location name] } {
	if { [info exists looking_for_em_wire] && $looking_for_em_wire } {
	    set rval(redhawk_em_wire)                   $data
	    set rval(redhawk_em_wire_net)                   $net
	    set rval(redhawk_em_wire_limit)                   $limit
	    set rval(redhawk_em_wire,line_number)       $line_number
	    set looking_for_em_wire 0
	}
    } elseif { [regexp {^\s+VIA\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)} $line match data net limit location name] } {
	if { [info exists looking_for_em_via] && $looking_for_em_via } {
	    set rval(redhawk_em_via)                   $data
	    set rval(redhawk_em_via_net)                   $net
	    set rval(redhawk_em_via_limit)                   $limit
	    set rval(redhawk_em_via,line_number)       $line_number
	    set looking_for_em_via 0
	}
    }
  }

  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_redhawk_log \
  -info "Parses information from ICC2/redhawk log file." \
  -define_args {
  {-file "The log file to parse." AString string required}
}

## -----------------------------------------------------------------------------
## sproc_parse_irdrop_report:
## -----------------------------------------------------------------------------

proc sproc_parse_irdrop_report { args } {

  global env SVAR

  set options(-file) ""
  
  parse_proc_arguments -args $args options
  puts "static irdrop file is $options(-file)"
  
  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1

  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------
  set line_number 0
  set starting_report 0
  foreach line $lines {
      incr line_number
      if {[regexp {^#} $line]} {
	  set skip 1
      } elseif {[regexp {^(\S+)\s+(\S+)} $line match pin drop] }  {
	  set rval(pin) $pin
#	  set rval(rail) $rail
	  set rval(drop) $drop
	  set rval(line_number) $line_number
	  break
      }
  }
  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------
  return [array get rval]
}

define_proc_attributes sproc_parse_irdrop_report \
  -info "Parses information from Fusion Redhawk report_rail_result" \
  -define_args {
  {-file "The results file to check." AString string required}
}

## -----------------------------------------------------------------------------
## sproc_parse_report_signal_em:
## -----------------------------------------------------------------------------

proc sproc_parse_report_signal_em { args } {

  global env SVAR

  set options(-file) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1
    return [array get rval]
  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------
  set line_number 0
  set starting_report 0
  foreach line $lines {
    incr line_number

    if { [regexp {^Signal EM Analysis Summary} $line] } {
      set starting_report 1
    } elseif {$starting_report} {

	if {[regexp {^Scenario:\s+(\S+)} $line match scenario]}  {
	    set rval(scenario)              $scenario
	    set rval(scenario,line_number)  $line_number
	} elseif {[regexp {^Total Number of Nets:\s+(\d+)} $line match nets_all]}  {
	    set rval(nets_all)              $nets_all
	    set rval(nets_all,line_number)  $line_number
	} elseif {[regexp {^Nets with Violations:\s+(\d+)} $line match nets_violating]}  {
	    set rval(nets_violating)              $nets_violating
	    set rval(nets_violating,line_number)  $line_number
	} elseif {[regexp {^Ignored Nets:\s+(\d+)} $line match nets_ignored]}  {
	    set rval(nets_ignored)              $nets_ignored
	    set rval(nets_ignored,line_number)  $line_number
	} elseif {[regexp {^Signal\s+\|\s+([\d]+)\s+\|\s+([\d]+)\s+\|\s+([\d]+)\s+\|\s+([\d]+)\s+\|\s+([\d]+)\s+\|\s+([\d]+)} $line match nets all avg rms peak unfixable]}  {
	    set rval(signal_nets)                   $nets
	    set rval(signal_violators_all)          $all
	    set rval(signal_violators_avg)          $avg
	    set rval(signal_violators_rms)          $rms
	    set rval(signal_violators_peak)         $peak
	    set rval(signal_violators_unfixable)    $unfixable
	    set rval(signal_violators,line_number)  $line_number
	} elseif { [regexp {^Clock\s+\|\s+([\d]+)\s+\|\s+([\d]+)\s+\|\s+([\d]+)\s+\|\s+([\d]+)\s+\|\s+([\d]+)\s+\|\s+([\d]+)} $line match nets all avg rms peak unfixable] } {
	    set rval(clock_nets)                   $nets
	    set rval(clock_violators_all)          $all
	    set rval(clock_violators_avg)          $avg
	    set rval(clock_violators_rms)          $rms
	    set rval(clock_violators_peak)         $peak
	    set rval(clock_violators_unfixable)    $unfixable
	    set rval(clock_violators,line_number)  $line_number
	} elseif { [regexp {^Other\s+\|\s+([\d]+)\s+\|\s+([\d]+)\s+\|\s+([\d]+)\s+\|\s+([\d]+)\s+\|\s+([\d]+)\s+\|\s+([\d]+)} $line match nets all avg rms peak unfixable] } {
	    set rval(other_nets)                   $nets
	    set rval(other_violators_all)          $all
	    set rval(other_violators_avg)          $avg
	    set rval(other_violators_rms)          $rms
	    set rval(other_violators_peak)         $peak
	    set rval(other_violators_unfixable)    $unfixable
	    set rval(other_violators,line_number)  $line_number
	}
    }
  }

  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------

  return [array get rval]
}

define_proc_attributes sproc_parse_report_signal_em \
  -info "Parses information from report_signal_em" \
  -define_args {
  {-file "The pass file to check." AString string required}
}

## -----------------------------------------------------------------------------
## sproc_parse_lef_area:
## -----------------------------------------------------------------------------

proc sproc_parse_lef_area { args } {

  global env SVAR

  set options(-file) ""
  parse_proc_arguments -args $args options

  ## -------------------------------------
  ## Standard setup
  ## -------------------------------------

  set rval(error_flag) 0

  ## -------------------------------------
  ## Standard argument processing
  ## -------------------------------------

  if { ![file exists $options(-file)] } {
    sproc_msg -error "The specified report file does not exist: '$options(-file)'"
    set rval(error_flag) 1

  }

  ## -------------------------------------
  ## Read the report
  ## -------------------------------------

  set fid [open $options(-file) r]
  set string_file [read $fid]
  close $fid
  set lines [split $string_file \n]

  ## -------------------------------------
  ## Parse the report
  ## -------------------------------------
  set line_number 0
  set starting_report 0
  set ready_for_size 0
  foreach line $lines {
      incr line_number
      if {[regexp {^MACRO (\S+)} $line match blockname]}  {
	  set ready_for_size 1
      } elseif {$ready_for_size && [regexp {^\s+SIZE (\S+) BY (\S+) ;} $line match xsize ysize] }  {
	  set rval(xsize) $xsize
	  set rval(ysize) $ysize
	  set rval(xsize,line_number) $line_number
	  break
      }
  }

  ## -------------------------------------
  ## Return the parsed information
  ## -------------------------------------
  return [array get rval]
}

define_proc_attributes sproc_parse_lef_area \
  -info "Parses information from LEF for block size" \
  -define_args {
  {-file "The lef file to check." AString string required}
}

## -----------------------------------------------------------------------------
## End Of File
## -----------------------------------------------------------------------------
