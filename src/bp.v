`include "constant.v"
module bp(
    input clk,
    input rst,
    input rdy,

    input [`BP_BRANCH_TAG] in_fetcher_tag,
    output wire out_fetcher_jump,

    input in_rob_bp, //know the B-type instr
    input in_rob_jump, //know the B-type instr jump or not 
    input [`BP_BRANCH_TAG] in_rob_tag
);
    reg [1:0] predictor_table [(`BP_SIZE-1):0];
    assign out_fetcher_jump = predictor_table[in_fetcher_tag][1];

    integer i;
  always @(posedge clk) begin
    if (rst == `TRUE) begin
        for (i = 0;i < `BP_SIZE;i = i + 1) begin
            predictor_table[i] <= 2'b01;
        end
    end else if (rdy == `TRUE) begin
        if (in_rob_bp == `TRUE) begin
            if (in_rob_jump == `TRUE) begin
                predictor_table[in_rob_tag] <= predictor_table[in_rob_tag] + ((predictor_table[in_rob_tag] == 2'b11) ? 0 : 1);
            end else begin
                predictor_table[in_rob_tag] <= predictor_table[in_rob_tag] - ((predictor_table[in_rob_tag] == 2'b00) ? 0 : 1);
            end
        end
    end
  end

endmodule