module av_slide(input wire clk,sw0_n,sd_miso,input wire [3:0] key_col,output wire [3:0] key_row,
 output wire sd_clk,sd_mosi,sd_cs,output wire [7:0] led,output wire uart_tx,
 output wire HDMI_CLK_P,HDMI_D0_P,HDMI_D1_P,HDMI_D2_P);
 reg [7:0] code50_reg=0,code_meta=0,code_pix=0;
 wire pix,ser,memshift,locked,rstpix,frame_commit;wire [7:0] code;reg [1:0] seek50=0;
 reg scale_reset=1;always @(posedge pix)scale_reset<=rstpix;
 video_pll pll(.refclk(clk),.reset(!sw0_n),.clk0_out(pix),.clk1_out(ser),.clk2_out(memshift),.locked(locked));
 reg [1:0] release50=0,releasepix=0,miso_sync=3;
 always @(posedge clk or negedge sw0_n)
 if(!sw0_n)release50<=0;else release50<={release50[0],locked};
 always @(posedge pix or negedge sw0_n)
 if(!sw0_n)releasepix<=0;else releasepix<={releasepix[0],locked};
 always @(posedge clk)miso_sync<={miso_sync[0],sd_miso};
 // Hold pixel-domain reset as in the board-validated HDMI audio test.
 reg [15:0] startup=0;
 always @(posedge pix)if(!releasepix[1])startup<=0;
 else if(!startup[15])startup<=startup+1'b1;
 wire rst50=!release50[1];assign rstpix=!releasepix[1] || !startup[15];
 reg init_half=0,scale_done_half=0,scale_file_half=0,hold_half=0,seek_half=0,diag_half=0;reg [9:0] flags_half=0;
 wire mem_init,mem_busy,rd_valid,wr_en,rd_en;wire [20:0] wr_addr,rd_addr;
 wire [31:0] wr_data,rd_data;wire loaded,overflow;
 reg [1:0] init_sync=0;
 always @(negedge clk)if(rst50)init_sync[0]<=0;else init_sync[0]<=init_half;
 always @(posedge clk)if(rst50)init_sync[1]<=0;else init_sync[1]<=init_sync[0];
 wire [7:0] sd_error_detail;wire req,card_ready,card_error,sector_done,valid;wire [31:0] lba;
 wire [8:0] index;wire [7:0] octet,fs_code,pixel_byte;
 wire [10:0] pixel_width,pixel_height,original_w0,original_h0,original_w1,original_h1;
 wire [9:0] fitw0,fith0,fitw1,fith1;
 wire scale_active,scale_start,scale_source_file,scale_done,scale_done_file;
 wire [10:0] scale_width,scale_height;reg [1:0] scale_done50=0,scale_file50=0;
 always @(negedge clk)if(rst50)begin scale_done50[0]<=0;scale_file50[0]<=0;end else begin scale_done50[0]<=scale_done_half;scale_file50[0]<=scale_file_half;end
 always @(posedge clk)if(rst50)begin scale_done50[1]<=0;scale_file50[1]<=0;end else begin scale_done50[1]<=scale_done50[0];scale_file50[1]<=scale_file50[0];end
 wire mounted,files_found,test_ok,alt_ok,passed,failed,pixel_valid,pixel_file;
 wire [2:0] pixel_profile,test_profile50,alt_profile50,active_profile;
 reg [2:0] tp_meta=0,tp_pix=0,ap_meta=0,ap_pix=0;
 always @(posedge pix)if(rstpix)begin tp_meta<=0;tp_pix<=0;ap_meta<=0;ap_pix<=0;end
 else begin tp_meta<=test_profile50;tp_pix<=tp_meta;ap_meta<=alt_profile50;ap_pix<=ap_meta;end
 wire wav_byte_valid,wav_ok,audio_space;wire [7:0] wav_byte;
 wire audio_valid,acr_valid,audio_started,audio_underrun,audio_overflow;
 wire [23:0] pcm_left,pcm_right,output_left,output_right;
 wire output_audio_valid,output_acr_valid,output_sample_played,tone_active,block_wav,source_changed,source_changing;
 reg tone_display=0;
 wire paused,restart_hold,flushing,reader_idle;wire [31:0] total_frames;
 reg [1:0] hold50=0,idle_pix=0;reg [31:0] total_meta=0,total_pix=0;
 always @(negedge clk)if(rst50)hold50[0]<=0;else hold50[0]<=hold_half;
 always @(posedge clk)if(rst50)hold50[1]<=0;else hold50[1]<=hold50[0];
 always @(posedge pix)if(rstpix)begin idle_pix<=0;total_meta<=0;total_pix<=0;end
 else begin idle_pix<={idle_pix[0],reader_idle};total_meta<=total_frames;total_pix<=total_meta;end
 wire [31:0] position;wire [7:0] seconds;wire [4:0] progress;
 sd_block_reader #(.POWER_WAIT(2500000)) sd(.clk(clk),.rst(rst50 || !init_sync[1]),.miso(miso_sync[1]),
 .req(req),.lba(lba),.initialized_out(card_ready),.error_out(card_error),
 .done(sector_done),.data_valid(valid),.data_index_out(index),.data_out(octet),
 .sck(sd_clk),.mosi(sd_mosi),.cs(sd_cs),.status(),.debug_error(sd_error_detail));
 fat_bmp_check fs(.clk(clk),.rst(rst50),.card_ready(card_ready),.card_error(card_error),
 .req(req),.lba(lba),.sector_done(sector_done),.data_valid(valid),.byte_index(index),.octet(octet),
 .image_ready(scale_done50[1] && scale_file50[1]==pixel_file),.pixel_width(pixel_width),.pixel_height(pixel_height),
 .restart_hold(hold50[1]),.seek_second(seek50[1]),.restart_idle(reader_idle),.total_frames(total_frames),.audio_space(audio_space),.wav_byte_valid(wav_byte_valid),.wav_byte(wav_byte),.wav_ok(wav_ok),.pixel_profile(pixel_profile),.test_profile(test_profile50),.alt_profile(alt_profile50),.pixel_file(pixel_file),.pixel_byte_valid(pixel_valid),.pixel_byte(pixel_byte),
 .mounted(mounted),.files_found(files_found),.test_ok(test_ok),.alt_ok(alt_ok),
 .passed(passed),.failed(failed),.error_code(fs_code));
 wire loader_wr,scaler_wr,scaler_rd;wire [20:0] loader_addr,scaler_waddr,scaler_raddr;
 wire [31:0] loader_data,scaler_data;
 generic_bmp_loader loader(.clk50(clk),.rst50(rst50),.byte_valid(pixel_valid),.octet(pixel_byte),.pixel_file(pixel_file),
 .pixel_width(pixel_width),.pixel_height(pixel_height),.pix(pix),.rst_pix(rstpix),.mem_busy(mem_busy),.scaling(scale_active),
 .wr_en(loader_wr),.wr_addr(loader_addr),.wr_data(loader_data),.start_scale(scale_start),.source_file(scale_source_file),
 .source_width(scale_width),.source_height(scale_height),.overflow(overflow));
 frame_scaler scaler(.clk(pix),.rst(scale_reset),.start(scale_start),.source_file(scale_source_file),
 .source_width(scale_width),.source_height(scale_height),.mem_busy(mem_busy),.rd_valid(rd_valid),.rd_data(rd_data),
 .active(scale_active),.rd_en(scaler_rd),.wr_en(scaler_wr),.rd_addr(scaler_raddr),.wr_addr(scaler_waddr),.wr_data(scaler_data),
 .done_valid(scale_done),.done_file(scale_done_file),.complete(loaded),
 .width0(original_w0),.height0(original_h0),.width1(original_w1),.height1(original_h1),
 .fitw0(fitw0),.fith0(fith0),.fitw1(fitw1),.fith1(fith1));
 assign wr_en=loader_wr || scaler_wr;
 assign wr_addr=loader_wr?loader_addr:scaler_waddr;assign wr_data=loader_wr?loader_data:scaler_data;
 wire ras,cas,we;wire [10:0] ma;wire [1:0] ba;wire [31:0] dq;
 burst_sdram controller(.clk(pix),.rst(rstpix),.wr_en(wr_en),.rd_en(scale_active?scaler_rd:rd_en),
 .addr(wr_en?wr_addr:(scale_active?scaler_raddr:rd_addr)),.wr_data(wr_data),.busy(mem_busy),.init_done(mem_init),
 .rd_valid(rd_valid),.rd_data(rd_data),.ras_n(ras),.cas_n(cas),.we_n(we),.ma(ma),.ba(ba),.dq(dq));
 EG_PHY_SDRAM_2M_32 memory(.clk(memshift),.ras_n(ras),.cas_n(cas),.we_n(we),
 .addr(ma),.ba(ba),.dq(dq),.cs_n(1'b0),.dm0(1'b0),.dm1(1'b0),.dm2(1'b0),.dm3(1'b0),.cke(1'b1));
 reg [1:0] pass_sync=0,fail_sync=0,audio_overflow_pix=0;
 always @(posedge pix)if(rstpix)audio_overflow_pix<=0;else audio_overflow_pix<={audio_overflow_pix[0],audio_overflow};
 always @(posedge pix)if(rstpix)begin pass_sync<=0;fail_sync<=0;end
 else begin pass_sync<={pass_sync[0],passed};fail_sync<={fail_sync[0],failed};end
 wire frame_ready=pass_sync[1] && loaded && !overflow;
 wire [23:0] rgb;wire hs,vs,de,underrun,displaying,active_frame;
 wire next_press,mode_press,emergency_press,requested_frame,auto_mode,diag_hold;
 wire brightness_down,brightness_up,contrast_down,contrast_up,defaults_press,tone_press,effect_press;
 reg effect_pending=1,effect_display=1;wire [9:0] planned_shift,display_shift,pixel_source_y;wire pixel_source_frame;
 always @(posedge pix)begin
 if(rstpix)begin effect_pending<=1;effect_display<=1;end
 else begin if(effect_press)effect_pending<=!effect_pending;if(frame_commit)effect_display<=effect_pending;end end
 wire signed [7:0] brightness;wire [2:0] contrast_level;
 wire previous_slide_press,next_slide_press,auto_press,manual_mode,manual_page,audio_frame;
 wire playback_paused=paused;wire seek_second,audio_seek_ready;reg manual_display=0;
 always @(negedge clk)if(rst50)seek50[0]<=0;else seek50[0]<=seek_half;
 always @(posedge clk)if(rst50)seek50[1]<=0;else seek50[1]<=seek50[0];
 matrix_keys keys(.clk(pix),.rst(rstpix),.col(key_col),.row(key_row),.next_press(next_press),.mode_press(mode_press),.emergency_press(emergency_press),.diagnostic_hold(diag_hold),.previous_slide_press(previous_slide_press),.next_slide_press(next_slide_press),.auto_press(auto_press),.brightness_down(brightness_down),.brightness_up(brightness_up),.contrast_down(contrast_down),.contrast_up(contrast_up),.defaults_press(defaults_press),.tone_press(tone_press),.effect_press(effect_press));
 assign auto_mode=!playback_paused;
 transport_control control(.clk(pix),.rst(rstpix),.ready(frame_ready && displaying && total_pix!=0 && audio_seek_ready),.failed(fail_sync[1]),
 .pause_press(next_press),.replay_press(mode_press),.previous_press(previous_slide_press),.next_press(next_slide_press),.auto_press(auto_press),
 .reader_idle(idle_pix[1]),.active_frame(active_frame),.auto_frame(audio_frame),.paused(paused),.manual_mode(manual_mode),.page(manual_page),
 .seek_second(seek_second),.restart_hold(restart_hold),.flushing(flushing),.requested_frame(requested_frame));
 always @(posedge pix)if(rstpix)begin manual_display<=0;tone_display<=0;end else if(frame_commit)begin manual_display<=manual_mode;tone_display<=tone_active;end
 wire [9:0] out_x,out_y,look_y;wire [10:0] look_x;wire [23:0] osd_rgb,wave_rgb,fade_rgb,info_rgb;wire emergency_active;wire [10:0] scroll_offset;wire [4:0] fade_gain;
 // Match the two registered colour stages with coordinates and HDMI timing.
 wire [23:0] adjusted_rgb;wire video_letterbox;
 wire [9:0] active_fw=pixel_source_frame?fitw1:fitw0,active_fh=pixel_source_frame?fith1:fith0;
 wire [9:0] active_left=(800-active_fw)>>1,active_top=(600-active_fh)>>1;
 wire letterbox=frame_ready && (out_x<active_left || out_x>=active_left+active_fw || pixel_source_y<active_top || pixel_source_y>=active_top+active_fh);
reg lb1=0,lb2=0;wire [23:0] fitted_rgb=lb2?24'd0:adjusted_rgb;
 reg [9:0] x1,y1,x2,y2,ly1,ly2;reg [10:0] lx1,lx2;reg hs1,vs1,de1,hs2,vs2,de2;
 always @(posedge pix)begin
 if(rstpix)begin lb1<=0;lb2<=0;x1<=0;y1<=0;x2<=0;y2<=0;lx1<=0;ly1<=0;lx2<=0;ly2<=0;hs1<=1;vs1<=1;de1<=0;hs2<=1;vs2<=1;de2<=0;end
 else begin lb1<=letterbox;lb2<=lb1;x1<=out_x;y1<=out_y;x2<=x1;y2<=y1;lx1<=look_x;ly1<=look_y;lx2<=lx1;ly2<=ly1;
 hs1<=hs;vs1<=vs;de1<=de;hs2<=hs1;vs2<=vs1;de2<=de1;end
 end
 display_params parameters(.clk(pix),.rst(rstpix),.frame_commit(frame_commit),.brightness_down(brightness_down),.brightness_up(brightness_up),
 .contrast_down(contrast_down),.contrast_up(contrast_up),.defaults_press(defaults_press),.brightness(brightness),.contrast_level(contrast_level));
 image_adjust adjust(.clk(pix),.rst(rstpix),.rgb(rgb),.brightness(brightness),.contrast_level(contrast_level),.result(adjusted_rgb));
 fade_video fade(.clk(pix),.rst(rstpix),.frame_commit(frame_commit),.position(position),
 .total_frames(total_pix),.requested_frame(audio_frame),.rgb(fitted_rgb),.result(fade_rgb),.gain(fade_gain));wire sample_played;
 audio_waveform wave(.clk(pix),.rst(rstpix),.clear(flushing || source_changed),.sample_valid(output_sample_played),
 .left(output_left),.right(output_right),.look_x(lx2),.x(x2),.y(y2),.rgb((manual_display || tone_display || effect_display)?fitted_rgb:fade_rgb),.result(wave_rgb));
 reg [23:0] wave_stage,osd_stage;reg [9:0] x3,y3,x4,y4;reg [10:0] lx3,lx4;reg [9:0] ly3,ly4;
 reg [4:0] vs_pipe,de_pipe;
 always @(posedge pix)begin
 if(rstpix)begin wave_stage<=0;osd_stage<=0;x3<=0;y3<=0;x4<=0;y4<=0;lx3<=0;ly3<=0;lx4<=0;ly4<=0;vs_pipe<=0;de_pipe<=0;end
 else begin wave_stage<=wave_rgb;osd_stage<=osd_rgb;x3<=x2;y3<=y2;x4<=x3;y4<=y3;lx3<=lx2;ly3<=ly2;lx4<=lx3;ly4<=ly3;
 vs_pipe<={vs_pipe[3:0],vs2};de_pipe<={de_pipe[3:0],de2};end
 end
 status_osd osd(.slide_mode(effect_display),.clk(pix),.rst(rstpix),.error_code(code_pix),.source_width(active_frame?original_w1:original_w0),.source_height(active_frame?original_h1:original_h0),.tone_mode(tone_display),.source_profile(active_profile),.brightness(brightness),.contrast_level(contrast_level),.x(x3),.y(y3),.rgb(wave_stage),.paused(playback_paused),.manual_mode(manual_display),.active_frame(active_frame),
 .waiting(!audio_started || flushing || source_changing),.failed(fail_sync[1] || audio_underrun || audio_overflow_pix[1] || underrun),
 .seconds(seconds),.progress(progress),.result(osd_rgb));
 info_overlay information(.clk(pix),.rst(rstpix),.emergency_press(emergency_press),
 .play_running(audio_started && !playback_paused && !flushing),.look_x(lx4),.look_y(ly4),.x(x4),.y(y4),
 .rgb(osd_stage),.result(info_rgb),.emergency_active(emergency_active),.scroll_offset(scroll_offset));
 slide_timing transition(.clk(pix),.rst(rstpix),.position(position),.total_frames(total_pix),.base_frame(audio_frame),.offset(planned_shift));
 wire [9:0] selected_shift=(effect_pending && !manual_mode && !tone_active && !flushing && !source_changing)?planned_shift:10'd0;
 line_video video(.slide_offset(selected_shift),.active_shift(display_shift),.pixel_frame(pixel_source_frame),.pixel_source_y(pixel_source_y),.clk(pix),.rst(rstpix),.frame_ready(frame_ready),.fatal_error(fail_sync[1] || overflow),
 .requested_frame(requested_frame),.profile0(3'd0),.profile1(3'd0),.active_profile(active_profile),.letterbox(video_letterbox),.mem_busy(mem_busy),.rd_valid(rd_valid),.rd_data(rd_data),.rd_en(rd_en),.rd_addr(rd_addr),
 .frame_commit(frame_commit),.look_x(look_x),.look_y(look_y),.out_x(out_x),.out_y(out_y),.rgb(rgb),.hs(hs),.vs(vs),.de(de),.underrun(underrun),.displaying(displaying),.active_frame(active_frame));
 wav_audio audio(.clk50(clk),.rst50(rst50),.byte_valid(wav_byte_valid),.octet(wav_byte),.space(audio_space),
 .pix(pix),.rst_pix(rstpix),.pause_play(playback_paused || block_wav),.seek_second(seek_second),.flush50(hold50[1]),.flush_pix(flushing),
 .play_enable(frame_ready && displaying),.total_frames(total_pix),.position(position),.seconds(seconds),.progress(progress),.requested_frame(audio_frame),.sample_played(sample_played),.audio_valid(audio_valid),.left(pcm_left),.right(pcm_right),.acr_valid(acr_valid),
 .started(audio_started),.underrun(audio_underrun),.overflow(audio_overflow),.seek_ready(audio_seek_ready));
 tone_audio source(.clk(pix),.rst(rstpix),.toggle_press(tone_press),.voice_press(auto_press),.replay_press(mode_press),
 .paused(paused),.flushing(flushing),.play_enable(frame_ready && displaying && audio_started && !flushing && !fail_sync[1]),
 .in_valid(audio_valid),.in_acr(acr_valid),.in_sample_played(sample_played),.in_left(pcm_left),.in_right(pcm_right),
 .out_valid(output_audio_valid),.out_acr(output_acr_valid),.sample_played(output_sample_played),.left(output_left),.right(output_right),
 .active_tone(tone_active),.source_changed(source_changed),.block_wav(block_wav),.source_changing(source_changing));
 wire axis_valid,axis_user,axis_last,axis_ready,video_overflow;wire [23:0] axis_data;
 rgb_to_hdmi_raster bridge(.clk(pix),.rst(rstpix),.vs(vs_pipe[4]),.de(de_pipe[4]),.rgb(info_rgb),.ready(axis_ready),
 .valid(axis_valid),.user(axis_user),.last(axis_last),.data(axis_data),.rejected(video_overflow));
 wire [9:0] ch0,ch1,ch2,chclk;wire unused_scl;tri1 unused_sda;wire hdmi_locked;
 hdmi_1_4b_transmitter_core_wrapper #(.DEVICE("EG"),.HTOTAL(1056),.HSA(128),.HFP(40),.HBP(88),.HACTIVE(800),
 .VTOTAL(628),.VSA(4),.VFP(1),.VBP(23),.VACTIVE(600),.VIDEO_VIC(0),.VIDEO_TPG("Disable"),
 .VIDEO_FORMAT("RGB"),.AUDIO_SAMPLE_RATE("48K"),.IIC_SCL_DIV(250)) core(
 .I_pixel_clk(pix),.I_rst(rstpix),.I_edid_read_trig(1'b0),.O_edid_read_valid(),.O_edid_read_data(),
 .I_axis_s_user(axis_user),.I_axis_s_valid(axis_valid),.I_axis_s_last(axis_last),.I_axis_s_data(axis_data),.O_axis_s_ready(axis_ready),
 .I_audio_valid(output_audio_valid),.I_audio_left_data(fail_sync[1]?24'd0:output_left),.I_audio_right_data(fail_sync[1]?24'd0:output_right),.I_acr_valid(output_acr_valid),
 .I_acr_cts(20'd40000),.I_acr_n(20'd6144),.O_video_locked(hdmi_locked),.O_ddc_scl(unused_scl),.IO_ddc_sda(unused_sda),
 .O_ch0_tmds_data(ch0),.O_ch1_tmds_data(ch1),.O_ch2_tmds_data(ch2),.O_clk_tmds_data(chclk));
 hdmi_phy_wrapper #(.DEVICE("EG")) phy(.I_pixel_clk(pix),.I_serial_clk(ser),.I_rst(rstpix),
 .I_tmds_channel_0(ch0),.I_tmds_channel_1(ch1),.I_tmds_channel_2(ch2),.I_tmds_channel_clk(chclk),
 .O_tmds_ch0_p(HDMI_D0_P),.O_tmds_ch1_p(HDMI_D1_P),.O_tmds_ch2_p(HDMI_D2_P),.O_tmds_clk_p(HDMI_CLK_P));
 reg [9:0] pm=0,ps=0;reg [24:0] heartbeat=0;
 always @(negedge clk)pm<=flags_half;
 always @(posedge clk)begin heartbeat<=heartbeat+1'b1;ps<=pm;end
 wire error=failed || ps[8] || ps[7] || ps[6] || ps[1] || ps[0];
 wire [7:0] flags={ps[9] && ps[2] && ps[5] && wav_ok && !error,error,ps[3],ps[4] && test_ok && alt_ok,files_found,mounted,card_ready,1'b0};
 reg [1:0] diag_sync=0;
 always @(negedge clk)diag_sync[0]<=diag_half;
 always @(posedge clk)diag_sync[1]<=diag_sync[0];
 assign led=diag_sync[1]?{code[5],error,code[4:0],heartbeat[24]}:(flags|{7'd0,heartbeat[24]});
 assign code=failed?(fs_code==8'h01 && sd_error_detail!=0?sd_error_detail:fs_code):ps[0]?8'h20:ps[1]?8'h21:ps[6]?8'h22:ps[7]?8'h23:ps[8]?8'h25:8'h00;
 status_uart diagnostic(.clk(clk),.rst(rst50),.flags(flags),.code(code),.tx(uart_tx));
 always @(posedge clk)code50_reg<=code;
 always @(posedge pix)begin code_meta<=code50_reg;code_pix<=code_meta;end
 always @(negedge pix)begin
 init_half<=mem_init;scale_done_half<=scale_done;scale_file_half<=scale_done_file;hold_half<=restart_hold;seek_half<=seek_second;diag_half<=diag_hold;
 flags_half<={hdmi_locked,video_overflow,audio_overflow_pix[1],audio_underrun,audio_started,auto_mode,active_frame,displaying,underrun,overflow};end
endmodule
