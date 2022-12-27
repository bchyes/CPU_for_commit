`include "constant.v"
module rob(
    input clk,
    input rst,
    input rdy,
    input [`INSIDE_OPCODE_WIDTH] in_decode_op,
    input [`REG_TAG_WIDTH] in_decode_rd,
    input [`DATA_WIDTH] in_decode_pc,
    input in_decode_jump,

    //ALU solve the line in the reorder buffer
    input [`DATA_WIDTH] in_alu_value,
    input [`ROB_TAG_WIDTH] in_alu_reorder,
    input [`DATA_WIDTH] in_alu_newpc,

    //SLB solve the line in the reorder buffer
    input [`DATA_WIDTH] in_slb_destination,
    input [`DATA_WIDTH] in_slb_value,
    input [`ROB_TAG_WIDTH] in_slb_reorder,

    output reg [`DATA_WIDTH] out_reg_value,
    output reg [`REG_TAG_WIDTH] out_reg_index,
    //Compare to the reorder in the reg to judge whether to change the value in the reg
    output reg [`ROB_TAG_WIDTH] out_reg_value_reorder,

    output reg [2:0] out_mem_size,
    output reg [`RAM_ADDRESS_WIDTH] out_mem_address,
    output reg [`DATA_WIDTH] out_mem_data,
    output reg out_mem_save_data, // ask mem to save data
    input in_mem_save_data, // complete save data

    output [`ROB_TAG_WIDTH] out_decode_reorder, //change wire to reg to solve the time problem (I can't solve it)

    output out_fetcher_idle,

    //branch
    output reg out_misbranch,
    output reg [`DATA_WIDTH] out_misbranch_newpc,
    output reg out_bp,
    output reg out_bp_jump,
    output reg [`BP_BRANCH_TAG] out_bp_tag,

    output reg [`DATA_WIDTH] out_rs_update_value,
    output reg [`ROB_TAG_WIDTH] out_rs_update_reorder,
    output reg [`DATA_WIDTH] out_slb_update_value,
    output reg [`ROB_TAG_WIDTH] out_slb_update_reorder, //forget to transfer
    output reg [`DATA_WIDTH] out_decode_update_value,
    output reg [`ROB_TAG_WIDTH] out_decode_update_reorder
);
    //reg busy [(`ROB_SIZE - 1):0];
    reg ready [(`ROB_SIZE - 1):0];
    reg [`ROB_TAG_WIDTH] head;
    reg [`ROB_TAG_WIDTH] tail;
    wire [`ROB_TAG_WIDTH] head_next_ptr;
    wire [`ROB_TAG_WIDTH] tail_next_ptr;
    reg [`INSIDE_OPCODE_WIDTH] ops [(`ROB_SIZE - 1):0];
    reg [`DATA_WIDTH] pcs [(`ROB_SIZE - 1):0];
    reg [`REG_TAG_WIDTH] dest [(`ROB_SIZE - 1):0]; 
    reg [`RAM_ADDRESS_WIDTH] dest_mem [(`ROB_SIZE - 1):0];
    reg [`DATA_WIDTH] value [(`ROB_SIZE - 1):0];

    localparam IDLE = 0,WAIT_MEM = 1;
    reg status;//above status

    assign head_next_ptr = (head % (`ROB_SIZE - 1)) + 1;
    assign tail_next_ptr = (tail % (`ROB_SIZE - 1)) + 1;

    assign out_decode_reorder = (tail_next_ptr == head) ? `ZERO_ROB_TAG : tail_next_ptr;

    assign out_fetcher_idle = (tail_next_ptr != head);

    reg [`DATA_WIDTH] newpc [(`ROB_SIZE - 1):0];
    reg prediction [(`ROB_SIZE - 1):0];

    /*reg debug;
    reg debug_value;
    reg debug_prediction;
    reg debug_ready;
    //reg [`INSIDE_OPCODE_WIDTH] debug_op1;
    //reg [`INSIDE_OPCODE_WIDTH] debug_op2;
    //reg [`INSIDE_OPCODE_WIDTH] debug_op3;
    //reg [`INSIDE_OPCODE_WIDTH] debug_op4;
    wire [`INSIDE_OPCODE_WIDTH] debug_op8;
    assign debug_op8 = ops[8];
    wire [`INSIDE_OPCODE_WIDTH] debug_op5;
    assign debug_op5 = ops[5];
    wire [`INSIDE_OPCODE_WIDTH] debug_op4;
    assign debug_op4 = ops[4];
    wire [`INSIDE_OPCODE_WIDTH] debug_opc;
    assign debug_opc = ops[12];
    wire [`INSIDE_OPCODE_WIDTH] debug_op9;
    assign debug_op9 = ops[9];
    wire [`INSIDE_OPCODE_WIDTH] debug_op2;
    assign debug_op2 = ops[2];
    wire [`INSIDE_OPCODE_WIDTH] debug_op1;
    assign debug_op1 = ops[1];
    wire [`INSIDE_OPCODE_WIDTH] debug_op3;
    assign debug_op3 = ops[3];
    wire [`INSIDE_OPCODE_WIDTH] debug_opd;
    assign debug_opd = ops[13];

    wire debug_ready_2;
    assign debug_ready_2 = ready[2];
    wire debug_ready_8;
    assign debug_ready_8 = ready[8];
    wire debug_ready_3;
    assign debug_ready_3 = ready[3];
    wire [`DATA_WIDTH] debug_pc_2;
    assign debug_pc_2 = pcs[2];
    wire [`DATA_WIDTH] debug_pc_8;
    assign debug_pc_8 = pcs[8];
    wire [`DATA_WIDTH] debug_pc_5;
    assign debug_pc_5 = pcs[5];
    wire [`DATA_WIDTH] debug_pc_4;
    assign debug_pc_4 = pcs[4];
    wire [`DATA_WIDTH] debug_pc_9;
    assign debug_pc_9 = pcs[9];
    wire [`DATA_WIDTH] debug_pc_1;
    assign debug_pc_1 = pcs[1];
    wire [`DATA_WIDTH] debug_pc_3;
    assign debug_pc_3 = pcs[3];
    wire [`DATA_WIDTH] debug_pc_d;
    assign debug_pc_d = pcs[13];*/

    integer i;
  always @(posedge clk) begin
    if (rst == `TRUE) begin
        head <= 0;
        tail <= 0;
        status <= IDLE;
        out_misbranch <= `FALSE;
        out_reg_index <= `ZERO_REG_TAG;
        out_mem_save_data <= `FALSE;
        out_bp <= `FALSE;
        for (i = 0;i < `ROB_SIZE;i = i + 1) begin
            ready[i] <= `FALSE;
        end
        /*debug <= `FALSE;
        debug_value <= `FALSE;
        debug_prediction <= `FALSE;
        debug_ready <= `FALSE;*/
        //out_decode_reorder <= `ZERO_ROB_TAG;
    end else if (rdy == `TRUE && out_misbranch == `FALSE) begin
        /*debug <= `FALSE;
        debug_value <= `TRUE;
        debug_prediction <= `TRUE;
        debug_ready <= ready[4];*/
        //debug_op1 <= ops[1];
        //debug_op2 <= ops[2];
        //debug_op3 <= ops[3];
        //debug_op4 <= ops[4];
        out_rs_update_reorder <= `ZERO_ROB_TAG;
        out_slb_update_reorder <= `ZERO_ROB_TAG;
        out_decode_update_reorder <= `ZERO_ROB_TAG; //!!!!!
        //out_decode_reorder <= `ZERO_ROB_TAG;
        if (in_decode_op != `NOP) begin
            pcs[tail_next_ptr] <= in_decode_pc;
            ops[tail_next_ptr] <= in_decode_op;
            dest[tail_next_ptr] <= in_decode_rd;
            //dest_mem[tail_next_ptr]
            prediction[tail_next_ptr] <= in_decode_jump;
            ready[tail_next_ptr] <= `FALSE;
            tail <= tail_next_ptr;
            //out_decode_reorder <= tail_next_ptr;
        end
        if (in_alu_reorder != `ZERO_ROB_TAG) begin
            value[in_alu_reorder] <= in_alu_value;
            //reorder[in_alu_reorder] <= `ZERO_ROB_TAG;
            ready[in_alu_reorder] <= `TRUE;
            newpc[in_alu_reorder] <= in_alu_newpc;
            //debug_ready <= ready[in_alu_reorder];
            //out_rs_update_reorder <= in_alu_reorder;
            //out_rs_update_value <= in_alu_value;//exactly it can go to slb!!!!!!!!!!(exactly we must update when commit)
        end
        if (in_slb_reorder != `ZERO_SLB_TAG) begin
            value[in_slb_reorder] <= in_slb_value;
            //reorder[in_slb_reorder] <= `ZERO_ROB_TAG;
            ready[in_slb_reorder] <= `TRUE;
            dest_mem[in_slb_reorder] <= in_slb_destination;
            //out_slb_update_reorder <= in_slb_reorder;
            //out_slb_update_value <= in_slb_value;//exactly it can go to rs!!!!!!!!!!
        end
        if (ready[head_next_ptr] == `TRUE && head != tail) begin
            if (status == IDLE) begin
                //!!!!ready[head_next_ptr] <= `FALSE; //
                case (ops[head_next_ptr])
                    `NOP:begin end
                    `JALR:begin
                        out_reg_index <= dest[head_next_ptr];
                        out_reg_value <= value[head_next_ptr];
                        out_reg_value_reorder <= head_next_ptr;
                        out_misbranch <= `TRUE;
                        out_misbranch_newpc <= newpc[head_next_ptr];
                        out_rs_update_reorder <= head_next_ptr;
                        out_rs_update_value <= value[head_next_ptr];//!!!!!
                        out_slb_update_reorder <= head_next_ptr;
                        out_slb_update_value <= value[head_next_ptr];//!!!!!
                        out_decode_update_reorder <= head_next_ptr;
                        out_decode_update_value <= value[head_next_ptr];
                    end
                    `BEQ,`BNE,`BLT,`BGE,`BLTU,`BGEU:begin
                        out_bp <= `TRUE;
                        out_bp_jump <= ((value[head_next_ptr] == `TRUE) ? 1 : 0);
                        out_bp_tag <= pcs[head_next_ptr][`BP_HASH_TAG];
                        ready[head_next_ptr] <= `FALSE;
                        head <= head_next_ptr;
                        /*debug_value <= value[head_next_ptr];
                        debug_prediction <= prediction[head_next_ptr];*/
                        out_rs_update_reorder <= head_next_ptr;
                        out_rs_update_value <= value[head_next_ptr];//!!!!!
                        out_slb_update_reorder <= head_next_ptr;
                        out_slb_update_value <= value[head_next_ptr];//!!!!!
                        out_decode_update_reorder <= head_next_ptr;
                        out_decode_update_value <= value[head_next_ptr];
                        if (value[head_next_ptr] == `TRUE && prediction[head_next_ptr] == `FALSE) begin
                            out_misbranch <= `TRUE;
                            out_misbranch_newpc <= newpc[head_next_ptr];
                        end else if (value[head_next_ptr] == `FALSE && prediction[head_next_ptr] == `TRUE) begin
                            out_misbranch <= `TRUE;
                            out_misbranch_newpc <= pcs[head_next_ptr] + 4;//!!
                        end
                    end
                    `SB:begin
                        status <= WAIT_MEM;
                        out_mem_size <= 1;
                        out_mem_address <= dest_mem[head_next_ptr];
                        out_mem_data <= value[head_next_ptr];
                        out_mem_save_data <= `TRUE;
                    end
                    `SH:begin
                        status <= WAIT_MEM;
                        out_mem_size <= 2;
                        out_mem_address <= dest_mem[head_next_ptr];
                        out_mem_data <= value[head_next_ptr];
                        out_mem_save_data <= `TRUE;
                    end
                    `SW:begin
                        status <= WAIT_MEM;
                        out_mem_size <= 4;
                        out_mem_address <= dest_mem[head_next_ptr];
                        out_mem_data <= value[head_next_ptr];
                        out_mem_save_data <= `TRUE;
                    end
                    default:begin
                        out_reg_index <= dest[head_next_ptr];
                        out_reg_value <= value[head_next_ptr];
                        out_reg_value_reorder <= head_next_ptr;
                        ready[head_next_ptr] <= `FALSE;
                        head <= head_next_ptr; //!
                        out_rs_update_reorder <= head_next_ptr;
                        out_rs_update_value <= value[head_next_ptr];//!!!!!
                        out_slb_update_reorder <= head_next_ptr;
                        out_slb_update_value <= value[head_next_ptr];//!!!!!
                        out_decode_update_reorder <= head_next_ptr;
                        out_decode_update_value <= value[head_next_ptr];
                    end
                endcase
            end else if (status == WAIT_MEM) begin
                out_mem_save_data <= `FALSE; //outside to avoid second save
                if (in_mem_save_data == `TRUE) begin
                    //debug <= `TRUE;
                    status <= IDLE;
                    ready[head_next_ptr] <= `FALSE;
                    head <= head_next_ptr;
                    out_rs_update_reorder <= head_next_ptr;
                    out_rs_update_value <= value[head_next_ptr];//!!!!!
                    out_slb_update_reorder <= head_next_ptr;
                    out_slb_update_value <= value[head_next_ptr];//!!!!!
                    out_decode_update_reorder <= head_next_ptr;
                    out_decode_update_value <= value[head_next_ptr];

                end
            end
        end
    end else if (rdy == `TRUE && out_misbranch == `TRUE) begin
        out_misbranch <= `FALSE;
        status <= IDLE;
        head <= 0; tail <= 0;
        out_reg_index <= `ZERO_REG_TAG;
        out_mem_save_data <= `FALSE;
        out_bp <= `FALSE;
        for (i = 0;i < `ROB_SIZE;i = i + 1) begin
            ready[i] <= `FALSE;
        end
    end
    else begin
        //nothing to do when rdy == `FALSE
    end
  end
endmodule