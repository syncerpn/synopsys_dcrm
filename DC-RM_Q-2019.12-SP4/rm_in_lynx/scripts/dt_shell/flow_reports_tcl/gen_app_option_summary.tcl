#! /usr/bin/env tclsh
## -----------------------------------------------------------------------------
## HEADER_MSG  Lynx Design System: Baseline Flow
## HEADER_MSG  Version 2019.12-SP4
## HEADER_MSG  Copyright (c) 2020 Synopsys
## -----------------------------------------------------------------------------
## DESCRIPTION:
## * TBD
## -----------------------------------------------------------------------------

## -----------------------------------------------------------------------------
## Parse arguments
## -----------------------------------------------------------------------------

set garg(config_list) ""
set garg(config_file) ""
set garg(report_file) ""
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
  puts "Usage: gen_app_option_summary.tcl"
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

## -----------------------------------------------------------------------------
## sproc_gather_data:
## -----------------------------------------------------------------------------

proc sproc_gather_data {} {

  global env garg gvar
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
          if {$data != "--"} {
            set misc_status($build_label,$task_id,$metric_name,value) $data
	    set misc_status($build_label,$task_id,$metric_name,link) $link

            set default_data $app_options(value,$app_option,default)
            set default_link ""
            set misc_status($build_label,$task_id,$metric_name,default_value) $default_data
	    set misc_status($build_label,$task_id,$metric_name,default_link) $default_link
	  
            set src_file_data $app_options(value,$app_option,app_option_src_file)
            set src_file_link $app_options(value,$app_option,app_option_src_file_link)
            set misc_status($build_label,$task_id,$metric_name,src_file_value) $src_file_data
            set misc_status($build_label,$task_id,$metric_name,src_file_link) $src_file_link

            sproc_metric -cmd add -metric_name $metric_name -display_name $metric_display
	  }
        }
      }
    }
  }
}

## -----------------------------------------------------------------------------
## Metric colors
## -----------------------------------------------------------------------------

proc attrColor { metric_name metric_value } {

  set attr ""

  ## if app option is set to non-default value
  ## set color to black:chartreuse
  if { $metric_value == "N" } {
    set attr "#000000:#7fff00"
  }

  return $attr

}

## -----------------------------------------------------------------------------
## sproc_create_final_report:
## -----------------------------------------------------------------------------

proc sproc_create_final_report {} {

  global env garg gvar
  global misc_status

  set fid [open $gvar(report_file) w]

  ## -------------------------------------
  ## Determine all available builds
  ## -------------------------------------

  set build_label_list [list]
  foreach build_item $gvar(build_item_list) {
    lassign $build_item build_label build_dir
    lappend build_label_list $build_label
  }

  set hasSingleBlock 0
  if { [llength $build_label_list] == 1 } {
    set hasSingleBlock 1
  }

  ## -------------------------------------
  ## Print the LYNX_BEGIN statement
  ## -------------------------------------

  puts $fid "LYNX_BEGIN|lynx_table_merge|my_table_merge"
  puts $fid ""

  puts $fid "TABLE_ID_FORMAT|TableStyle"
  puts $fid ""

  set tableStyleList [list TaskFocus TrendFocus]

  foreach tableStyle $tableStyleList {

    ## -------------------------------------
    ## Print the TABLE_BEGIN statement
    ## -------------------------------------

    puts $fid "TABLE_BEGIN"
    puts $fid ""

    puts $fid "TABLE_ID|$tableStyle"
    puts $fid ""

    ## -------------------------------------
    ## Print the DATA section
    ## -------------------------------------

    unset -nocomplain attr_lines
    unset -nocomplain link_lines

    set attr_array(rowHeader1) #ffffff:#000099:L
    set attr_array(rowHeader2) #ffffff:#3333ff:C
    set attr_array(colHeader1) #ffffff:#303030:L

    puts $fid "DATA_BEGIN"

    ## -------------------------------------
    ## Print the HEADER lines
    ## While doing this, also:
    ## Create information for ATTR section (create $attr_lines, which is output later)
    ## Create information for LINK section (create $link_lines, which is output later)
    ## -------------------------------------

    if { $tableStyle == "TaskFocus" } {

      ## Tasks across top (and builds if multi-build), Metrics down left
      ## Row 0: task_step
      ## Row 1: task_dst
      ## Row 2: task_name
      ## Row 3: build_label (if multi-build)

      ## Single frozen col for metrics
      puts $fid "HEADER_COLS|1"

      if { $hasSingleBlock } {
        ## step, dst, task, Value & Source
        set headerRows 4
      } else {
        ## step, dst, task, build, Value & Source
        set headerRows 5
      }

      for { set row 0 } { $row < $headerRows } { incr row } {

        set header_line "HEADER"
        set attr_line   "HEADER"
        set link_line   "HEADER"

        set header_line "$header_line|Metric"
        set attr_line   "$attr_line|$attr_array(rowHeader1)"
        set link_line   "$link_line|"

        foreach task_info [sproc_build_info -build_label $build_label -cmd get] {
          lassign $task_info task_flow_order task_step task_dst task_name task_id task_tool task_report_list

          foreach build_label $build_label_list {
            switch $row {
              0 {
                set header_line "$header_line|$task_step|$task_step"
                set attr_line   "$attr_line|$attr_array(rowHeader2)|$attr_array(rowHeader2)"
                set link_line   "$link_line||"
              }
              1 {
                set header_line "$header_line|$task_dst|$task_dst"
                set attr_line   "$attr_line|$attr_array(rowHeader2)|$attr_array(rowHeader2)"
                set link_line   "$link_line||"
              }
              2 {
                set header_line "$header_line|$task_name|$task_name"
                set attr_line   "$attr_line|$attr_array(rowHeader2)|$attr_array(rowHeader2)"
                set link_line   "$link_line||"
              }
              3 {
                if {$headerRows == 5} {
                  set header_line "$header_line|$build_label|$build_label"
                  set attr_line   "$attr_line|$attr_array(rowHeader2)|$attr_array(rowHeader2)"
                  set link_line   "$link_line||"
		} else {
                  set header_line "$header_line|Value|Source"
                  set attr_line   "$attr_line|$attr_array(rowHeader2)|$attr_array(rowHeader2)"
                  set link_line   "$link_line||"
		}
              }
              4 {
                set header_line "$header_line|Value|Source"
                set attr_line   "$attr_line|$attr_array(rowHeader2)|$attr_array(rowHeader2)"
                set link_line   "$link_line||"
              }
            }
          }
        }

        puts $fid $header_line
        lappend attr_lines $attr_line
        lappend link_lines $link_line

      }

    } else {

      ## Metrics across top (and builds if multi-build), tasks down left

      if { $hasSingleBlock } {

        ## Print 2 row headers
        ## Row 0: metrics
        ## Row 1: Value Source
	
        puts $fid "HEADER_COLS|3"

        ## Row 0:

        set header_line "HEADER"
        set attr_line   "HEADER"
        set link_line   "HEADER"

        set header_line "$header_line|Step|Dst|Task"
        set attr_line   "$attr_line|$attr_array(rowHeader1)|$attr_array(rowHeader1)|$attr_array(rowHeader1)"
        set link_line   "$link_line|||"

        foreach metric_name [lsort [sproc_metric -cmd metrics]] {
          set header_line "$header_line|[sproc_metric -cmd display -metric_name $metric_name]|[sproc_metric -cmd display -metric_name $metric_name]"
          set attr_line   "$attr_line|$attr_array(rowHeader2)|$attr_array(rowHeader2)"
          set link_line   "$link_line||"
        }

        puts $fid $header_line
        lappend attr_lines $attr_line
        lappend link_lines $link_line

        ## Row 1:

        set header_line "HEADER"
        set attr_line   "HEADER"
        set link_line   "HEADER"

        set header_line "$header_line|Step|Dst|Task"
        set attr_line   "$attr_line|$attr_array(rowHeader1)|$attr_array(rowHeader1)|$attr_array(rowHeader1)"
        set link_line   "$link_line|||"

        foreach metric_name [lsort [sproc_metric -cmd metrics]] {
          set header_line "$header_line|Value|Source"
          set attr_line   "$attr_line|$attr_array(rowHeader2)|$attr_array(rowHeader2)"
          set link_line   "$link_line||"
        }

        puts $fid $header_line
        lappend attr_lines $attr_line
        lappend link_lines $link_line
	
      } else {

        ## Print 3 row headers
        ## Row 0: metrics (replicate each column of metrics per number of builds)
        ## Row 1: builds (cycle through builds for each metric)
        ## Row 2: Value Source
	
        puts $fid "HEADER_COLS|3"

        ## Row 0:

        set header_line "HEADER"
        set attr_line   "HEADER"
        set link_line   "HEADER"

        set header_line "$header_line|Step|Dst|Task"
        set attr_line   "$attr_line|$attr_array(rowHeader1)|$attr_array(rowHeader1)|$attr_array(rowHeader1)"
        set link_line   "$link_line|||"

        foreach metric_name [lsort [sproc_metric -cmd metrics]] {
          foreach build_label $build_label_list {
            set header_line "$header_line|[sproc_metric -cmd display -metric_name $metric_name]|[sproc_metric -cmd display -metric_name $metric_name]"
            set attr_line   "$attr_line|$attr_array(rowHeader2)|$attr_array(rowHeader2)"
            set link_line   "$link_line||"
          }
        }

        puts $fid $header_line
        lappend attr_lines $attr_line
        lappend link_lines $link_line

        ## Row 1:

        set header_line "HEADER"
        set attr_line   "HEADER"
        set link_line   "HEADER"

        set header_line "$header_line|Step|Dst|Task"
        set attr_line   "$attr_line|$attr_array(rowHeader1)|$attr_array(rowHeader1)|$attr_array(rowHeader1)"
        set link_line   "$link_line|||"

        foreach metric_name [lsort [sproc_metric -cmd metrics]] {
          foreach build_label $build_label_list {
            set header_line "$header_line|$build_label|$build_label"
            set attr_line   "$attr_line|$attr_array(rowHeader2)|$attr_array(rowHeader2)"
            set link_line   "$link_line||"
          }
        }

        puts $fid $header_line
        lappend attr_lines $attr_line
        lappend link_lines $link_line

        ## Row 2:

        set header_line "HEADER"
        set attr_line   "HEADER"
        set link_line   "HEADER"

        set header_line "$header_line|Step|Dst|Task"
        set attr_line   "$attr_line|$attr_array(rowHeader1)|$attr_array(rowHeader1)|$attr_array(rowHeader1)"
        set link_line   "$link_line|||"

        foreach metric_name [lsort [sproc_metric -cmd metrics]] {
          foreach build_label $build_label_list {
            set header_line "$header_line|Value|Source"
            set attr_line   "$attr_line|$attr_array(rowHeader2)|$attr_array(rowHeader2)"
            set link_line   "$link_line||"
          }
        }

        puts $fid $header_line
        lappend attr_lines $attr_line
        lappend link_lines $link_line
	
      }

    }

    ## -------------------------------------
    ## Print the VALUE lines
    ## While doing this, also:
    ## Create information for ATTR section (create $attr_lines, which is output later)
    ## Create information for LINK section (create $link_lines, which is output later)
    ## -------------------------------------

    if { $tableStyle == "TaskFocus" } {

      ## Tasks across top (and builds if multi-build), Metrics down left

      foreach metric_name [lsort [sproc_metric -cmd metrics]] {

        set value_line "VALUE"
        set attr_line  "VALUE"
        set link_line  "VALUE"

        set value_line "$value_line|[sproc_metric -cmd display -metric_name $metric_name]"
        set attr_line  "$attr_line|$attr_array(colHeader1)"
        set link_line  "$link_line|"

        foreach task_info [sproc_build_info -build_label $build_label -cmd get] {
          lassign $task_info task_flow_order task_step task_dst task_name task_id task_tool task_report_list

          foreach build_label $build_label_list {

            if { [info exists misc_status($build_label,$task_id,$metric_name,value)] } {
              set value $misc_status($build_label,$task_id,$metric_name,value)
            } else {
              set value ""
            }
            if { [info exists misc_status($build_label,$task_id,$metric_name,default_value)] } {
              set attr [attrColor $metric_name $misc_status($build_label,$task_id,$metric_name,default_value)]
	    } else {
              set attr ""
	    }

            if { [info exists misc_status($build_label,$task_id,$metric_name,link)] } {
              set link $misc_status($build_label,$task_id,$metric_name,link)
            } else {
              set link ""
            }

            if { [info exists misc_status($build_label,$task_id,$metric_name,src_file_value)] } {
              set src_file_value $misc_status($build_label,$task_id,$metric_name,src_file_value)
            } else {
              set src_file_value ""
            }
            set src_file_attr ""
#            set src_file_attr [attrColor $metric_name $src_file_value]
	    
            if { [info exists misc_status($build_label,$task_id,$metric_name,src_file_link)] } {
              set src_file_link $misc_status($build_label,$task_id,$metric_name,src_file_link)
            } else {
              set src_file_link ""
            }
	    
            set value_line "$value_line|$value|$src_file_value"
            set attr_line  "$attr_line|$attr|$src_file_attr"
            set link_line  "$link_line|$link|$src_file_link"

          }

        }

        puts $fid $value_line
        lappend attr_lines $attr_line
        lappend link_lines $link_line

      }

    } else {

      foreach task_info [sproc_build_info -build_label $build_label -cmd get] {
        lassign $task_info task_flow_order task_step task_dst task_name task_id task_tool task_report_list

        set value_line "VALUE|$task_step|$task_dst|$task_name"
        set attr_line  "VALUE|$attr_array(colHeader1)|$attr_array(colHeader1)|$attr_array(colHeader1)"
        set link_line  "VALUE|||"

        foreach metric_name [lsort [sproc_metric -cmd metrics]] {
          foreach build_label $build_label_list {

            if { [info exists misc_status($build_label,$task_id,$metric_name,value)] } {
              set value $misc_status($build_label,$task_id,$metric_name,value)
            } else {
              set value ""
            }
            if { [info exists misc_status($build_label,$task_id,$metric_name,default_value)] } {
              set attr [attrColor $metric_name $misc_status($build_label,$task_id,$metric_name,default_value)]
	    } else {
              set attr ""
	    }
	    
            if { [info exists misc_status($build_label,$task_id,$metric_name,link)] } {
              set link $misc_status($build_label,$task_id,$metric_name,link)
            } else {
              set link ""
            }

            if { [info exists misc_status($build_label,$task_id,$metric_name,src_file_value)] } {
              set src_file_value $misc_status($build_label,$task_id,$metric_name,src_file_value)
            } else {
              set src_file_value ""
            }
            set src_file_attr ""
#            set src_file_attr [attrColor $metric_name $src_file_value]
	    
            if { [info exists misc_status($build_label,$task_id,$metric_name,src_file_link)] } {
              set src_file_link $misc_status($build_label,$task_id,$metric_name,src_file_link)
            } else {
              set src_file_link ""
            }
	    
            set value_line "$value_line|$value|$src_file_value"
            set attr_line  "$attr_line|$attr|$src_file_attr"
            set link_line  "$link_line|$link|$src_file_link"

          }
        }

        puts $fid $value_line
        lappend attr_lines $attr_line
        lappend link_lines $link_line
      }

    }

    puts $fid "DATA_END"
    puts $fid ""

    ## -------------------------------------
    ## Print the ATTR section
    ## -------------------------------------

    puts $fid "ATTR_BEGIN"
    foreach line $attr_lines {
      puts $fid $line
    }
    puts $fid "ATTR_END"
    puts $fid ""

    ## -------------------------------------
    ## Print the LINK section
    ## -------------------------------------

    puts $fid "LINK_BEGIN"
    foreach line $link_lines {
      puts $fid $line
    }
    puts $fid "LINK_END"
    puts $fid ""

    ## -------------------------------------
    ## Print the FORMAT section
    ## -------------------------------------

    ## -------------------------------------
    ## Create the title information
    ## -------------------------------------

    set title "App Option Summary ($tableStyle) : "

    foreach build_label $build_label_list {
      set title "$title $build_label"
    }

    set subtitle "Created on [sproc_date]"

    ## -------------------------------------
    ## Output the section information
    ## -------------------------------------

    puts $fid "FORMAT_BEGIN"
    puts $fid "TITLE|$title"
    puts $fid "SUBTITLE|$subtitle"
    puts $fid "FORMAT_END"
    puts $fid ""

    ## -------------------------------------
    ## Print the TABLE_END statement
    ## -------------------------------------

    puts $fid "TABLE_END"
    puts $fid ""

  }

  ## -------------------------------------
  ## Print the LYNX_END statement
  ## -------------------------------------

  puts $fid "LYNX_END"

  close $fid

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
