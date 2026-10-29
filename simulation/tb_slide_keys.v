`timescale 1ns/1ps
module tb_slide_keys;
 reg clk=0,rst=1;always #20 clk=~clk;reg [15:0] pressed=0;tri [3:0] rows;reg [3:0] cols;
 wire fx;integer fx_count=0;always @(posedge clk)if(fx)fx_count=fx_count+1;
 wire kt,k0,k1,k2,diag,prev,nextp,autop,bd,bu,cd,cu,df;wire [12:0] events={df,cu,cd,bu,bd,kt,autop,nextp,prev,1'b0,k2,k1,k0};
 integer r,c,i,j,count[0:12];
 matrix_keys #(.SCAN_TICKS(10),.DEBOUNCE_FRAMES(3)) dut(.clk(clk),.rst(rst),.col(cols),.row(rows),
 .next_press(k0),.mode_press(k1),.emergency_press(k2),.diagnostic_hold(diag),.previous_slide_press(prev),.next_slide_press(nextp),.auto_press(autop),
 .brightness_down(bd),.brightness_up(bu),.contrast_down(cd),.contrast_up(cu),.defaults_press(df),.tone_press(kt),.effect_press(fx));
 always @*begin cols=15;for(r=0;r<4;r=r+1)for(c=0;c<4;c=c+1)if(rows[r]===1'b0 && pressed[(3-r)*4+c])cols[c]=0;end
 always @(posedge clk)for(j=0;j<13;j=j+1)if(events[j])count[j]=count[j]+1;
 task ticks;input integer n;begin repeat(n)@(negedge clk);end endtask
 initial begin
 for(i=0;i<13;i=i+1)count[i]=0;
 ticks(10);rst=0;ticks(300);
 for(i=0;i<13;i=i+1)begin
 pressed=16'd1<<i;ticks(1200);
 if(i==3)begin if(!diag)$fatal(1,"diagnostic KEY3");end
 else if(count[i]!=1)$fatal(1,"KEY%d map/held one shot",i);
 pressed=0;ticks(300);
 end
 pressed=16'h0300;ticks(400);if(count[8]!=1 || count[9]!=1)$fatal(1,"two keys triggered");
 pressed=16'h0200;ticks(400);if(count[9]!=1)$fatal(1,"no-release rollover triggered");pressed=0;ticks(300);
 pressed=16'h0200;ticks(10);pressed=0;ticks(300);if(count[9]!=1)$fatal(1,"bounce");
 pressed=16'h0200;ticks(400);if(count[9]!=2)$fatal(1,"clean repress");
 pressed=0;ticks(300);pressed=16'h2000;ticks(1200);if(fx_count!=1)$fatal(1,"KEY13 held repeated");
 pressed=0;ticks(300);pressed=16'h2000;ticks(1200);if(fx_count!=2)$fatal(1,"KEY13 repress");
 pressed=0;ticks(300);pressed=16'h6000;ticks(500);if(fx_count!=2)$fatal(1,"KEY13 multi-key");
 $display("PASS: matrix KEY0..6 preserved, KEY7 tone one-shot, KEY8/9 brightness, KEY10/11 contrast, KEY12 defaults; KEY13 effect selection held-one-shot and clean repress; held one-shot, debounce, multi-key/rollover ignore, KEY3 diagnostic");$finish;
 end
endmodule
