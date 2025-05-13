`timescale 1ns/1ps
module i2c_master_tb;

//===測試訊號宣告===
reg clk;
reg rst_n;
reg start;
reg rw;
reg [7:0] data_in;
wire [7:0] data_out;
wire busy;
wire ack_error;
wire scl;
wire sda_out;
reg sda_in;

//===產生I2C Master實例===
i2c_master uut(
	.clk(clk),
	.rst_n(rst_n),
	.start(start),
	.rw(rw),
	.data_in(data_in),
	.data_out(data_out),
	.busy(busy),
	.ack_error(ack_error),
	.scl(scl),
	.sda_out(sda_out),
	.sda_in(sda_in)
);

//=== Clock產生(50MHz)===
always #10 clk = ~clk;  // 20ns一個週期-> 50MHz

//=== SDA線模擬(簡單的Slave行為)===
// Slave固定給ACK (拉低SDA)

always @ (negedge scl) begin
	if (uut.state == uut.WAIT_ACK) begin
		sda_in <= 1'b0;  //給ACK
	end else begin
		sda_in <= 1'b1;  //平時保持高
	end
end

//===初始測試流程===
initial begin
	//初始條件
	clk = 0;
	rst_n = 0;
	start = 0;
	rw = 0;  //先做Write
	data_in = 8'b10101010;
	sda_in = 1'b1;  // SDA預設拉高(I2C Idle狀態)
	
	// Reset流程
	#100;
	rst_n = 1;
	
	//傳送一筆資料
	#100;
   start= 1;
	#20;
	start = 0;
	
	//等待傳輸完成
	wait(busy == 0);
	#100;
	
	//結束模擬
	$stop;
end
endmodule