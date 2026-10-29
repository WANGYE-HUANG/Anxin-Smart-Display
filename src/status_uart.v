module status_uart(input wire clk,input wire rst,input wire [7:0] flags,code,output wire tx);
 reg [1:0] state;reg [7:0] last_flags,last_code,saved_flags,saved_code;
 reg [3:0] character,bit_count;reg [8:0] ticks;reg [9:0] shift;
 reg first;reg [25:0] repeat_ticks;
 always @(posedge clk)if(rst || repeat_ticks==49999999)repeat_ticks<=0;else repeat_ticks<=repeat_ticks+1'b1;
 function [7:0] hex;input [3:0] n;begin hex=n<10?8'h30+n:8'h41+n-10;end endfunction
 function [7:0] message;input [3:0] n;begin case(n)
 0:message="F";1:message=hex(saved_flags[7:4]);2:message=hex(saved_flags[3:0]);
 3:message=" ";4:message="E";5:message=hex(saved_code[7:4]);6:message=hex(saved_code[3:0]);
 7:message=13;default:message=10;endcase end endfunction
 assign tx=shift[0];
 always @(posedge clk)begin
 if(rst)begin state<=0;last_flags<=0;last_code<=0;saved_flags<=0;saved_code<=0;
 character<=0;bit_count<=0;ticks<=0;shift<=10'h3ff;first<=1;end
 else case(state)
 0:if(first || flags!=last_flags || code!=last_code || repeat_ticks==49999999)begin
 first<=0;saved_flags<=flags;saved_code<=code;last_flags<=flags;last_code<=code;
 character<=0;state<=1;end
 1:begin shift<={1'b1,message(character),1'b0};bit_count<=0;ticks<=0;state<=2;end
 2:if(ticks==433)begin
 ticks<=0;shift<={1'b1,shift[9:1]};
 if(bit_count==9)begin if(character==8)state<=0;else begin character<=character+1'b1;state<=1;end end
 else bit_count<=bit_count+1'b1;
 end else ticks<=ticks+1'b1;
 default:state<=0;
 endcase
 end
endmodule
