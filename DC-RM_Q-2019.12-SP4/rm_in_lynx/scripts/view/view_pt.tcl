## -----------------------------------------------------------------------------
## DESCRIPTION:
## * This task is used to interactively open a session with PrimeTime.
## -----------------------------------------------------------------------------

source ../../../../../scripts_global/conf/header_start.tcl

## NAME: TEV(session)
## TYPE: string
## INFO:
## * Used to specify a PT sessionspecific scenario.
set TEV(session) ""

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
source rm_setup/common_setup.tcl
source rm_setup/pt_setup.tcl

if { $TEV(session) != "" } {
  restore_session $TEV(session)
} else {
  sproc_msg -warning "Session $TEV(session)"
}

## SECTION_STOP: body

## SECTION_START: final

## SECTION_STOP: final

sproc_script_stop

## -----------------------------------------------------------------------------
## End Of File
## -----------------------------------------------------------------------------
