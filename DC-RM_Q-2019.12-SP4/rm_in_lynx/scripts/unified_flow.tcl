source ../../../../../scripts_global/conf/header_start.tcl

source ../../../../../scripts_global/conf/header_stop.tcl

set FC_SETUP_FILE [open $SEV(workarea_dir)/rm_setup/fc_setup.tcl r]
while {[gets $FC_SETUP_FILE line] >= 0} {
  if {[regexp "set UNIFIED_FLOW" $line]} {
    if {[regexp true $line]} {
      sproc_msg -info "From fc_setup.tcl --> UNIFIED_FLOW"
      set decision 1
    } else {
      sproc_msg -info "From fc_setup.tcl --> CLASSIC_FLOW"
      set decision 2
    }
  }
}

sproc_broadcast_decision -decision $decision

sproc_script_stop

## -----------------------------------------------------------------------------
## End Of File
## -----------------------------------------------------------------------------
