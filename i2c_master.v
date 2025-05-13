module i2c_master(
	input wire clk,  //系統時脈
	input wire rst_n,  //非同步Reset(低有效)
	input wire start,  //啟動傳輸
	input wire rw,     //0=Write, 1=Read
	input wire [7:0] data_in,  //要傳送的資料
	output reg [7:0] data_out,  //接收的資料
	output reg busy,  //傳輸進行中標誌
	output reg ack_error,  //ACK回應錯誤
	output reg scl,   //I2C時脈輸出
	output reg sda_out,  //資料輸出控制
	input wire sda_in   //資料輸入(讀Slave)
);

//===狀態定義===
localparam IDLE = 3'd0;
localparam START_COND = 3'd1;
localparam SEND_BYTE = 3'd2;
localparam WAIT_ACK = 3'd3;
localparam STOP_COND = 3'd4;

reg [2:0] state, next_state;

//=== Clock Divider ===
parameter SCL_DIV = 250;  //假設clk是50MHx,要降到100kHz
reg [8:0] clk_div;
wire scl_tick;
assign scl_tick = (clk_div == 0);

//===傳輸相關===
reg [7:0] tx_reg;
reg [7:0] rx_reg;
reg [3:0] bit_cnt;
reg sda_dir;

//=== Clock Divider計數===
always @( posedge clk or negedge rst_n) begin
	if (!rst_n)
		clk_div <= 0;
	else if (busy)
		clk_div <= (clk_div == 0)? (SCL_DIV-1): clk_div - 1;
	else
		clk_div <= 0;
end

//===狀態轉移===
always @(posedge clk or negedge rst_n) begin
	if (!rst_n)
		state <= IDLE;
	else
		state <= next_state;
end

//===下一個狀態邏輯===
always @(*) begin
	case (state)
		IDLE: next_state = (start)? START_COND : IDLE;
		START_COND: next_state = (scl_tick) ? SEND_BYTE : START_COND;
		SEND_BYTE: next_state = (bit_cnt == 4'd8 && scl_tick && scl == 1'b0) ? WAIT_ACK : SEND_BYTE;
		WAIT_ACK: next_state = (scl_tick && scl == 1'b1) ? STOP_COND : WAIT_ACK;
		STOP_COND: next_state = (scl_tick && scl == 1'b1) ? IDLE : STOP_COND;
		default: next_state = IDLE;
	endcase
end
//=== SCL控制===
always @(posedge clk or negedge rst_n) begin
	if (!rst_n)
		scl <= 1'b1;  // I2C idle時SCL預設高
	else if (busy && scl_tick)
		scl <= ~scl;
	else if (!busy)
		scl <= 1'b1;
end

//===主資料流程===
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		tx_reg <= 8'd0;
		rx_reg <= 8'd0;
		bit_cnt <= 4'd0;
		busy <= 1'b0;
		sda_out <= 1'b1;
		data_out <= 8'd0;
		ack_error <= 1'b0;
		sda_dir <= 1'b1;
	end else begin
		case (state)
			IDLE: begin
				busy <= 1'b0;
				sda_out <= 1'b1;
				ack_error <= 1'b0;
			end
			
			START_COND: begin
				busy <= 1'b1;
				if (scl_tick && scl == 1'b1) begin
					sda_out <= 1'b0;  //產生Start
					tx_reg <= data_in;  //載入要送的資料
					bit_cnt <= 4'd0;
					sda_dir <= 1'b1;  //設定自己控制SDA
				end
			end
			
			SEND_BYTE: begin
				if (scl_tick) begin
					if (scl == 1'b0) begin
						//在SCL低時設定下一個資料位元
						sda_out <= tx_reg [7];
						tx_reg <= {tx_reg[6:0],1'b0};  //左移
					end else begin
						//在SCL高時資料被對方讀取
						bit_cnt <= bit_cnt + 1;
					end
				end
			end
			
			WAIT_ACK: begin
				if (scl_tick) begin
					if (scl == 1'b0) begin
						sda_dir <= 1'b0;  //釋放SDA,讓Slave送ACK
					end else if (scl == 1'b1) begin
						if (sda_in) begin
							ack_error <= 1'b1;  // Slave沒拉低ACK
						end
					end
				end
			end
			
			STOP_COND: begin
				if (scl_tick) begin
					if (scl == 1'b1)
						sda_out <= 1'b1;  // SCL高時SDA拉高,產生Stop
					else
						sda_out <=1'b0;  //等待下一個上升沿前保持SDA低
					sda_dir <= 1'b1;   //SDA方向自己控制
				end
			end
		endcase
	end
end
endmodule

		
