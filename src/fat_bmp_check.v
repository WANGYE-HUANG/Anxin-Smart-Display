// FAT32 directory/FAT validation; optional MEDIA.CRC supplies expected BMP CRC32 values.
// No processor, no sector signature scanning for file discovery, no write commands.
module fat_bmp_check(
 input wire clk,input wire rst,input wire card_ready,input wire card_error,
 output reg req,output reg [31:0] lba,input wire sector_done,
 input wire data_valid,input wire [8:0] byte_index,input wire [7:0] octet,
 input wire restart_hold,seek_second,output wire restart_idle,output reg [31:0] total_frames,
 input wire image_ready,input wire audio_space,output wire wav_byte_valid,output wire [7:0] wav_byte,
 output wire [10:0] pixel_width,pixel_height,output reg wav_ok,output wire [2:0] pixel_profile,output reg [2:0] test_profile,alt_profile,output wire pixel_file, output wire pixel_byte_valid, output wire [7:0] pixel_byte,
 output reg mounted,output wire files_found,output reg test_ok,output reg alt_ok,
 output reg passed,output reg failed,output reg [7:0] error_code);
 localparam START=0,WAIT_SECTOR=1,ANALYZE=2,SELECT_PART=3,BOOT_CHECK=4,
 BOOT_CALC=5,BOOT_READY=6,DIR_START=7,CHAIN_NEXT=8,FILE_START=9,
 FILE_CHECK=10,DONE=11,ERROR=12,WAIT_SPACE=13,RESTART_WAIT=14,SEEK_STEP=15,FETCH_CHECK=16;
 localparam MBR=0,BOOT=1,DIR=2,FAT=3,FILE_DATA=4;
 reg [4:0] state;reg [2:0] kind,fetch_kind;reg [31:0] watchdog,fetch_address;
 reg [7:0] part_type[0:3];reg [31:0] part_lba[0:3],part_size[0:3];
 reg [2:0] part_index;reg [31:0] partition_start,partition_size;
 reg [15:0] bytes_per_sector,reserved,extflags,fs_version;
 reg [7:0] spc,nfats,sig0,sig1;reg [31:0] total_sectors,fat_size,root_cluster;
 reg [3:0] shift;reg [31:0] fat_base,data_base,volume_end,cluster_count;
 reg [31:0] chain_cluster,chain_hops;reg [6:0] sub_sector;reg chain_is_file;
 reg [31:0] next_cluster;wire [8:0] fat_offset={chain_cluster[6:0],2'b00};
 reg [3:0] found;reg dir_end;reg [31:0] test_cluster,alt_cluster,test_size,alt_size;
 reg [87:0] entry_name;reg [7:0] entry_first,entry_attr;
 reg [31:0] entry_cluster,entry_size;reg [1:0] file_select;
 reg [31:0] file_position,file_size,file_crc;
 reg [31:0] manifest_cluster,manifest_size,expected_test_crc,expected_alt_crc;
 reg [63:0] manifest_magic;reg checksum_present;
 reg [31:0] wav_cluster,wav_size,held_lba;
 reg [31:0] seek_target,seek_clusters;reg seeking,seek_header;
 wire [31:0] second_offset=32'd44+((total_frames>>1)<<2);
 wire [6:0] target_subsector=(seek_target>>9)&(spc-1);
 reg [31:0] riff_magic,riff_size,wave_magic,fmt_magic,fmt_size,wav_rate,wav_byte_rate,data_magic,data_size;
 reg [15:0] wav_format,wav_channels,wav_align,wav_bits;
 wire [31:0] selected_cluster=file_select==0?test_cluster:file_select==1?alt_cluster:file_select==2?wav_cluster:manifest_cluster;
 wire [31:0] selected_size=file_select==0?test_size:file_select==1?alt_size:file_select==2?wav_size:manifest_size;
 wire header_good=riff_magic==32'h46464952 && riff_size==file_size-8 && wave_magic==32'h45564157 &&
 fmt_magic==32'h20746d66 && fmt_size==16 && wav_format==1 && wav_channels==2 && wav_rate==48000 &&
 wav_byte_rate==192000 && wav_align==4 && wav_bits==16 && data_magic==32'h61746164 && data_size==file_size-44 && data_size[2:0]==0;
 assign restart_idle=state==RESTART_WAIT;
 assign wav_byte_valid=!restart_hold && !seek_header && state==WAIT_SECTOR && data_valid && kind==FILE_DATA && file_select==2 &&
 file_position>=seek_target && file_position<file_size && header_good;
 assign wav_byte=octet;
 reg [15:0] bmp_magic,bmp_planes,bmp_bits;
 reg [31:0] bmp_offset,bmp_dib,bmp_width,bmp_height,bmp_compression,bmp_file_size,bmp_image_size;
 assign pixel_profile=(bmp_width==640 && bmp_height==480)?3'd0:
 (bmp_width==320 && bmp_height==240)?3'd1:(bmp_width==640 && bmp_height==360)?3'd2:3'd7;
 assign pixel_width=bmp_width[10:0];assign pixel_height=bmp_height[10:0];
 wire dimensions_good=bmp_width>=1 && bmp_width<=1024 && bmp_height>=1 && bmp_height<=1024;
 wire [12:0] payload_calc={2'd0,bmp_width[10:0]}+({2'd0,bmp_width[10:0]}<<1);
 reg [12:0] bmp_row_bytes,payload_bytes;reg [23:0] expected_bmp_size;
 always @(posedge clk)begin
 if(rst)begin bmp_row_bytes<=0;payload_bytes<=0;expected_bmp_size<=54;end
 else begin payload_bytes<=payload_calc;bmp_row_bytes<=(payload_calc+13'd3)&13'h1ffc;
 expected_bmp_size<=24'd54+bmp_row_bytes*bmp_height[10:0];end
 end
 reg [12:0] bmp_row_position;
 wire bmp_header_good=dimensions_good && bmp_magic==16'h4d42 && bmp_offset==54 && bmp_dib==40 &&
 bmp_planes==1 && bmp_bits==24 && bmp_compression==0 && bmp_file_size==file_size && file_size==expected_bmp_size &&
 (bmp_image_size==0 || bmp_image_size==expected_bmp_size-54);
 wire [8:0] part_relative=byte_index-9'd446;
 wire [1:0] part_slot=part_relative[5:4];
 wire [31:0] cluster_lba=data_base+((chain_cluster-2)<<shift)+sub_sector;
 assign files_found=&found[2:0];
 // Stream stable identities; publish after full format checks and optional manifest CRC32 checks.
 assign pixel_byte_valid=state==WAIT_SECTOR && data_valid && kind==FILE_DATA &&
                         file_select<2 && file_position>=54 && file_position<file_size && bmp_header_good && bmp_row_position < payload_bytes;
 assign pixel_byte=octet;
 assign pixel_file=file_select;
 function [31:0] crc32_byte;
 input [31:0] previous;input [7:0] value;reg [31:0] c;integer j;
 begin c=previous^{24'd0,value};for(j=0;j<8;j=j+1)c=c[0]?(c>>1)^32'hEDB88320:(c>>1);crc32_byte=c;end
 endfunction
 task stop_error;input [7:0] code;
 begin failed<=1;error_code<=code;state<=ERROR;end endtask
 task fetch;input [2:0] purpose;input [31:0] address;
 begin
 // Register the calculated address before the range/backpressure checks.
 fetch_address<=address;fetch_kind<=purpose;state<=FETCH_CHECK;
 end endtask
 integer i;
 always @(posedge clk)begin
 req<=0;
 if(rst)begin
 seek_header<=0;seek_target<=44;seek_clusters<=0;seeking<=0;test_profile<=0;alt_profile<=0;manifest_cluster<=0;manifest_size<=0;expected_test_crc<=0;expected_alt_crc<=0;manifest_magic<=0;checksum_present<=0;total_frames<=0;wav_ok<=0;wav_cluster<=0;wav_size<=0;held_lba<=0;
 riff_magic<=0;riff_size<=0;wave_magic<=0;fmt_magic<=0;fmt_size<=0;wav_rate<=0;wav_byte_rate<=0;
 data_magic<=0;data_size<=0;wav_format<=0;wav_channels<=0;wav_align<=0;wav_bits<=0;
 state<=START;kind<=MBR;fetch_kind<=MBR;fetch_address<=0;watchdog<=0;req<=0;lba<=0;mounted<=0;
 test_ok<=0;alt_ok<=0;passed<=0;failed<=0;error_code<=0;part_index<=0;
 partition_start<=0;partition_size<=0;found<=0;dir_end<=0;
 test_cluster<=0;alt_cluster<=0;test_size<=0;alt_size<=0;
 bytes_per_sector<=0;reserved<=0;extflags<=0;fs_version<=0;spc<=0;nfats<=0;
 sig0<=0;sig1<=0;total_sectors<=0;fat_size<=0;root_cluster<=0;
 fat_base<=0;data_base<=0;volume_end<=0;cluster_count<=0;shift<=0;
 chain_cluster<=0;chain_hops<=0;sub_sector<=0;chain_is_file<=0;next_cluster<=0;
 entry_name<=0;entry_first<=0;entry_attr<=0;entry_cluster<=0;entry_size<=0;
 file_select<=0;file_position<=0;file_size<=0;file_crc<=32'hffffffff;
 bmp_magic<=0;bmp_planes<=0;bmp_bits<=0;bmp_offset<=0;bmp_dib<=0;
 bmp_row_position<=0;bmp_width<=0;bmp_height<=0;bmp_compression<=0;bmp_file_size<=0;bmp_image_size<=0;
 for(i=0;i<4;i=i+1)begin part_type[i]<=0;part_lba[i]<=0;part_size[i]<=0;end
 end else if(state!=DONE && state!=ERROR && (card_error || watchdog==32'd2999999999))begin
 stop_error(card_error?8'h01:8'h07);
 end else begin
 if(state!=DONE && state!=ERROR)watchdog<=watchdog+1'b1;
 if(state==WAIT_SECTOR && data_valid)begin
 if(kind==MBR || kind==BOOT)begin
 case(byte_index)
 11:bytes_per_sector[7:0]<=octet;12:bytes_per_sector[15:8]<=octet;
 13:spc<=octet;14:reserved[7:0]<=octet;15:reserved[15:8]<=octet;16:nfats<=octet;
 32:total_sectors[7:0]<=octet;33:total_sectors[15:8]<=octet;
 34:total_sectors[23:16]<=octet;35:total_sectors[31:24]<=octet;
 36:fat_size[7:0]<=octet;37:fat_size[15:8]<=octet;38:fat_size[23:16]<=octet;39:fat_size[31:24]<=octet;
 40:extflags[7:0]<=octet;41:extflags[15:8]<=octet;
 42:fs_version[7:0]<=octet;43:fs_version[15:8]<=octet;
 44:root_cluster[7:0]<=octet;45:root_cluster[15:8]<=octet;
 46:root_cluster[23:16]<=octet;47:root_cluster[31:24]<=octet;
 510:sig0<=octet;511:sig1<=octet;
 endcase
 if(kind==MBR && byte_index>=446 && byte_index<510)case(part_relative[3:0])
 4:part_type[part_slot]<=octet;
 8:part_lba[part_slot][7:0]<=octet;9:part_lba[part_slot][15:8]<=octet;
 10:part_lba[part_slot][23:16]<=octet;11:part_lba[part_slot][31:24]<=octet;
 12:part_size[part_slot][7:0]<=octet;13:part_size[part_slot][15:8]<=octet;
 14:part_size[part_slot][23:16]<=octet;15:part_size[part_slot][31:24]<=octet;
 endcase
 end
 if(kind==DIR && !dir_end)begin
 if(byte_index[4:0]<11)entry_name<={entry_name[79:0],octet};
 case(byte_index[4:0])
 0:begin entry_first<=octet;if(octet==0)dir_end<=1;end
 11:entry_attr<=octet;
 20:entry_cluster[23:16]<=octet;21:entry_cluster[31:24]<=octet;
 26:entry_cluster[7:0]<=octet;27:entry_cluster[15:8]<=octet;
 28:entry_size[7:0]<=octet;29:entry_size[15:8]<=octet;30:entry_size[23:16]<=octet;
 31:if(entry_first!=8'he5 && entry_first!=0 && (entry_attr&8'h18)==0 && entry_attr!=8'h0f)begin
 if(entry_name=="TEST    BMP")begin found[0]<=1;test_cluster<=entry_cluster&32'h0fffffff;test_size<={octet,entry_size[23:0]};end
 if(entry_name=="ALT     BMP")begin found[1]<=1;alt_cluster<=entry_cluster&32'h0fffffff;alt_size<={octet,entry_size[23:0]};end
 if(entry_name=="MEDIA   CRC")begin found[3]<=1;manifest_cluster<=entry_cluster&32'h0fffffff;manifest_size<={octet,entry_size[23:0]};end
 if(entry_name=="AUDIO   WAV")begin found[2]<=1;wav_cluster<=entry_cluster&32'h0fffffff;wav_size<={octet,entry_size[23:0]};end
 end
 endcase
 end
 if(kind==FAT)begin
 if(byte_index==fat_offset)next_cluster[7:0]<=octet;
 if(byte_index==fat_offset+1)next_cluster[15:8]<=octet;
 if(byte_index==fat_offset+2)next_cluster[23:16]<=octet;
 if(byte_index==fat_offset+3)next_cluster[31:24]<=octet;
 end
 if(kind==FILE_DATA && file_position<file_size)begin
 if(file_select<2 && file_position>=54)begin
 if(bmp_row_position==bmp_row_bytes-1)bmp_row_position<=0;else bmp_row_position<=bmp_row_position+1'b1;end
 file_position<=file_position+1'b1;file_crc<=crc32_byte(file_crc,octet);
 if(file_select<2 && file_position==54)begin
 if(!bmp_header_good)stop_error(8'h09);
 else if(file_select==0)test_profile<=pixel_profile;else alt_profile<=pixel_profile;
 end
 if(file_select==3)begin
 case(file_position)
 0,1,2,3,4,5,6,7:manifest_magic<={manifest_magic[55:0],octet};
 8,9,10,11:expected_test_crc<={octet,expected_test_crc[31:8]};
 12,13,14,15:expected_alt_crc<={octet,expected_alt_crc[31:8]};
 endcase
 end
 if(file_select==2)begin
 case(file_position)
 0,1,2,3:riff_magic<={octet,riff_magic[31:8]};
 4,5,6,7:riff_size<={octet,riff_size[31:8]};
 8,9,10,11:wave_magic<={octet,wave_magic[31:8]};
 12,13,14,15:fmt_magic<={octet,fmt_magic[31:8]};
 16,17,18,19:fmt_size<={octet,fmt_size[31:8]};
 20,21:wav_format<={octet,wav_format[15:8]};
 22,23:wav_channels<={octet,wav_channels[15:8]};
 24,25,26,27:wav_rate<={octet,wav_rate[31:8]};
 28,29,30,31:wav_byte_rate<={octet,wav_byte_rate[31:8]};
 32,33:wav_align<={octet,wav_align[15:8]};
 34,35:wav_bits<={octet,wav_bits[15:8]};
 36,37,38,39:data_magic<={octet,data_magic[31:8]};
 40,41,42,43:data_size<={octet,data_size[31:8]};
 endcase
 if(file_position==44)begin if(!header_good)stop_error(8'h0b);else begin wav_ok<=1;total_frames<=data_size>>2;end end
 end
 case(file_position)
 0:bmp_magic[7:0]<=octet;1:bmp_magic[15:8]<=octet;
 2:bmp_file_size[7:0]<=octet;3:bmp_file_size[15:8]<=octet;4:bmp_file_size[23:16]<=octet;5:bmp_file_size[31:24]<=octet;
 10:bmp_offset[7:0]<=octet;11:bmp_offset[15:8]<=octet;12:bmp_offset[23:16]<=octet;13:bmp_offset[31:24]<=octet;
 14:bmp_dib[7:0]<=octet;15:bmp_dib[15:8]<=octet;16:bmp_dib[23:16]<=octet;17:bmp_dib[31:24]<=octet;
 18:bmp_width[7:0]<=octet;19:bmp_width[15:8]<=octet;20:bmp_width[23:16]<=octet;21:bmp_width[31:24]<=octet;
 22:bmp_height[7:0]<=octet;23:bmp_height[15:8]<=octet;24:bmp_height[23:16]<=octet;25:bmp_height[31:24]<=octet;
 26:bmp_planes[7:0]<=octet;27:bmp_planes[15:8]<=octet;
 28:bmp_bits[7:0]<=octet;29:bmp_bits[15:8]<=octet;
 30:bmp_compression[7:0]<=octet;31:bmp_compression[15:8]<=octet;
 32:bmp_compression[23:16]<=octet;33:bmp_compression[31:24]<=octet;
 34:bmp_image_size[7:0]<=octet;35:bmp_image_size[15:8]<=octet;36:bmp_image_size[23:16]<=octet;37:bmp_image_size[31:24]<=octet;
 endcase
 end
 end
 if(state==WAIT_SPACE || state==RESTART_WAIT || restart_hold)watchdog<=0;
 if(restart_hold && passed && state!=ERROR && state!=RESTART_WAIT &&
    (state!=WAIT_SECTOR || sector_done))begin state<=RESTART_WAIT;req<=0;end
 else case(state)
 FETCH_CHECK:begin
 if(mounted && (fetch_address<partition_start || fetch_address>=volume_end))stop_error(8'h06);
 else if(fetch_kind==FILE_DATA && file_select==2 && !audio_space)begin held_lba<=fetch_address;state<=WAIT_SPACE;end
 else begin
 kind<=fetch_kind;lba<=fetch_address;req<=1;state<=WAIT_SECTOR;
 if(fetch_kind==MBR || fetch_kind==BOOT)begin
 bytes_per_sector<=0;reserved<=0;extflags<=0;fs_version<=0;spc<=0;nfats<=0;
 sig0<=0;sig1<=0;total_sectors<=0;fat_size<=0;root_cluster<=0;end
 if(fetch_kind==FAT)next_cluster<=0;
 end
 end
 RESTART_WAIT:if(!restart_hold)begin
 file_select<=2;
 // Re-read the header on every seek, even if a loop header was partly read when parked.
 seek_header<=seek_second;seeking<=0;state<=FILE_START;
 end
 SEEK_STEP:if(seek_clusters!=0)begin chain_is_file<=1;fetch(FAT,fat_base+(chain_cluster>>7));end
 else begin
 seeking<=0;sub_sector<=target_subsector;file_position<=seek_target&32'hfffffe00;
 fetch(FILE_DATA,data_base+((chain_cluster-2)<<shift)+target_subsector);
 end
 WAIT_SPACE:if(audio_space)fetch(FILE_DATA,held_lba);
 START:if(card_ready)fetch(MBR,0);
 WAIT_SECTOR:if(sector_done)state<=ANALYZE;
 ANALYZE:case(kind)
 MBR:if(sig0!=8'h55 || sig1!=8'haa)stop_error(8'h02);else begin part_index<=0;state<=SELECT_PART;end
 BOOT:state<=BOOT_CHECK;
 DIR:if(&found || dir_end)begin
 if(&found[2:0])begin file_select<=found[3]?2'd3:2'd0;state<=FILE_START;end
 else stop_error(8'h04);
 end
 else if(sub_sector==spc-1)begin sub_sector<=0;chain_is_file<=0;fetch(FAT,fat_base+(chain_cluster>>7));end
 else begin sub_sector<=sub_sector+1'b1;state<=DIR_START;end
 FAT:state<=CHAIN_NEXT;
 FILE_DATA:if(file_select==2 && seek_header)begin
 if(!header_good)stop_error(8'h0b);
 else begin
 seek_header<=0;seek_target<=second_offset;seek_clusters<=second_offset>>(shift+9);seeking<=1;
 chain_cluster<=wav_cluster;chain_hops<=0;sub_sector<=0;file_size<=wav_size;state<=SEEK_STEP;
 end
 end else if(file_position>=file_size)state<=FILE_CHECK;
 else if(sub_sector==spc-1)begin sub_sector<=0;chain_is_file<=1;fetch(FAT,fat_base+(chain_cluster>>7));end
 else begin sub_sector<=sub_sector+1'b1;fetch(FILE_DATA,cluster_lba+1);end
 endcase
 SELECT_PART:if(part_type[part_index]==8'h0b || part_type[part_index]==8'h0c)begin
 partition_start<=part_lba[part_index];partition_size<=part_size[part_index];fetch(BOOT,part_lba[part_index]);end
 else if(part_index==3)begin partition_start<=0;partition_size<=total_sectors;state<=BOOT_CHECK;end
 else part_index<=part_index+1'b1;
 BOOT_CHECK:begin
 if(sig0!=8'h55 || sig1!=8'haa || bytes_per_sector!=512 || reserved==0 ||
 (nfats!=1 && nfats!=2) || fat_size==0 || fat_size>=total_sectors || fs_version!=0 ||
 total_sectors>partition_size || total_sectors==0 || root_cluster<2 || root_cluster[31:28]!=0 ||
 (extflags[7] && extflags[3:0]>=nfats))stop_error(8'h03);
 else case(spc)
 1:begin shift<=0;state<=BOOT_CALC;end 2:begin shift<=1;state<=BOOT_CALC;end
 4:begin shift<=2;state<=BOOT_CALC;end 8:begin shift<=3;state<=BOOT_CALC;end
 16:begin shift<=4;state<=BOOT_CALC;end 32:begin shift<=5;state<=BOOT_CALC;end
 64:begin shift<=6;state<=BOOT_CALC;end 128:begin shift<=7;state<=BOOT_CALC;end
 default:stop_error(8'h03);endcase
 end
 BOOT_CALC:begin
 fat_base<=partition_start+reserved+((extflags[7] && extflags[3:0]==1)?fat_size:0);
 data_base<=partition_start+reserved+(nfats==2?(fat_size<<1):fat_size);
 volume_end<=partition_start+total_sectors;
 cluster_count<=(total_sectors-reserved-(nfats==2?(fat_size<<1):fat_size))>>shift;
 state<=BOOT_READY;
 end
 BOOT_READY:if(volume_end<=partition_start || data_base>=volume_end || cluster_count<65525 ||
 cluster_count>=32'h0ffffff5 || root_cluster>=cluster_count+2 ||
 ({1'b0,cluster_count}+2) > ({1'b0,fat_size}<<7))stop_error(8'h03);
 else begin mounted<=1;chain_cluster<=root_cluster;chain_hops<=0;sub_sector<=0;state<=DIR_START;end
 DIR_START:if(chain_cluster<2 || chain_cluster>=cluster_count+2)stop_error(8'h06);else fetch(DIR,cluster_lba);
 CHAIN_NEXT:if(!chain_is_file && (next_cluster&32'h0fffffff)>=32'h0ffffff8)begin
 // A full root directory may end by FAT EOC without an empty directory slot.
 if(&found[2:0])begin file_select<=found[3]?2'd3:2'd0;state<=FILE_START;end
 else stop_error(8'h04);
 end else if((next_cluster&32'h0fffffff)<2 || (next_cluster&32'h0fffffff)>=cluster_count+2 ||
 chain_hops>=cluster_count)stop_error(8'h05);
 else begin
 chain_hops<=chain_hops+1'b1;chain_cluster<=next_cluster&32'h0fffffff;
 sub_sector<=0;
 if(seeking)begin seek_clusters<=seek_clusters-1;state<=SEEK_STEP;end
 else if(chain_is_file)fetch(FILE_DATA,data_base+(((next_cluster&32'h0fffffff)-2)<<shift));
 else state<=DIR_START;
 end
 FILE_START:begin
 if(file_select==3)begin manifest_magic<=0;expected_test_crc<=0;expected_alt_crc<=0;end
 seek_target<=44;seeking<=0;watchdog<=0;riff_magic<=0;riff_size<=0;wave_magic<=0;fmt_magic<=0;fmt_size<=0;
 wav_rate<=0;wav_byte_rate<=0;data_magic<=0;data_size<=0;wav_format<=0;wav_channels<=0;wav_align<=0;wav_bits<=0;
 bmp_row_position<=0;file_position<=0;file_crc<=32'hffffffff;sub_sector<=0;chain_hops<=0;
 bmp_magic<=0;bmp_planes<=0;bmp_bits<=0;bmp_offset<=0;bmp_dib<=0;
 bmp_row_position<=0;bmp_width<=0;bmp_height<=0;bmp_compression<=0;bmp_file_size<=0;bmp_image_size<=0;
 if(file_select==3 && selected_size!=16)stop_error(8'h0c);
 else if((file_select<2 && (selected_size<58 || selected_size>3145782)) || (file_select==2 && (selected_size<48 || selected_size>11520044 || selected_size[1:0]!=0)) || selected_cluster<2 ||
 selected_cluster>=cluster_count+2)stop_error(8'h08);
 else begin
 file_size<=selected_size;chain_cluster<=selected_cluster;
 fetch(FILE_DATA,data_base+((selected_cluster-2)<<shift));
 end
 end
 FILE_CHECK:if(file_select==3)begin
 if(manifest_magic!="AVCRC001")stop_error(8'h0c);
 else begin checksum_present<=1;file_select<=0;state<=FILE_START;end
 end else if(file_select==2)begin
 if(!header_good)stop_error(8'h0b);else state<=FILE_START;
 end else if(!bmp_header_good)stop_error(8'h09);
 else if(checksum_present && (~file_crc)!=(file_select?expected_alt_crc:expected_test_crc))stop_error(8'h0a);
 else if(!image_ready)begin watchdog<=0;end
 else if(!file_select)begin test_ok<=1;file_select<=1;state<=FILE_START;end
 else begin alt_ok<=1;passed<=1;file_select<=2;state<=FILE_START;end
 DONE:state<=DONE;
 ERROR:state<=ERROR;
 default:stop_error(8'hff);
 endcase
 end
 end
endmodule

