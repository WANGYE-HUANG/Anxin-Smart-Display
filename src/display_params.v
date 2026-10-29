// Pending key edits publish together in vertical blank; paused/manual video still commits.
module display_params(input wire clk,rst,frame_commit,brightness_down,brightness_up,
 contrast_down,contrast_up,defaults_press,output reg signed [7:0] brightness,
 output reg [2:0] contrast_level);
 reg signed [7:0] pending_brightness;reg [2:0] pending_contrast;
 always @(posedge clk)begin
 if(rst)begin brightness<=0;contrast_level<=4;pending_brightness<=0;pending_contrast<=4;end
 else begin
 if(defaults_press)begin pending_brightness<=0;pending_contrast<=4;end
 else begin
 if(brightness_down && !brightness_up && pending_brightness> -8'sd64)pending_brightness<=pending_brightness-8'sd16;
 else if(brightness_up && !brightness_down && pending_brightness<8'sd64)pending_brightness<=pending_brightness+8'sd16;
 if(contrast_down && !contrast_up && pending_contrast>2)pending_contrast<=pending_contrast-1'b1;
 else if(contrast_up && !contrast_down && pending_contrast<6)pending_contrast<=pending_contrast+1'b1;
 end
 if(frame_commit)begin brightness<=pending_brightness;contrast_level<=pending_contrast;end
 end
 end
endmodule
