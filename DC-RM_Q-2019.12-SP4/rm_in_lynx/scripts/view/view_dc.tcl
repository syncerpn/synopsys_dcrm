## -----------------------------------------------------------------------------
## DESCRIPTION:
## * This task is used to interactively open a session with Design Compiler.
## -----------------------------------------------------------------------------

source ../../../../../scripts_global/conf/header_start.tcl

## NAME: TEV(ddc_override)
## TYPE: file
## INFO:
## * Use this to optionally open a different ddc than default dst_dir
set TEV(ddc_override) ""

source ../../../../../scripts_global/conf/header_stop.tcl

## -----------------------------------------------------------------------------
## End of script header
## -----------------------------------------------------------------------------

## SECTION_START: initial
## SECTION_STOP: initial

## SECTION_START: setup
set cwd [pwd]
cd ../../../../../
## SECTION_STOP: setup

## SECTION_START: body
source rm_setup/dc_setup.tcl

if { $TEV(ddc_override) != "" } {
  set src_design $TEV(ddc_override)
} else {
  set src_design results/$DCRM_FINAL_DDC_OUTPUT_FILE
}

set dst_design $SEV(dst_dir)/$DESIGN_NAME.ddc

if { [file exists $src_design] } {

  if { $SEV(src_dir) == $SEV(dst_dir) } {
    read_ddc $src_design
    set ddc_loc $src_design
  } else {
    file delete -force $dst_design
    file copy -force $src_design $dst_design
    read_ddc $dst_design
    set ddc_loc $dst_design
  }
  link
  if { [get_object_name [current_design]] != $DESIGN_NAME } {
    sproc_msg -warning "Design $DESIGN_NAME not found in $src_design"
    sproc_msg -warning "Exit tool or manually open design of interest"
  } else {
    sproc_msg -info "Design $DESIGN_NAME opened from $ddc_loc"
  }
} else {
  sproc_msg -warning "Database $src_design not found"
  sproc_msg -warning "Exit tool or manually open design of interest"
}

current_design $DESIGN_NAME
link

## SECTION_STOP: body

## SECTION_START: final

## SECTION_STOP: final

sproc_script_stop

## -----------------------------------------------------------------------------
## End Of File
## -----------------------------------------------------------------------------
