import_device eagle_s20.db -package EG4S20BG256
read_hdl -file {hdmi_core.enc.v hdmi_phy_warpper.v lane_lvds_10_1.v video_pll.v sd_block_reader.v status_uart.v burst_sdram.v fat_bmp_check.v frame_scaler.v slide_timing.v scaled_line_video.v matrix_keys.v transport_control.v display_params.v image_adjust.v status_osd.v audio_waveform.v fade_video.v info_overlay.v audio_fifo.v wav_audio.v tone_audio.v rgb_to_hdmi_raster.v av_slide.v} -top av_slide
read_adc pins.adc
optimize_rtl
read_sdc timing.sdc
optimize_gate
legalize_phy_inst
read_sdc timing.sdc
set_param place fix_hold high
set_param place seed 1
commit_param -step place
place
phys_opt -hold_fix
set_param route hold_fix_iteration 20
commit_param -step route
route
fix_hold
report_area -file av_area.rpt
update_timing -mode final
report_timing_summary -file av_timing.rpt
set timing_fd [open av_timing.rpt r]
set timing_text [read $timing_fd]
close $timing_fd
if {![regexp {SWNS: ([-0-9.]+)ns} $timing_text -> setup_wns]} {error "Missing setup result"}
if {![regexp {HWNS: ([-0-9.]+)ns} $timing_text -> hold_wns]} {error "Missing hold result"}
if {$setup_wns < 0 || $hold_wns < 0} {error "Timing failed; no release bit generated"}
bitgen -bit av_slide.bit
exit

