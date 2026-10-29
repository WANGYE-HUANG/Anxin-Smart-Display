// Fade through black around media boundaries. No extra pixel latency.
// 16 levels x 1500 PCM frames = 0.5s at 48kHz for each fade-in/out.
module fade_video #(parameter STEP_SAMPLES=1500)(input wire clk,rst,frame_commit,
 input wire [31:0] position,total_frames,input wire requested_frame,
 input wire [23:0] rgb,output wire [23:0] result,output reg [4:0] gain);
 wire [31:0] half_frames=total_frames>>1;
 wire [31:0] elapsed=requested_frame?position-half_frames:position;
 wire [31:0] remaining=requested_frame?total_frames-position:half_frames-position;
 reg [4:0] up,down;integer i;
 always @* begin
 up=0;down=0;
 for(i=1;i<=16;i=i+1)begin
 if(elapsed>=STEP_SAMPLES*i)up=i;
 if(remaining>=STEP_SAMPLES*i)down=i;
 end
 end
 always @(posedge clk)begin
 if(rst)gain<=0;
 else if(frame_commit)gain<=total_frames==0?5'd0:(up<down?up:down);
 end
 wire [12:0] red=rgb[23:16]*gain,green=rgb[15:8]*gain,blue=rgb[7:0]*gain;
 assign result={red[11:4],green[11:4],blue[11:4]};
endmodule
