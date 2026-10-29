// 40MHz, SDRAM falling-edge clock; CAS3, BL8 reads, single writes.
// Read requests must be 128-word aligned. Sixteen pipelined BL8 commands.
module burst_sdram(input wire clk,rst,wr_en,rd_en,input wire [20:0] addr,
 input wire [31:0] wr_data,output wire busy,output reg init_done,
 output reg rd_valid,output reg [31:0] rd_data,
 output reg ras_n,cas_n,we_n,output reg [10:0] ma,
 output reg [1:0] ba,inout wire [31:0] dq);
 reg [4:0] state;reg [15:0] timer;reg [8:0] refresh_timer;
 reg [3:0] refresh_count;reg [20:0] saved_addr;reg [31:0] saved_data;
 reg is_write,drive;
 assign dq=drive?saved_data:32'bz;
 // Refresh early enough that an entire 128-word read fits before 7.8us.
 assign busy=state!=8 || refresh_timer>=150;
 always @(posedge clk)begin
 ras_n<=1;cas_n<=1;we_n<=1;rd_valid<=0;
 if(rst)begin
 state<=0;timer<=0;refresh_timer<=0;refresh_count<=0;init_done<=0;
 drive<=0;rd_data<=0;saved_addr<=0;saved_data<=0;ma<=0;ba<=0;is_write<=0;
 end else begin
 if(init_done && refresh_timer<511)refresh_timer<=refresh_timer+1'b1;
 case(state)
 0:if(timer==12000)begin timer<=0;state<=1;end else timer<=timer+1'b1;
 1:begin ras_n<=0;we_n<=0;ma<=11'h400;timer<=0;state<=2;end
 2:if(timer==3)begin timer<=0;state<=3;end else timer<=timer+1'b1;
 3:begin ras_n<=0;cas_n<=0;timer<=0;state<=4;end
 4:if(timer==5)begin timer<=0;if(refresh_count==7)state<=5;
 else begin refresh_count<=refresh_count+1'b1;state<=3;end end else timer<=timer+1'b1;
 5:begin ras_n<=0;cas_n<=0;we_n<=0;ma<=11'h233;ba<=0;timer<=0;state<=6;end
 6:if(timer==3)begin init_done<=1;refresh_timer<=0;state<=8;end else timer<=timer+1'b1;
 // Requests from the preceding cycle win arbitration, as with the tested BL1 controller.
 8:if(wr_en || rd_en)begin saved_addr<=addr;saved_data<=wr_data;is_write<=wr_en;state<=9;end
 else if(refresh_timer>=150)begin ras_n<=0;cas_n<=0;timer<=0;state<=7;refresh_timer<=0;end
 7:if(timer==5)state<=8;else timer<=timer+1'b1;
 9:begin ras_n<=0;ba<=saved_addr[9:8];ma<=saved_addr[20:10];timer<=0;state<=10;end
 10:if(timer==1)begin state<=11;timer<=0;end else timer<=timer+1'b1;
 11:begin cas_n<=0;we_n<=!is_write;ba<=saved_addr[9:8];
 ma<={3'b000,saved_addr[7:0]};drive<=is_write;timer<=0;state<=is_write?12:13;end
 12:begin drive<=0;if(timer==3)begin state<=15;timer<=0;end else timer<=timer+1'b1;end
 13:begin
 // t=8,16,...120 issue the next BL8; first capture at t=4.
 if(timer[2:0]==7 && timer<120)begin
 cas_n<=0;ma<={3'b000,(saved_addr[7:0]+timer[7:0]+8'd1)};ba<=saved_addr[9:8];end
 if(timer>=3)begin rd_valid<=1;rd_data<=dq;end
 if(timer==130)begin state<=14;timer<=0;end else timer<=timer+1'b1;
 end
 14:begin timer<=0;state<=15;end
 15:begin ras_n<=0;we_n<=0;ma<=11'h400;timer<=0;state<=16;end
 16:if(timer==1)begin timer<=0;state<=8;end else timer<=timer+1'b1;
 default:state<=0;
 endcase
 end
 end
endmodule

