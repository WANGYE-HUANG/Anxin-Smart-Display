// Two registered stages: signed contrast about mid-grey, brightness offset, saturation.
// Q2 contrast values 2..6 represent 50,75,100,125,150 percent.
module image_adjust(input wire clk,rst,input wire [23:0] rgb,
 input wire signed [7:0] brightness,input wire [2:0] contrast_level,output reg [23:0] result);
 wire signed [8:0] cr=$signed({1'b0,rgb[23:16]})-9'sd128;
 wire signed [8:0] cg=$signed({1'b0,rgb[15:8]})-9'sd128;
 wire signed [8:0] cb=$signed({1'b0,rgb[7:0]})-9'sd128;
 wire signed [3:0] factor=$signed({1'b0,contrast_level});
 reg signed [12:0] pr,pg,pb;reg signed [7:0] bias;
 wire signed [13:0] vr=($signed(pr)>>>2)+14'sd128+$signed(bias);
 wire signed [13:0] vg=($signed(pg)>>>2)+14'sd128+$signed(bias);
 wire signed [13:0] vb=($signed(pb)>>>2)+14'sd128+$signed(bias);
 function [7:0] saturate;input signed [13:0] value;begin
 if(value<0)saturate=0;else if(value>255)saturate=255;else saturate=value[7:0];
 end endfunction
 always @(posedge clk)begin
 if(rst)begin pr<=0;pg<=0;pb<=0;bias<=0;result<=0;end
 else begin pr<=cr*factor;pg<=cg*factor;pb<=cb*factor;bias<=brightness;
 result<={saturate(vr),saturate(vg),saturate(vb)};end
 end
endmodule
