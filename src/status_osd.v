module status_osd(input wire clk,rst,slide_mode,input wire [7:0] error_code,input wire [10:0] source_width,source_height,input wire tone_mode,input wire [2:0] source_profile,input wire [9:0] x,y,input wire [23:0] rgb,input wire paused,waiting,failed,
 input wire signed [7:0] brightness,input wire [2:0] contrast_level,input wire manual_mode,active_frame,input wire [7:0] seconds,input wire [4:0] progress,output reg [23:0] result);
 function [7:0] digit;input [10:0] value;begin digit=8'd48+value;end endfunction
 function [7:0] hexchar;input [3:0] value;begin hexchar=value<10?8'd48+value:8'd65+value-10;end endfunction
 function [34:0] glyph;input [7:0] ch;begin case(ch)
8'd68:glyph=35'b11110100011000110001100011000111110;
8'd70:glyph=35'b11111100001000011110100001000010000;
8'd75:glyph=35'b10001100101010011000101001001010001;
8'd86:glyph=35'b10001100011000110001100010101000100;
8'd88:glyph=35'b10001100010101000100010101000110001;
8'd66:glyph=35'b11110100011000111110100011000111110;
8'd67:glyph=35'b01111100001000010000100001000001111;
8'd43:glyph=35'b00000001000010011111001000010000000;
8'd45:glyph=35'b00000000000000011111000000000000000;
8'd37:glyph=35'b11001110100001000100010001011110011;
8'd77:glyph=35'b10001110111010110101100011000110001;
8'd78:glyph=35'b10001110011010110011100011000110001;
8'd32:glyph=35'b00000000000000000000000000000000000;
8'd80:glyph=35'b11110100011000111110100001000010000;
8'd76:glyph=35'b10000100001000010000100001000011111;
8'd65:glyph=35'b01110100011000111111100011000110001;
8'd89:glyph=35'b10001100010101000100001000010000100;
8'd85:glyph=35'b10001100011000110001100011000101110;
8'd83:glyph=35'b01111100001000001110000010000111110;
8'd69:glyph=35'b11111100001000011110100001000011111;
8'd87:glyph=35'b10001100011000110001101011101110001;
8'd73:glyph=35'b11111001000010000100001000010011111;
8'd84:glyph=35'b11111001000010000100001000010000100;
8'd82:glyph=35'b11110100011000111110101001001010001;
8'd79:glyph=35'b01110100011000110001100011000101110;
8'd48:glyph=35'b01110100011001110101110011000101110;
8'd49:glyph=35'b00100011000010000100001000010001110;
8'd50:glyph=35'b01110100010000100010001000100011111;
8'd51:glyph=35'b11110000010000101110000010000111110;
8'd52:glyph=35'b00010001100101010010111110001000010;
8'd53:glyph=35'b11111100001000011110000010000111110;
8'd54:glyph=35'b01110100001000011110100011000101110;
8'd55:glyph=35'b11111000010001000100010000100001000;
8'd56:glyph=35'b01110100011000101110100011000101110;
8'd57:glyph=35'b01110100011000101111000010000101110;
default:glyph=0;endcase end endfunction
 wire [15:0] w_bcd,h_bcd;
 osd_bcd wconv(clk,rst,source_width,w_bcd);osd_bcd hconv(clk,rst,source_height,h_bcd);
 reg [63:0] effect_label;
 reg [95:0] source_label;reg [87:0] dimension_label;reg [87:0] parameter_label;reg [7:0] magnitude,percent;reg [47:0] label;reg [47:0] mode_label;reg [7:0] ch;reg [34:0] bits;integer col,row,index;reg ink;
 always @* begin
 label=failed?"ERROR ":waiting?"WAIT  ":paused?"PAUSE ":"PLAY  ";
 mode_label=manual_mode?"MAN   ":"AUTO  ";
 effect_label=slide_mode?"FX SLIDE":"FX FADE ";
 source_label=tone_mode?"TONE L1K R2K":"WAV 48K     ";
 dimension_label={8'd73,8'd78,8'd48+{4'd0,w_bcd[15:12]},8'd48+{4'd0,w_bcd[11:8]},8'd48+{4'd0,w_bcd[7:4]},8'd48+{4'd0,w_bcd[3:0]},8'd88,
 8'd48+{4'd0,h_bcd[15:12]},8'd48+{4'd0,h_bcd[11:8]},8'd48+{4'd0,h_bcd[7:4]},8'd48+{4'd0,h_bcd[3:0]}};
 magnitude=brightness[7]?-brightness:brightness;percent={5'd0,contrast_level}*8'd25;
 parameter_label={8'd66,brightness[7]?8'd45:8'd43,(8'd48+magnitude/8'd100),(8'd48+(magnitude/8'd10)%8'd10),(8'd48+magnitude%8'd10),
 8'd32,8'd67,(8'd48+percent/8'd100),(8'd48+(percent/8'd10)%8'd10),(8'd48+percent%8'd10),8'd37};
 ch=32;col=0;row=0;index=0;bits=0;ink=0;result=rgb;
 if(x<800 && y>=568 && y<600)begin
 result=24'h101c30;
 if(x>=16 && x<88 && y>=570 && y<584)begin
 index=(x-16)/12;ch=label >> ((5-index)*8);col=((x-16)%12)/2;row=(y-570)/2;
 bits=glyph(ch);if(col<5)ink=bits[34-row*5-col];
 end
 if(x>=120 && x<144 && y>=570 && y<584)begin
 ch=x<132?(8'd48+seconds/10):(8'd48+seconds%10);col=((x-120)%12)/2;row=(y-570)/2;
 bits=glyph(ch);if(col<5)ink=bits[34-row*5-col];
 end
 if(x>=164 && x<212 && y>=570 && y<584)begin
 index=(x-164)/12;ch=mode_label >> ((5-index)*8);col=((x-164)%12)/2;row=(y-570)/2;
 bits=glyph(ch);if(col<5)ink=bits[34-row*5-col];
 end
 if(x>=220 && x<230 && y>=570 && y<584)begin
 ch=active_frame?8'd50:8'd49;col=(x-220)/2;row=(y-570)/2;bits=glyph(ch);ink=bits[34-row*5-col];
 end
 if(x>=16 && x<148 && y>=586 && y<600)begin
 index=(x-16)/12;ch=parameter_label >> ((10-index)*8);col=((x-16)%12)/2;row=(y-586)/2;
 bits=glyph(ch);if(col<5)ink=bits[34-row*5-col];
 end
 if(x>=176 && x<308 && y>=586 && y<600)begin
 index=(x-176)/12;ch=dimension_label >> ((10-index)*8);col=((x-176)%12)/2;row=(y-586)/2;
 bits=glyph(ch);if(col<5)ink=bits[34-row*5-col];
 end
 if(x>=320 && x<464 && y>=586 && y<600)begin
 index=(x-320)/12;ch=source_label >> ((11-index)*8);col=((x-320)%12)/2;row=(y-586)/2;
 bits=glyph(ch);if(col<5)ink=bits[34-row*5-col];
 end
 if(failed && x>=492 && x<528 && y>=586 && y<600)begin
 index=(x-492)/12;ch=index==0?8'd69:index==1?hexchar(error_code[7:4]):hexchar(error_code[3:0]);
 col=((x-492)%12)/2;row=(y-586)/2;bits=glyph(ch);if(col<5)ink=bits[34-row*5-col];
 end
 if(x>=544 && x<640 && y>=586 && y<600)begin
 index=(x-544)/12;ch=effect_label >> ((7-index)*8);col=((x-544)%12)/2;row=(y-586)/2;
 bits=glyph(ch);if(col<5)ink=bits[34-row*5-col];end
 if(ink)result=failed?24'hff6868:paused?24'hffcf60:24'hffffff;
 if(x>=240 && x<624 && y>=571 && y<583)begin
 result=((x-240)/24<progress)?(paused?24'hffcf60:24'h35d6b0):24'h344359;
 if((x-240)%24==0)result=24'h101c30;
 end
 end
 end
endmodule

// Stable source dimensions converted outside the per-pixel critical path.
module osd_bcd(input wire clk,rst,input wire[10:0] value,output reg[15:0] digits);
 reg[10:0] target,shift;reg[15:0] work;reg[3:0] count;reg busy;
 reg[15:0] corrected;integer i;
 always @*begin corrected=work;for(i=0;i<4;i=i+1)if(work[i*4+:4]>=5)corrected[i*4+:4]=work[i*4+:4]+4'd3;end
 always @(posedge clk)begin
 if(rst)begin target<=0;shift<=0;work<=0;count<=0;busy<=0;digits<=0;end
 else if(value!=target)begin target<=value;shift<=value;work<=0;count<=0;busy<=1;end
 else if(busy)begin shift<=shift<<1;work<={corrected[14:0],shift[10]};
 if(count==10)begin digits<={corrected[14:0],shift[10]};busy<=0;end else count<=count+1'b1;end
 end
endmodule
