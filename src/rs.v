`include "constant.v"
module rs(
    input clk,
    input rst,
    input rdy,
    //input in_decode_get,//Bool, to know whether a instr in coming.
    input [`INSIDE_OPCODE_WIDTH] in_decode_op,
    input [`DATA_WIDTH] in_decode_pc,
    //input [`REG_TAG_WIDTH] in_decode_rs1,//TAG
    //input [`REG_TAG_WIDTH] in_decode_rs2,//TAG
    input [`ROB_TAG_WIDTH] in_decode_reorder,//to know whether a instr in coming.(No by reorder == `ZERO_ROB_TAG)
    input [`DATA_WIDTH] in_decode_imm,
    //?input in_reg_get_rs1,//Bool, to know if we can get the data from reg(reorder == 0)
    //input in_reg_wait_rs1,//Bool, reg reorder != 0
    //?input in_reg_get_rs2,//Bool, to know if we can get the data from reg(reorder == 0)
    //input in_reg_wait_rs2,//Bool, reg reorder != 0
    input [`DATA_WIDTH] in_decode_value_rs1,
    input [`DATA_WIDTH] in_decode_value_rs2,
    input [`ROB_TAG_WIDTH] in_decode_reorder_rs1,
    input [`ROB_TAG_WIDTH] in_decode_reorder_rs2,//initial above come from reg,now reg->decode->rs!!!!
    
    input in_rob_ready_rs1,//Bool, if we can't get data from reg, then we wait the ROB to commit the data
    input in_rob_ready_rs2,//Bool, if we can't get data from reg, then we wait the ROB to commit the data
    input [`DATA_WIDTH] in_rob_value_rs1,
    input [`DATA_WIDTH] in_rob_value_rs2,

    //When reorder buffer refresh, then we change the value
    input [`DATA_WIDTH] in_rob_update_value,
    input [`ROB_TAG_WIDTH] in_rob_update_reorder, //from rs
    //input [`ROB_TAG_WIDTH] in_rob_update_reorder_from_slb,
    //input [`DATA_WIDTH] in_rob_update_value_from_slb,//maybe it needn't be deleted(x)
    /*input [`ROB_TAG_WIDTH] in_reg_update_rs1_reorder,
    input [`DATA_WIDTH] in_reg_update_rs1_value,
    input [`ROB_TAG_WIDTH] in_reg_update_rs2_reorder,
    input [`DATA_WIDTH] in_reg_update_rs2_value,*/

    output out_fetcher_idle,

    input in_rs_misbranch,

    //output for ALU
    output reg [`INSIDE_OPCODE_WIDTH] out_alu_op, //NOP means no operation
    output reg [`DATA_WIDTH] out_alu_value_rs1,
    output reg [`DATA_WIDTH] out_alu_value_rs2,
    output reg [`DATA_WIDTH] out_alu_imm,
    output reg [`DATA_WIDTH] out_alu_pc,
    output reg [`ROB_TAG_WIDTH] out_alu_reorder

    //input [`ROB_TAG_WIDTH] in_alu_update_reorder,
    //input [`DATA_WIDTH] in_alu_update_value
);
    reg busy [(`RS_SIZE-1):0]; // to know line in RS has instr which has not been operated.
    wire [`RS_TAG_WIDTH] free_line; // the place where new instr put. 
    // reg [`RS_TAG_WIDTH] head;
    // reg [`RS_TAG_WIDTH] tail;
    wire ready [(`RS_SIZE-1):0]; // to know whether rs1 and rs2 are ready or not. 
    wire [`RS_TAG_WIDTH] ready_line;
    reg [`DATA_WIDTH] pcs [(`RS_SIZE-1):0];
    reg [`DATA_WIDTH] rs1_value [(`RS_SIZE-1):0];
    reg [`DATA_WIDTH] rs2_value [(`RS_SIZE-1):0];
    reg [`ROB_TAG_WIDTH] rs1_reorder [(`RS_SIZE-1):0];
    reg [`ROB_TAG_WIDTH] rs2_reorder [(`RS_SIZE-1):0];
    reg [`DATA_WIDTH] imms [(`RS_SIZE-1):0];
    reg [`INSIDE_OPCODE_WIDTH] ops [(`RS_SIZE-1):0];
    reg [`ROB_TAG_WIDTH] reorder [(`RS_SIZE-1):0];

    /*reg debug;
    wire debug_;
    //assign debug_=rs1_reorder[1];
    wire [`DATA_WIDTH] debug_wire_pc1;
    wire [`DATA_WIDTH] debug_wire_pc2;
    wire [`DATA_WIDTH] debug_wire_pc3;
    wire [`DATA_WIDTH] debug_wire_pc4;
    wire [`DATA_WIDTH] debug_wire_pc5;
    wire [`DATA_WIDTH] debug_wire_pc6;
    wire [`DATA_WIDTH] debug_wire_pc7;
    wire [`DATA_WIDTH] debug_wire_pc8;
    wire [`DATA_WIDTH] debug_wire_pc9;
    wire [`DATA_WIDTH] debug_wire_pc10;
    wire [`DATA_WIDTH] debug_wire_pc11;
    wire [`DATA_WIDTH] debug_wire_pc12;
    wire [`DATA_WIDTH] debug_wire_pc13;
    wire [`DATA_WIDTH] debug_wire_pc14;
    wire [`DATA_WIDTH] debug_wire_pc15;
    assign debug_wire_pc1 = pcs[1];
    assign debug_wire_pc2 = pcs[2];
    assign debug_wire_pc3 = pcs[3];
    assign debug_wire_pc4 = pcs[4];
    assign debug_wire_pc5 = pcs[5];
    assign debug_wire_pc6 = pcs[6];
    assign debug_wire_pc7 = pcs[7];
    assign debug_wire_pc8 = pcs[8];
    assign debug_wire_pc9 = pcs[9];
    assign debug_wire_pc10 = pcs[10];
    assign debug_wire_pc11 = pcs[11];
    assign debug_wire_pc12 = pcs[12];
    assign debug_wire_pc13 = pcs[13];
    assign debug_wire_pc14 = pcs[14];
    assign debug_wire_pc15 = pcs[15];

    wire [`ROB_TAG_WIDTH] debug_rs2_reorder_1;
    wire [`DATA_WIDTH] debug_rs2_value_1;
    wire [`ROB_TAG_WIDTH] debug_rs1_reorder_1;
    wire [`DATA_WIDTH] debug_rs1_value_1;

    assign debug_rs2_reorder_1 = rs2_reorder[1];
    assign debug_rs1_reorder_1 = rs1_reorder[1];
    assign debug_rs2_value_1 = rs2_value[1];
    assign debug_rs1_value_1 = rs1_value[1];

    wire [`ROB_TAG_WIDTH] debug_rs2_reorder_2;
    wire [`DATA_WIDTH] debug_rs2_value_2;
    wire [`ROB_TAG_WIDTH] debug_rs1_reorder_2;
    wire [`DATA_WIDTH] debug_rs1_value_2;

    assign debug_rs2_reorder_2 = rs2_reorder[2];
    assign debug_rs1_reorder_2 = rs1_reorder[2];
    assign debug_rs2_value_2 = rs2_value[2];
    assign debug_rs1_value_2 = rs1_value[2];

    wire [`ROB_TAG_WIDTH] debug_rs2_reorder_5;
    wire [`DATA_WIDTH] debug_rs2_value_5;
    wire [`ROB_TAG_WIDTH] debug_rs1_reorder_5;
    wire [`DATA_WIDTH] debug_rs1_value_5;

    assign debug_rs2_reorder_5 = rs2_reorder[5];
    assign debug_rs1_reorder_5 = rs1_reorder[5];
    assign debug_rs2_value_5 = rs2_value[5];
    assign debug_rs1_value_5 = rs1_value[5];

    wire [`DATA_WIDTH] debug_reorder_5;
    assign debug_reorder_5 = reorder[5];*/
    
    assign out_fetcher_idle = (free_line != `ZERO_RS_TAG);
    
    genvar j;
    generate
        for (j = 1;j < `RS_SIZE;j = j + 1) begin
            assign ready[j] = (busy[j] == `TRUE) && (rs1_reorder[j] == `ZERO_ROB_TAG) && (rs2_reorder[j] == `ZERO_ROB_TAG);
        end
    endgenerate

    assign free_line =  ~busy[1] ? 1 :
                        ~busy[2] ? 2 :
                        ~busy[3] ? 3 :
                        ~busy[4] ? 4 :
                        ~busy[5] ? 5 :
                        ~busy[6] ? 6 :
                        ~busy[7] ? 7 :
                        ~busy[8] ? 8 :
                        ~busy[9] ? 9 :
                        ~busy[10] ? 10 :
                        ~busy[11] ? 11 :
                        ~busy[12] ? 12 :
                        ~busy[13] ? 13 :
                        ~busy[14] ? 14 :
                        ~busy[15] ? 15 : `ZERO_RS_TAG;

    assign ready_line = ready[1] ? 1 :
                        ready[2] ? 2 :
                        ready[3] ? 3 :
                        ready[4] ? 4 :
                        ready[5] ? 5 :
                        ready[6] ? 6 :
                        ready[7] ? 7 :
                        ready[8] ? 8 :
                        ready[9] ? 9 :
                        ready[10] ? 10 :
                        ready[11] ? 11 :
                        ready[12] ? 12 :
                        ready[13] ? 13 :
                        ready[14] ? 14 :
                        ready[15] ? 15 : `ZERO_RS_TAG;

    integer i;
  always @(posedge clk) begin
    if (rst == `TRUE) begin
        out_alu_op <= `NOP;
        for (i = 1;i < `RS_SIZE;i = i + 1) begin
            busy[i] <= `FALSE;
            ops[i] <= `NOP;
        end
        //debug <= busy[1];
    end else if (rdy == `TRUE) begin
        out_alu_op <= `NOP;
        out_alu_reorder <= `ZERO_ROB_TAG;
        if (in_rs_misbranch == `TRUE) begin
            for (i = 1;i < `RS_SIZE;i = i + 1) begin
            busy[i] <= `FALSE;
            //ops[i] <= `NOP;
            reorder[i] <= `ZERO_ROB_TAG; //
        end
        end else begin
            if (ready_line != `ZERO_RS_TAG) begin
                out_alu_op <= ops[ready_line];
                out_alu_imm <= imms[ready_line];
                out_alu_pc <= pcs[ready_line];
                out_alu_reorder <= reorder[ready_line];
                out_alu_value_rs1 <= rs1_value[ready_line];
                out_alu_value_rs2 <= rs2_value[ready_line];
                busy[ready_line] <= `FALSE;
            end
            if (in_decode_reorder != `ZERO_ROB_TAG && free_line != `ZERO_RS_TAG /*&& in_reg_get_rs1 == `TRUE && in_reg_get_rs2 == `TRUE*/) begin
                busy[free_line] <= `TRUE;
                //ready[free_line] <= `FALSE;
                pcs[free_line] <= in_decode_pc;
                imms[free_line] <= in_decode_imm;
                ops[free_line] <= in_decode_op;
                reorder[free_line] <= in_decode_reorder;
                rs1_value[free_line] <= in_decode_value_rs1;
                rs2_value[free_line] <= in_decode_value_rs2;
                rs1_reorder[free_line] <= in_decode_reorder_rs1;
                rs2_reorder[free_line] <= in_decode_reorder_rs2;
                if (in_decode_reorder_rs1 != `ZERO_ROB_TAG && in_decode_reorder_rs1 == in_rob_update_reorder) begin
                    rs1_reorder[free_line] <= `ZERO_ROB_TAG;
                    rs1_value[free_line] <= in_rob_update_value;
                end
                if (in_decode_reorder_rs2 != `ZERO_ROB_TAG && in_decode_reorder_rs2 == in_rob_update_reorder) begin
                    rs2_reorder[free_line] <= `ZERO_ROB_TAG;
                    rs2_value[free_line] <= in_rob_update_value;
                end//!!!!!!!!!
                /*if (in_decode_reorder_rs1 != `ZERO_ROB_TAG && in_decode_reorder_rs1 == in_rob_update_reorder_from_slb) begin
                    rs1_reorder[free_line] <= `ZERO_ROB_TAG;
                    rs1_value[free_line] <= in_rob_update_value_from_slb;
                end
                if (in_decode_reorder_rs2 != `ZERO_ROB_TAG && in_decode_reorder_rs2 == in_rob_update_reorder_from_slb) begin
                    rs2_reorder[free_line] <= `ZERO_ROB_TAG;
                    rs2_value[free_line] <= in_rob_update_value_from_slb;
                end//!!!!!!!!!*/
                /*if (in_decode_reorder_rs1 != `ZERO_ROB_TAG && in_decode_reorder_rs1 == in_reg_update_rs1_reorder) begin
                    rs1_reorder[free_line] <= `ZERO_ROB_TAG;
                    rs1_value[free_line] <= in_reg_update_rs1_value;
                end
                if (in_decode_reorder_rs2 != `ZERO_ROB_TAG && in_decode_reorder_rs2 == in_reg_update_rs2_reorder) begin
                    rs2_reorder[free_line] <= `ZERO_ROB_TAG;
                    rs2_value[free_line] <= in_reg_update_rs2_value;
                end//!!!!!!!!!*/
            end
            if (in_rob_update_reorder != `ZERO_ROB_TAG) begin
                for (i = 1; i < `RS_SIZE; i = i + 1) begin
                    if (busy[i] == `TRUE && (rs1_reorder[i] == in_rob_update_reorder)) begin
                        rs1_reorder[i] <= `ZERO_ROB_TAG;
                        rs1_value[i] <= in_rob_update_value;
                    end
                    if (busy[i] == `TRUE && (rs2_reorder[i] == in_rob_update_reorder)) begin
                        rs2_reorder[i] <= `ZERO_ROB_TAG;
                        rs2_value[i] <= in_rob_update_value;
                    end
                end
            end
            if (in_rob_update_reorder != `ZERO_ROB_TAG) begin
                for (i = 1; i < `RS_SIZE; i = i + 1) begin
                    if (busy[i] == `TRUE && (rs1_reorder[i] == in_rob_update_reorder)) begin
                        rs1_reorder[i] <= `ZERO_ROB_TAG;
                        rs1_value[i] <= in_rob_update_value;
                    end
                    if (busy[i] == `TRUE && (rs2_reorder[i] == in_rob_update_reorder)) begin
                        rs2_reorder[i] <= `ZERO_ROB_TAG;
                        rs2_value[i] <= in_rob_update_value;
                    end
                end
            end
            /*if (in_rob_update_reorder_from_slb != `ZERO_ROB_TAG) begin
                for (i = 1; i < `RS_SIZE; i = i + 1) begin
                    if (busy[i] == `TRUE && (rs1_reorder[i] == in_rob_update_reorder_from_slb)) begin
                        rs1_reorder[i] <= `ZERO_ROB_TAG;
                        rs1_value[i] <= in_rob_update_value_from_slb;
                    end
                    if (busy[i] == `TRUE && (rs2_reorder[i] == in_rob_update_reorder_from_slb)) begin
                        rs2_reorder[i] <= `ZERO_ROB_TAG;
                        rs2_value[i] <= in_rob_update_value_from_slb;
                    end
                end
            end*/
        end
    end else begin
        // nothing to do when rdy == `FALSE
    end
  end
endmodule