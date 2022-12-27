`include "constant.v"
module decode(
    input clk,
    input rst,
    input rdy,
    //Decode get instr & pc from fetcher
    input in_fetcher_get_instr, //bool
    input [`DATA_WIDTH] in_fetcher_instr,
    input [`DATA_WIDTH] in_fetcher_pc,

    input in_decode_jump,
    output reg out_rob_jump,

    input [`ROB_TAG_WIDTH] in_rob_free_reorder,//from rob get which reorder is free
    //when hit icache,it is wrong!!
    
    output [`DATA_WIDTH] out_decode_pc,

    output [`REG_TAG_WIDTH] out_reg_rs1,
    output [`REG_TAG_WIDTH] out_reg_rs2,
    output reg [`REG_TAG_WIDTH] out_reg_rd,
    output [`ROB_TAG_WIDTH] out_reg_reorder,

    input [`ROB_TAG_WIDTH] in_reg_rs1_reorder,
    input [`ROB_TAG_WIDTH] in_reg_rs2_reorder,
    input [`DATA_WIDTH] in_reg_rs1_value,
    input [`DATA_WIDTH] in_reg_rs2_value,

    output reg [`INSIDE_OPCODE_WIDTH] out_rob_op,
    output reg [`REG_TAG_WIDTH] out_rob_rd,
    //output reg [`ROB_TAG_WIDTH] out_rob_reorder,

    output reg [`INSIDE_OPCODE_WIDTH] out_rs_op,
    output reg [`DATA_WIDTH] out_rs_imm,
    output reg [`ROB_TAG_WIDTH] out_rs_reorder,
    output reg [`ROB_TAG_WIDTH] out_rs_rs1_reorder,
    output reg [`ROB_TAG_WIDTH] out_rs_rs2_reorder,
    output reg [`DATA_WIDTH] out_rs_rs1_value,
    output reg [`DATA_WIDTH] out_rs_rs2_value,

    input in_decode_misbranch,

    //output reg out_fetcher_idle,
    input in_slb_idle,
    input in_rob_idle,
    input in_rs_idle,
 
    output reg [`INSIDE_OPCODE_WIDTH] out_slb_op,
    output reg [`ROB_TAG_WIDTH] out_slb_reorder,
    output reg [`DATA_WIDTH] out_slb_imm,
    output reg [`DATA_WIDTH] out_slb_value1,
    output reg [`DATA_WIDTH] out_slb_value2,
    output reg [`ROB_TAG_WIDTH] out_slb_reorder1,
    output reg [`ROB_TAG_WIDTH] out_slb_reorder2,

    input [`ROB_TAG_WIDTH] in_rob_update_reorder,
    input [`DATA_WIDTH] in_rob_update_value // to avoid missing
);
    wire [6:0] opcode; 
    wire [4:0] rd;
    wire [2:0] funct3;
    wire [6:0] funct7;

    assign opcode = in_fetcher_instr[`OPCODE_WIDTH];
    assign rd = in_fetcher_instr[11:7];
    assign funct3 = in_fetcher_instr[14:12];
    assign funct7 = in_fetcher_instr[31:25];
    assign out_reg_rs2 = in_fetcher_instr[24:20];
    assign out_reg_rs1 = in_fetcher_instr[19:15];

    assign out_decode_pc = in_fetcher_pc;

    //assign out_rob_jump = in_decode_jump;//?

    //assign out_reg_rd = in_fetcher_instr[11:7];
    assign out_reg_reorder = in_rob_free_reorder;

    wire next_idle;
    assign next_idle = in_slb_idle && in_rs_idle && in_rob_idle;

    always @(posedge clk) begin
        if (rst == `TRUE) begin
            out_rs_reorder <= `ZERO_ROB_TAG;
            out_slb_reorder <= `ZERO_ROB_TAG;
            //out_rob_reorder <= `ZERO_ROB_TAG;
            out_rs_op <= `NOP;
            out_slb_op <= `NOP;
            out_rob_op <= `NOP;
            out_rs_rs1_reorder <= `ZERO_ROB_TAG;
            out_rs_rs2_reorder <= `ZERO_ROB_TAG;
            out_rs_rs1_value <= `ZERO_DATA;
            out_rs_rs2_value <= `ZERO_DATA;
            out_reg_rd <= `ZERO_REG_TAG;
            out_rob_jump <= `FALSE;
            //out_fetcher_idle <= `FALSE;
            out_slb_reorder1 <= `ZERO_ROB_TAG;//
            out_slb_reorder2 <= `ZERO_ROB_TAG;//
            out_slb_value1 <= `ZERO_DATA;//
            out_slb_value2 <= `ZERO_DATA;//forget to initialize
        end else if (rdy == `TRUE && in_decode_misbranch == `FALSE) begin
            out_rs_reorder <= `ZERO_ROB_TAG;
            out_slb_reorder <= `ZERO_ROB_TAG;
            //out_rob_reorder <= `ZERO_ROB_TAG;
            out_rs_op <= `NOP;
            out_slb_op <= `NOP;
            out_rob_op <= `NOP;
            out_rs_rs1_reorder <= `ZERO_ROB_TAG;
            out_rs_rs2_reorder <= `ZERO_ROB_TAG;
            out_rs_rs1_value <= `ZERO_DATA;
            out_rs_rs2_value <= `ZERO_DATA;
            out_slb_reorder1 <= `ZERO_ROB_TAG;//
            out_slb_reorder2 <= `ZERO_ROB_TAG;//
            out_slb_value1 <= `ZERO_DATA;//
            out_slb_value2 <= `ZERO_DATA;//forget to initialize
            out_reg_rd <= `ZERO_REG_TAG; //!
            out_rob_jump <= `FALSE;
            //out_fetcher_idle <= `FALSE;
            if (in_fetcher_get_instr == `TRUE && next_idle == `TRUE/*&& in_rob_free_reorder != `ZERO_ROB_TAG*/) begin
                //out_fetcher_idle <= `TRUE;
                case (opcode) 
                    7'b110111:begin //LUI
                        out_rob_op <= `LUI;
                        out_rs_op <= `LUI;
                        out_rob_rd <= rd;
                        out_rs_imm <= {in_fetcher_instr[31:12],12'b0};
                        out_rs_reorder <= in_rob_free_reorder;
                        //out_rob_reorder <= in_rob_free_reorder;
                        out_reg_rd <= rd;
                    end
                    7'b10111:begin //AUIPC
                        out_rob_op <= `AUIPC;
                        out_rs_op <= `AUIPC;
                        out_rs_reorder <= in_rob_free_reorder;
                        out_rob_rd <= rd;
                        out_rs_imm <= {in_fetcher_instr[31:12],12'b0};
                        //out_rob_reorder <= in_rob_free_reorder;
                        out_reg_rd <= rd;
                    end
                    7'b1101111:begin //JAL
                        out_rob_op <= `JAL;
                        out_rs_op <= `JAL;
                        out_rs_reorder <= in_rob_free_reorder;
                        out_rob_rd <= rd;
                        //out_rob_reorder <= in_rob_free_reorder;
                        out_reg_rd <= rd;
                    end
                    7'b1100111:begin //JALR
                        out_rob_op <= `JALR;
                        out_rs_op <= `JALR;
                        out_rs_reorder <= in_rob_free_reorder;
                        out_rob_rd <= rd;
                        //out_rob_reorder <= in_rob_free_reorder;
                        if (in_rob_update_reorder == in_reg_rs1_reorder && in_rob_update_reorder != `ZERO_ROB_TAG) begin
                            out_rs_rs1_reorder <= `ZERO_ROB_TAG;
                            out_rs_rs1_value <= in_rob_update_value;
                        end else begin
                            out_rs_rs1_reorder <= in_reg_rs1_reorder;
                            out_rs_rs1_value <= in_reg_rs1_value;
                        end
                        out_rs_imm <= {{21{in_fetcher_instr[31]}},in_fetcher_instr[30:20]};
                        out_reg_rd <= rd;
                    end
                    7'b1100011:begin //B-type
                        out_rs_reorder <= in_rob_free_reorder;
                        out_rob_rd <= rd;
                        if (in_rob_update_reorder == in_reg_rs1_reorder && in_rob_update_reorder != `ZERO_ROB_TAG) begin
                            out_rs_rs1_reorder <= `ZERO_ROB_TAG;
                            out_rs_rs1_value <= in_rob_update_value;
                        end else begin
                            out_rs_rs1_reorder <= in_reg_rs1_reorder;
                            out_rs_rs1_value <= in_reg_rs1_value;
                        end
                        if (in_rob_update_reorder == in_reg_rs2_reorder && in_rob_update_reorder != `ZERO_ROB_TAG) begin
                            out_rs_rs2_reorder <= `ZERO_ROB_TAG;
                            out_rs_rs2_value <= in_rob_update_value;
                        end else begin
                            out_rs_rs2_reorder <= in_reg_rs2_reorder;
                            out_rs_rs2_value <= in_reg_rs2_value;
                        end
                        out_rs_imm <= {{20{in_fetcher_instr[31]}},in_fetcher_instr[7],in_fetcher_instr[30:25],in_fetcher_instr[11:8], 1'b0};
                        out_rob_jump <= in_decode_jump;
                        case (funct3)
                            3'b0:begin //BEQ
                                out_rob_op <= `BEQ;
                                out_rs_op <= `BEQ;
                            end
                            3'b1:begin //BNE
                                out_rob_op <= `BNE;
                                out_rs_op <= `BNE;
                            end
                            3'b100:begin //BLT
                                out_rob_op <= `BLT;
                                out_rs_op <= `BLT;
                            end
                            3'b101:begin //BGE
                                out_rob_op <= `BGE;
                                out_rs_op <= `BGE;
                            end
                            3'b110:begin //BLTU
                                out_rob_op <= `BLTU;
                                out_rs_op <= `BLTU;
                            end
                            3'b111:begin //BGEU
                                out_rob_op <= `BGEU;
                                out_rs_op <= `BGEU;
                            end
                        endcase
                    end
                    7'b11:begin //L-type
                        out_slb_imm <= {{21{in_fetcher_instr[31]}},in_fetcher_instr[30:20]};
                        out_slb_reorder <= in_rob_free_reorder;
                        if (in_rob_update_reorder == in_reg_rs1_reorder && in_rob_update_reorder != `ZERO_ROB_TAG) begin
                            out_slb_reorder1 <= `ZERO_ROB_TAG;
                            out_slb_value1 <= in_rob_update_value;
                        end else begin
                            out_slb_reorder1 <= in_reg_rs1_reorder;
                            out_slb_value1 <= in_reg_rs1_value;
                        end
                        out_reg_rd <= rd;
                        out_rob_rd <= rd; //!!!!!
                        case (funct3)
                            3'b0:begin //LB
                                out_rob_op <= `LB;
                                out_slb_op <= `LB;
                            end
                            3'b1:begin //LH
                                out_rob_op <= `LH;
                                out_slb_op <= `LH;
                            end
                            3'b10:begin //LW
                                out_rob_op <= `LW;
                                out_slb_op <= `LW;
                            end
                            3'b100:begin //LBU
                                out_rob_op <= `LBU;
                                out_slb_op <= `LBU;
                            end
                            3'b101:begin //LHU
                                out_rob_op <= `LHU;
                                out_slb_op <= `LHU;
                            end
                        endcase
                    end
                    7'b100011:begin //S-type
                        out_slb_imm <= {{21{in_fetcher_instr[31]}},in_fetcher_instr[30:25],in_fetcher_instr[11:7]};
                        out_slb_reorder <= in_rob_free_reorder;
                        if (in_rob_update_reorder == in_reg_rs1_reorder && in_rob_update_reorder != `ZERO_ROB_TAG) begin
                            out_slb_reorder1 <= `ZERO_ROB_TAG;
                            out_slb_value1 <= in_rob_update_value;
                        end else begin
                            out_slb_reorder1 <= in_reg_rs1_reorder;
                            out_slb_value1 <= in_reg_rs1_value;
                        end
                        if (in_rob_update_reorder == in_reg_rs2_reorder && in_rob_update_reorder != `ZERO_ROB_TAG) begin
                            out_slb_reorder2 <= `ZERO_ROB_TAG;
                            out_slb_value2 <= in_rob_update_value;
                        end else begin
                            out_slb_reorder2 <= in_reg_rs2_reorder;
                            out_slb_value2 <= in_reg_rs2_value;
                        end
                        case (funct3)
                            3'b0:begin //SB
                                out_rob_op <= `SB;
                                out_slb_op <= `SB;
                            end
                            3'b1:begin //SH
                                out_rob_op <= `SH;
                                out_slb_op <= `SH;
                            end
                            3'b10:begin //SW
                                out_rob_op <= `SW;
                                out_slb_op <= `SW;
                            end
                        endcase
                    end
                    7'b10011:begin //I-type
                        out_rs_reorder <= in_rob_free_reorder;
                        out_rob_rd <= rd;
                        //out_rob_reorder <= in_rob_free_reorder;
                        if (in_rob_update_reorder == in_reg_rs1_reorder && in_rob_update_reorder != `ZERO_ROB_TAG) begin
                            out_rs_rs1_reorder <= `ZERO_ROB_TAG;
                            out_rs_rs1_value <= in_rob_update_value;
                        end else begin
                            out_rs_rs1_reorder <= in_reg_rs1_reorder;
                            out_rs_rs1_value <= in_reg_rs1_value;
                        end //I forget to modify the last two type reorder.....
                        out_rs_imm = {{21{in_fetcher_instr[31]}},in_fetcher_instr[30:20]};
                        out_reg_rd <= rd;
                        case (funct3)
                            3'b0:begin //ADDI
                                out_rob_op <= `ADDI;
                                out_rs_op <= `ADDI;
                            end
                            3'b10:begin //SLTI
                                out_rob_op <= `SLTI;
                                out_rs_op <= `SLTI;
                            end
                            3'b11:begin //SLTIU
                                out_rob_op <= `SLTIU;
                                out_rs_op <= `SLTIU;
                            end
                            3'b100:begin //XORI
                                out_rob_op <= `XORI;
                                out_rs_op <= `XORI;
                            end
                            3'b110:begin //ORI
                                out_rob_op <= `ORI;
                                out_rs_op <= `ORI;
                            end
                            3'b111:begin //ANDI //write 110!!!
                                out_rob_op <= `ANDI;
                                out_rs_op <= `ANDI;
                            end
                            3'b1:begin //SLLI
                                out_rob_op <= `SLLI;
                                out_rs_op <= `SLLI;
                                out_rs_imm = {26'b0,in_fetcher_instr[25:20]};
                            end
                            3'b101:begin
                                out_rs_imm = {26'b0,in_fetcher_instr[25:20]};
                                case (funct7)
                                    7'b0:begin //SRLI
                                        out_rob_op <= `SRLI;
                                        out_rs_op <= `SRLI;
                                    end
                                    7'b100000:begin //SRAI
                                        out_rob_op <= `SRAI;
                                        out_rs_op <= `SRAI;
                                    end
                                endcase
                            end
                        endcase
                    end
                    7'b110011:begin //R-type
                        out_rs_reorder <= in_rob_free_reorder;
                        out_rob_rd <= rd;
                        //out_rob_reorder <= in_rob_free_reorder;
                        if (in_rob_update_reorder == in_reg_rs1_reorder && in_rob_update_reorder != `ZERO_ROB_TAG) begin
                            out_rs_rs1_reorder <= `ZERO_ROB_TAG;
                            out_rs_rs1_value <= in_rob_update_value;
                        end else begin
                            out_rs_rs1_reorder <= in_reg_rs1_reorder;
                            out_rs_rs1_value <= in_reg_rs1_value;
                        end
                        if (in_rob_update_reorder == in_reg_rs2_reorder && in_rob_update_reorder != `ZERO_ROB_TAG) begin
                            out_rs_rs2_reorder <= `ZERO_ROB_TAG;
                            out_rs_rs2_value <= in_rob_update_value;
                        end else begin
                            out_rs_rs2_reorder <= in_reg_rs2_reorder;
                            out_rs_rs2_value <= in_reg_rs2_value;
                        end
                        out_reg_rd <= rd;
                        case (funct3)
                            3'b0:begin 
                                case (funct7)
                                    7'b0:begin //ADD
                                        out_rob_op <= `ADD;
                                        out_rs_op <= `ADD;
                                    end
                                    7'b100000:begin //SUB
                                        out_rob_op <= `SUB;
                                        out_rs_op <= `SUB;
                                    end
                                endcase
                            end
                            3'b1:begin //SLL
                                out_rob_op <= `SLL;
                                out_rs_op <= `SLL;
                            end
                            3'b10:begin //SLT
                                out_rob_op <= `SLT;
                                out_rs_op <= `SLT;
                            end
                            3'b11:begin //SLTU
                                out_rob_op <= `SLTU;
                                out_rs_op <= `SLTU;
                            end
                            3'b100:begin //XOR
                                out_rob_op <= `XOR;
                                out_rs_op <= `XOR;
                            end
                            3'b101:begin 
                                case (funct7)
                                    7'b0:begin //SRL
                                        out_rob_op <= `SRL;
                                        out_rs_op <= `SRL;
                                    end
                                    7'b100000:begin //SRA
                                        out_rob_op <= `SRA;
                                        out_rs_op <= `SRA;
                                    end
                                endcase
                            end
                            3'b110:begin //OR
                                out_rob_op <= `OR;
                                out_rs_op <= `OR;
                            end
                            3'b111:begin //AND
                                out_rob_op <= `AND;
                                out_rs_op <= `AND;
                            end
                        endcase
                    end
                endcase
            end /*else if (in_fetcher_get_instr == `TRUE) begin
                out_fetcher_idle <= `FALSE;
            end*/
        end else if (rdy == `TRUE && in_decode_misbranch == `TRUE) begin
            out_slb_op <= `NOP;
            out_rs_op <= `NOP;
            out_rob_op <= `NOP;
            out_slb_reorder <= `ZERO_ROB_TAG;
            out_rs_reorder <= `ZERO_ROB_TAG;//!!!!!!!!!!!!
            out_reg_rd <= `ZERO_REG_TAG;//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        end else begin

        end
    end
endmodule