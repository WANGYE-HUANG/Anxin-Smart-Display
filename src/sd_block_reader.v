module sd_spi_byte #(parameter FAST_HALF_DIV=7)(input wire clk,input wire rst,input wire fast,
 input wire start,input wire [7:0] tx,input wire miso,
 output reg sck,output reg mosi,output reg busy,output reg done,output reg [7:0] rx);
 reg [7:0] divcnt,shift;reg [2:0] bitidx;
 wire tick=divcnt==(fast?FAST_HALF_DIV:8'd124);
 always @(posedge clk) begin
 done<=0;
 if(rst) begin sck<=0;mosi<=1;busy<=0;rx<=0;divcnt<=0;shift<=0;bitidx<=0;end
 else if(!busy) begin
 sck<=0;divcnt<=0;
 if(start) begin busy<=1;shift<=tx;mosi<=tx[7];bitidx<=7;rx<=0;end
 end else if(tick) begin
 divcnt<=0;
 if(!sck) begin sck<=1;rx<={rx[6:0],miso};end
 else begin
 sck<=0;
 if(bitidx==0) begin busy<=0;done<=1;mosi<=1;end
 else begin bitidx<=bitidx-1'b1;shift<={shift[6:0],1'b1};mosi<=shift[6];end
 end
 end else divcnt<=divcnt+1'b1;
 end
endmodule
module sd_block_reader #(parameter POWER_WAIT=500000)(input wire clk,input wire rst,input wire miso,
 input wire req,input wire [31:0] lba,output wire initialized_out,output wire error_out,
 output reg done,output wire data_valid,output wire [8:0] data_index_out,output wire [7:0] data_out,
 output wire sck,output wire mosi,output reg cs,
 output wire [6:0] status,output reg [7:0] debug_error);
 localparam IDLE=23,POSTREAD=24,POWER=0,CLOCKS=1,CLOCKDONE=2,CMDSTART=3,CMDSEND=4,
 CMDDONE=5,R1SEND=6,R1CHECK=7,RESPONSE=8,EXTSEND=9,EXTCHECK=10,
 EXTDONE=11,TOKSEND=12,TOKCHECK=13,DATA=14,DATADONE=15,CRC1=16,
 CRC1DONE=17,CRC2=18,CRC2DONE=19,FINISH=20,ERROR=21,BWAIT=22;
 reg [4:0] state,return_state;
 reg start,fast;reg [7:0] tx;wire [7:0] rx;wire byte_busy,byte_done;
 sd_spi_byte spi(.clk(clk),.rst(rst),.fast(fast),.start(start),.tx(tx),.miso(miso),
 .sck(sck),.mosi(mosi),.busy(byte_busy),.done(byte_done),.rx(rx));
 reg [27:0] watchdog;reg [21:0] power_count;
 reg [3:0] clocks_count;reg [5:0] command;reg [31:0] argument;
 reg [7:0] command_crc,r1;reg [2:0] cmdpos,extpos;reg [31:0] extended;
 reg [10:0] attempts;reg [15:0] pollcount;reg [8:0] data_index;
 reg [15:0] crc;reg [7:0] crc_hi,sign_lo,sign_hi;
 reg initialized,read_done,signature_ok,crc_ok,failed,timed_out,passed;
 assign initialized_out=initialized;
 assign error_out=failed;
 assign data_valid=(state==DATADONE);
 assign data_index_out=data_index;
 assign data_out=rx;
 assign status={timed_out,failed,crc_ok,signature_ok,read_done,initialized,passed};
 reg [4:0] previous_state;reg [5:0] previous_command;
 always @(posedge clk)begin
 if(rst)begin debug_error<=0;previous_state<=0;previous_command<=0;end
 else begin
 previous_state<=state;previous_command<=command;
 if(failed && debug_error==0)begin
 case(previous_state)
 R1CHECK:debug_error<=8'h18;
 RESPONSE:case(previous_command)
 0:debug_error<=8'h10;8:debug_error<=8'h11;55:debug_error<=8'h13;
 41:debug_error<=8'h14;58:debug_error<=8'h15;17:debug_error<=8'h17;
 default:debug_error<=8'h1d;endcase
 EXTDONE:debug_error<=previous_command==8?8'h12:8'h16;
 TOKCHECK:debug_error<=rx==8'hff ? 8'h1a : 8'h19;
 CRC2DONE:debug_error<=8'h1b;
 default:debug_error<=timed_out?8'h1c:8'h1d;
 endcase
 end
 end
 end
 function [15:0] crc16;
 input [15:0] previous;input [7:0] octet;reg [15:0] c;integer k;
 begin c=previous^{octet,8'b0};for(k=0;k<8;k=k+1)c=c[15]?(c<<1)^16'h1021:(c<<1);crc16=c;end
 endfunction
 task transfer;
 input [7:0] value;input [4:0] next_state;
 begin tx<=value;start<=1;return_state<=next_state;state<=BWAIT;end
 endtask
 task issue;
 input [5:0] cmd;input [31:0] arg;input [7:0] check;
 begin command<=cmd;argument<=arg;command_crc<=check;state<=CMDSTART;end
 endtask
 always @(posedge clk) begin
 start<=0;done<=0;
 if(rst) begin
 done<=0;state<=POWER;return_state<=POWER;cs<=1;fast<=0;start<=0;tx<=8'hff;
 watchdog<=0;power_count<=0;clocks_count<=0;command<=0;argument<=0;
 command_crc<=8'h95;r1<=8'hff;cmdpos<=0;extpos<=0;extended<=0;
 attempts<=0;pollcount<=0;data_index<=0;crc<=0;crc_hi<=0;sign_lo<=0;sign_hi<=0;
 initialized<=0;read_done<=0;signature_ok<=0;crc_ok<=0;failed<=0;timed_out<=0;passed<=0;
 end else if(state!=FINISH && state!=ERROR && state!=IDLE && watchdog==28'd249999999) begin
 failed<=1;timed_out<=1;cs<=1;state<=ERROR;
 end else begin
 if(state!=FINISH && state!=ERROR && state!=IDLE)watchdog<=watchdog+1'b1;
 case(state)
 POWER:if(power_count==POWER_WAIT)state<=CLOCKS;else power_count<=power_count+1'b1;
 CLOCKS:transfer(8'hff,CLOCKDONE);
 CLOCKDONE:if(clocks_count==9)begin cs<=0;issue(0,0,8'h95);end
 else begin clocks_count<=clocks_count+1'b1;state<=CLOCKS;end
 CMDSTART:begin cmdpos<=0;pollcount<=0;transfer(8'hff,CMDSEND);end
 CMDSEND:case(cmdpos)
 0:transfer({2'b01,command},CMDDONE);
 1:transfer(argument[31:24],CMDDONE);
 2:transfer(argument[23:16],CMDDONE);
 3:transfer(argument[15:8],CMDDONE);
 4:transfer(argument[7:0],CMDDONE);
 5:transfer(command_crc,CMDDONE);
 default:begin failed<=1;state<=ERROR;end
 endcase
 CMDDONE:if(cmdpos==5)state<=R1SEND;else begin cmdpos<=cmdpos+1'b1;state<=CMDSEND;end
 R1SEND:transfer(8'hff,R1CHECK);
 R1CHECK:if(!rx[7])begin r1<=rx;state<=RESPONSE;end
 else if(pollcount==255)begin failed<=1;timed_out<=1;state<=ERROR;end
 else begin pollcount<=pollcount+1'b1;state<=R1SEND;end
 RESPONSE:case(command)
 0:if(r1==1)issue(8,32'h1aa,8'h87);else begin failed<=1;state<=ERROR;end
 8,58:if(r1==(command==8?1:0))begin extpos<=0;extended<=0;state<=EXTSEND;end
 else begin failed<=1;state<=ERROR;end
 55:if(r1==0 || r1==1)issue(41,32'h40000000,8'hff);else begin failed<=1;state<=ERROR;end
 41:if(r1==0)issue(58,0,8'hff);
 else if(r1==1 && attempts<2047)begin attempts<=attempts+1'b1;issue(55,0,8'hff);end
 else begin failed<=1;state<=ERROR;end
 17:if(r1==0)begin pollcount<=0;state<=TOKSEND;end else begin failed<=1;state<=ERROR;end
 default:begin failed<=1;state<=ERROR;end
 endcase
 EXTSEND:transfer(8'hff,EXTCHECK);
 EXTCHECK:begin extended<={extended[23:0],rx};if(extpos==3)state<=EXTDONE;
 else begin extpos<=extpos+1'b1;state<=EXTSEND;end end
 EXTDONE:if(command==8)begin
 if(extended[11:0]==12'h1aa)issue(55,0,8'hff);else begin failed<=1;state<=ERROR;end
 end else if(extended[31:30]==2'b11)begin initialized<=1;fast<=1;cs<=1;state<=IDLE;end
 else begin failed<=1;state<=ERROR;end
 TOKSEND:transfer(8'hff,TOKCHECK);
 TOKCHECK:if(rx==8'hfe)begin data_index<=0;crc<=0;state<=DATA;end
 else if(rx!=8'hff || pollcount==65535)begin failed<=1;state<=ERROR;end
 else begin pollcount<=pollcount+1'b1;state<=TOKSEND;end
 DATA:transfer(8'hff,DATADONE);
 DATADONE:begin crc<=crc16(crc,rx);
 if(data_index==510)sign_lo<=rx;if(data_index==511)sign_hi<=rx;
 if(data_index==511)begin read_done<=1;state<=CRC1;end
 else begin data_index<=data_index+1'b1;state<=DATA;end end
 CRC1:transfer(8'hff,CRC1DONE);
 CRC1DONE:begin crc_hi<=rx;state<=CRC2;end
 CRC2:transfer(8'hff,CRC2DONE);
 CRC2DONE:begin
 crc_ok<=({crc_hi,rx}==crc);
 if({crc_hi,rx}==crc)begin cs<=1;transfer(8'hff,POSTREAD);end
 else begin failed<=1;cs<=1;state<=ERROR;end
 end
 POSTREAD:begin done<=1;watchdog<=0;state<=IDLE;end
 IDLE:begin watchdog<=0;cs<=1;if(req)begin cs<=0;issue(17,lba,8'hff);end end
 BWAIT:if(byte_done)state<=return_state;
 FINISH:cs<=1;
 ERROR:cs<=1;
 default:begin failed<=1;state<=ERROR;end
 endcase
 end
 end
endmodule

