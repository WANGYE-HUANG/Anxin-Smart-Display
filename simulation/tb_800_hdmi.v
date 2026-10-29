`timescale 1ns/1ps
module tb_800_hdmi #(parameter PROFILE=0);
 localparam [2:0] profile_id=PROFILE;wire [2:0] current_profile;wire letterbox;
 reg [4:0]vs_pipe=0,de_pipe=0;reg clk=0;always #12.5 clk=~clk;reg rst=1,frame_ready=0,requested=0;
 wire busy,init,rv,rd;wire [20:0] addr;wire [31:0] q;
 wire ras,cas,we;wire [10:0] ma;wire [1:0] ba;tri [31:0] dq;
 wire [23:0] rgb,adjusted_rgb,axis_data,osd_rgb,wave_rgb,fade_rgb,info_rgb;reg alert_press=0;wire alert_active;wire [10:0] ticker_offset;wire frame_commit;wire [4:0] fade_gain;reg [31:0] position=24000;integer phase=0;wire [9:0] out_x,out_y,look_y;wire [10:0] look_x;wire hs,vs,de,line_error,displaying,active;
 wire valid,user,last,ready,rejected,locked;wire [9:0] ch0,ch1,ch2;tri1 sda;wire scl;
 burst_sdram controller(.clk(clk),.rst(rst),.wr_en(1'b0),.rd_en(rd),.addr(addr),.wr_data(32'd0),
 .busy(busy),.init_done(init),.rd_valid(rv),.rd_data(q),.ras_n(ras),.cas_n(cas),.we_n(we),.ma(ma),.ba(ba),.dq(dq));
 sdram_model model(clk,ras,cas,we,ma,ba,dq);
 line_video video(.slide_offset(10'd0),.clk(clk),.rst(rst),.frame_ready(frame_ready),.fatal_error(1'b0),.mem_busy(busy),
 .rd_valid(rv),.rd_data(q),.requested_frame(requested),.profile0(profile_id),.profile1(3'd0),.active_profile(current_profile),.letterbox(letterbox),.rd_en(rd),.rd_addr(addr),.frame_commit(frame_commit),.look_x(look_x),.look_y(look_y),.out_x(out_x),.out_y(out_y),.rgb(rgb),.hs(hs),.vs(vs),.de(de),
 .underrun(line_error),.displaying(displaying),.active_frame(active));
 reg lb1=0,lb2=0;wire [23:0] fitted_rgb=lb2?24'd0:adjusted_rgb;reg [9:0] x1,y1,x2,y2,ly1,ly2;reg [10:0] lx1,lx2;reg hs1,vs1,de1,hs2,vs2,de2;
 always @(posedge clk)begin
 if(rst)begin lb1<=0;lb2<=0;x1<=0;y1<=0;x2<=0;y2<=0;lx1<=0;ly1<=0;lx2<=0;ly2<=0;hs1<=1;vs1<=1;de1<=0;hs2<=1;vs2<=1;de2<=0;end
 else begin lb1<=(out_x<100 || out_x>=700);lb2<=lb1;x1<=out_x;y1<=out_y;x2<=x1;y2<=y1;lx1<=look_x;ly1<=look_y;lx2<=lx1;ly2<=ly1;
 hs1<=hs;vs1<=vs;de1<=de;hs2<=hs1;vs2<=vs1;de2<=de1;end
 end
 image_adjust adjust(.clk(clk),.rst(rst),.rgb(rgb),.brightness(8'sd32),.contrast_level(3'd5),.result(adjusted_rgb));
 rgb_to_hdmi_raster bridge(clk,rst,vs_pipe[4],de_pipe[4],info_rgb,ready,valid,user,last,axis_data,rejected);
 hdmi_1_4b_transmitter_core_wrapper #(.DEVICE("EG"),.HTOTAL(1056),.HSA(128),.HFP(40),.HBP(88),.HACTIVE(800),
 .VTOTAL(628),.VSA(4),.VFP(1),.VBP(23),.VACTIVE(600),.VIDEO_VIC(0),.VIDEO_TPG("Disable"),.VIDEO_FORMAT("RGB"),
 .AUDIO_SAMPLE_RATE("48K"),.IIC_SCL_DIV(250)) core(.I_pixel_clk(clk),.I_rst(rst),.I_edid_read_trig(1'b0),
 .O_edid_read_valid(),.O_edid_read_data(),.I_axis_s_user(user),.I_axis_s_valid(valid),.I_axis_s_last(last),.I_axis_s_data(axis_data),
 .O_axis_s_ready(ready),.I_audio_valid(1'b0),.I_audio_left_data(24'd0),.I_audio_right_data(24'd0),
 .I_acr_valid(1'b0),.I_acr_cts(20'd40000),.I_acr_n(20'd6144),.O_video_locked(locked),.O_ddc_scl(scl),.IO_ddc_sda(sda),
 .O_ch0_tmds_data(ch0),.O_ch1_tmds_data(ch1),.O_ch2_tmds_data(ch2),.O_clk_tmds_data());
reg [23:0] wave_stage,osd_stage;reg [9:0] x3,y3,x4,y4,ly3,ly4;reg [10:0]lx3,lx4;
 always @(posedge clk)begin
 wave_stage<=wave_rgb;osd_stage<=osd_rgb;x3<=x2;y3<=y2;x4<=x3;y4<=y3;lx3<=lx2;ly3<=ly2;lx4<=lx3;ly4<=ly3;
 vs_pipe<={vs_pipe[3:0],vs2};de_pipe<={de_pipe[3:0],de2};end
 status_osd overlay(.slide_mode(1'b0),.clk(clk),.rst(rst),.source_width(11'd1024),.source_height(11'd1024),.tone_mode(1'b1),.source_profile(profile_id),.brightness(8'sd32),.contrast_level(3'd5),.manual_mode(1'b0),.active_frame(1'b0),.x(x3),.y(y3),.rgb(wave_stage),.paused(1'b0),.waiting(1'b0),.failed(1'b0),.seconds(8'd3),.progress(5'd6),.result(osd_rgb));
 info_overlay information(.clk(clk),.rst(rst),.emergency_press(alert_press),.play_running(1'b0),
 .look_x(lx4),.look_y(ly4),.x(x4),.y(y4),.rgb(osd_stage),.result(info_rgb),.emergency_active(alert_active),.scroll_offset(ticker_offset));
 `include "tb_800_info_reference.vh"
 reg emergency_ref=0,blink_ref=1;integer normal_frames=0,alert_frames=0;reg [255:0] preview_name;
 reg [9:0] ex=1023,ey=1023;reg [23:0] bg=0;wire [23:0] overlay_expected;
 status_osd reference(.slide_mode(1'b0),.clk(clk),.rst(rst),.source_width(11'd1024),.source_height(11'd1024),.tone_mode(1'b1),.source_profile(profile_id),.brightness(8'sd32),.contrast_level(3'd5),.manual_mode(1'b0),.active_frame(1'b0),.x(ex),.y(ey),.rgb(bg),.paused(1'b0),.waiting(1'b0),.failed(1'b0),.seconds(8'd3),.progress(5'd6),.result(overlay_expected));
 reg [31:0] wave_words[0:383999];reg sample_valid=0;reg [23:0] pcm_l=0,pcm_r=0;
 fade_video fade(.clk(clk),.rst(rst),.frame_commit(frame_commit),.position(position),.total_frames(32'd384000),
 .requested_frame(requested),.rgb(fitted_rgb),.result(fade_rgb),.gain(fade_gain));
 audio_waveform wave(.clk(clk),.rst(rst),.clear(1'b0),.sample_valid(sample_valid),.left(pcm_l),.right(pcm_r),
 .look_x(lx2),.x(x2),.y(y2),.rgb(fade_rgb),.result(wave_rgb));
 integer image_file,output_gain=16,j;reg [23:0] prefix[0:39];reg [16:0] gains_seen=0;reg preview_done=0,save_frame=0;
 function [23:0] dim;input [23:0] color;input integer level;integer r,g,b;begin
 r=((($signed({1'b0,color[23:16]})-128)*5)>>>2)+160;
 g=((($signed({1'b0,color[15:8]})-128)*5)>>>2)+160;
 b=((($signed({1'b0,color[7:0]})-128)*5)>>>2)+160;
 r=r<0?0:r>255?255:r;g=g<0?0:g>255?255:g;b=b<0?0:b>255?255:b;
 r=r*level/16;g=g*level/16;b=b*level/16;dim={r[7:0],g[7:0],b[7:0]};end endfunction
 reg [23:0] source[0:479999];integer source_count;reg [23:0] a[0:479999],b[0:479999];integer i,cycles=0,last_sof=-1,last_line=-1,ix=0,iy=0,input_frames=0;
 always @(posedge clk)if(!rst)begin
 cycles=cycles+1;alert_press<=0;
 if(video.x==200 && video.y==200 && frame_ready)begin
 if(phase%8==1 || phase%8==5)alert_press<=1;
 position=24000;requested=0;

 phase=phase+1;
 end
 if(line_error || rejected)$fatal(1,"raster path error line=%b rejected=%b",line_error,rejected);
 if(user)begin
 if(last_sof>=0 && cycles-last_sof!=663168)$fatal(1,"frame cadence violated");
 last_sof=cycles;input_frames=input_frames+1;iy=0;ix=0;last_line=-1;
 end
 if(valid)begin
 if(!ready)$fatal(1,"real HDMI rejected valid pixel");
 if(ix==0)begin if(last_line>=0 && cycles-last_line!=1056)$fatal(1,"line cadence violated");last_line=cycles;end
 if(last!==(ix==799))$fatal(1,"EOL position error");
 if(ix==799)begin ix=0;iy=iy+1;end else ix=ix+1;
 end
 end
 function [9:0] reverse10;input [9:0] v;integer n;
 begin for(n=0;n<10;n=n+1)reverse10[n]=v[9-n];end endfunction
 function is_control;input [9:0] v;begin
 is_control=v==10'h354 || v==10'h0ab || v==10'h154 || v==10'h2ab;end endfunction
 function [7:0] decode;input [9:0] v;reg [7:0] m;integer n;
 begin m=v[9]?~v[7:0]:v[7:0];decode[0]=m[0];
 for(n=1;n<8;n=n+1)decode[n]=v[8]?(m[n]^m[n-1]):~(m[n]^m[n-1]);end endfunction
 reg reversed=0;wire [9:0] s0=reversed?reverse10(ch0):ch0,s1=reversed?reverse10(ch1):ch1,s2=reversed?reverse10(ch2):ch2;
 wire guard=s0==10'h2cc && s1==10'h133 && s2==10'h2cc;
 wire control=is_control(s0) && is_control(s1) && is_control(s2);
 reg previous_vs=1,arm=1,video_active=0;integer warmup_frames=2;integer guards=0,ox=0,oy=0,kind=2,matched=0,test_frames=0,alt_frames=0;
 integer idx,cur_l,cur_r,prev_l,prev_r,row_ref,col_ref;reg hit_l,hit_r;reg [34:0] glyph_ref;
 function integer height_ref;input integer value;integer amp;begin amp=(value>>>7)+(value>>>8);height_ref=amp>48?0:amp< -48?96:48-amp;end endfunction
 reg [23:0] decoded,expected;reg ctrl_vs;
 task pixel;
 begin
 decoded={decode(s2),decode(s1),decode(s0)};
 if(ox==0 && arm)begin
 oy=0;arm=0;
 kind=0;output_gain=16;save_frame=0;
if(warmup_frames>0)begin warmup_frames=warmup_frames-1;kind=2;end
 end
 if(ox>=800 || oy>=600)$fatal(1,"TMDS active geometry invalid x=%d y=%d",ox,oy);
 if(kind<2)begin
 if(oy==0 && ox<40)prefix[ox]=decoded;
 if(oy==0 && ox==40)begin
 kind=0;output_gain=16;
 gains_seen[output_gain]=1;
 for(j=0;j<40;j=j+1)if(prefix[j]!==24'd0)$fatal(1,"TMDS faded prefix mismatch");
 save_frame=1;
 $sformat(preview_name,"scale_profile%0d_%0d.ppm",PROFILE,matched);image_file=$fopen(preview_name,"wb");$fwrite(image_file,"P6\n800 600\n255\n");
 if(save_frame)begin for(j=0;j<40;j=j+1)$fwrite(image_file,"%c%c%c",prefix[j][23:16],prefix[j][15:8],prefix[j][7:0]);end
 end
 expected=(ox<100 || ox>=700)?24'd0:dim(kind==0?a[oy*800+ox]:b[oy*800+ox],output_gain);
 ex=ox;ey=oy;
 if(ox>=16 && ox<784 && oy>=440 && oy<560)begin
 expected={2'b0,expected[23:18],2'b0,expected[15:10],2'b0,expected[7:2]};
 if(ox==16 || ox==783 || oy==440 || oy==559)expected=24'h52627a;
 if(ox>=144 && ox<656 && oy>=452 && oy<=548)begin
 if(oy==464 || oy==500 || oy==536 || ox==144 || ox==272 || ox==400 || ox==528 || ox==655)expected=24'h344359;
 idx=(ox-144)/2;cur_l=height_ref($signed(wave_words[24000+idx][15:0]));cur_r=height_ref($signed(wave_words[24000+idx][31:16]));
 prev_l=idx==0?cur_l:height_ref($signed(wave_words[23999+idx][15:0]));
 prev_r=idx==0?cur_r:height_ref($signed(wave_words[23999+idx][31:16]));
 hit_l=(oy-452>=(cur_l<prev_l?cur_l:prev_l) && oy-452<=(cur_l>prev_l?cur_l:prev_l));
 hit_r=(oy-452>=(cur_r<prev_r?cur_r:prev_r) && oy-452<=(cur_r>prev_r?cur_r:prev_r));
 if(hit_l)expected=24'h50f090;if(hit_r)expected=hit_l?24'hffffff:24'h48cfff;
 end
 if(ox>=108 && ox<118 && ((oy>=458 && oy<472)||(oy>=524 && oy<538)))begin
 glyph_ref=oy>=524?35'b11110100011000111110101001001010001:35'b10000100001000010000100001000011111;
 row_ref=oy>=524?(oy-524)/2:(oy-458)/2;col_ref=(ox-108)/2;
 if(glyph_ref[34-row_ref*5-col_ref])expected=oy>=524?24'h48cfff:24'h50f090;
 end
 end
 if(ox==16 && oy==16)begin
 if(decoded==24'h487ca0)begin emergency_ref=0;blink_ref=1;end
 else if(decoded==24'hffe090)begin emergency_ref=1;blink_ref=1;end
 else if(decoded==24'hff6070)begin emergency_ref=1;blink_ref=0;end
 else $fatal(1,"unrecognized information banner border");
 end
 bg=expected;#1;expected=info_expected(ox,oy,0,emergency_ref,blink_ref,overlay_expected);
 if(save_frame)$fwrite(image_file,"%c%c%c",decoded[23:16],decoded[15:8],decoded[7:0]);
 if(!(oy==0 && ox<40) && decoded!==expected)$fatal(1,"TMDS pixel mismatch type=%d x=%d y=%d got=%h exp=%h",kind,ox,oy,decoded,expected);
 if(ox==799 && oy==599)begin
 if(save_frame)begin preview_done=1;$fclose(image_file);end
 if(emergency_ref)alert_frames=alert_frames+1;else normal_frames=normal_frames+1;
 matched=matched+1;if(kind==0)test_frames=test_frames+1;else alt_frames=alt_frames+1;
 if(matched>=3 && preview_done && normal_frames>0 && alert_frames>0)begin
 if(!locked || rejected || line_error)$fatal(1,"HDMI not healthy after matched output frames");
 $display("PASS: real encrypted Anlogic HDMI core + official EG simulation library + SDRAM renderer, zero rejected pixels and fixed1056/628 cadence");
 $display("PASS: input profile=%d, original SDRAM source -> aspect-fit -> B+032/C125percent -> wave/status/Chinese overlay -> actual TMDS pixels exact; complete frames=%d",PROFILE,matched);
 $display("PASS: Chinese normal and emergency banners through actual TMDS output, normal=%d alert=%d; frame-atomic mode changes",normal_frames,alert_frames);$finish;end
 end
 end
 ox=ox+1;
 end endtask
 always @(negedge clk)if(!rst)begin
 if(ch0==10'h0cd && ch1==10'h332 && ch2==10'h0cd)reversed=1;
 if(control)begin
 ctrl_vs=(s0==10'h154 || s0==10'h2ab);
 if(ctrl_vs!=previous_vs)arm=1;previous_vs=ctrl_vs;
 if(video_active)begin
 if(ox!=800)$fatal(1,"TMDS line width=%d",ox);
 video_active=0;ox=0;oy=oy+1;
 end
 guards=0;
 end else if(guard)guards=guards+1;
 else if(guards>=2)begin guards=0;video_active=1;ox=0;pixel;end
 else if(video_active)pixel;
 end
 initial begin
 $readmemh("font_rows.hex",golden_font);$readmemh("message_codes.hex",golden_code);
 $readmemh("audio_words.hex",wave_words);image_file=0;
 if(PROFILE==0)begin source_count=480000;$readmemh("gold_1024x1024.hex",source,0,479999);$readmemh("gold_1024x1024.hex",a);end
 else if(PROFILE==1)begin source_count=76800;$readmemh("profile1_raw.hex",source,0,76799);$readmemh("profile1_fit.hex",a);end
 else begin source_count=230400;$readmemh("profile2_raw.hex",source,0,230399);$readmemh("profile2_fit.hex",a);end
 for(i=0;i<1048576;i=i+1)model.mem[i]=0;
 for(i=0;i<source_count;i=i+1)model.mem[PROFILE==1?(i/320)*384+i%320:i]={8'd0,source[i]};
 for(i=0;i<480000;i=i+1)b[i]=a[i];
 repeat(100)@(negedge clk);rst=0;
 for(i=0;i<256;i=i+1)begin
 @(negedge clk);sample_valid=1;pcm_l={wave_words[24000+i][15:0],8'd0};pcm_r={wave_words[24000+i][31:16],8'd0};
 @(negedge clk);sample_valid=0;
 end
 wait(init);frame_ready=1;
 end
 initial begin #260000000;$fatal(1,"real HDMI output validation timeout matched=%d input_frames=%d",matched,input_frames);end
endmodule

