`timescale 1ns/1ps
module tb_800_scaler #(parameter W=320,H=240,REAL_MEM=0);
 reg clk=0;always #12.5 clk=~clk;reg rst=1,start=0,file_id=0;
 wire active,rd,wr,busy,rv,dv,df,complete;wire [20:0] ra,wa;wire [31:0] wd,qd;
 wire [10:0] w0,h0,w1,h1;wire [9:0] fw0,fh0,fw1,fh1;
 frame_scaler dut(clk,rst,start,file_id,11'(W),11'(H),busy,rv,qd,active,rd,wr,ra,wa,wd,dv,df,complete,w0,h0,w1,h1,fw0,fh0,fw1,fh1);
 reg [23:0] gold[0:479999];reg [1023:0] fname;integer i,j,count=0,burstcount=0;reg [20:0] expected_addr=0;
 function [23:0] pattern;input integer x,y;begin pattern={8'((x*13+y*3)%256),8'((x*7+y*19)%256),8'((x*31+y*11)%256)};end endfunction
 generate if(REAL_MEM)begin:realmem
 wire ras,cas,we,init;wire [10:0] ma;wire [1:0] ba;tri[31:0] dq;
 burst_sdram mem(clk,rst,wr,rd,wr?wa:ra,wd,busy,init,rv,qd,ras,cas,we,ma,ba,dq);
 sdram_model model(clk,ras,cas,we,ma,ba,dq);
 initial begin
 for(j=0;j<H;j=j+1)for(i=0;i<W;i=i+1)model.mem[1048576+j*1024+i]={8'd0,pattern(i,j)};
 end
 end else begin:mock
 reg [31:0] mem[0:2097151];reg[31:0] q=0;reg b=0,v=0;integer remaining=0,delay=0;reg [20:0] addr;
 assign busy=b;assign rv=v;assign qd=q;
 initial begin for(j=0;j<H;j=j+1)for(i=0;i<W;i=i+1)mem[1048576+j*1024+i]={8'd0,pattern(i,j)};end
 always @(posedge clk)begin
 v<=0;
 if(rst)begin b<=0;remaining<=0;delay<=0;end
 else if(rd || wr)begin
 if(b)$fatal(1,"request while busy");
 b<=1;
 if(wr)begin mem[wa]<=wd;delay<=2;end else begin remaining<=128;addr<=ra;end
 end else if(remaining!=0)begin
 q<=mem[addr];v<=1;addr<=addr+1'b1;remaining<=remaining-1;
 if(remaining==1)b<=0;
 end else if(delay!=0)begin delay<=delay-1;if(delay==1)b<=0;end
 end
 end endgenerate
 always @(posedge clk)if(!rst)begin
 if(wr)begin
 if(wa!==expected_addr || wd[31:24]!=0 || wd[23:0]!==gold[count%480000])
 $fatal(1,"bilinear pixel mismatch W=%d H=%d index=%d addr=%d actual=%h expected=%h",W,H,count,wa,wd,gold[count%480000]);
 count=count+1;expected_addr=expected_addr+1'b1;
 end
 if(rd)begin
 burstcount=burstcount+1;
 if(ra<1048576 || ra>2097024 || ra[6:0]!=0)$fatal(1,"source address/burst bounds");
 end
 end
 initial begin
 $sformat(fname,"gold_%0dx%0d.hex",W,H);$readmemh(fname,gold);
 repeat(10)@(negedge clk);rst=0;repeat(13000)@(negedge clk);
 start=1;@(negedge clk);start=0;
 wait(dv && !active);@(negedge clk);
 if(count!=480000 || w0!=W || h0!=H)$fatal(1,"first page complete");
 file_id=1;expected_addr=524288;start=1;@(negedge clk);start=0;
 wait(complete);@(negedge clk);
 if(count!=960000 || w1!=W || h1!=H || !df)$fatal(1,"second page complete");
 $display("PASS: bilinear W=%0d H=%0d fit=%0dx%0d, both pages960000 pixels exact, real_sdram=%0d bursts=%0d",W,H,fw1,fh1,REAL_MEM,burstcount);$finish;
 end
 initial begin #2000000000;$fatal(1,"timeout state=%d count=%d",dut.state,count);end
endmodule

