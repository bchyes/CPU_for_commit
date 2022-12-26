module register(
    input clk,
    input rst,
    input rdy,

    output [`ROB_TAG_WIDTH] out_reg_rs1_reorder,
    output [`ROB_TAG_WIDTH] out_reg_rs2_reorder,
    output [`DATA_WIDTH] out_reg_rs1_value,
    output [`DATA_WIDTH] out_reg_rs2_value,

    input [`REG_TAG_WIDTH] in_decode_rs1,
    input [`REG_TAG_WIDTH] in_decode_rs2,
    input [`REG_TAG_WIDTH] in_decode_rd,
    input [`ROB_TAG_WIDTH] in_decode_reorder,

    input in_reg_misbranch,

    input [`REG_TAG_WIDTH] in_rob_index,
    input [`DATA_WIDTH] in_rob_value,
    input [`ROB_TAG_WIDTH] in_rob_reorder
);
    reg [`DATA_WIDTH] value [(`REG_SIZE-1):0];
    reg [`ROB_TAG_WIDTH] reorder [(`REG_SIZE-1):0];
    
    wire [`ROB_TAG_WIDTH] debug_reorder_s0;
    assign debug_reorder_s0 = reorder[8];
    wire [`DATA_WIDTH] debug_value_s0;
    assign debug_value_s0 = value[8];
    wire [`ROB_TAG_WIDTH] debug_reorder_s2;
    assign debug_reorder_s2 = reorder[18];
    wire [`DATA_WIDTH] debug_value_s2;
    assign debug_value_s2 = value[18];
    wire [`ROB_TAG_WIDTH] debug_reorder_s9;
    assign debug_reorder_s9 = reorder[25];
    wire [`DATA_WIDTH] debug_value_s9;
    assign debug_value_s9 = value[25];
    wire [`ROB_TAG_WIDTH] debug_reorder_a0;
    assign debug_reorder_a0 = reorder[10];
    wire [`DATA_WIDTH] debug_value_a0;
    assign debug_value_a0 = value[10];
    wire [`ROB_TAG_WIDTH] debug_reorder_0;
    assign debug_reorder_0 = reorder[0];
    wire [`DATA_WIDTH] debug_value_0;
    assign debug_value_0 = value[0];
    wire [`ROB_TAG_WIDTH] debug_reorder_a3;
    assign debug_reorder_a3 = reorder[13];
    wire [`DATA_WIDTH] debug_value_a3;
    assign debug_value_a3 = value[13];
    wire [`ROB_TAG_WIDTH] debug_reorder_a4;
    assign debug_reorder_a4 = reorder[14];
    wire [`DATA_WIDTH] debug_value_a4;
    assign debug_value_a4 = value[14];
    wire [`ROB_TAG_WIDTH] debug_reorder_t0;
    assign debug_reorder_t0 = reorder[5];
    wire [`DATA_WIDTH] debug_value_t0;
    assign debug_value_t0 = value[5];
    wire [`ROB_TAG_WIDTH] debug_reorder_ra;
    assign debug_reorder_ra = reorder[1];
    wire [`DATA_WIDTH] debug_value_ra;
    assign debug_value_ra = value[1];
    wire [`ROB_TAG_WIDTH] debug_reorder_sp;
    assign debug_reorder_sp = reorder[2];
    wire [`DATA_WIDTH] debug_value_sp;
    assign debug_value_sp = value[2];
    wire [`ROB_TAG_WIDTH] debug_reorder_s3;
    assign debug_reorder_s3 = reorder[19];
    wire [`DATA_WIDTH] debug_value_s3;
    assign debug_value_s3 = value[19];
    wire [`ROB_TAG_WIDTH] debug_reorder_a5;
    assign debug_reorder_a5 = reorder[15];
    wire [`DATA_WIDTH] debug_value_a5;
    assign debug_value_a5 = value[15];
    wire [`ROB_TAG_WIDTH] debug_reorder_a2;
    assign debug_reorder_a2 = reorder[12];
    wire [`DATA_WIDTH] debug_value_a2;
    assign debug_value_a2 = value[12];
    wire [`ROB_TAG_WIDTH] debug_reorder_a1;
    assign debug_reorder_a1 = reorder[11];
    wire [`DATA_WIDTH] debug_value_a1;
    assign debug_value_a1 = value[11];
    wire [`ROB_TAG_WIDTH] debug_reorder_s1;
    assign debug_reorder_s1 = reorder[9];
    wire [`DATA_WIDTH] debug_value_s1;
    assign debug_value_s1 = value[9];
    wire [`ROB_TAG_WIDTH] debug_reorder_s5;
    assign debug_reorder_s5 = reorder[21];
    wire [`DATA_WIDTH] debug_value_s5;
    assign debug_value_s5 = value[21];
    wire [`ROB_TAG_WIDTH] debug_reorder_s8;
    assign debug_reorder_s8 = reorder[24];
    wire [`DATA_WIDTH] debug_value_s8;
    assign debug_value_s8 = value[24];
    wire [`ROB_TAG_WIDTH] debug_reorder_a6;
    assign debug_reorder_a6 = reorder[16];
    wire [`DATA_WIDTH] debug_value_a6;
    assign debug_value_a6 = value[16];
    wire [`ROB_TAG_WIDTH] debug_reorder_t1;
    assign debug_reorder_t1 = reorder[6];
    wire [`DATA_WIDTH] debug_value_t1;
    assign debug_value_t1 = value[6];
    wire [`ROB_TAG_WIDTH] debug_reorder_t3;
    assign debug_reorder_t3 = reorder[28];
    wire [`DATA_WIDTH] debug_value_t3;
    assign debug_value_t3 = value[28];
    wire [`ROB_TAG_WIDTH] debug_reorder_a7;
    assign debug_reorder_a7 = reorder[17];
    wire [`DATA_WIDTH] debug_value_a7;
    assign debug_value_a7 = value[17];

    assign out_reg_rs1_reorder = reorder[in_decode_rs1];
    assign out_reg_rs2_reorder = reorder[in_decode_rs2];
    assign out_reg_rs1_value = value[in_decode_rs1];
    assign out_reg_rs2_value = value[in_decode_rs2];

    integer i;
    always @(posedge clk) begin
        if (rst == `TRUE) begin
            for (i = 0;i < `REG_SIZE;i = i + 1) begin
                value[i] <= `ZERO_DATA;
                reorder[i] <= `ZERO_ROB_TAG;
            end
        end else if (rdy == `TRUE && in_reg_misbranch == `FALSE) begin
            if (in_rob_index != `ZERO_REG_TAG) begin
                value[in_rob_index] <=  in_rob_value;
                /////! jump 的时候后面有些不需要的指令跟进的时候有时候覆盖了reorder，但是实际上并不需要修改，jump之后就仅仅只是把reorder去了，并没有更改value
                if (in_rob_reorder == reorder[in_rob_index] || reorder[in_rob_index] == `ZERO_REG_TAG) begin
                    reorder[in_rob_index] <= `ZERO_REG_TAG;
                    
                end
            end
            if (in_decode_rd != `ZERO_REG_TAG) begin
                if (in_decode_reorder != `ZERO_ROB_TAG) begin
                    reorder[in_decode_rd] <= in_decode_reorder;
                end
            end
        end else if (rdy == `TRUE && in_reg_misbranch == `TRUE) begin
            for (i = 0;i < `REG_SIZE;i = i + 1) begin
                //!!value[i] <= `ZERO_DATA;
                reorder[i] <= `ZERO_ROB_TAG;
            end
        end
        else begin
            //nothing to do when rdy == `FALSE
        end
    end
endmodule