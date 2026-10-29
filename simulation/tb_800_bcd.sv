`timescale 1ns/1ps
module tb_800_bcd;
 reg clk=0;always #12.5 clk=~clk;reg rst=1;reg [10:0]value=0;wire[15:0]digits;
 osd_bcd dut(clk,rst,value,digits);integer i;reg[15:0]expected;
 initial begin repeat(5)@(negedge clk);rst=0;
 for(i=0;i<=2047;i=i+1)begin value=i;repeat(14)@(negedge clk);
 expected={4'(i/1000),4'((i/100)%10),4'((i/10)%10),4'(i%10)};
 if(digits!==expected)$fatal(1,"BCD i%0d got%h exp%h",i,digits,expected);end
 $display("PASS: all2048 original-dimension BCD encodings match integer decimal reference");$finish;end
endmodule
