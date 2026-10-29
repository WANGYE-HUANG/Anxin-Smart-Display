// Command-level functional model only; not a vendor timing/electrical model.
module sdram_model(input wire clk,ras,cas,we,input wire [10:0] ma,
 input wire [1:0] ba,inout wire [31:0] dq);
 reg [31:0] mem[0:2097151];reg [10:0] row[0:3];reg [3:0] opened=0;
 reg drive=0;reg [31:0] q;assign dq=drive?q:32'bz;
 integer latency=0,remain=0,refs=0,writes=0,reads=0,cycles=0,last_ref=0,max_interval=0;
 reg [20:0] pending_addr,active_addr;
 reg configured=0;
 always @(negedge clk)begin
 cycles=cycles+1;drive<=0;
 if(configured && cycles-last_ref>312)$fatal(1,"refresh deadline exceeded %d",cycles-last_ref);
 if(remain>0)begin q<=mem[active_addr];drive<=1;active_addr=active_addr+1;remain=remain-1;end
 if(latency>0)begin
 latency=latency-1;
 if(latency==0)begin q<=mem[pending_addr];drive<=1;active_addr=pending_addr+1;remain=7;end
 end
 case({ras,cas,we})
 3'b000:begin if(ma!=11'h233)$fatal(1,"unexpected mode %h",ma);configured=1;last_ref=cycles;end
 3'b011:begin row[ba]<=ma;opened[ba]<=1;end
 3'b010:begin if(remain>0 || latency>0)$fatal(1,"precharge during burst");opened<=0;end
 3'b001:begin
 if(opened!=0)$fatal(1,"refresh with open bank");refs=refs+1;
 if(configured && cycles-last_ref>max_interval)max_interval=cycles-last_ref;last_ref=cycles;
 end
 3'b100:begin
 if(!opened[ba])$fatal(1,"write without active row");
 mem[{row[ba],ba,ma[7:0]}]<=dq;writes=writes+1;
 end
 3'b101:begin
 if(!opened[ba] || ma[2:0]!=0)$fatal(1,"bad READ alignment/active");
 pending_addr={row[ba],ba,ma[7:0]};latency=3;reads=reads+1;
 end
 endcase
 end
endmodule

