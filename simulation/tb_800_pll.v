`timescale 1ns/1ps
module tb_800_pll;
 reg refclk=0,rst=1;always #10 refclk=~refclk;wire p,s,m,locked;
 video_pll dut(refclk,rst,locked,p,s,m);
 integer pc=0,sc=0,mc=0;real prevp=0,prevs=0,prevm=0;reg checking=0;
 always @(posedge p)if(checking)begin if(prevp>0 && ($realtime-prevp<24.999 || $realtime-prevp>25.001))$fatal(1,"pixel period");prevp=$realtime;pc=pc+1;end
 always @(posedge s)if(checking)begin if(prevs>0 && ($realtime-prevs<4.999 || $realtime-prevs>5.001))$fatal(1,"serial period");prevs=$realtime;sc=sc+1;end
 always @(posedge m)if(checking)begin if(prevm>0 && ($realtime-prevm<24.999 || $realtime-prevm>25.001))$fatal(1,"memory period");prevm=$realtime;mc=mc+1;
 if(prevp>0 && ($realtime-prevp<12.499 || $realtime-prevp>12.501))$fatal(1,"memory shift %f",$realtime-prevp);end
 initial begin #500;rst=0;wait(locked);#1000;checking=1;#100000;checking=0;
 if(pc!=4000 || sc!=20000 || mc!=4000)$fatal(1,"PLL counts p%0d s%0d m%0d",pc,sc,mc);
 $display("PASS: vendor PLL model40/200/40MHz, memory phase180degrees;4000/20000/4000 edges per100us");$finish;end
 initial begin #1000000;$fatal(1,"PLL timeout");end
endmodule

