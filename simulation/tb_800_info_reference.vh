reg [31:0] golden_font[0:2047];reg [5:0] golden_code[0:255];
function [23:0] info_expected;
 input integer px,py,offset;input emergency,blink;input [23:0] base;
 integer u,v,msg,index,glyph,col;reg inside_text,ink;
 begin
 info_expected=base;u=0;v=0;msg=0;inside_text=0;
 if(!emergency && px>=32 && px<768 && py>=24 && py<56)begin
 u=(px-32+offset)%1248;v=py-24;inside_text=1;end
 if(emergency)begin
 if(px>=304 && px<496 && py>=24 && py<56)begin u=px-304;v=py-24;msg=1;inside_text=1;end
 if(px>=240 && px<560 && py>=68 && py<100)begin u=px-240;v=py-68;msg=2;inside_text=1;end
 if(px>=240 && px<560 && py>=108 && py<140)begin u=px-240;v=py-108;msg=3;inside_text=1;end
 end
 index=u/32;col=u%32;glyph=golden_code[msg*64+index];
 ink=inside_text && golden_font[glyph*32+v][31-col];
 if(px>=16 && px<784 && py>=16 && py<(emergency?152:64))begin
 info_expected=emergency?24'ha01624:24'h122440;
 if(px==16 || px==783 || py==16 || py==(emergency?151:63))info_expected=emergency?(blink?24'hffe090:24'hff6070):24'h487ca0;
 if(ink)info_expected=emergency && py<56?24'hffe090:24'hffffff;
 end
 end
endfunction
