// Real consumed stereo PCM; 256 samples/window, 2 display pixels/sample.
// Two snapshot banks: fill the back bank, publish only in vertical blank.
module audio_waveform(input wire clk,rst,clear,sample_valid,input wire [23:0] left,right,
 input wire [10:0] look_x,input wire [9:0] x,y,input wire [23:0] rgb,output reg [23:0] result);
 reg [27:0] memory[0:511]; /* fehdl force_ram=1, ram_style="bram" */
 reg [27:0] q;
 reg front,back,front_valid,pending,capturing;
 reg [7:0] index;reg [9:0] trigger_wait;reg previous_negative;
 reg [6:0] previous_left,previous_right;
 wire [9:0] look_delta=look_x-10'd144;
 wire [7:0] read_index=look_delta[8:1];
 function [6:0] height;input [23:0] pcm;reg signed [24:0] value,amp;
 begin
 value={pcm[23],pcm};amp=(value>>>15)+(value>>>16);
 if(amp>48)height=0;else if(amp< -48)height=96;else height=25'sd48-amp;
 end endfunction
 wire [6:0] lh=height(left),rh=height(right);
 wire trigger=!front_valid || (previous_negative && !left[23]) || trigger_wait==1023;
 wire capture=sample_valid && !pending && (capturing || trigger) && !rst && !clear;
 wire [6:0] lp=capturing?previous_left:lh,rp=capturing?previous_right:rh;
 wire [27:0] entry={(rh>rp?rh:rp),(rh<rp?rh:rp),(lh>lp?lh:lp),(lh<lp?lh:lp)};
 always @(posedge clk)begin
 if(capture)memory[{back,index}]<=entry;
 q<=memory[{front,read_index}];
 if(rst || clear)begin
 front<=0;back<=1;front_valid<=0;pending<=0;capturing<=0;
 index<=0;trigger_wait<=0;previous_negative<=0;previous_left<=48;previous_right<=48;
 end else begin
 if(sample_valid)previous_negative<=left[23];
 if(pending && x==0 && y==600)begin
 front<=back;back<=front;front_valid<=1;pending<=0;index<=0;trigger_wait<=0;capturing<=0;
 end
 if(sample_valid && !pending)begin
 if(capturing || trigger)begin
 previous_left<=lh;previous_right<=rh;trigger_wait<=0;
 if(index==255)begin pending<=1;capturing<=0;end
 else begin index<=index+1'b1;capturing<=1;end
 end else trigger_wait<=trigger_wait+1'b1;
 end
 end
 end
 wire panel=x>=16 && x<784 && y>=440 && y<560;
 wire plot=x>=144 && x<656 && y>=452 && y<=548;
 wire [9:0] local_y=y-10'd452;
 wire lhit=front_valid && local_y>=q[6:0] && local_y<=q[13:7];
 wire rhit=front_valid && local_y>=q[20:14] && local_y<=q[27:21];
 // Simple L/R legend, scaled 2x, in the colors of the stereo traces.
 function [34:0] letter;input is_right;begin
 letter=is_right?35'b11110100011000111110101001001010001:35'b10000100001000010000100001000011111;
 end endfunction
 reg [34:0] glyph;reg ink;integer row,col;
 always @* begin
 result=rgb;glyph=0;ink=0;row=0;col=0;
 if(panel)begin
 result={2'b0,rgb[23:18],2'b0,rgb[15:10],2'b0,rgb[7:2]};
 if(x==16 || x==783 || y==440 || y==559)result=24'h52627a;
 if(plot)begin
 if(y==464 || y==500 || y==536 || x==144 || x==272 || x==400 || x==528 || x==655)result=24'h344359;
 if(!front_valid && y==500)result=24'h708097;
 if(lhit)result=24'h50f090;
 if(rhit)result=lhit?24'hffffff:24'h48cfff;
 end
 if(x>=108 && x<118 && ((y>=458 && y<472)||(y>=524 && y<538)))begin
 glyph=letter(y>=524);row=y>=524?(y-524)/2:(y-458)/2;col=(x-108)/2;
 ink=glyph[34-row*5-col];
 if(ink)result=y>=524?24'h48cfff:24'h50f090;
 end
 end
 end
endmodule
