// Unsigned restoring divider; fixed 32-cycle latency, no combinational divide.
module scale_div(input wire clk,rst,start,input wire [31:0] numerator,denominator,
 output reg done,output reg [31:0] quotient);
 reg [31:0] dividend,divisor,q;reg [32:0] remainder;reg [5:0] count;reg busy;
 wire [32:0] shifted={remainder[31:0],dividend[31]};
 wire subtract=shifted>={1'b0,divisor};
 always @(posedge clk)begin
 done<=0;
 if(rst)begin busy<=0;count<=0;dividend<=0;divisor<=1;q<=0;remainder<=0;quotient<=0;end
 else if(start && !busy)begin busy<=1;count<=0;dividend<=numerator;divisor<=denominator;remainder<=0;q<=0;end
 else if(busy)begin
 dividend<=dividend<<1;remainder<=subtract?shifted-{1'b0,divisor}:shifted;q<={q[30:0],subtract};
 if(count==31)begin busy<=0;done<=1;quotient<={q[30:0],subtract};end else count<=count+1'b1;
 end
 end
endmodule

// Original BMP pixels go to a reusable 4MiB SDRAM workspace at word1048576.
// Holds one stable bundled request across the tested 50MHz->25MHz toggle CDC.
module generic_bmp_loader(input wire clk50,rst50,byte_valid,input wire [7:0] octet,
 input wire pixel_file,input wire [10:0] pixel_width,pixel_height,
 input wire pix,rst_pix,mem_busy,input wire scaling,
 output reg wr_en,output reg [20:0] wr_addr,output reg [31:0] wr_data,
 output reg start_scale,output reg source_file,output reg [10:0] source_width,source_height,
 output reg overflow);
 reg seen_file,started;reg [10:0] width,height;reg [1:0] phase;
 reg [7:0] blue,green;reg [10:0] col;reg [20:0] row_base,held_addr;reg [31:0] held_data;
 reg toggle,held_last;reg [1:0] sync;reg seen,pending,pending_last;
 reg [20:0] pending_addr;reg [31:0] pending_data;
 always @(posedge clk50)begin
 if(rst50)begin seen_file<=0;started<=0;width<=0;height<=0;phase<=0;blue<=0;green<=0;
 col<=0;row_base<=0;held_addr<=0;held_data<=0;toggle<=0;held_last<=0;end
 else if(byte_valid)case(phase)
 0:begin blue<=octet;phase<=1;
 if(!started || pixel_file!=seen_file)begin
 started<=1;seen_file<=pixel_file;width<=pixel_width;height<=pixel_height;col<=0;
 row_base<=21'd1048576+(({10'd0,pixel_height}-21'd1)<<10);
 end end
 1:begin green<=octet;phase<=2;end
 2:begin
 held_data<={8'd0,octet,green,blue};held_addr<=row_base+col;toggle<=!toggle;phase<=0;
 held_last<=row_base==1048576 && col==width-1;
 if(col==width-1)begin col<=0;row_base<=row_base-1024;end else col<=col+1'b1;
 end
 default:phase<=0;endcase
 end
 always @(posedge pix)begin
 wr_en<=0;start_scale<=0;
 if(rst_pix)begin sync<=0;seen<=0;pending<=0;pending_last<=0;pending_addr<=0;pending_data<=0;
 wr_addr<=0;wr_data<=0;overflow<=0;source_file<=0;source_width<=0;source_height<=0;end
 else begin
 sync<={sync[0],toggle};
 if(sync[1]!=seen)begin
 seen<=sync[1];if(pending || scaling)overflow<=1;
 pending<=1;pending_addr<=held_addr;pending_data<=held_data;pending_last<=held_last;
 end
 if(pending && !scaling && !mem_busy && !wr_en)begin
 wr_en<=1;wr_addr<=pending_addr;wr_data<=pending_data;pending<=0;
 if(pending_last)begin start_scale<=1;source_file<=seen_file;source_width<=width;source_height<=height;end
 end
 end
 end
endmodule

// Load-time aspect-fit bilinear scaler; renderer only scans final800x600 buffers.
// Source workspace is disjoint from both destination pages. Full frame, including bars,
// is written before publishing completion. No reads/writes overlap playback.
module frame_scaler(input wire clk,rst,start,input wire source_file,input wire [10:0] source_width,source_height,
 input wire mem_busy,rd_valid,input wire [31:0] rd_data,
 output reg active,rd_en,wr_en,output reg [20:0] rd_addr,wr_addr,output reg [31:0] wr_data,
 output reg done_valid,done_file,complete,
 output reg [10:0] width0,height0,width1,height1,
 output reg [9:0] fitw0,fith0,fitw1,fith1);
 reg [5:0] state;reg file_id;reg [10:0] w,h;
 reg [9:0] dw,dh,ox,oy,left_edge,top_edge;
 reg [30:0] xstep,ystep,ax,ay;
 reg [9:0] sy0,sy1;reg [9:0] sx0,sx1,sample_addr;
 reg [7:0] fx,fy;
 reg [23:0] a,b,c,d;reg [17:0] hr0,hg0,hb0,hr1,hg1,hb1;
 reg div_start;reg [31:0] numerator,denominator;wire div_done;wire [31:0] quotient;
 reg wide;reg row_bank;reg [10:0] fill_index;reg [2:0] chunk,last_chunk;reg [6:0] within_chunk;
 reg [20:0] destination;
 wire content_y=oy>=top_edge && oy<top_edge+dh;
 wire content_x=ox>=left_edge && ox<left_edge+dw;
 wire [23:0] top_pixel,bottom_pixel;
 wire row_we=state==14 && rd_valid;
 scale_row top_row(clk,row_we && !row_bank,fill_index[9:0],sample_addr,rd_data[23:0],top_pixel);
 scale_row bottom_row(clk,row_we && row_bank,fill_index[9:0],sample_addr,rd_data[23:0],bottom_pixel);
 scale_div divider(clk,rst,div_start,numerator,denominator,div_done,quotient);
 function [17:0] horizontal;input [7:0] p0,p1,weight;reg signed [8:0] delta;
 reg signed [17:0] product;begin delta=$signed({1'b0,p1})-$signed({1'b0,p0});
 product=delta*$signed({1'b0,weight});horizontal=$signed({2'b00,p0,8'd0})+product;end endfunction
 function [7:0] vertical;input [17:0] p0,p1;input [7:0] weight;reg signed [18:0] delta;
 reg signed [27:0] product,total;begin
 delta=$signed({1'b0,p1})-$signed({1'b0,p0});product=delta*$signed({1'b0,weight});
 total=$signed({2'b00,p0,8'd0})+product+28'sd32768;vertical=total[23:16];end endfunction
 always @(posedge clk)begin
 rd_en<=0;wr_en<=0;div_start<=0;
 if(rst)begin
 state<=0;active<=0;done_valid<=0;done_file<=0;complete<=0;file_id<=0;w<=0;h<=0;dw<=0;dh<=0;
 ox<=0;oy<=0;left_edge<=0;top_edge<=0;xstep<=0;ystep<=0;ax<=0;ay<=0;sy0<=0;sy1<=0;
 sx0<=0;sx1<=0;sample_addr<=0;fx<=0;fy<=0;a<=0;b<=0;c<=0;d<=0;
 hr0<=0;hg0<=0;hb0<=0;hr1<=0;hg1<=0;hb1<=0;wide<=0;row_bank<=0;fill_index<=0;chunk<=0;last_chunk<=0;within_chunk<=0;
 numerator<=0;denominator<=1;rd_addr<=0;wr_addr<=0;wr_data<=0;destination<=0;
 width0<=0;height0<=0;width1<=0;height1<=0;fitw0<=0;fith0<=0;fitw1<=0;fith1<=0;
 end else case(state)
 0:if(start)begin active<=1;file_id<=source_file;w<=source_width;h<=source_height;
 last_chunk<=(source_width-11'd1)>>7;destination<=source_file?21'd524288:21'd0;
 state<=1;end
 1:if(!mem_busy)state<=2; // Wait for the final source write to commit.
 2:begin
 if(({21'd0,w}*32'd600)>=({21'd0,h}*32'd800))begin
 wide<=1;dw<=800;numerator<={21'd0,h}*32'd800;denominator<={21'd0,w};
 end else begin wide<=0;dh<=600;numerator<={21'd0,w}*32'd600;denominator<={21'd0,h};end
 state<=3;end
 3:begin div_start<=1;state<=4;end
 4:if(div_done)begin
 if(wide)begin dh<=quotient==0?10'd1:quotient[9:0];left_edge<=0;top_edge<=(600-(quotient==0?1:quotient))>>1;end
 else begin dw<=quotient==0?10'd1:quotient[9:0];top_edge<=0;left_edge<=(800-(quotient==0?1:quotient))>>1;end
 state<=5;end
 5:begin numerator<=({21'd0,w}-1)<<20;denominator<=dw>1?dw-1:1;state<=6;end
 6:begin div_start<=1;state<=7;end
 7:if(div_done)begin xstep<=quotient[30:0];state<=8;end
 8:begin numerator<=({21'd0,h}-1)<<20;denominator<=dh>1?dh-1:1;state<=9;end
 9:begin div_start<=1;state<=10;end
 10:if(div_done)begin ystep<=quotient[30:0];ox<=0;oy<=0;ax<=0;ay<=0;state<=11;end
 11:begin
 ax<=0;
 if(content_y)begin
 sy0<=oy==top_edge+dh-1?h-1:ay[29:20];
 sy1<=oy==top_edge+dh-1 || ay[29:20]>=h-1?h-1:ay[29:20]+1'b1;
 fy<=oy==top_edge+dh-1?8'd0:ay[19:12];state<=12;
 end else state<=16;
 end
 12:begin
 row_bank<=0;fill_index<=0;chunk<=0;within_chunk<=0;
 rd_addr<=21'd1048576+({11'd0,sy0}<<10);state<=13;
 end
 13:if(!mem_busy && !rd_en)begin rd_en<=1;state<=14;end
 14:if(rd_valid)begin
 fill_index<=fill_index+1'b1;within_chunk<=within_chunk+1'b1;
 if(within_chunk==127)begin
 within_chunk<=0;
 if(chunk==last_chunk)begin
 if(!row_bank)begin row_bank<=1;fill_index<=0;chunk<=0;rd_addr<=21'd1048576+({11'd0,sy1}<<10);state<=13;end
 else state<=16;
 end else begin chunk<=chunk+1'b1;rd_addr<=rd_addr+128;state<=13;end
 end
 end
 16:if(content_y && content_x)begin
 sx0<=ox==left_edge+dw-1?w-1:ax[29:20];
 sx1<=ox==left_edge+dw-1 || ax[29:20]>=w-1?w-1:ax[29:20]+1'b1;
 fx<=ox==left_edge+dw-1?8'd0:ax[19:12];state<=17;
 end else begin wr_data<=0;state<=25;end
 17:begin sample_addr<=sx0;state<=18;end
 18:state<=19;
 19:begin a<=top_pixel;c<=bottom_pixel;sample_addr<=sx1;state<=20;end
 20:state<=21;
 21:begin b<=top_pixel;d<=bottom_pixel;state<=22;end
 22:begin
 hr0<=horizontal(a[23:16],b[23:16],fx);hg0<=horizontal(a[15:8],b[15:8],fx);hb0<=horizontal(a[7:0],b[7:0],fx);
 hr1<=horizontal(c[23:16],d[23:16],fx);hg1<=horizontal(c[15:8],d[15:8],fx);hb1<=horizontal(c[7:0],d[7:0],fx);state<=23;end
 23:begin wr_data<={8'd0,vertical(hr0,hr1,fy),vertical(hg0,hg1,fy),vertical(hb0,hb1,fy)};state<=25;end
 25:if(!mem_busy && !wr_en)begin wr_en<=1;wr_addr<=destination;state<=26;end
 26:if(mem_busy)state<=27;
 27:if(!mem_busy)begin
 destination<=destination+1'b1;
 if(content_x && content_y)ax<=ax+xstep;
 if(ox==799)begin
 ox<=0;if(content_y)ay<=ay+ystep;
 if(oy==599)state<=28;else begin oy<=oy+1'b1;state<=11;end
 end else begin ox<=ox+1'b1;state<=16;end
 end
 28:begin
 done_valid<=1;done_file<=file_id;active<=0;
 if(file_id)begin complete<=1;width1<=w;height1<=h;fitw1<=dw;fith1<=dh;end
 else begin width0<=w;height0<=h;fitw0<=dw;fith0<=dh;end
 state<=0;end
 default:state<=0;
 endcase
 end
endmodule

module scale_row(input wire clk,we,input wire [9:0] wa,ra,input wire [23:0] wd,output reg [23:0] q);
 reg [23:0] mem[0:1023]; /* fehdl force_ram=1, ram_style="bram" */
 always @(posedge clk)begin if(we)mem[wa]<=wd;q<=mem[ra];end
endmodule

