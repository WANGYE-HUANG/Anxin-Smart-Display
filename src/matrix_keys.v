// Board reference mapping: row1110->KEY15..12, row0111->KEY3..0.
// 1ms/row, full-frame debounce; inactive rows float to avoid opposing drivers.
module matrix_keys #(parameter SCAN_TICKS=40000,DEBOUNCE_FRAMES=5)(
 input wire clk,rst,input wire [3:0] col,output wire [3:0] row,
 output reg next_press,mode_press,emergency_press,output wire diagnostic_hold,output reg previous_slide_press,next_slide_press,auto_press,brightness_down,brightness_up,contrast_down,contrast_up,defaults_press,tone_press,effect_press);
 reg [3:0] meta,sync_col;reg [15:0] ticks;
 reg [1:0] row_index;reg [15:0] samples,candidate,stable;
 reg [3:0] matches;
 assign diagnostic_hold=stable==16'h0008;
 wire [15:0] frame_sample={samples[15:4],~sync_col};
 genvar r;generate for(r=0;r<4;r=r+1)begin:rows
 assign row[r]=(row_index==r)?1'b0:1'bz;
 end endgenerate
 always @(posedge clk)begin
 next_press<=0;mode_press<=0;emergency_press<=0;previous_slide_press<=0;next_slide_press<=0;auto_press<=0;brightness_down<=0;brightness_up<=0;contrast_down<=0;contrast_up<=0;defaults_press<=0;tone_press<=0;effect_press<=0;
 if(rst)begin meta<=15;sync_col<=15;ticks<=0;row_index<=0;
 samples<=0;candidate<=0;stable<=0;matches<=0;end
 else begin
 meta<=col;sync_col<=meta;
 if(ticks==SCAN_TICKS-1)begin
 ticks<=0;row_index<=row_index+1'b1;
 case(row_index)
 0:samples[15:12]<=~sync_col;
 1:samples[11:8]<=~sync_col;
 2:samples[7:4]<=~sync_col;
 3:begin
 samples[3:0]<=~sync_col;
 if(frame_sample!=candidate)begin candidate<=frame_sample;matches<=0;end
 else if(matches<DEBOUNCE_FRAMES)begin
 matches<=matches+1'b1;
 if(matches==DEBOUNCE_FRAMES-1)begin
 stable<=candidate;
 // One event after a clean release; simultaneous/ghost keys are ignored.
 if(stable==0)begin
 if(candidate==16'h0001)next_press<=1;
 if(candidate==16'h0002)mode_press<=1;
 if(candidate==16'h0004)emergency_press<=1;
 if(candidate==16'h0010)previous_slide_press<=1;
 if(candidate==16'h0020)next_slide_press<=1;
 if(candidate==16'h0040)auto_press<=1;
 if(candidate==16'h0080)tone_press<=1;
 if(candidate==16'h0100)brightness_down<=1;
 if(candidate==16'h0200)brightness_up<=1;
 if(candidate==16'h0400)contrast_down<=1;
 if(candidate==16'h0800)contrast_up<=1;
 if(candidate==16'h1000)defaults_press<=1;
 if(candidate==16'h2000)effect_press<=1;
 end
 end
 end
 end
 endcase
 end else ticks<=ticks+1'b1;
 end
 end
endmodule
