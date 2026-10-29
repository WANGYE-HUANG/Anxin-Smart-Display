// Same48kHz cadence and ACR as WAV. Crossfade via5.33ms fade-out/switch/fade-in.
// Voice is parked only while the tone source is active; FIFO contents remain intact.
module tone_audio(input wire clk,rst,toggle_press,voice_press,replay_press,paused,flushing,play_enable,
 input wire in_valid,in_acr,in_sample_played,input wire [23:0] in_left,in_right,
 output reg out_valid,out_acr,sample_played,output reg [23:0] left,right,
 output reg active_tone,source_changed,output wire block_wav,source_changing);
 reg desired_tone;reg [8:0] gain;reg [5:0] phase;
 assign block_wav=active_tone;
 assign source_changing=(active_tone!=desired_tone) || (play_enable && !paused && gain!=256);
 wire [6:0] twice={phase,1'b0};
 wire [5:0] right_phase=twice>=48?twice-48:twice;
 function signed [15:0] sine;input [5:0] index;begin case(index)
 6'd0:sine=16'sd0;
 6'd1:sine=16'sd535;
 6'd2:sine=16'sd1060;
 6'd3:sine=16'sd1567;
 6'd4:sine=16'sd2048;
 6'd5:sine=16'sd2493;
 6'd6:sine=16'sd2896;
 6'd7:sine=16'sd3250;
 6'd8:sine=16'sd3547;
 6'd9:sine=16'sd3784;
 6'd10:sine=16'sd3956;
 6'd11:sine=16'sd4061;
 6'd12:sine=16'sd4096;
 6'd13:sine=16'sd4061;
 6'd14:sine=16'sd3956;
 6'd15:sine=16'sd3784;
 6'd16:sine=16'sd3547;
 6'd17:sine=16'sd3250;
 6'd18:sine=16'sd2896;
 6'd19:sine=16'sd2493;
 6'd20:sine=16'sd2048;
 6'd21:sine=16'sd1567;
 6'd22:sine=16'sd1060;
 6'd23:sine=16'sd535;
 6'd24:sine=16'sd0;
 6'd25:sine=-16'sd535;
 6'd26:sine=-16'sd1060;
 6'd27:sine=-16'sd1567;
 6'd28:sine=-16'sd2048;
 6'd29:sine=-16'sd2493;
 6'd30:sine=-16'sd2896;
 6'd31:sine=-16'sd3250;
 6'd32:sine=-16'sd3547;
 6'd33:sine=-16'sd3784;
 6'd34:sine=-16'sd3956;
 6'd35:sine=-16'sd4061;
 6'd36:sine=-16'sd4096;
 6'd37:sine=-16'sd4061;
 6'd38:sine=-16'sd3956;
 6'd39:sine=-16'sd3784;
 6'd40:sine=-16'sd3547;
 6'd41:sine=-16'sd3250;
 6'd42:sine=-16'sd2896;
 6'd43:sine=-16'sd2493;
 6'd44:sine=-16'sd2048;
 6'd45:sine=-16'sd1567;
 6'd46:sine=-16'sd1060;
 6'd47:sine=-16'sd535;
 default:sine=0;endcase end endfunction
 function [23:0] attenuate;input signed [15:0] value;input [8:0] level;reg signed [25:0] product;reg signed [15:0] result;begin
 product=value*$signed({1'b0,level});result=product>>>8;attenuate={result,8'd0};
 end endfunction
 always @(posedge clk)begin
 out_valid<=!rst && in_valid;out_acr<=!rst && in_acr;sample_played<=0;source_changed<=0;
 if(rst)begin desired_tone<=0;active_tone<=0;gain<=256;phase<=0;left<=0;right<=0;end
 else if(replay_press || flushing)begin
 desired_tone<=0;active_tone<=0;gain<=0;phase<=0;left<=0;right<=0;source_changed<=active_tone;
 end else begin
 if(voice_press)desired_tone<=0;else if(toggle_press && play_enable)desired_tone<=!desired_tone;
 if(in_valid)begin
 left<=!play_enable?24'd0:attenuate(active_tone?sine(phase):$signed(in_left[23:8]),gain);
 right<=!play_enable?24'd0:attenuate(active_tone?sine(right_phase):$signed(in_right[23:8]),gain);
 sample_played<=play_enable && (active_tone?(gain!=0 || !paused):in_sample_played);
 if(active_tone && play_enable && (gain!=0 || !paused))phase<=phase==47?0:phase+1'b1;
 if(active_tone!=desired_tone)begin
 if(gain!=0)gain<=gain-1'b1;
 else begin active_tone<=desired_tone;phase<=0;source_changed<=1;end
 end else if(paused || !play_enable)begin if(gain!=0)gain<=gain-1'b1;end
 else if(gain!=256)gain<=gain+1'b1;
 end
 end
 end
endmodule

