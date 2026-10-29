// 800x600 OSD: three registered stages (address, glyph row, composition).
module info_overlay #(parameter SCROLL_FRAMES=2)(input wire clk,rst,emergency_press,play_running,
 input wire [10:0] look_x,input wire [9:0] look_y,x,y,input wire [23:0] rgb,
 output reg [23:0] result,output reg emergency_active,output reg [10:0] scroll_offset);
 `include "info_font.vh"
 localparam MESSAGE_WIDTH=1248;
 reg desired_emergency;reg [5:0] blink_count;reg [7:0] scroll_count;
 wire ui_frame=look_x==0 && look_y==600;
 always @(posedge clk)begin
 if(rst)begin desired_emergency<=0;emergency_active<=0;scroll_offset<=0;scroll_count<=0;blink_count<=0;end
 else begin
 if(emergency_press)desired_emergency<=!desired_emergency;
 if(ui_frame)begin emergency_active<=desired_emergency;blink_count<=blink_count==59?0:blink_count+1'b1;
 if(play_running && !desired_emergency)begin
 if(scroll_count==SCROLL_FRAMES-1)begin scroll_count<=0;scroll_offset<=scroll_offset==MESSAGE_WIDTH-1?0:scroll_offset+1'b1;end
 else scroll_count<=scroll_count+1'b1;end end end end
 reg [11:0] u,wrapped;reg [9:0] v;reg [5:0] index;reg [1:0] message;reg text_here,panel,border;
 always @* begin
 u=0;v=0;wrapped=0;index=0;message=0;text_here=0;
 panel=x>=16 && x<784 && y>=16 && y<(emergency_active?152:64);
 border=x==16 || x==783 || y==16 || y==(emergency_active?151:63);
 if(!emergency_active)begin
 if(x>=32 && x<768 && y>=24 && y<56)begin u=x-10'd32+scroll_offset;wrapped=u>=MESSAGE_WIDTH?u-MESSAGE_WIDTH:u;
 index=wrapped[10:5];v=y-24;text_here=1;end end
 else begin
 if(x>=304 && x<496 && y>=24 && y<56)begin u=x-304;wrapped=u;index=u[10:5];v=y-24;message=1;text_here=1;end
 if(x>=240 && x<560 && y>=68 && y<100)begin u=x-240;wrapped=u;index=u[10:5];v=y-68;message=2;text_here=1;end
 if(x>=240 && x<560 && y>=108 && y<140)begin u=x-240;wrapped=u;index=u[10:5];v=y-108;message=3;text_here=1;end
 end end
 reg [5:0] code1;reg [4:0] row1,col1,col2;reg text1,text2,panel1,panel2,border1,border2;
 reg [23:0] rgb1,rgb2,bg1,bg2,fg1,fg2,edge1,edge2;reg [31:0] glyph2;
 always @(posedge clk)begin
 if(rst)begin code1<=0;row1<=0;col1<=0;col2<=0;text1<=0;text2<=0;panel1<=0;panel2<=0;border1<=0;border2<=0;
 rgb1<=0;rgb2<=0;bg1<=0;bg2<=0;fg1<=0;fg2<=0;edge1<=0;edge2<=0;glyph2<=0;result<=0;end
 else begin
 code1<=text_code(message,index);row1<=v[4:0];col1<=wrapped[4:0];text1<=text_here;panel1<=panel;border1<=border;rgb1<=rgb;
 bg1<=emergency_active?24'ha01624:24'h122440;fg1<=emergency_active && y<56?24'hffe090:24'hffffff;
 edge1<=emergency_active?(blink_count<30?24'hffe090:24'hff6070):24'h487ca0;
 glyph2<=font_row({code1,row1});col2<=col1;text2<=text1;panel2<=panel1;border2<=border1;rgb2<=rgb1;bg2<=bg1;fg2<=fg1;edge2<=edge1;
 result<=panel2?((text2 && glyph2[31-col2])?fg2:(border2?edge2:bg2)):rgb2;
 end end
endmodule
