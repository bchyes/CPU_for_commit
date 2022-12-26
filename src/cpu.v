// RISCV32I CPU top module
// port modification allowed for debugging purposes
`include "alu.v"
`include "memCtrl.v"
`include "bp.v"
`include "constant.v"
`include "decode.v"
`include "fetch.v"
`include "register.v"
`include "rs.v"
`include "slb.v"
module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)
wire mem_from_fetcher_get_instr;
wire [`RAM_ADDRESS_WIDTH] mem_from_fetcher_get_address;
wire [`DATA_WIDTH] mem_out_data;
wire fetcher_from_mem_get_instr;
wire [`DATA_WIDTH] fetcher_to_decode_instr;
wire [`DATA_WIDTH] fetcher_to_decode_pc;
wire fetcher_to_decode_get_instr;
wire [`REG_TAG_WIDTH] decode_to_reg_rs1;
wire [`REG_TAG_WIDTH] decode_to_reg_rs2;
wire [`REG_TAG_WIDTH] decode_to_reg_rd;
wire [`ROB_TAG_WIDTH] decode_to_reg_reorder;
wire [`ROB_TAG_WIDTH] reg_to_decode_rs1_reorder;
wire [`DATA_WIDTH] reg_to_decode_rs1_value;
wire [`ROB_TAG_WIDTH] reg_to_decode_rs2_reorder;
wire [`DATA_WIDTH] reg_to_decode_rs2_value;
wire [`DATA_WIDTH] decode_pc;
wire [`DATA_WIDTH] decode_to_rs_imm;
wire [`INSIDE_OPCODE_WIDTH] decode_to_rs_op;
wire [`ROB_TAG_WIDTH] decode_to_rs_reorder;
wire [`ROB_TAG_WIDTH] decode_to_rs_rs1_reorder;
wire [`ROB_TAG_WIDTH] decode_to_rs_rs2_reorder;
wire [`DATA_WIDTH] decode_to_rs_rs1_value;
wire [`DATA_WIDTH] decode_to_rs_rs2_value;
wire [`ROB_TAG_WIDTH] rob_to_decode_reorder;
wire [`INSIDE_OPCODE_WIDTH] decode_to_rob_op;
wire [`REG_TAG_WIDTH] decode_to_rob_rd;
wire decode_to_rob_jump;
wire [`DATA_WIDTH] rs_to_alu_pc;
wire [`DATA_WIDTH] rs_to_alu_value_rs1;
wire [`DATA_WIDTH] rs_to_alu_value_rs2;
wire [`DATA_WIDTH] rs_to_alu_imm;
wire [`INSIDE_OPCODE_WIDTH] rs_to_alu_op;
wire [`ROB_TAG_WIDTH] rs_to_alu_reorder;
wire [`DATA_WIDTH] alu_to_rob_value;
wire [`ROB_TAG_WIDTH] alu_to_rob_reorder;
wire [`DATA_WIDTH] alu_to_rob_newpc;
wire [`REG_TAG_WIDTH] rob_to_reg_index;
wire [`DATA_WIDTH] rob_to_reg_value;
wire [`ROB_TAG_WIDTH] rob_to_reg_reorder;
wire [`INSIDE_OPCODE_WIDTH] decode_to_slb_op;
wire [`ROB_TAG_WIDTH] decode_to_slb_reorder;
wire [`DATA_WIDTH] decode_to_slb_imm;
wire [`DATA_WIDTH] decode_to_slb_value1;
wire [`DATA_WIDTH] decode_to_slb_value2;
wire [`ROB_TAG_WIDTH] decode_to_slb_reorder1;
wire [`ROB_TAG_WIDTH] decode_to_slb_reorder2;
wire slb_to_mem_get_data;
wire [2:0] slb_to_mem_get_size;
wire [`RAM_ADDRESS_WIDTH] slb_to_mem_get_address;
wire mem_to_slb_get_data;
//wire [`DATA_WIDTH] mem_to_slb_data;
wire slb_to_mem_signed;
wire rob_misbranch;
wire [`DATA_WIDTH] rob_misbranch_pc;
wire out_bp;
wire out_bp_jump;
wire [`BP_BRANCH_TAG] out_bp_tag;
wire rs_to_fetcher_idle;
wire rob_to_fetcher_idle;
wire slb_to_fetcher_idle;
wire [`BP_BRANCH_TAG] fetcher_to_bp_tag;
wire bp_to_fetcher_jump;
wire fetcher_to_decode_jump;
wire [`BP_BRANCH_TAG] rob_to_bp_tag;
wire [`DATA_WIDTH] slb_to_rob_mem_destination;
wire [`DATA_WIDTH] slb_to_rob_mem_value;
wire [`ROB_TAG_WIDTH] slb_to_rob_reorder;
wire [2:0] rob_to_mem_size;
wire [`RAM_ADDRESS_WIDTH] rob_to_mem_address;
wire [`DATA_WIDTH] rob_to_mem_data;
wire rob_to_mem_save_data;
wire mem_to_rob_save_data;
wire decode_to_fetcher_idle;
wire [`ROB_TAG_WIDTH] rob_to_rs_update_reorder;
wire [`DATA_WIDTH] rob_to_rs_update_value;
wire [`ROB_TAG_WIDTH] rob_to_slb_update_reorder;
wire [`DATA_WIDTH] rob_to_slb_update_value;
wire [`ROB_TAG_WIDTH] rob_to_decode_update_reorder;
wire [`DATA_WIDTH] rob_to_decode_update_value;

memCtrl memCtrl_unit(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .io_buffer_full(io_buffer_full),
  .mem_din(mem_din),
  .mem_dout(mem_dout),
  .mem_a(mem_a),
  .mem_wr(mem_wr),
  .in_mem_get_instr(mem_from_fetcher_get_instr),
  .in_mem_get_address(mem_from_fetcher_get_address),
  .out_data(mem_out_data),
  .out_mem_get_instr(fetcher_from_mem_get_instr),

  .in_mem_get_data(slb_to_mem_get_data),
  .in_mem_get_size(slb_to_mem_get_size),
  .in_mem_get_address_from_slb(slb_to_mem_get_address),
  .in_slb_signed(slb_to_mem_signed),
  .out_mem_get_data(mem_to_slb_get_data),

  .in_mem_save_data(rob_to_mem_save_data),
  .in_mem_save_size(rob_to_mem_size),
  .in_mem_get_address_from_rob(rob_to_mem_address),
  .in_mem_save_data_value(rob_to_mem_data),
  .out_mem_save_data(mem_to_rob_save_data),

  .in_mem_misbranch(rob_misbranch) //!!!!!!!!!!!!!!!!!!!
);

fetcher fetcher_unit(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .out_mem_get_instr(mem_from_fetcher_get_instr),
  .out_mem_pc(mem_from_fetcher_get_address),
  .in_mem_instr(mem_out_data),
  .in_mem_get_instr(fetcher_from_mem_get_instr),
  .out_instr(fetcher_to_decode_instr),
  .out_pc(fetcher_to_decode_pc),
  .out_decode_get_instr(fetcher_to_decode_get_instr),

  .in_rs_idle(rs_to_fetcher_idle),
  .in_rob_idle(rob_to_fetcher_idle),
  .in_slb_idle(slb_to_fetcher_idle),
  //.in_decode_idle(decode_to_fetcher_idle),

  .in_bp_jump(bp_to_fetcher_jump),
  .out_bp_tag(fetcher_to_bp_tag),
  .out_decode_jump(fetcher_to_decode_jump),

  .in_fetcher_misbranch_pc(rob_misbranch_pc),
  .in_fetcher_misbranch(rob_misbranch)
);

decode decode_unit(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .in_fetcher_get_instr(fetcher_to_decode_get_instr),
  .in_fetcher_instr(fetcher_to_decode_instr),
  .in_fetcher_pc(fetcher_to_decode_pc),
  .out_reg_rs1(decode_to_reg_rs1),
  .out_reg_rs2(decode_to_reg_rs2),
  .out_reg_rd(decode_to_reg_rd),
  .out_reg_reorder(decode_to_reg_reorder),
  .in_reg_rs1_reorder(reg_to_decode_rs1_reorder),
  .in_reg_rs2_reorder(reg_to_decode_rs2_reorder),
  .in_reg_rs1_value(reg_to_decode_rs1_value),
  .in_reg_rs2_value(reg_to_decode_rs2_value),

  .out_decode_pc(decode_pc),
  .out_rs_imm(decode_to_rs_imm),
  .out_rs_op(decode_to_rs_op),
  .out_rs_reorder(decode_to_rs_reorder),
  .out_rs_rs1_reorder(decode_to_rs_rs1_reorder),
  .out_rs_rs2_reorder(decode_to_rs_rs2_reorder),
  .out_rs_rs1_value(decode_to_rs_rs1_value),
  .out_rs_rs2_value(decode_to_rs_rs2_value),

  .out_rob_op(decode_to_rob_op),
  .out_rob_rd(decode_to_rob_rd),
  .out_rob_jump(decode_to_rob_jump),
  .in_rob_free_reorder(rob_to_decode_reorder),

  .in_rs_idle(rs_to_fetcher_idle),
  .in_rob_idle(rob_to_fetcher_idle),
  .in_slb_idle(slb_to_fetcher_idle),//is same as fetcher

  .out_slb_op(decode_to_slb_op),
  .out_slb_reorder(decode_to_slb_reorder),
  .out_slb_imm(decode_to_slb_imm),
  .out_slb_value1(decode_to_slb_value1),
  .out_slb_value2(decode_to_slb_value2),
  .out_slb_reorder1(decode_to_slb_reorder1),
  .out_slb_reorder2(decode_to_slb_reorder2),

  .in_decode_jump(fetcher_to_decode_jump),

  .in_decode_misbranch(rob_misbranch),

  //.out_fetcher_idle(decode_to_fetcher_idle)

  .in_rob_update_reorder(rob_to_decode_update_reorder),
  .in_rob_update_value(rob_to_decode_update_value)
);
rs rs_unit(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .in_decode_op(decode_to_rs_op),
  .in_decode_imm(decode_to_rs_imm),
  .in_decode_pc(decode_pc),
  .in_decode_reorder(decode_to_rs_reorder),
  .in_decode_reorder_rs1(decode_to_rs_rs1_reorder),
  .in_decode_reorder_rs2(decode_to_rs_rs2_reorder),
  .in_decode_value_rs1(decode_to_rs_rs1_value),
  .in_decode_value_rs2(decode_to_rs_rs2_value),

  .out_fetcher_idle(rs_to_fetcher_idle),

  .out_alu_op(rs_to_alu_op),
  .out_alu_value_rs1(rs_to_alu_value_rs1),
  .out_alu_value_rs2(rs_to_alu_value_rs2),
  .out_alu_imm(rs_to_alu_imm),
  .out_alu_pc(rs_to_alu_pc),
  .out_alu_reorder(rs_to_alu_reorder),

  .in_rs_misbranch(rob_misbranch),

  .in_rob_update_reorder(rob_to_rs_update_reorder),
  .in_rob_update_value(rob_to_rs_update_value)
  //.in_rob_update_reorder_from_slb(rob_to_slb_update_reorder),
  //.in_rob_update_value_from_slb(rob_to_slb_update_value)
  /*.in_reg_update_rs1_reorder(reg_to_decode_rs1_reorder),
  .in_reg_update_rs1_value(reg_to_decode_rs1_value),
  .in_reg_update_rs2_reorder(reg_to_decode_rs2_reorder),
  .in_reg_update_rs2_value(reg_to_decode_rs2_value) //to avoid missing*/ //it is wrong
  //.out_reg_update_reorder(out_reg_reorder),
  //.out_reg_update_value(out_reg_value)??


  //.in_alu_update_reorder(alu_to_rob_reorder),
  //.in_alu_update_value(alu_to_rob_value) //to avoid missing
);

rob rob_unit(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .in_decode_op(decode_to_rob_op),
  .in_decode_rd(decode_to_rob_rd),
  .in_decode_pc(decode_pc),
  .in_decode_jump(decode_to_rob_jump),

  .out_decode_reorder(rob_to_decode_reorder),

  .out_fetcher_idle(rob_to_fetcher_idle),

  .in_alu_value(alu_to_rob_value),
  .in_alu_reorder(alu_to_rob_reorder),
  .in_alu_newpc(alu_to_rob_newpc),

  .in_slb_destination(slb_to_rob_mem_destination),
  .in_slb_value(slb_to_rob_mem_value),
  .in_slb_reorder(slb_to_rob_reorder),

  .out_reg_index(rob_to_reg_index),
  .out_reg_value(rob_to_reg_value),
  .out_reg_value_reorder(rob_to_reg_reorder),

  .out_mem_size(rob_to_mem_size),
  .out_mem_address(rob_to_mem_address),
  .out_mem_data(rob_to_mem_data),
  .out_mem_save_data(rob_to_mem_save_data),
  .in_mem_save_data(mem_to_rob_save_data),

  .out_misbranch(rob_misbranch),
  .out_misbranch_newpc(rob_misbranch_pc),
  .out_bp(rob_to_bp),
  .out_bp_jump(rob_to_bp_jump),
  .out_bp_tag(rob_to_bp_tag),

  .out_rs_update_reorder(rob_to_rs_update_reorder),
  .out_rs_update_value(rob_to_rs_update_value),
  .out_slb_update_reorder(rob_to_slb_update_reorder),
  .out_slb_update_value(rob_to_slb_update_value),
  .out_decode_update_reorder(rob_to_decode_update_reorder),
  .out_decode_update_value(rob_to_decode_update_value)
);

register register_unit(
 .clk(clk_in),
 .rst(rst_in),
 .rdy(rdy_in),
 .in_decode_rs1(decode_to_reg_rs1),
 .in_decode_rs2(decode_to_reg_rs2),
 .in_decode_rd(decode_to_reg_rd),
 .in_decode_reorder(decode_to_reg_reorder),
 .out_reg_rs1_reorder(reg_to_decode_rs1_reorder),
 .out_reg_rs1_value(reg_to_decode_rs1_value),
 .out_reg_rs2_reorder(reg_to_decode_rs2_reorder),
 .out_reg_rs2_value(reg_to_decode_rs2_value),

 .in_rob_index(rob_to_reg_index),
 .in_rob_value(rob_to_reg_value),
 .in_rob_reorder(rob_to_reg_reorder),
 //.out_reg_update_reorder(),
 //.out_reg_update_value()

 .in_reg_misbranch(rob_misbranch)
);

alu alu_unit(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .in_rs_op(rs_to_alu_op),
  .in_rs_value_rs1(rs_to_alu_value_rs1),
  .in_rs_value_rs2(rs_to_alu_value_rs2),
  .in_rs_value_imm(rs_to_alu_imm),
  .in_rs_pc(rs_to_alu_pc),
  .in_rs_reorder(rs_to_alu_reorder),

  .out_rob_value(alu_to_rob_value),
  .out_update_reorder(alu_to_rob_reorder),
  .out_rob_newpc(alu_to_rob_newpc)
);

slb slb_unit(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  
  .in_decode_op(decode_to_slb_op),
  .in_decode_imm(decode_to_slb_imm),
  .in_decode_reorder(decode_to_slb_reorder),
  .in_decode_value1(decode_to_slb_value1),
  .in_decode_value2(decode_to_slb_value2),
  .in_decode_reorder1(decode_to_slb_reorder1),
  .in_decode_reorder2(decode_to_slb_reorder2),

  .out_fetcher_idle(slb_to_fetcher_idle),

  .out_mem_get_data(slb_to_mem_get_data),
  .out_mem_get_size(slb_to_mem_get_size),
  .out_mem_address(slb_to_mem_get_address),
  .out_mem_signed(slb_to_mem_signed),

  .out_rob_mem_destination(slb_to_rob_mem_destination),
  .out_rob_mem_value(slb_to_rob_mem_value),
  .out_rob_reorder(slb_to_rob_reorder),

  .in_mem_get_data(mem_to_slb_get_data),
  .in_mem_data(mem_out_data),

  .in_slb_misbranch(rob_misbranch),

  .in_rob_update_reorder(rob_to_slb_update_reorder),
  .in_rob_update_value(rob_to_slb_update_value)
  //.in_rob_update_reorder_from_rs(rob_to_rs_update_reorder),
  //.in_rob_update_value_from_rs(rob_to_rs_update_value)
  /*.in_reg_update_rs1_reorder(reg_to_decode_rs1_reorder),
  .in_reg_update_rs1_value(reg_to_decode_rs1_value),
  .in_reg_update_rs2_reorder(reg_to_decode_rs2_reorder),
  .in_reg_update_rs2_value(reg_to_decode_rs2_value)*/ //it is wrong
);

bp bp_unit(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  
  .in_fetcher_tag(fetcher_to_bp_tag),
  .out_fetcher_jump(bp_to_fetcher_jump),

  .in_rob_bp(rob_to_bp),
  .in_rob_jump(rob_to_bp_jump),
  .in_rob_tag(rob_to_bp_tag)
);
endmodule