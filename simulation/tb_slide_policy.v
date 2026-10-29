`timescale 1ns/1ps
// Integration check of the exact top-level mode/gating logic. Test forces only
// upstream plan and control inputs; real renderer mode registers remain active.
module tb_slide_policy;
 reg c50=0,pix=0;always #10 c50=~c50;always #12.5 pix=~pix;
 reg rst=1,fc=0,key=0,manual=0,tone=0,flush=0,changing=0;reg [9:0] plan=299;
 wire [3:0] rows;wire[7:0]led;
 av_slide dut(.clk(c50),.sw0_n(1'b1),.sd_miso(1'b1),.key_col(4'b1111),.key_row(rows),.led(led),.sd_clk(),.sd_mosi(),.sd_cs(),.uart_tx(),.HDMI_CLK_P(),.HDMI_D0_P(),.HDMI_D1_P(),.HDMI_D2_P());
 task frame;begin @(negedge pix);fc=1;@(negedge pix);fc=0;end endtask
 task toggle;begin @(negedge pix);key=1;@(negedge pix);key=0;end endtask
 initial begin
 force dut.pix=pix;force dut.rstpix=rst;force dut.frame_commit=fc;force dut.effect_press=key;
 force dut.manual_mode=manual;force dut.tone_active=tone;force dut.flushing=flush;force dut.source_changing=changing;force dut.planned_shift=plan;
 repeat(6)@(negedge pix);rst=0;frame;
 if(!dut.effect_display || dut.display_shift!=299)$fatal(1,"default slide plan not latched");
 toggle;if(dut.effect_pending || !dut.effect_display || dut.display_shift!=299)$fatal(1,"mode tore current frame");
 frame;if(dut.effect_display || dut.display_shift!=0)$fatal(1,"fade mode not frame atomic");
 toggle;frame;if(!dut.effect_display || dut.display_shift!=299)$fatal(1,"slide re-enable");
 manual=1;frame;if(dut.display_shift!=0)$fatal(1,"manual slide not bypassed");manual=0;frame;
 tone=1;frame;if(dut.display_shift!=0)$fatal(1,"tone slide not bypassed");tone=0;frame;
 flush=1;frame;if(dut.display_shift!=0)$fatal(1,"seek slide not bypassed");flush=0;frame;
 changing=1;frame;if(dut.display_shift!=0)$fatal(1,"source switch slide not bypassed");changing=0;frame;
 plan=175;frame;if(dut.display_shift!=175)$fatal(1,"plan update");
 $display("PASS: exact top-level KEY13 selection, frame-atomic mode, fade preservation and manual/tone/seek/source-switch bypass");$finish;end
 initial begin #100000;$fatal(1,"policy timeout");end
endmodule
