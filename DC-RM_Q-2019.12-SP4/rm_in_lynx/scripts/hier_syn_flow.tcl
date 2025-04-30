source ../../../../../scripts_global/conf/header_start.tcl

source ../../../../../scripts_global/conf/header_stop.tcl

set FC_MAKEFILE [open $SEV(workarea_dir)/rm_setup/Makefile_dp_flat r]
while {[gets $FC_MAKEFILE line] >= 0} {
  if {[regexp "^HIER_SYNTHESIS_FLOW" $line]} {
    if {[regexp true $line]} {
      sproc_msg -info "From Makefile_dp_flat --> HIER_SYNTHESIS_FLOW=true"
      set decision 1
    } else {
      sproc_msg -info "From Makefile_dp_flat --> HIER_SYNTHESIS_FLOW!=true"
      set decision 2
    }
  }
}

sproc_broadcast_decision -decision $decision

sproc_script_stop

## -----------------------------------------------------------------------------
## End Of File
## -----------------------------------------------------------------------------
