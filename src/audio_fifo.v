// Dual-clock 2048 stereo-frame FIFO, Gray pointer synchronizers.
module audio_fifo #(parameter AW=11)(input wire wclk,wrst,we,input wire [31:0] wd,
 output wire full,output wire [AW:0] wlevel,
 input wire rclk,rrst,pop,output reg [31:0] q,output wire empty,output wire [AW:0] rlevel);
 reg [31:0] memory[0:(1<<AW)-1]; /* fehdl force_ram=1, ram_style="bram" */
 reg [AW:0] wb,wg,rb,rg,rg1,rg_mid,rg2,wg1,wg2;
 function [AW:0] gray_to_bin;input [AW:0] g;integer i;
 begin gray_to_bin[AW]=g[AW];for(i=AW-1;i>=0;i=i-1)gray_to_bin[i]=gray_to_bin[i+1]^g[i];end endfunction
 assign full=wg=={~rg2[AW:AW-1],rg2[AW-2:0]};
 assign empty=rg==wg2;
 assign wlevel=wb-gray_to_bin(rg2);assign rlevel=gray_to_bin(wg2)-rb;
 wire [AW:0] wn=wb+1'b1,rn=rb+1'b1;
 // Related 50/40MHz domains: first pointer capture on opposite write-clock edge,
 // followed by two rising-edge stages. This avoids zero-edge hold budget and
 // preserves a full extra cycle of metastability resolution before pointer use.
 reg [AW:0] rg_half=0;
 always @(negedge rclk)if(rrst)rg_half<=0;else rg_half<=rg;
 always @(negedge wclk)if(wrst)rg1<=0;else rg1<=rg_half;
 always @(posedge wclk)begin
 if(wrst)begin wb<=0;wg<=0;rg_mid<=0;rg2<=0;end
 else begin rg_mid<=rg1;rg2<=rg_mid;if(we && !full)begin wb<=wn;wg<=(wn>>1)^wn;end end
 if(we && !full && !wrst)memory[wb[AW-1:0]]<=wd;
 end
 always @(posedge rclk)begin
 // Read current head continuously; pop consumers use the already-prefetched q.
 q<=memory[rb[AW-1:0]];
 if(rrst)begin rb<=0;rg<=0;wg1<=0;wg2<=0;end
 else begin wg1<=wg;wg2<=wg1;if(pop && !empty)begin rb<=rn;rg<=(rn>>1)^rn;end end
 end
endmodule
