// Packed800x600 pages. Aligned 128-word reads use per-line offsets0/32/64/96.
// Seven bursts fit each cache; no 896-word SDRAM stride (which would exceed page slots).
module line_video(input wire [9:0] slide_offset,output reg [9:0] active_shift,pixel_source_y,output reg pixel_frame,input wire clk,rst,frame_ready,fatal_error,mem_busy,rd_valid,
 input wire requested_frame,input wire [2:0] profile0,profile1,input wire [31:0] rd_data,
 output reg rd_en,output reg [20:0] rd_addr,output wire frame_commit,
 output wire [10:0] look_x,output wire [9:0] look_y,output reg [9:0] out_x,out_y,output wire [23:0] rgb,
 output reg hs,vs,de,underrun,displaying,active_frame,output wire [2:0] active_profile,output wire letterbox);
 reg [10:0] x;reg [9:0] y;
 wire [10:0] source_sum={1'b0,y}+{1'b0,active_shift};
 wire source_cross=source_sum>=600;
 wire [9:0] source_y=source_cross?source_sum-11'd600:source_sum[9:0];
 wire source_frame=active_frame^source_cross;
 assign look_x=x;assign look_y=y;assign frame_commit=x==0 && y==627 && frame_ready;
 assign active_profile=0;assign letterbox=0;
 wire [23:0] even_pixel,odd_pixel;reg bank_select,pixel_good,pixel_error;
 assign rgb=pixel_good?(bank_select?odd_pixel:even_pixel):(pixel_error?24'h800000:24'h000040);
 reg even_frame,odd_frame,fill_frame;reg [9:0] even_tag,odd_tag,fill_row;reg even_valid,odd_valid;
 reg [6:0] even_offset,odd_offset,fill_offset;
 reg filling,waiting;reg [9:0] fill_index;reg [2:0] chunk;reg [6:0] within_chunk;
 wire line_ok=y[0]?(odd_valid && odd_frame==source_frame && odd_tag==y):(even_valid && even_frame==source_frame && even_tag==y);
 wire [9:0] source_x=x[9:0]+(y[0]?odd_offset:even_offset);
 wire [9:0] target_y=y==627?10'd0:y+1'b1;
 wire [9:0] target_shift=y==627?slide_offset:active_shift;
 wire [10:0] target_sum={1'b0,target_y}+{1'b0,target_shift};
 wire target_cross=target_sum>=600;
 wire [9:0] target_source_y=target_cross?target_sum-11'd600:target_sum[9:0];
 wire target_source_frame=(y==627?requested_frame:active_frame)^target_cross;
 wire [20:0] target_row=({11'd0,target_source_y}<<9)+({11'd0,target_source_y}<<8)+({11'd0,target_source_y}<<5);
 line_ram even_buffer(.clk(clk),.we(filling && waiting && rd_valid && !fill_row[0]),.wa(fill_index),.wd(rd_data[23:0]),.ra(source_x),.q(even_pixel));
 line_ram odd_buffer(.clk(clk),.we(filling && waiting && rd_valid && fill_row[0]),.wa(fill_index),.wd(rd_data[23:0]),.ra(source_x),.q(odd_pixel));
 always @(posedge clk)begin
 rd_en<=0;out_x<=x[9:0];out_y<=y;
 if(rst)begin active_shift<=0;pixel_source_y<=0;pixel_frame<=0;x<=0;y<=0;bank_select<=0;pixel_good<=0;pixel_error<=0;hs<=0;vs<=0;de<=0;
 underrun<=0;displaying<=0;active_frame<=0;even_frame<=0;odd_frame<=0;fill_frame<=0;
 even_tag<=0;odd_tag<=0;even_offset<=0;odd_offset<=0;fill_offset<=0;
 even_valid<=0;odd_valid<=0;filling<=0;waiting<=0;fill_row<=0;fill_index<=0;chunk<=0;within_chunk<=0;rd_addr<=0;end
 else begin
 if(x==1055)begin x<=0;if(y==627)y<=0;else y<=y+1'b1;end else x<=x+1'b1;
 hs<=x>=840 && x<968;vs<=y>=601 && y<605;de<=x<800 && y<600;
 pixel_source_y<=source_y;pixel_frame<=source_frame;
 bank_select<=y[0];pixel_good<=frame_ready && line_ok && x<800;pixel_error<=fatal_error;
 if(x==0 && y<600 && frame_ready)begin if(displaying && !line_ok)underrun<=1;else if(y==0 && line_ok)displaying<=1;end
 if(frame_commit)begin active_frame<=requested_frame;active_shift<=slide_offset;end
 if(x==0 && frame_ready && (y==627 || (y<599 && (displaying || (y==0 && line_ok)))))begin
 if(filling)underrun<=1;
 else begin
 filling<=1;waiting<=0;fill_index<=0;chunk<=0;within_chunk<=0;fill_row<=target_y;fill_offset<=target_row[6:0];
 fill_frame<=target_source_frame;
 rd_addr<=(target_source_frame?21'd524288:21'd0)+{target_row[20:7],7'd0};
 if(!target_y[0])even_valid<=0;else odd_valid<=0;
 end end
 if(filling && !waiting && !mem_busy && !rd_en)begin rd_en<=1;waiting<=1;end
 if(filling && waiting && rd_valid)begin
 fill_index<=fill_index+1'b1;within_chunk<=within_chunk+1'b1;
 if(within_chunk==127)begin
 waiting<=0;within_chunk<=0;chunk<=chunk+1'b1;rd_addr<=rd_addr+128;
 if(chunk==6)begin filling<=0;
 if(fill_row[0])begin odd_tag<=fill_row;odd_valid<=1;odd_frame<=fill_frame;odd_offset<=fill_offset;end
 else begin even_tag<=fill_row;even_valid<=1;even_frame<=fill_frame;even_offset<=fill_offset;end
 end end end
 end end
endmodule
module line_ram(input wire clk,we,input wire [9:0] wa,ra,input wire [23:0] wd,output reg [23:0] q);
 reg [23:0] memory[0:1023]; /* fehdl force_ram=1, ram_style="bram" */
 always @(posedge clk)begin if(we)memory[wa]<=wd;q<=memory[ra];end
endmodule

