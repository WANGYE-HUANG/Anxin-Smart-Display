// Vendor HDMI video input is a fixed-cadence raster interface, not an elastic
// AXI byte stream: preserve all horizontal and vertical blanking intervals.
module rgb_to_hdmi_raster(input wire clk,rst,vs,de,input wire [23:0] rgb,
 input wire ready,output wire valid,user,last,output wire [23:0] data,output reg rejected);
 reg frame_arm,prev_vs;reg [9:0] x;
 assign valid=de;assign data=rgb;
 assign user=de && frame_arm && x==0;
 assign last=de && x==799;
 always @(posedge clk)begin
 if(rst)begin frame_arm<=1;prev_vs<=1;x<=0;rejected<=0;end
 else begin
 prev_vs<=vs;
 if(vs!=prev_vs)frame_arm<=1;
 if(de)begin
 x<=x+1'b1;if(frame_arm)frame_arm<=0;
 if(!ready)rejected<=1;
 end else x<=0;
 end
 end
endmodule
