module wav_audio #(parameter PREFILL=512,CLOCK_RATE=40000000)(input wire clk50,rst50,byte_valid,input wire [7:0] octet,
 output wire space,input wire pix,rst_pix,pause_play,flush50,flush_pix,play_enable,seek_second,input wire [31:0] total_frames,
 output reg [31:0] position,output reg [7:0] seconds,output reg [4:0] progress,output wire requested_frame,output reg sample_played,output reg audio_valid,
 output reg [23:0] left,right,output reg acr_valid,output reg started,underrun,output reg overflow,output wire seek_ready);
 reg [1:0] byte_phase;reg [23:0] partial;reg [31:0] word;reg we;
 wire full,empty;wire [11:0] wlevel,rlevel;wire [31:0] head;
 reg [15:0] second_phase;reg [35:0] progress_phase;
 // Calculate the half-file timestamp in the background, one subtraction per cycle.
 // This avoids a long combinational constant-divider path in the 25MHz timeline.
 reg [31:0] half_target,half_remaining;reg [15:0] half_phase;
 reg [7:0] half_seconds;reg half_busy;
 assign seek_ready=!half_busy && half_target==(total_frames>>1);
 always @(posedge pix)begin
 if(rst_pix)begin half_target<=0;half_remaining<=0;half_phase<=0;half_seconds<=0;half_busy<=0;end
 else if(half_target!=(total_frames>>1))begin
 half_target<=total_frames>>1;half_remaining<=total_frames>>1;half_seconds<=0;half_busy<=1;
 end else if(half_busy)begin
 if(half_remaining>=48000)begin half_remaining<=half_remaining-48000;half_seconds<=half_seconds+1'b1;end
 else begin half_phase<=half_remaining[15:0];half_busy<=0;end
 end
 end
 assign requested_frame=total_frames!=0 && position>=(total_frames>>1);
 reg [25:0] sample_phase;reg [5:0] acr_count;
 wire tick=sample_phase>=CLOCK_RATE-48000;
 wire pop=tick && started && !empty && !pause_play && !flush_pix && play_enable;
 assign space=wlevel<=1024 && !overflow;
 audio_fifo fifo(.wclk(clk50),.wrst(rst50 || flush50),.we(we),.wd(word),.full(full),.wlevel(wlevel),
 .rclk(pix),.rrst(rst_pix || flush_pix),.pop(pop),.q(head),.empty(empty),.rlevel(rlevel));
 always @(posedge clk50)begin
 we<=0;
 if(rst50 || flush50)begin byte_phase<=0;partial<=0;word<=0;we<=0;overflow<=0;end
 else begin
 if(we && full)overflow<=1;
 if(byte_valid)begin
 case(byte_phase)
 0:partial[7:0]<=octet;
 1:partial[15:8]<=octet;
 2:partial[23:16]<=octet;
 3:begin if(full)overflow<=1;else begin word<={octet,partial};we<=1;end end
 endcase
 byte_phase<=byte_phase+1'b1;
 end
 end
 end
 always @(posedge pix)begin
 audio_valid<=0;acr_valid<=0;sample_played<=!rst_pix && pop;
 if(rst_pix)begin sample_phase<=0;acr_count<=0;started<=0;underrun<=0;left<=0;right<=0;end
 else begin
 if(flush_pix)begin started<=0;underrun<=0;end
 else if(!started && rlevel>=PREFILL && !tick && total_frames!=0)started<=1;
 if(tick)begin
 sample_phase<=sample_phase-(CLOCK_RATE-48000);audio_valid<=1;
 if(pop)begin left<={head[15:0],8'd0};right<={head[31:16],8'd0};end
 else begin left<=0;right<=0;if(started && !pause_play && !flush_pix && play_enable)underrun<=1;end
 if(acr_count==47)begin acr_count<=0;acr_valid<=1;end else acr_count<=acr_count+1'b1;
 end else sample_phase<=sample_phase+26'd48000;
 end
 end
always @(posedge pix)begin
 if(rst_pix)begin position<=0;seconds<=0;second_phase<=0;progress<=0;progress_phase<=0;end
 else if(flush_pix)begin
 position<=seek_second?(total_frames>>1):0;
 seconds<=seek_second?half_seconds:0;
 second_phase<=seek_second?half_phase:0;
 progress<=seek_second?5'd8:5'd0;progress_phase<=0;
 end
 else if(pop)begin
 if(position==total_frames-1)begin position<=0;seconds<=0;second_phase<=0;progress<=0;progress_phase<=0;end
 else begin
 position<=position+1'b1;
 if(second_phase==47999)begin second_phase<=0;seconds<=seconds+1'b1;end else second_phase<=second_phase+1'b1;
 if(progress_phase+16>=total_frames)begin progress_phase<=progress_phase+16-total_frames;progress<=progress+1'b1;end
 else progress_phase<=progress_phase+16;
 end
 end
 end
endmodule
