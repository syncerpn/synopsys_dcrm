# ====common_setup.tcl====
set DESIGN_NAME                   ""  ;#  The name of the top-level design
set DESIGN_REF_DATA_PATH          ""  ;#  Absolute path prefix variable for library/design data.
set DESIGN_MODE                   ""  ;#  use in "analyze" command later for HDL "`ifdef", "`endif" constructs

set RTL_SOURCE_FILES  ""      ;# Enter the list of source RTL files if reading from RTL

# For the following variables, use a blank space to separate multiple entries.
# Example: set TARGET_LIBRARY_FILES "lib1.db lib2.db lib3.db"
set ADDITIONAL_SEARCH_PATH        ""  ;#  Additional search path to be added to the default search path

set TARGET_LIBRARY_FILES          ""  ;#  Target technology logical libraries
set ADDITIONAL_LINK_LIB_FILES     ""  ;#  Extra link logical libraries not included in TARGET_LIBRARY_FILES

set MIN_LIBRARY_FILES             ""  ;#  List of max min library pairs "max1 min1 max2 min2 max3 min3"...

set LIBRARY_DONT_USE_FILE        ""   ;# Tcl file with library modifications for dont_use
set LIBRARY_DONT_USE_PRE_COMPILE_LIST ""; #Tcl file for customized don't use list before first compile
set LIBRARY_DONT_USE_PRE_INCR_COMPILE_LIST "";# Tcl file with library modifications for dont_use before incr compile

# ====dc_setup_filenames.tcl====
# Input Files #
# nghiant
set GENERAL_CONSTRAINTS_INPUT_FILE                      ""
set DCRM_SDC_INPUT_FILE                                 ${DESIGN_NAME}.sdc
set DCRM_CONSTRAINTS_INPUT_FILE                         ${DESIGN_NAME}.constraints.tcl

# Output Files #
set DCRM_AUTOREAD_RTL_SCRIPT                            ${DESIGN_NAME}.autoread_rtl.tcl
set DCRM_ELABORATED_DESIGN_DDC_OUTPUT_FILE              ${DESIGN_NAME}.elab.ddc
set DCRM_FINAL_DDC_OUTPUT_FILE                          ${DESIGN_NAME}.mapped.ddc
set DCRM_FINAL_VERILOG_OUTPUT_FILE                      ${DESIGN_NAME}.mapped.v
set DCRM_FINAL_SDC_OUTPUT_FILE                          ${DESIGN_NAME}.mapped.sdc

# Formality Flow Files
set DCRM_SVF_OUTPUT_FILE                                ${DESIGN_NAME}.mapped.svf

set FMRM_UNMATCHED_POINTS_REPORT                        ${DESIGN_NAME}.fmv_unmatched_points.rpt

set FMRM_FAILING_SESSION_NAME                           ${DESIGN_NAME}
set FMRM_FAILING_POINTS_REPORT                          ${DESIGN_NAME}.fmv_failing_points.rpt
set FMRM_ABORTED_POINTS_REPORT                          ${DESIGN_NAME}.fmv_aborted_points.rpt
set FMRM_ANALYZE_POINTS_REPORT                          ${DESIGN_NAME}.fmv_analyze_points.rpt

# ====dc_setup.tcl====
# The following setting removes new variable info messages from the end of the log file
set_app_var sh_new_variable_message false

if {$synopsys_program_name == "dc_shell"}  {
  set_host_options -max_cores 4
  set_app_var alib_library_analysis_path .
}

set REPORTS_DIR "reports"
set RESULTS_DIR "results"

file mkdir ${REPORTS_DIR}
file mkdir ${RESULTS_DIR}

#set variable OPTIMIZATION_FLOW from following RM+ flows
#High Performance Low Power (hplp)

set OPTIMIZATION_FLOW  "" ;# Specify one flow out of hplp

set_app_var search_path ". ${ADDITIONAL_SEARCH_PATH} $search_path"

# The remainder of the setup below should only be performed in Design Compiler
if {$synopsys_program_name == "dc_shell"}  {

  set_app_var target_library ${TARGET_LIBRARY_FILES}
  set_app_var synthetic_library dw_foundation.sldb

  set_app_var link_library "* $target_library $ADDITIONAL_LINK_LIB_FILES $synthetic_library"

  # Set min libraries if they exist
  foreach {max_library min_library} $MIN_LIBRARY_FILES {
    set_min_library $max_library -min_version $min_library
  }

  # Apply library modifications after the libraries are loaded.
  if {[file exists [which ${LIBRARY_DONT_USE_FILE}]]} {
    puts "RM-Info: Sourcing script file [which ${LIBRARY_DONT_USE_FILE}]\n"
    source -echo -verbose ${LIBRARY_DONT_USE_FILE}
  }
}

# ====dc.tcl====
if { $OPTIMIZATION_FLOW == "hplp"} {
 set_app_var hdlin_infer_multibit default_all
}

if {[file exists [which ${LIBRARY_DONT_USE_PRE_COMPILE_LIST}]]} {
  puts "RM-Info: Sourcing script file [which ${LIBRARY_DONT_USE_PRE_COMPILE_LIST}]\n"
  source -echo -verbose $LIBRARY_DONT_USE_PRE_COMPILE_LIST
}

# Define the verification setup file for Formality
set_svf ${RESULTS_DIR}/${DCRM_SVF_OUTPUT_FILE}

# Setup SAIF Name Mapping Database
saif_map -start

define_design_lib WORK -path ./WORK


# Note: When autoread is used ${RTL_SOURCE_FILES} can include a list of
#       both directories and files.
analyze -autoread \
        -define {$DESIGN_MODE} \
        -rebuild \
        -recursive \
        -verbose \
        -top ${DESIGN_NAME} \
        -output_script ${RESULTS_DIR}/${DCRM_AUTOREAD_RTL_SCRIPT} \
        ${RTL_SOURCE_FILES}

elaborate ${DESIGN_NAME}

# nghiant: extra, explicitly set the top-level
set_verification_top

# OR

# You can read an elaborated design from the same release.
# Using an elaborated design from an older release will not give the best results.

# read_ddc ${DCRM_ELABORATED_DESIGN_DDC_OUTPUT_FILE}
write -hierarchy -format ddc -output ${RESULTS_DIR}/${DCRM_ELABORATED_DESIGN_DDC_OUTPUT_FILE}

#################################################################################
# sets the multibit_mode attribute
#################################################################################
if { $OPTIMIZATION_FLOW == "hplp"} {
  # Enable mapping to multibit only if the timing is not degraded.
  set_multibit_options -mode timing_driven
}

#################################################################################
# Reports pre-synthesis congestion analysis.
#################################################################################
analyze_rtl_congestion > ${REPORTS_DIR}/rtl_congestion.rpt

# Apply Logical Design Constraints
# You can use either SDC file ${DCRM_SDC_INPUT_FILE} or Tcl file 
# ${DCRM_CONSTRAINTS_INPUT_FILE} to constrain your design.
if {[file exists [which ${GENERAL_CONSTRAINTS_INPUT_FILE}]]} {
  puts "RM-Info: Sourcing general constraints script file [which ${GENERAL_CONSTRAINTS_INPUT_FILE}]\n"
  source -echo -verbose ${GENERAL_CONSTRAINTS_INPUT_FILE}
}
if {[file exists [which ${DCRM_SDC_INPUT_FILE}]]} {
  puts "RM-Info: Reading SDC file [which ${DCRM_SDC_INPUT_FILE}]\n"
  read_sdc ${DCRM_SDC_INPUT_FILE}
}
if {[file exists [which ${DCRM_CONSTRAINTS_INPUT_FILE}]]} {
  puts "RM-Info: Sourcing script file [which ${DCRM_CONSTRAINTS_INPUT_FILE}]\n"
  source -echo -verbose ${DCRM_CONSTRAINTS_INPUT_FILE}
}

# Apply Additional Optimization Constraints
# Prevent assignment statements in the Verilog netlist.
set_fix_multiple_port_nets -all -buffer_constants

write_environment -consistency -output ${REPORTS_DIR}/env_consistency.rpt

# Check the current design for consistency
check_design -summary
check_design > ${REPORTS_DIR}/check_design_precompile.rpt

# The analyze_datapath_extraction command can help you to analyze why certain data 
# paths are no extracted, uncomment the following line to report analyisis.
analyze_datapath_extraction > ${REPORTS_DIR}/datapath_extraction.rpt


# verify that the desired bussed registers are grouped as multibit components 
# These multibit components are mapped to multibit registers during compile_ultra
if { $OPTIMIZATION_FLOW == "hplp"} {
    redirect ${REPORTS_DIR}/multibit_components.rpt {report_multibit -hierarchical }
}

# Compile the Design
if { $OPTIMIZATION_FLOW == "hplp"} {
    # The following variable enables register replication across the hierarchy by creating new ports
    # on the instances of the subdesigns if it is necessary to improve the timing of the design
    set_app_var compile_register_replication_across_hierarchy true 
}

# First compile
compile_ultra -scan -gate_clock -no_autoungroup -no_boundary_optimization -no_seq_output_inversion

## RM+ Variable and Command Settings before incremental compile
if { $OPTIMIZATION_FLOW == "hplp" } {
    # Creating path groups to reduce TNS
    create_auto_path_groups -mode mapped
}

if {[file exists [which ${LIBRARY_DONT_USE_PRE_INCR_COMPILE_LIST}]]} {
  puts "RM-Info: Sourcing script file [which ${LIBRARY_DONT_USE_PRE_INCR_COMPILE_LIST}]\n"
  source -echo -verbose $LIBRARY_DONT_USE_PRE_INCR_COMPILE_LIST
}

# Incremental compile is required if netlist and/or constraints are changed after first compile
compile_ultra -incremental -scan -gate_clock -no_autoungroup -no_boundary_optimization -no_seq_output_inversion

# Remove the path groups generated by create_path_groups command. 
# This does not remove user created path groups
if { $OPTIMIZATION_FLOW == "hplp" } {
    remove_auto_path_groups
}
# High-effort area optimization
optimize_netlist -area

#################################################################################
# Write Out Final Design and Reports
#
#        .ddc:   Recommended binary format used for subsequent Design Compiler sessions
#    Milkyway:   Recommended binary format for IC Compiler
#        .v  :   Verilog netlist for ASCII flow (Formality, PrimeTime, VCS)
#       .spef:   Topographical mode parasitics for PrimeTime
#        .sdf:   SDF backannotated topographical mode timing for PrimeTime
#        .sdc:   SDC constraints for ASCII flow
#
#################################################################################
change_names -rules verilog -hierarchy

write -format verilog -hierarchy -output ${RESULTS_DIR}/${DCRM_FINAL_VERILOG_OUTPUT_FILE}
write -format ddc     -hierarchy -output ${RESULTS_DIR}/${DCRM_FINAL_DDC_OUTPUT_FILE}

# Write and close SVF file and make it available for immediate use
set_svf -off

write_sdc -nosplit ${RESULTS_DIR}/${DCRM_FINAL_SDC_OUTPUT_FILE}

printvar > ${REPORTS_DIR}/printvar.rpt
report_qor > ${REPORTS_DIR}/qor.rpt

report_timing -input_pins -nets -derate -max_paths 100 -nosplit > ${REPORTS_DIR}/timing.rpt
report_timing -transition_time -nets -attributes -nosplit > ${REPORTS_DIR}/timing_details.rpt
check_timing > ${REPORTS_DIR}/check_timing.rpt
report_constraint -all_violators -nosplit > ${REPORTS_DIR}/timing_constraints.rpt

report_area -hierarchy > ${REPORTS_DIR}/area_hierarchy.rpt
report_area -designware  > ${REPORTS_DIR}/area_dw.rpt

report_reference -h -nosplit > ${REPORTS_DIR}/reference.rpt
set collection_result_display_limit 100000000
all_registers > ${REPORTS_DIR}/all_registers.rpt

report_net_fanout -th 40 -nosplit > ${REPORTS_DIR}/high_fanout.rpt
check_design -summary -nosplit > ${REPORTS_DIR}/check_design.rpt
report_dont_touch > ${REPORTS_DIR}/dont_touch_ideal_net.rpt
report_saif -missing > ${REPORTS_DIR}/saif_missing.rpt
report_resources -hierarchy > ${REPORTS_DIR}/resources.rpt
report_clock_gating -gated -ungated > ${REPORTS_DIR}/clock_gating.rpt

report_timing -delay max > ${REPORTS_DIR}/_delay.rpt
report_power > ${REPORTS_DIR}/_power.rpt
report_area > ${REPORTS_DIR}/_area.rpt

if { $OPTIMIZATION_FLOW == "hplp"} {
    redirect ${REPORTS_DIR}/multibit_banking.rpt {report_multibit_banking -nosplit }
}

exit
