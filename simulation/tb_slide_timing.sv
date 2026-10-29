`timescale 1ns/1ps
module tb_slide_timing;
 reg clk=0;always #12.5 clk=~clk;reg rst=1;reg [31:0] pos=0,total=1152000;reg page=0;wire [9:0] offset;
 slide_timing dut(clk,rst,pos,total,page,offset);
 task check;input[31:0] t,p;input f;integer half,window,remaining,expected;begin
 @(negedge clk);total=t;pos=p;page=f;repeat(100)@(negedge clk);
 half=t/2;window=half<24000?half:24000;remaining=f?t-p:half-p;
 expected=(t!=0 && p<t && remaining>0 && remaining<=window)?((window-remaining)*600/window):0;
 if(offset!==expected)$fatal(1,"slide timing t%0d p%0d f%0d got%0d exp%0d",t,p,f,offset,expected);
 end endtask
 integer i;reg[9:0] held;
 initial begin repeat(8)@(negedge clk);rst=0;
 check(1152000,0,0);check(1152000,551999,0);check(1152000,552000,0);
 for(i=0;i<600;i=i+1)check(1152000,552000+i*40,0);
 held=offset;repeat(1000)@(negedge clk);if(offset!=held)$fatal(1,"pause changed offset");
 check(1152000,576000,1);check(1152000,1128000,1);check(1152000,1151999,1);
 check(1152000,0,0);check(2048,1000,0);check(2048,1024,1);check(2048,2047,1);check(0,0,0);
 $display("PASS: all600 slide offsets follow actual PCM position; pause hold, both halves, wrap/replay, short WAV and empty media");$finish;end
 initial begin #10000000;$fatal(1,"timing timeout");end
endmodule
