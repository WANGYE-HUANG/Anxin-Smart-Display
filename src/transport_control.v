// One transport state: browsing implies paused; either PLAY or AUTO starts selected page.
// seek_second is held stable throughout the SD park/flush handshake.
module transport_control(input wire clk,rst,ready,failed,pause_press,replay_press,
 previous_press,next_press,auto_press,reader_idle,active_frame,auto_frame,
 output reg paused,manual_mode,page,seek_second,output wire restart_hold,flushing,requested_frame);
 reg [1:0] state;reg [3:0] count;
 assign restart_hold=state!=0;assign flushing=state!=0;
 assign requested_frame=(manual_mode || flushing)?page:auto_frame;
 always @(posedge clk)begin
 if(rst)begin paused<=0;manual_mode<=0;page<=0;seek_second<=0;state<=0;count<=0;end
 else if(ready && replay_press && !failed)begin
 // Replay wins even while a previous seek is being parked or flushed.
 paused<=0;manual_mode<=0;page<=0;seek_second<=0;state<=1;count<=0;
 end else case(state)
 0:if(ready && !failed)begin
 if(previous_press || next_press)begin
 page<=manual_mode?!page:!active_frame;manual_mode<=1;paused<=1;
 end else if(manual_mode && (pause_press || auto_press))begin
 manual_mode<=0;paused<=0;seek_second<=page;state<=1;
 end else if(auto_press)begin manual_mode<=0;paused<=0;end
 else if(pause_press)paused<=!paused;
 end
 1:if(reader_idle)begin state<=2;count<=0;end
 2:if(count==15)state<=0;else count<=count+1'b1;
 default:state<=0;
 endcase
 end
endmodule
