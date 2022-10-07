`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:22:02 03/11/2019 
// Design Name: 
// Module Name:    Layer1_Conv_Top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module Layer1_Conv_Top#(
	parameter									bits						=	16		,	//quantization bit number
	parameter									bits_shift				=	4		,	//we can shift but not multy
	parameter									channel_num				=	4		,
	parameter									channel_in_num 		=	16		, //�?次输�?16个数据，几何上为4*4*1
	parameter									channel_in_num_2		=	5		,
	parameter									channel_out_num		=	64		,//�?次输�?64个数据，几何上为4*4*4
	parameter									pool_stride_num_length = 2		,
	parameter									pool_stride_num_height = 2		,
	parameter									pool_channel_heignt	=	2		,
	parameter									pool_channel_length	=	2		,
	parameter									pool_channel			=	4		,
	parameter									pool_channel_bits		=	256		,//�?个pool�?4（channel方向�?*2*2*16bits
	parameter									pool_channel_bits_shift	=	8	,
	parameter 									conv_num					=	64 ,	//channel_num*channel_in_num
	parameter 		                            filter_size		=		3	,
	parameter			                        filter_size_2		=		2	
	)
	(
	input																clk_in,
	input 															rst_n,
	input 	[(channel_in_num<<bits_shift)-1:0]			data_in,
	input																start,
	input		[(channel_num<<bits_shift)-1:0]				weights,
	output	reg [(channel_out_num<<bits_shift)-1:0]	data_out,
	output															ready
    );

wire				[bits-1:0]				data_in_conv			[0:channel_in_num-1]		; 
wire				[bits-1:0]				weight_in_conv			[0:channel_num-1]			;
//进行乘法位数�?要扩展两倍，再进行加法也�?要扩展位数，比如说kernal大小�?5*5=25，进�?25<2^5次加法可能导�?5次进�?
wire	signed	[(bits<<1)-1+filter_size_2:0]					data_conv					[0:conv_num-1]				;
wire											ready_conv				[0:conv_num-1]				;
assign 										ready			=			ready_conv[0]				;
wire	signed	[(bits<<1)-1:0]		bias						[0:channel_num-1]			;
//data_temp[哪一组pool,�?4组][�?组pool�?�?256bits的数据]
wire				[pool_channel_bits-1:0]data_temp				[0:pool_channel-1]		;
assign										bias[3]		=			32'b00100010001011000011010000000000	;																				 
assign										bias[2]		=			32'b00000110100101101100110010111000	;
assign										bias[1]		=			32'b00001001111010011000011110110000	;
assign										bias[0]		=			32'b00011001011001001000001101100000	;
genvar i,j,k,l,r,s,t,u,v;
generate
	for(i = 0; i < channel_num; i = i + 1)
	begin:conv_channel
		for(l = 0; l < channel_in_num; l = l + 1)
		begin:conv_in_channel
			Conv_unsign_sign layer_conv(
				.clk_in			(clk_in)					,
				.rst_n			(rst_n)					,
				.data_in			(data_in_conv[l])		,	
				.weight			(weight_in_conv[i])	,
				.bias				(bias[i])				,
				.start			(start)					,
				.data_out		(data_conv[i*channel_in_num+l])				,
				.ready			(ready_conv[i*channel_in_num+l])
				);
		end
	end
	
	//四个pool�?起运算，（r,s)定位pool，v指定channel方向，因为一个pool�?2*2，（pool_stride_num_height，pool_stride_num_length）定位一个pool中的位置
	for (r = 0; r < pool_channel_heignt; r = r + 1)
	begin:data_temp1
		for (s = 0; s < pool_channel_length; s = s + 1)
		begin:data_temp2
			for (v = 0; v < channel_num; v = v + 1)
			begin:data_temp3
				for (t = 0; t < pool_stride_num_height; t = t + 1)
				begin:data_temp4
					for (u = 0; u < pool_stride_num_length; u = u + 1)
					begin:data_temp5
						assign data_temp[r*pool_channel_length+s][((v*pool_stride_num_length*pool_stride_num_height+(t*pool_stride_num_length+u))<<bits_shift)+bits-1:((v*pool_stride_num_length*pool_stride_num_height+(t*pool_stride_num_length+u))<<bits_shift)]    =
								 (data_conv[v*channel_in_num+((r*pool_stride_num_height+t)*pool_channel_length*pool_stride_num_length+s*pool_stride_num_length+u)]>0)?
								 data_conv[v*channel_in_num+((r*pool_stride_num_height+t)*pool_channel_length*pool_stride_num_length+s*pool_stride_num_length+u)][(bits<<1)+1:bits+1]:0;
					end
				end
			end
		end
	end
	for (l = 0; l < pool_channel; l = l + 1) 
	begin:output_data
		always@(posedge clk_in)
		begin
			data_out[(l<<pool_channel_bits_shift)+pool_channel_bits-1:(l<<pool_channel_bits_shift)]		<=		data_temp[l]	;
		end
	end
	
	for(j = 0; j < channel_in_num; j = j + 1)
	begin:conv_data_in
		assign data_in_conv[j]			=			data_in[(j<<bits_shift)+bits-1:(j<<bits_shift)]	;
	end
	
	for(k = 0; k < channel_num; k = k + 1)
	begin:conv_parameters_in
		assign weight_in_conv[k]		=			weights[(k<<bits_shift)+bits-1:(k<<bits_shift)]	;
	end
endgenerate	

// integer w_file;
// initial w_file = $fopen("mult1_1.txt");
// always @(*)
// begin
//     $fdisplay(w_file,"%d",data_out[255:240]);
// end
endmodule
