## -----------------------------------------------------------------------------
## HEADER_MSG  Lynx Design System: Baseline Flow
## HEADER_MSG  Version 2019.12-SP4
## HEADER_MSG  Copyright (c) 2020 Synopsys
## -----------------------------------------------------------------------------
## DESCRIPTION:
## * Flow menu setup
## -----------------------------------------------------------------------------

source $SEV(scripts_dir)/flow_menus/BuildSelectWidget.tcl

gui_create_menu -menu "R2G Menu->DesignSummary" \
  -anchor_item "Help" \
  -anchor_offset -1 \
  -window_type $window_type \
  -help_string {Create DesignSummary report} \
  -tcl_cmd "BuildSelectWidget::newWidget DesignSummary 0"

gui_create_menu -menu "R2G Menu->ResourceSummary" \
  -window_type $window_type \
  -help_string {Create ResourceSummary report} \
  -tcl_cmd "BuildSelectWidget::newWidget ResourceSummary 0"

gui_create_menu -menu "R2G Menu->ClockTreeSummary" \
  -window_type $window_type \
  -help_string {Create ClockTreeSummary report} \
  -tcl_cmd "BuildSelectWidget::newWidget ClockTreeSummary 1"

gui_create_menu -menu "R2G Menu->ToolLicenseSummary" \
  -window_type $window_type \
  -help_string {Create ToolLicenseSummary report} \
  -tcl_cmd "BuildSelectWidget::newWidget ToolLicenseSummary 0"

gui_create_menu -menu "R2G Menu->AppOptionSummary" \
  -window_type $window_type \
  -help_string {Create AppOptionSummary report} \
  -tcl_cmd "BuildSelectWidget::newWidget AppOptionSummary 0"

gui_create_menu -menu "R2G Menu->foo" -window_type $window_type -separator

gui_create_menu -menu "R2G Menu->TimingMatrix" \
  -window_type $window_type \
  -help_string {Create TimingMatrix report} \
  -tcl_cmd "BuildSelectWidget::newWidget TimingMatrix 1"

gui_create_menu -menu "R2G Menu->PowerMatrix" \
  -window_type $window_type \
  -help_string {Create PowerMatrix report} \
  -tcl_cmd "BuildSelectWidget::newWidget PowerMatrix 1"

gui_create_menu -menu "R2G Menu->ClockTreeMatrix" \
  -window_type $window_type \
  -help_string {Create ClockTreeMatrix report} \
  -tcl_cmd "BuildSelectWidget::newWidget ClockTreeMatrix 1"

gui_create_menu -menu "R2G Menu->ScenarioTrend" \
  -window_type $window_type \
  -help_string {Create ScenarioTrend report} \
  -tcl_cmd "BuildSelectWidget::newWidget ScenarioTrend 0"

gui_create_menu -menu "R2G Menu->foo" -window_type $window_type -separator

gui_create_menu -menu "R2G Menu->DesignSummaryComparison" \
  -window_type $window_type \
  -help_string {Create DesignSummaryComparison report} \
  -tcl_cmd "BuildSelectWidget::newWidget DesignSummaryComparison 0"
  
gui_create_menu -menu "R2G Menu->ResourceSummaryComparison" \
  -window_type $window_type \
  -help_string {Create ResourceSummaryComparison report} \
  -tcl_cmd "BuildSelectWidget::newWidget ResourceSummaryComparison 0"
  
gui_create_menu -menu "R2G Menu->AppOptionComparison" \
  -window_type $window_type \
  -help_string {Create AppOptionComparison report} \
  -tcl_cmd "BuildSelectWidget::newWidget AppOptionComparison 0"

## gui_create_menu -menu "R2G Menu->foo" -window_type $window_type -separator
## gui_create_menu -menu "R2G Menu->Status" \
##   -window_type $window_type \
##   -help_string {Create Status report} \
##   -tcl_cmd "BuildSelectWidget::newWidget Status 0"

## -----------------------------------------------------------------------------
## End Of File
## -----------------------------------------------------------------------------
