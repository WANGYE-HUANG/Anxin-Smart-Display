`timescale 1ns/1ps
module tb_800_system;
 reg clk=0,pix=0;always #10 clk=~clk;always #12.5 pix=~pix;reg rst=1;
 wire req,fs_ok,fs_fail,pv,pfile,mem_busy,rv,loader_wr,scale_wr,scale_rd,scale_active,scale_start,source_file,done_valid,done_file,loaded,overflow;
 wire [31:0] lba,rd_data,loader_data,scale_data;wire [20:0] loader_addr,scale_wa,scale_ra;
 wire [10:0] pw,ph,sw,sh,w0,h0,w1,h1;wire [9:0] fw0,fh0,fw1,fh1;wire [7:0] pb,code;
 reg done=0,dvalid=0;reg [8:0] byte_index=0;reg [7:0] octet=0;reg [1:0] dv50=0,df50=0;
 wire wav_valid;wire [7:0] wav_byte;wire [31:0] total;
 reg done_half=0,file_half=0;
 always @(negedge pix)begin done_half<=done_valid;file_half<=done_file;end
 always @(negedge clk)if(rst)begin dv50[0]<=0;df50[0]<=0;end else begin dv50[0]<=done_half;df50[0]<=file_half;end
 always @(posedge clk)if(rst)begin dv50[1]<=0;df50[1]<=0;end else begin dv50[1]<=dv50[0];df50[1]<=df50[0];end
 fat_bmp_check fs(.clk(clk),.rst(rst),.card_ready(1'b1),.card_error(1'b0),.req(req),.lba(lba),.sector_done(done),
 .data_valid(dvalid),.byte_index(byte_index),.octet(octet),.image_ready(dv50[1] && df50[1]==pfile),
 .restart_hold(1'b0),.seek_second(1'b0),.restart_idle(),.total_frames(total),.audio_space(1'b1),
 .wav_byte_valid(wav_valid),.wav_byte(wav_byte),.wav_ok(),.pixel_width(pw),.pixel_height(ph),.pixel_profile(),.test_profile(),.alt_profile(),
 .pixel_file(pfile),.pixel_byte_valid(pv),.pixel_byte(pb),.mounted(),.files_found(),.test_ok(),.alt_ok(),.passed(fs_ok),.failed(fs_fail),.error_code(code));
 generic_bmp_loader loader(clk,rst,pv,pb,pfile,pw,ph,pix,rst,mem_busy,scale_active,loader_wr,loader_addr,loader_data,scale_start,source_file,sw,sh,overflow);
 frame_scaler scaler(pix,rst,scale_start,source_file,sw,sh,mem_busy,rv,rd_data,scale_active,scale_rd,scale_wr,scale_ra,scale_wa,scale_data,done_valid,done_file,loaded,w0,h0,w1,h1,fw0,fh0,fw1,fh1);
 wire vr,init,ras,cas,we,commit,hs,vs,de,underrun,displaying,active,bar;wire [20:0] va;wire [10:0] ma;wire [1:0] ba;tri[31:0] dq;
 wire [9:0] x,y,ly;wire [10:0] lx;wire [23:0] rgb;
 wire wr=loader_wr || scale_wr;
 burst_sdram controller(pix,rst,wr,scale_active?scale_rd:vr,wr?(loader_wr?loader_addr:scale_wa):(scale_active?scale_ra:va),loader_wr?loader_data:scale_data,mem_busy,init,rv,rd_data,ras,cas,we,ma,ba,dq);
 sdram_model model(pix,ras,cas,we,ma,ba,dq);
 reg requested=0;
 line_video video(.slide_offset(10'd0),.clk(pix),.rst(rst),.frame_ready(fs_ok && loaded),.fatal_error(fs_fail),.mem_busy(mem_busy),.rd_valid(rv),.rd_data(rd_data),
 .requested_frame(requested),.profile0(3'd0),.profile1(3'd0),.rd_en(vr),.rd_addr(va),.frame_commit(commit),.look_x(lx),.look_y(ly),
 .out_x(x),.out_y(y),.rgb(rgb),.hs(hs),.vs(vs),.de(de),.underrun(underrun),.displaying(displaying),.active_frame(active),.active_profile(),.letterbox(bar));
 reg [7:0] first[0:173],second[0:396089],wav[0:8235];reg [23:0] gold0[0:479999],gold1[0:479999];
 integer mode=0;integer count0=0,count1=0,wavcount=0,checks0=0,checks1=0;
 integer host_state=0,pos=0,pace=0;reg [31:0] saved_lba;
 function [31:0] fatentry;input integer c;begin fatentry=32'h0fffffff;
 if(c>=5000 && c<=5288 && (c-5000)%3==0 && c<5288)fatentry=c+3;
 if(c==9000)fatentry=9005;if(c==9005)fatentry=9010;
 end endfunction
 function [7:0] getbyte;input integer sector,n;integer c,sub,offset,entry,field;reg[87:0] name;reg[31:0] v;begin
 getbyte=0;
 if(sector==0)begin
 if(n==450)getbyte=8'h0c;if(n>=454 && n<458)getbyte=32'd32>>((n-454)*8);
 if(n>=458 && n<462)getbyte=32'd1000000>>((n-458)*8);if(n==510)getbyte=8'h55;if(n==511)getbyte=8'haa;
 end else if(sector==32)begin
 case(n)12:getbyte=2;13:getbyte=8;14:getbyte=32;16:getbyte=2;44:getbyte=2;510:getbyte=8'h55;511:getbyte=8'haa;endcase
 if(n>=32 && n<36)getbyte=32'd1000000>>((n-32)*8);if(n>=36 && n<40)getbyte=32'd4096>>((n-36)*8);
 end else if(sector>=64 && sector<4160)begin v=fatentry((sector-64)*128+n/4);getbyte=v>>((n%4)*8);end
 else if(sector>=8256)begin
 c=2+(sector-8256)/8;sub=(sector-8256)%8;
 if(c==2 && sub==0)begin
 entry=n/32;field=n%32;name=entry==0?"TEST    BMP":entry==1?"ALT     BMP":"AUDIO   WAV";
 if(entry<3)begin
 if(field<11)getbyte=name>>((10-field)*8);if(field==11)getbyte=8'h20;
 if(field==26)getbyte=entry==0?8'd10:entry==1?8'h88:8'h28;
 if(field==27)getbyte=entry==0?0:entry==1?8'h13:8'h23;
 if(field>=28)getbyte=(entry==0?32'd174:entry==1?32'd396090:32'd8236)>>((field-28)*8);
 end
 end else if(c==10)begin offset=sub*512+n;if(offset<174)getbyte=first[offset];
 if(mode==1 && offset==18)getbyte=0;if(mode==1 && offset==19)getbyte=8'h08;
 if(mode==2 && offset>=22 && offset<=25)getbyte=8'hff;
 end else if(c>=5000 && c<=5288 && (c-5000)%3==0)begin
 offset=((c-5000)/3)*4096+sub*512+n;if(offset<396090)getbyte=second[offset];
 end else if(c==9000 || c==9005 || c==9010)begin offset=((c-9000)/5)*4096+sub*512+n;if(offset<8236)getbyte=wav[offset];end
 else $fatal(1,"bad FAT sector %d cluster %d",sector,c);
 end
 end endfunction
 always @(posedge clk)begin
 dvalid<=0;done<=0;pace<=pace==63?0:pace+1;
 if(rst)begin host_state<=0;pos<=0;end
 else if(req)begin if(host_state!=0)$fatal(1,"host overlap");saved_lba<=lba;pos<=0;host_state<=1;end
 else if(host_state==1 && pace==0)begin
 dvalid<=1;byte_index<=pos;octet<=getbyte(saved_lba,pos);if(pos==511)host_state<=2;else pos<=pos+1;
 end else if(host_state==2)host_state<=3;else if(host_state==3)begin done<=1;host_state<=0;end
 if(!rst && pv)begin
 if(pfile)begin
 if(pb!==second[54+(count1/(257*3))*772+count1%(257*3)] || pw!=257 || ph!=513)$fatal(1,"padded second pixel/metadata");
 count1=count1+1;
 end else begin
 if(pb!==first[54+(count0/21)*24+count0%21] || pw!=7 || ph!=5)$fatal(1,"padded first pixel/metadata");
 count0=count0+1;
 end
 end
 if(!rst && wav_valid)begin if(wav_byte!==wav[44+wavcount%8192])$fatal(1,"WAV loop changed");wavcount=wavcount+1;end
 end
 integer verified=0;reg saw_first=0;
 always @(negedge pix)if(!rst && mode==0)begin
 if(fs_fail || overflow || underrun)$fatal(1,"end-to-end fault %h",code);
 if(de && displaying && x==0 && y==0)saw_first=1;
 if(de && displaying && saw_first)begin
 if(rgb!==(active?gold1[y*800+x]:gold0[y*800+x]))$fatal(1,"SDRAM->scanout mismatch x=%d y=%d",x,y);
 if(active)checks1=checks1+1;else checks0=checks0+1;
 if(x==639 && y==479)begin requested=!requested;verified=verified+1;end
 end
 end
 initial begin
 $readmemh("input_7x5.hex",first);$readmemh("input_257x513.hex",second);$readmemh("wav_fixture.hex",wav);
 $readmemh("gold_7x5.hex",gold0);$readmemh("gold_257x513.hex",gold1);
 repeat(10)@(negedge clk);rst=0;
 wait(verified>=2 && checks0>=480000 && checks1>=480000 && wavcount>8192);@(negedge clk);
 if(count0!=105 || count1!=395523 || w0!=7 || h0!=5 || w1!=257 || h1!=513)$fatal(1,"pixel count/dimensions");
 // Explicitly reject width beyond1024 and negative height before image payload.
 $display("PASS: first full FAT/loader/SDRAM/bilinear/scanout path"); model.configured=0;model.opened=0;model.remain=0;model.latency=0;rst=1;mode=1;count0=0;count1=0;repeat(10)@(negedge clk);rst=0;wait(fs_fail);
 if(code!=8'h09 || count0!=0)$fatal(1,"unsupported width rejection");
 model.configured=0;model.opened=0;model.remain=0;model.latency=0;rst=1;mode=2;repeat(10)@(negedge clk);rst=0;wait(fs_fail);
 if(code!=8'h09 || count0!=0)$fatal(1,"negative height rejection");
 $display("PASS: fragmented FAT -> odd-width BMP padding filter -> CDC source loader -> real SDRAM -> bilinear writes -> both native scanout pages pixel exact; WAV loops; bounds/negative header reject");$finish;
 end
 initial begin #(64'd2500000000);$fatal(1,"system timeout fs=%d scale=%d verified=%d",fs.state,scaler.state,verified);end
endmodule


