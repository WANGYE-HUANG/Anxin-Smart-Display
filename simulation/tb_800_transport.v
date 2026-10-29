module tb_800_transport;
 reg [1:0] seek50=0;
 reg [1:0] hold50=0;
 reg clk=0;always #10 clk=~clk;reg rst=1;
 wire wav_valid,wav_ok;wire [7:0] wav_byte;wire audio_space,restart_hold;reg manual_pause=0;wire restart_idle;wire [31:0] total_frames;wire pixel_valid,pixel_file;wire [7:0] pixel_byte;wire req,mounted,found,tok,aok,passed,failed;wire [31:0] lba;wire [7:0] code;
 reg done=0,valid=0;reg [8:0] idx=0;reg [7:0] octet=0;
 reg [7:0] testbytes[0:921653],altbytes[0:921653];
 reg [7:0] wavbytes[0:8235];integer wav_count=0;integer cycle=0;integer mode=0;integer busy=0,pos=0;reg [31:0] saved_lba;
 fat_bmp_check dut(.image_ready(1'b1),.clk(clk),.rst(rst),.card_ready(1'b1),.card_error(1'b0),
 .req(req),.lba(lba),.sector_done(done),.data_valid(valid),.byte_index(idx),.octet(octet),
 .restart_hold(hold50[1]),.seek_second(seek50[1]),.restart_idle(restart_idle),.total_frames(total_frames),.audio_space(audio_space),.wav_byte_valid(wav_valid),.wav_byte(wav_byte),.wav_ok(wav_ok),.pixel_file(pixel_file),.pixel_byte_valid(pixel_valid),.pixel_byte(pixel_byte),.mounted(mounted),.files_found(found),.test_ok(tok),.alt_ok(aok),
 .passed(passed),.failed(failed),.error_code(code));
 integer first_bytes=0,second_bytes=0;
 always @(posedge clk)begin
 cycle<=cycle+1;
 if(rst || hold50[1])wav_count=0;
 else if(wav_valid && mode==0)begin
 if(wav_byte!==wavbytes[44+((wav_count+(seek50[1]?4096:0))%8192)])$fatal(1,"WAV byte/loop mismatch offset=%d",wav_count);
 wav_count=wav_count+1;
 end end
 always @(posedge clk)begin
 if(rst)begin first_bytes=0;second_bytes=0;end
 else if(pixel_valid && mode==0)begin
 if(pixel_file)begin
 if(pixel_byte!==altbytes[54+second_bytes])$fatal(1,"ALT stream mismatch");second_bytes=second_bytes+1;end
 else begin
 if(pixel_byte!==testbytes[54+first_bytes])$fatal(1,"TEST stream mismatch");first_bytes=first_bytes+1;end
 end end
 function [31:0] fatentry;input integer cluster;
 begin
 fatentry=32'h0fffffff;
 if(cluster==2)fatentry=3;
 if(cluster>=10 && cluster<=460 && (cluster-10)%2==0)
 fatentry=(cluster==460)?32'h0fffffff:cluster+2;
 if(cluster>=1000 && cluster<=1675 && (cluster-1000)%3==0)
 fatentry=(cluster==1675)?32'h0fffffff:cluster+3;
 if(cluster==3000)fatentry=3005;
 if(cluster==3005)fatentry=3010;
 if(cluster==3010)fatentry=32'h0fffffff;
 if(mode==1 && cluster==10)fatentry=32'h0ffffff7;
 end endfunction
 function [7:0] getbyte;input [31:0] sector;input integer n;
 integer cluster,sub,offset,ent,field;reg [31:0] v;reg [87:0] name;
 begin
 getbyte=0;
 if(sector==0)begin
 if(n==450)getbyte=8'h0c;
 if(n>=454 && n<458)getbyte=32'd32>>((n-454)*8);
 if(n>=458 && n<462)getbyte=32'd1000000>>((n-458)*8);
 if(n==510)getbyte=8'h55;if(n==511)getbyte=8'haa;
 end else if(sector==32)begin
 case(n)12:getbyte=2;13:getbyte=8;14:getbyte=32;16:getbyte=2;44:getbyte=2;
 510:getbyte=8'h55;511:getbyte=8'haa;endcase
 if(n>=32 && n<36)getbyte=32'd1000000>>((n-32)*8);
 if(n>=36 && n<40)getbyte=32'd4096>>((n-36)*8);
 end else if(sector>=64 && sector<4160)begin
 v=fatentry((sector-64)*128+n/4);getbyte=v>>((n%4)*8);
 end else if(sector>=8256)begin
 cluster=2+(sector-8256)/8;sub=(sector-8256)%8;
 if(cluster==2)begin if(n%32==0)getbyte=8'he5;end
 else if(cluster==3)begin
 if(sub==0)begin
 ent=n/32;field=n%32;
 name=ent==3?"AUDIO   WAV":(ent==2)?"ALT     BMP":"TEST    BMP";
 if(ent<4 && !(mode==3 && ent==2))begin
 if(field<11)getbyte=name>>((10-field)*8);
 if(field==11)getbyte=(ent==0)?8'h0f:8'h20;
 if(field==26)getbyte=ent==3?8'hb8:(ent==2)?8'he8:8'd10;
 if(field==27)getbyte=ent==3?8'h0b:(ent==2)?8'h03:0;
 if(field>=28)getbyte=(ent==3?32'd8236:ent==2?32'd691254:32'd230454)>>((field-28)*8);
 end
 end
 end else if(cluster>=10 && cluster<=460 && (cluster-10)%2==0)begin
 offset=((cluster-10)/2)*4096+sub*512+n;
 if(offset<230454)getbyte=testbytes[offset];
 if(mode==2 && offset==5000)getbyte=getbyte^1;
 end else if(cluster>=1000 && cluster<=1675 && (cluster-1000)%3==0)begin
 offset=((cluster-1000)/3)*4096+sub*512+n;
 if(offset<691254)getbyte=altbytes[offset];
 end else if(cluster==3000 || cluster==3005 || cluster==3010)begin
 offset=((cluster-3000)/5)*4096+sub*512+n;
 if(offset<8236)getbyte=wavbytes[offset];
 if(mode==4 && offset==24)getbyte=8'h44;
 end else $fatal(1,"unexpected sector %d cluster %d",sector,cluster);
 end else $fatal(1,"unexpected sector %d",sector);
 end endfunction
 always @(posedge clk)begin
 valid<=0;done<=0;
 if(rst)begin busy<=0;pos<=0;end
 else if(req)begin
 if(busy!=0)$fatal(1,"overlapping request");
 saved_lba<=lba;pos<=0;busy<=1;
 end else if(busy==1)begin
 valid<=1;idx<=pos;octet<=getbyte(saved_lba,pos);
 if(pos==511)busy<=2;else pos<=pos+1;
 end else if(busy==2)busy<=3;
 else if(busy==3)begin done<=1;busy<=0;end
 end
 reg pix=0;always #20 pix=~pix;
 reg tone_press=0; wire block_wav,tone_active,changed,changing,tv,ta,tp;wire [23:0] tl,tr;reg pause_press=0,replay_press=0;wire paused,flushing;reg [1:0] idle_pix=0;
 reg [31:0] total_meta=0,total_pix=0;
 always @(posedge clk)if(rst)hold50<=0;else hold50<={hold50[0],restart_hold};
 always @(posedge pix)if(rst)begin idle_pix<=0;total_meta<=0;total_pix<=0;end
 else begin idle_pix<={idle_pix[0],restart_idle};total_meta<=total_frames;total_pix<=total_meta;end
 reg previous_press=0,next_slide_press=0,auto_press=0;wire manual_mode,manual_page,display_frame,seek_second;
 wire frame;
 always @(posedge clk)if(rst)seek50<=0;else seek50<={seek50[0],seek_second};
 transport_control ctl(.clk(pix),.rst(rst),.ready(passed && total_pix!=0),.failed(failed),.pause_press(pause_press),.replay_press(replay_press),
 .reader_idle(idle_pix[1]),.previous_press(previous_press),.next_press(next_slide_press),.auto_press(auto_press),.active_frame(frame),.auto_frame(frame),
 .paused(paused),.manual_mode(manual_mode),.page(manual_page),.seek_second(seek_second),.restart_hold(restart_hold),.flushing(flushing),.requested_frame(display_frame));
 wire av,acr,started,under,over,sample_played;wire [23:0] left,right;wire [31:0] position;wire [7:0] seconds;wire [4:0] progress;
 wav_audio #(.CLOCK_RATE(1000000),.PREFILL(512)) audio(.clk50(clk),.rst50(rst),.byte_valid(wav_valid),.octet(wav_byte),.space(audio_space),
 .pix(pix),.rst_pix(rst),.pause_play(paused || block_wav),.seek_second(seek_second),.flush50(hold50[1]),.flush_pix(flushing),.play_enable(passed),.total_frames(total_pix),
 .position(position),.seconds(seconds),.progress(progress),.requested_frame(frame),.sample_played(sample_played),.audio_valid(av),.left(left),.right(right),
 .acr_valid(acr),.started(started),.underrun(under),.overflow(over));
 
 tone_audio mux(.clk(pix),.rst(rst),.toggle_press(tone_press),.voice_press(auto_press),.replay_press(replay_press),
 .paused(paused),.flushing(flushing),.play_enable(passed && started && !flushing),
 .in_valid(av),.in_acr(acr),.in_sample_played(sample_played),.in_left(left),.in_right(right),
 .out_valid(tv),.out_acr(ta),.sample_played(tp),.left(tl),.right(tr),.active_tone(tone_active),
 .source_changed(changed),.block_wav(block_wav),.source_changing(changing));
 reg old_av,old_acr;
 always @(posedge pix)begin old_av=av;old_acr=acr;end
 always @(negedge pix)if(!rst)begin
 if(tv!==old_av || ta!==old_acr)$fatal(1,"output cadence changed");
 end
 task tone_key;begin @(negedge pix);tone_press=1;@(negedge pix);tone_press=0;end endtask
 task stable_tone;input desired;begin wait(tone_active==desired && !changing);@(negedge pix);end endtask
 reg [10:0] wx=0;reg [9:0] wy=0,px=0,py=0;wire [23:0] wave_rgb;
 always @(posedge pix)begin
 if(rst)begin wx<=0;wy<=0;px<=0;py<=0;end else begin
 px<=wx;py<=wy;if(wx==1055)begin wx<=0;wy<=wy==627?0:wy+1'b1;end else wx<=wx+1'b1;
 end end
 reg bd=0,bu=0,cd=0,cu=0,df=0;wire signed [7:0] brightness;wire [2:0] contrast_level;
 display_params params(.clk(pix),.rst(rst),.frame_commit(wx==0 && wy==627 && passed),.brightness_down(bd),.brightness_up(bu),
 .contrast_down(cd),.contrast_up(cu),.defaults_press(df),.brightness(brightness),.contrast_level(contrast_level));
 wire [4:0] fade_gain;wire [23:0] fade_rgb;
 fade_video fade(.clk(pix),.rst(rst),.frame_commit(wx==0 && wy==627 && passed),
 .position(position),.total_frames(total_pix),.requested_frame(frame),.rgb(24'hffffff),.result(fade_rgb),.gain(fade_gain));
 audio_waveform wave(.clk(pix),.rst(rst),.clear(flushing || changed),.sample_valid(tp),.left(tl),.right(tr),
 .look_x(wx),.x(px),.y(py),.rgb(fade_rgb),.result(wave_rgb));
 reg alert_press=0;wire alert_active;wire [10:0] ticker_offset;wire [23:0] info_rgb;
 info_overlay info(.clk(pix),.rst(rst),.emergency_press(alert_press),.play_running(started && !paused && !flushing),
 .look_x(wx),.look_y(wy),.x(px),.y(py),.rgb(wave_rgb),.result(info_rgb),.emergency_active(alert_active),.scroll_offset(ticker_offset));
 integer expected_sample=0,consumed=0;reg popped;reg [31:0] expected_word;
 always @(posedge pix)begin
 popped=audio.pop;
 expected_word={wavbytes[47+4*expected_sample],wavbytes[46+4*expected_sample],wavbytes[45+4*expected_sample],wavbytes[44+4*expected_sample]};
 if(rst || flushing)expected_sample=seek_second?1024:0;
 else if(popped)begin expected_sample=(expected_sample+1)%2048;consumed=consumed+1;end
 end
 always @(negedge pix)if(!rst)begin
 if(sample_played!==popped)$fatal(1,"consumed PCM visualization strobe misaligned");
 if(failed || under || over)$fatal(1,"combined path fault fs=%h under=%b over=%b",code,under,over);
 if(position!==expected_sample)$fatal(1,"combined timeline mismatch");
 if(av && popped && (left!=={expected_word[15:0],8'd0} || right!=={expected_word[31:16],8'd0}))$fatal(1,"combined PCM mismatch");
 if(av && !popped && (left!==0 || right!==0))$fatal(1,"combined silence mismatch");
 end
 task key;input replay;begin @(negedge pix);if(replay)replay_press=1;else pause_press=1;
 @(negedge pix);pause_press=0;replay_press=0;end endtask
 task button;input integer n;begin @(negedge pix);
 case(n)0:pause_press=1;1:replay_press=1;4:previous_press=1;5:next_slide_press=1;6:auto_press=1;endcase
 @(negedge pix);pause_press=0;replay_press=0;previous_press=0;next_slide_press=0;auto_press=0;end endtask
 task playing_selected;input second;begin
 wait(flushing);wait(!flushing);wait(started);@(negedge pix);
 if(paused || manual_mode || seek_second!=second)$fatal(1,"selected-page single-key play failed");
 if(position!=(second?1024:0))$fatal(1,"wrong selected-page initial position %d",position);
 wait(audio.pop);@(negedge pix);
 end endtask
 integer frozen;reg selected;
 initial begin
 $readmemh("profile1_bytes.hex",testbytes,0,230453);$readmemh("wav_fixture.hex",wavbytes);$readmemh("profile2_bytes.hex",altbytes,0,691253);
 repeat(10)@(negedge pix);rst=0;wait(consumed>100);
 
 tone_key;stable_tone(1);frozen=position;
 repeat(25000)@(negedge pix);
 if(position!=frozen || !block_wav || under || over)$fatal(1,"tone did not park voice/FIFO");
 button(0);wait(mux.gain==0);repeat(100)@(negedge pix);
 if(!paused || tl!=0 || tr!=0)$fatal(1,"tone pause not silent");
 begin : pause_phase
 reg [5:0] saved_phase;saved_phase=mux.phase;
 repeat(3000)@(negedge pix);if(mux.phase!=saved_phase || position!=frozen)$fatal(1,"paused tone advanced");
 end
 button(0);stable_tone(1);repeat(1000)@(negedge pix);
 if(paused || position!=frozen)$fatal(1,"tone resume disturbed voice");
 tone_key;stable_tone(0);wait(position!=frozen);
 tone_key;stable_tone(1);button(6);stable_tone(0);
 if(paused)$fatal(1,"KEY6 voice resume");
 tone_key;stable_tone(1);button(1);playing_selected(0);
 if(tone_active || mux.desired_tone)$fatal(1,"KEY1 did not cancel tone");
 tone_key;stable_tone(1);button(5);selected=manual_page;button(0);playing_selected(selected);
 if(tone_active)$fatal(1,"manual selected-page play did not restore voice");
 button(5);selected=manual_page;frozen=position;repeat(5000)@(negedge pix);
 if(!manual_mode || !paused || position!=frozen)$fatal(1,"manual park");
 @(negedge pix);bu=1;cu=1;@(negedge pix);bu=0;cu=0;
 wait(brightness==16 && contrast_level==5);@(negedge pix);
 if(position!=frozen || !paused)$fatal(1,"parameter update altered generic FAT transport");
 button(0);playing_selected(selected);
 button(0);if(!paused)$fatal(1,"normal pause");button(6);if(paused)$fatal(1,"K6 must resume normal pause");
 button(0);button(4);selected=manual_page;button(0);playing_selected(selected);
 button(0);button(5);selected=manual_page;button(6);playing_selected(selected);
 button(5);selected=manual_page;button(6);playing_selected(selected);
 // Replay wins over selected second-page seek while handshake is active.
 if(frame)begin button(1);playing_selected(0);end
 button(5);button(6);wait(flushing);button(1);playing_selected(0);
 wait(consumed>1500);
 if(brightness!=16 || contrast_level!=5)$fatal(1,"seek/replay changed display settings");
 if(failed || first_bytes!=230400 || second_bytes!=691200)$fatal(1,"filesystem/image status");
 $display("PASS: tone park, pause silence/phase hold, resume, KEY7 toggle, KEY6 voice, KEY1 priority, manual selected-page voice recovery, continuous valid/ACR; mixed320x240/640x360 FAT decoder with optional manifest absent, paused display tuning and parameter preservation, user sequences K4/5->K0, K0->K6, K0->K4/5->K0 or K6, K4/5->K6 all play selected segment without two-key unlock; K1 overrides an active seek; exact FAT PCM bytes and samples, no FIFO faults, images retained");$finish;
 end
 initial begin #200000000;$fatal(1,"combined timeout");end
endmodule
