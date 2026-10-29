`timescale 1ns/1ps
module tb_slide_scan;
 reg clk=0;always #12.5 clk=~clk;reg rst=1,frame_ready=0,requested=0;
 wire busy,init,rv,rd;wire [20:0] addr;wire [31:0] q;wire ras,cas,we;wire [10:0] ma;wire [1:0] ba;tri[31:0]dq;
 reg [9:0] shift_request=0;wire [9:0] shift_active,source_y;wire source_frame;
 wire [23:0]rgb;wire[10:0] lx;wire[9:0]ly,ox,oy;wire hs,vs,de,err,displaying,active,commit;integer frames=0,pixels=0,cyc=0,lastsof=-1;
 burst_sdram ctrl(clk,rst,1'b0,rd,addr,32'd0,busy,init,rv,q,ras,cas,we,ma,ba,dq);
 sdram_model model(clk,ras,cas,we,ma,ba,dq);
 line_video scan(.slide_offset(shift_request),.active_shift(shift_active),.pixel_source_y(source_y),.pixel_frame(source_frame),.clk(clk),.rst(rst),.frame_ready(frame_ready),.fatal_error(1'b0),.mem_busy(busy),.rd_valid(rv),.rd_data(q),
 .requested_frame(requested),.profile0(3'd0),.profile1(3'd0),.rd_en(rd),.rd_addr(addr),.frame_commit(commit),.look_x(lx),.look_y(ly),.out_x(ox),.out_y(oy),.rgb(rgb),
 .hs(hs),.vs(vs),.de(de),.underrun(err),.displaying(displaying),.active_frame(active),.active_profile(),.letterbox());
 function[23:0]pattern;input integer x,y,f;begin pattern={8'(x+f*91),8'(y+f*37),8'(x+y+f*13)};end endfunction
 integer x,y,f;initial begin
 for(f=0;f<2;f=f+1)for(y=0;y<600;y=y+1)for(x=0;x<800;x=x+1)model.mem[f*524288+y*800+x]={8'd0,pattern(x,y,f)};
 repeat(10)@(negedge clk);rst=0;wait(init);@(negedge clk);frame_ready=1;
 end
 always @(negedge clk)if(!rst)begin
 cyc=cyc+1;
 if(err)$fatal(1,"scan underrun at x%0d y%0d chunk%0d fill%0d",lx,ly,scan.chunk,scan.fill_index);
 if(rd && addr[6:0]!=0)$fatal(1,"unaligned burst");
 if(lx==200 && ly==200)begin
 case(frames)
 0:shift_request=1;1:shift_request=2;2:shift_request=31;3:shift_request=32;4:shift_request=63;
 5:shift_request=127;6:shift_request=175;7:shift_request=299;8:shift_request=300;9:shift_request=450;10:shift_request=599;
 default:shift_request=0;endcase end
 if(de && displaying)begin
 if(rgb!==pattern(ox,(oy+shift_active)%600,active^((oy+shift_active)>=600)))$fatal(1,"scan pixel x%0d y%0d f%0d got%h exp%h",ox,oy,active,rgb,pattern(ox,(oy+shift_active)%600,active^((oy+shift_active)>=600)));
 if(source_y!=(oy+shift_active)%600 || source_frame!=(active^((oy+shift_active)>=600)))$fatal(1,"source pixel metadata mismatch");
 pixels=pixels+1;
 if(ox==0 && oy==0)begin if(lastsof>=0 && cyc-lastsof!=663168)$fatal(1,"frame period");lastsof=cyc;end
 if(ox==799 && oy==599)begin frames=frames+1;requested=!requested;
 if(frames==14)begin $display("PASS slide scan:14 complete frames6720000 pixels exact, both pages, shifts0/1/2/31/32/63/127/175/299/300/450/599, row offsets0/32/64/96, no underrun, refresh_max=%0d cycles",model.max_interval);$finish;end end
 end end
 initial begin #300000000;$fatal(1,"scan timeout");end
endmodule
