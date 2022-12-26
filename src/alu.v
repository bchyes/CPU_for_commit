`include "/mnt/c/Users/25693/Desktop/math/Computer_system/CPU/riscv/src/constant.v"
module alu(
    input clk,
    input rst,
    input rdy,
    input [`INSIDE_OPCODE_WIDTH] in_rs_op,
    input [`DATA_WIDTH] in_rs_value_rs1,
    input [`DATA_WIDTH] in_rs_value_rs2,
    input [`DATA_WIDTH] in_rs_value_imm,
    input [`DATA_WIDTH] in_rs_pc,
    input [`ROB_TAG_WIDTH] in_rs_reorder,

    output reg [`DATA_WIDTH] out_rob_value, //rd
    output reg[`ROB_TAG_WIDTH] out_update_reorder,
    output reg [`DATA_WIDTH] out_rob_newpc
);

    //assign out_update_reorder = in_rs_reorder;

  always @(posedge clk) begin
    if (rst == `TRUE) begin
        
    end else if (rdy == `TRUE) begin
        out_update_reorder <= in_rs_reorder;
        case(in_rs_op)
            `LUI:begin
                out_rob_value <= in_rs_value_imm;
            end
            `AUIPC:begin
                out_rob_value <= in_rs_pc + in_rs_value_imm;
            end
            `JAL:begin
                out_rob_value <= in_rs_pc + 4;
            end
            `JALR:begin
                out_rob_value <= in_rs_pc + 4;
                out_rob_newpc <= in_rs_value_rs1 + in_rs_value_imm;
            end

            `BEQ:begin
                out_rob_value <= (in_rs_value_rs1 == in_rs_value_rs2) ? 1 : 0;
                out_rob_newpc <= in_rs_pc + in_rs_value_imm;
            end
            `BNE:begin
                out_rob_value <= (in_rs_value_rs1 != in_rs_value_rs2) ? 1 : 0;
                out_rob_newpc <= in_rs_pc + in_rs_value_imm;
            end
            `BLT:begin
                out_rob_value <= ($signed(in_rs_value_rs1) < $signed(in_rs_value_rs2)) ? 1 : 0;
                out_rob_newpc <= in_rs_pc + in_rs_value_imm;
            end
            `BGE:begin
                out_rob_value <= ($signed(in_rs_value_rs1) >= $signed(in_rs_value_rs2)) ? 1 : 0;
                out_rob_newpc <= in_rs_pc + in_rs_value_imm;
            end
            `BLTU:begin
                out_rob_value <= (in_rs_value_rs1 < in_rs_value_rs2) ? 1 : 0;
                out_rob_newpc <= in_rs_pc + in_rs_value_imm;
            end
            `BGEU:begin
                out_rob_value <= (in_rs_value_rs1 >= in_rs_value_rs2) ? 1 : 0;
                out_rob_newpc <= in_rs_pc + in_rs_value_imm;
            end

            `ADDI:begin
                out_rob_value <= in_rs_value_rs1 + in_rs_value_imm;
            end
            `SLTI:begin
                out_rob_value <= ($signed(in_rs_value_rs1) < $signed(in_rs_value_imm)) ? 1 : 0;
            end
            `SLTIU:begin
                out_rob_value <= (in_rs_value_rs1 < in_rs_value_imm) ? 1 : 0;
            end
            `XORI:begin
                out_rob_value <= in_rs_value_rs1 ^ in_rs_value_imm;
            end
            `ORI:begin
                out_rob_value <= in_rs_value_rs1 | in_rs_value_imm;
            end
            `ANDI:begin
                out_rob_value <= in_rs_value_rs1 & in_rs_value_imm;
            end
            `SLLI:begin
                out_rob_value <= in_rs_value_rs1 << in_rs_value_imm;
            end
            `SRLI:begin
                out_rob_value <= in_rs_value_rs1 >> in_rs_value_imm;
            end
            `SRAI:begin
                out_rob_value <= in_rs_value_rs1 >>> in_rs_value_imm;
            end
            `ADD:begin
                out_rob_value <= in_rs_value_rs1 + in_rs_value_rs2;
            end
            `SUB:begin
                out_rob_value <= in_rs_value_rs1 - in_rs_value_rs2;
            end
            `SLL:begin
                out_rob_value <= in_rs_value_rs1 << in_rs_value_rs2;
            end
            `SLT:begin
                out_rob_value <= ($signed(in_rs_value_rs1) < $signed(in_rs_value_rs2)) ? 1 : 0;
            end
            `SLTU:begin
                out_rob_value <= (in_rs_value_rs1 < in_rs_value_rs2) ? 1 : 0;
            end
            `XOR:begin
                out_rob_value <= in_rs_value_rs1 ^ in_rs_value_rs2;
            end
            `SRL:begin
                out_rob_value <= in_rs_value_rs1 >> in_rs_value_rs2;
            end
            `SRA:begin
                out_rob_value <= in_rs_value_rs1 >>> in_rs_value_rs2;
            end
            `OR:begin
                out_rob_value <= in_rs_value_rs1 | in_rs_value_rs2;
            end
            `AND:begin
                out_rob_value <= in_rs_value_rs1 & in_rs_value_rs2;
            end
        endcase
    end else begin

    end
  end
endmodule