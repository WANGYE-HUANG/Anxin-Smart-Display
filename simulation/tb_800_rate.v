`timescale 1ns/1ps
module tb_800_rate;
 reg clk=0;always #12.5 clk=~clk;reg rst=1,toggle=0;
 wire iv,ia,ov,oa,sp,active,changed,block_wav,changing,space,started,under,over;
 wire [23:0] il,ir,l,r;wire [31:0] pos;wire [7:0] sec;wire [4:0] prog;
 wav_audio wav(.clk50(clk),.rst50(rst),.byte_valid(1'b0),.octet(8'd0),.space(space),
 .pix(clk),.rst_pix(rst),.pause_play(1'b1),.flush50(1'b0),.flush_pix(1'b0),.play_enable(1'b0),.seek_second(1'b0),.total_frames(32'd1152000),
 .position(pos),.seconds(sec),.progress(prog),.requested_frame(),.sample_played(),.audio_valid(iv),.left(il),.right(ir),.acr_valid(ia),.started(started),.underrun(under),.overflow(over),.seek_ready());
 tone_audio dut(clk,rst,toggle,1'b0,1'b0,1'b0,1'b0,1'b1,iv,ia,1'b0,il,ir,ov,oa,sp,l,r,active,changed,block_wav,changing);
 integer samples=0,acrs=0;
 always @(negedge clk)if(!rst)begin if(ov)samples=samples+1;if(oa)acrs=acrs+1;end
 initial begin
 repeat(10)@(negedge clk);rst=0;toggle=1;@(negedge clk);toggle=0;
 repeat(1600001)@(negedge clk);#1;
 if(samples!=1920 || acrs!=40 || !active || changing || under || over)$fatal(1,"40MHz cadence samples=%d acr=%d",samples,acrs);
 $display("PASS: real 40MHz clock, 1,600,000 cycles/40ms gives 1920 PCM samples (48kHz), 40 ACR strobes (1kHz), tone active, no faults");$finish;
 end
endmodule
