// Compute a half-second push transition from consumed PCM position.
// Background restoring division finishes long before the next 48kHz sample.
// Renderer samples the plan only in vertical blank; overlays remain screen-fixed.
module slide_timing(input wire clk,rst,input wire [31:0] position,total_frames,input wire base_frame,
 output wire [9:0] offset);
 wire [31:0] half_frames=total_frames>>1;
 wire [31:0] remaining=base_frame?total_frames-position:half_frames-position;
 wire [31:0] window=half_frames<24000?half_frames:32'd24000;
 wire in_window=total_frames!=0 && window!=0 && position<total_frames && remaining>0 && remaining<=window;
 reg [2:0] state;reg start_div;reg [31:0] numerator,denominator;wire done;wire [31:0] quotient;
 reg captured_frame,published_frame,valid;reg [9:0] published_offset;reg [31:0] elapsed;
 scale_div divide(clk,rst,start_div,numerator,denominator,done,quotient);
 assign offset=(in_window && valid && published_frame==base_frame)?published_offset:10'd0;
 always @(posedge clk)begin
 start_div<=0;
 if(rst)begin state<=0;numerator<=0;denominator<=1;captured_frame<=0;published_frame<=0;valid<=0;published_offset<=0;elapsed<=0;end
 else case(state)
 0:begin
 if(in_window)begin captured_frame<=base_frame;elapsed<=window-remaining;denominator<=window;state<=1;end
 else begin valid<=0;published_offset<=0;end end
 1:begin numerator<=elapsed[14:0]*32'd600;state<=2;end
 2:begin start_div<=1;state<=3;end
 3:if(done)begin
 published_frame<=captured_frame;published_offset<=quotient>599?10'd599:quotient[9:0];valid<=1;state<=0;end
 default:state<=0;
 endcase
 end
endmodule
