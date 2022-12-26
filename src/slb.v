module slb(
    input clk,
    input rst,
    input rdy,
    
    //input reg in_decode_get_data;
    input [`INSIDE_OPCODE_WIDTH] in_decode_op,
    input [`ROB_TAG_WIDTH] in_decode_reorder,//to know whether a instr in coming.(No by reorder == `ZERO_ROB_TAG)
    input [`DATA_WIDTH] in_decode_imm,
    input [`DATA_WIDTH] in_decode_value1,
    input [`DATA_WIDTH] in_decode_value2,
    input [`ROB_TAG_WIDTH] in_decode_reorder1,
    input [`ROB_TAG_WIDTH] in_decode_reorder2,

    input [`DATA_WIDTH] in_rob_update_value,
    input [`ROB_TAG_WIDTH] in_rob_update_reorder,//from slb
    //input [`ROB_TAG_WIDTH] in_rob_update_reorder_from_rs,
    //input [`DATA_WIDTH] in_rob_update_value_from_rs,
    /*input [`ROB_TAG_WIDTH] in_reg_update_rs1_reorder,
    input [`DATA_WIDTH] in_reg_update_rs1_value,
    input [`ROB_TAG_WIDTH] in_reg_update_rs2_reorder,
    input [`DATA_WIDTH] in_reg_update_rs2_value,*/

    output out_fetcher_idle,

    input in_slb_misbranch,

    input in_mem_get_data,
    input [`DATA_WIDTH] in_mem_data,
    output reg out_mem_get_data, //ask mem to get data
    output reg [2:0] out_mem_get_size, //data bite from mem
    output reg [`RAM_ADDRESS_WIDTH] out_mem_address,
    output reg out_mem_signed,

    output reg [`DATA_WIDTH] out_rob_mem_destination, //to rob for commit to mem
    output reg [`DATA_WIDTH] out_rob_mem_value,
    //output reg out_rob_signed,
    output reg [`ROB_TAG_WIDTH] out_rob_reorder
    //output reg out_io_load //0x30000 for load
);
    localparam IDLE = 1'b0,WAIT_MEM = 1'b1;
    reg status; //above status
    reg busy [(`SLB_SIZE-1):0];
    wire ready_to_issue [(`SLB_SIZE-1):0]; //ready to save/load
    wire ready_to_calculate [(`SLB_SIZE-1):0]; //ready to calculate address
    reg address_ready [(`SLB_SIZE-1):0];
    wire [`SLB_TAG_WIDTH] calculate_tag;//can execute out_of_order
    reg [`SLB_TAG_WIDTH] head;
    reg [`SLB_TAG_WIDTH] tail;
    reg [`INSIDE_OPCODE_WIDTH] ops [(`SLB_SIZE-1):0];
    reg [`RAM_ADDRESS_WIDTH] address [(`SLB_SIZE-1):0];
    reg [`DATA_WIDTH] value1 [(`SLB_SIZE-1):0];
    reg [`DATA_WIDTH] value2 [(`SLB_SIZE-1):0];
    reg [`ROB_TAG_WIDTH] reorder1 [(`SLB_SIZE-1):0];
    reg [`ROB_TAG_WIDTH] reorder2 [(`SLB_SIZE-1):0];
    reg [`ROB_TAG_WIDTH] rd_reorder [(`SLB_SIZE-1):0];
    reg [`DATA_WIDTH] imms [(`SLB_SIZE-1):0];

    wire [`SLB_TAG_WIDTH] nextPtr;
    wire [`SLB_TAG_WIDTH] nowPtr;
    assign nextPtr = tail % (`SLB_SIZE-1) + 1; // 1 - 15
    assign nowPtr = head % (`SLB_SIZE-1) + 1;

    assign out_fetcher_idle = (nextPtr != head);

    reg debug_ready;
    reg debug_address;
    reg [`ROB_TAG_WIDTH] debug_reorder2;

    wire [`ROB_TAG_WIDTH] debug_reorder_10;
    wire [`ROB_TAG_WIDTH] debug_reorder_9;
    assign debug_reorder_10 = rd_reorder[10];
    assign debug_reorder_9 = rd_reorder[9];
    wire [`ROB_TAG_WIDTH] debug_reorder_8;
    assign debug_reorder_8 = rd_reorder[8];

    wire [`ROB_TAG_WIDTH] debug_reorder1_3;
    assign debug_reorder1_3 = reorder1[3];
    wire [`ROB_TAG_WIDTH] debug_reorder2_3;
    assign debug_reorder2_3 = reorder2[3];
    wire [`ROB_TAG_WIDTH] debug_reorder1_1;
    assign debug_reorder1_1 = reorder1[1];
    wire [`ROB_TAG_WIDTH] debug_reorder2_1;
    assign debug_reorder2_1 = reorder2[1];
    wire [`ROB_TAG_WIDTH] debug_reorder1_2;
    assign debug_reorder1_2 = reorder1[2];
    wire [`ROB_TAG_WIDTH] debug_reorder2_2;
    assign debug_reorder2_2 = reorder2[2];

    wire [`ROB_TAG_WIDTH] debug_reorder1_6;
    assign debug_reorder1_6 = reorder1[6];
    wire [`ROB_TAG_WIDTH] debug_reorder2_6;
    assign debug_reorder2_6 = reorder2[6];
    wire [`DATA_WIDTH] debug_value1_6;
    assign debug_value1_6 = value1[6];
    wire [`DATA_WIDTH] debug_value2_6;
    assign debug_value2_6 = value2[6];
    wire [`DATA_WIDTH] debug_imms_6;
    assign debug_imms_6 = imms[6];
    wire [`ROB_TAG_WIDTH] debug_reorder1_9;
    assign debug_reorder1_9 = reorder1[9];
    wire [`ROB_TAG_WIDTH] debug_reorder2_9;
    assign debug_reorder2_9 = reorder2[9];
    wire [`DATA_WIDTH] debug_value1_9;
    assign debug_value1_9 = value1[9];
    wire [`DATA_WIDTH] debug_value2_9;
    assign debug_value2_9 = value2[9];
    wire [`DATA_WIDTH] debug_imms_9;
    assign debug_imms_9 = imms[9];
    wire [`INSIDE_OPCODE_WIDTH] debug_ops_9;
    assign debug_ops_9 = ops[9];
    reg debug_in;
    reg [`DATA_WIDTH] debug_value;

    wire ready_issue_1;
    assign ready_issue_1 = ready_to_issue[1];
    wire busy_1;
    assign busy_1 = busy[1];
    wire address_ready_1;
    assign address_ready_1 = address_ready[1];
    wire [`INSIDE_OPCODE_WIDTH] op_1;
    assign op_1 = ops[1];


    genvar i;
    generate
        for (i = 1;i < `SLB_SIZE;i = i + 1) begin
            assign ready_to_issue[i] = (busy[i] == `TRUE) && (reorder2[i] == `ZERO_ROB_TAG) && (address_ready[i] == `TRUE);
            assign ready_to_calculate[i] = (busy[i] == `TRUE) && (reorder1[i] == `ZERO_ROB_TAG) && (address_ready[i] == `FALSE);
        end
    endgenerate

    assign calculate_tag = ready_to_calculate[1] ? 1 :
                           ready_to_calculate[2] ? 2 :
                           ready_to_calculate[3] ? 3 :
                           ready_to_calculate[4] ? 4 :
                           ready_to_calculate[5] ? 5 :
                           ready_to_calculate[6] ? 6 :
                           ready_to_calculate[7] ? 7 :
                           ready_to_calculate[8] ? 8 :
                           ready_to_calculate[9] ? 9 :
                           ready_to_calculate[10] ? 10 :
                           ready_to_calculate[11] ? 11 :
                           ready_to_calculate[12] ? 12 :
                           ready_to_calculate[13] ? 13 :
                           ready_to_calculate[14] ? 14 :
                           ready_to_calculate[15] ? 15 : `ZERO_SLB_TAG;
    
    integer j;
  always @(posedge clk) begin
    if (rst == `TRUE) begin
        head <= 0;
        tail <= 0;
        out_mem_get_data <= `FALSE;
        out_rob_reorder <= `ZERO_ROB_TAG;
        status <= IDLE;
        for (j = 0;j < `SLB_SIZE;j = j + 1) begin
            busy[j] <= `FALSE;
            address_ready[j] <= `FALSE;
        end
        debug_in <= `FALSE;
        debug_value <= `ZERO_DATA;
    end else if (rdy == `TRUE && in_slb_misbranch == `FALSE) begin
        //if (debug_in == `TRUE) begin
        //    $display("This is a test number: %b.", value1[6]);
        //    $display("This is a test number: %b.", debug_value1_6);
        //end
        out_mem_get_data <= `FALSE;
        //out_io_load <= `FALSE;
        out_rob_mem_destination <= `ZERO_DATA;
        out_rob_reorder <= `ZERO_ROB_TAG;
        debug_ready <= ready_to_issue[3];
        debug_address <= address_ready[3];
        debug_reorder2 <= reorder2[3];
        //debug_in = `FALSE;
        //debug_value <= `ZERO_DATA;
        if (ready_to_issue[nowPtr] == `TRUE) begin
            if (status == IDLE) begin
                case (ops[nowPtr])
                    `NOP:begin end //?????
                    `SB,`SW,`SH:begin
                        status <= IDLE;
                        out_rob_mem_destination <= address[nowPtr];
                        out_rob_mem_value <= value2[nowPtr];
                        out_rob_reorder <= rd_reorder[nowPtr];
                        busy[nowPtr] <= `FALSE;
                        address_ready[nowPtr] <= `FALSE;
                        head <= nowPtr; 
                    end
                    `LB,`LBU:begin
                        /*if (address[nowPtr] == `IO_ADDRESS) begin
                            status <= IDLE;
                            out_rob_reorder <= rd_reorder[nowPtr];
                            busy[nowPtr] <= `FALSE;
                            address_ready[nowPtr] <= `FALSE;
                            head <= `FALSE;
                            out_io_load <= `TRUE;
                        end else */begin
                            status <= WAIT_MEM;
                            out_mem_get_data <= `TRUE;
                            //out_rob_signed <= (ops[nowPtr] == `LB) ? 1 : 0;
                            out_mem_signed <= (ops[nowPtr] == `LB) ? 1 : 0;
                            out_mem_get_size <= 1;
                            out_mem_address <= address[nowPtr];
                        end
                    end
                    `LH,`LHU:begin
                        status <= WAIT_MEM;
                        out_mem_get_data <= `TRUE;
                        //out_rob_signed <= (ops[nowPtr] == `LH) ? 1 : 0;
                        out_mem_signed <= (ops[nowPtr] == `LH) ? 1 : 0;
                        out_mem_get_size <= 2;
                        out_mem_address <= address[nowPtr];
                    end
                    `LW:begin
                        status <= WAIT_MEM;
                        out_mem_get_data <= `TRUE;
                        out_mem_get_size <= 4;
                        out_mem_address <= address[nowPtr];
                    end
                endcase
            end else if (status == WAIT_MEM) begin
                if (in_mem_get_data == `TRUE) begin
                    out_rob_reorder <= rd_reorder[nowPtr];
                    out_rob_mem_value <= in_mem_data;
                    status <= IDLE;
                    busy[nowPtr] <= `FALSE;
                    address_ready[nowPtr] <= `FALSE;
                    head <= nowPtr;
                end
            end
        end
        if (calculate_tag != `ZERO_SLB_TAG) begin
            address[calculate_tag] <= value1[calculate_tag] + imms[calculate_tag];
            address_ready[calculate_tag] <= `TRUE;
        end
        if (in_decode_reorder != `ZERO_ROB_TAG) begin
            busy[nextPtr] <= `TRUE;
            tail <= nextPtr;
            rd_reorder[nextPtr] <= in_decode_reorder;
            ops[nextPtr] <= in_decode_op;
            address_ready[nextPtr] <= `FALSE;
            imms[nextPtr] <= in_decode_imm;
            //debug_in <= `TRUE;
            //debug_value <= in_decode_value1;
            value1[nextPtr] <= in_decode_value1;
            value2[nextPtr] <= in_decode_value2;
            reorder1[nextPtr] <= in_decode_reorder1;
            reorder2[nextPtr] <= in_decode_reorder2;
            if (in_decode_reorder1 != `ZERO_ROB_TAG && in_decode_reorder1 == in_rob_update_reorder) begin
                reorder1[nextPtr] <= `ZERO_ROB_TAG;
                value1[nextPtr] <= in_rob_update_value;
            end
            if (in_decode_reorder2 != `ZERO_ROB_TAG && in_decode_reorder2 == in_rob_update_reorder) begin
                reorder2[nextPtr] <= `ZERO_ROB_TAG;
                value2[nextPtr] <= in_rob_update_value;
            end//!!!!!!!!!
            /*if (in_decode_reorder1 != `ZERO_ROB_TAG && in_decode_reorder1 == in_rob_update_reorder_from_rs) begin
                reorder1[nextPtr] <= `ZERO_ROB_TAG;
                value1[nextPtr] <= in_rob_update_value_from_rs;
            end
            if (in_decode_reorder2 != `ZERO_ROB_TAG && in_decode_reorder2 == in_rob_update_reorder_from_rs) begin
                reorder2[nextPtr] <= `ZERO_ROB_TAG;
                value2[nextPtr] <= in_rob_update_value_from_rs;
            end//!!!!!!!!!*/
            /*if (in_decode_reorder1 != `ZERO_ROB_TAG && in_decode_reorder1 == in_reg_update_rs1_reorder) begin
                reorder1[nextPtr] <= `ZERO_ROB_TAG;
                value1[nextPtr] <= in_reg_update_rs1_value;
            end
            if (in_decode_reorder2 != `ZERO_ROB_TAG && in_decode_reorder2 == in_reg_update_rs2_reorder) begin
                reorder2[nextPtr] <= `ZERO_ROB_TAG;
                value2[nextPtr] <= in_reg_update_rs2_value;
            end//!!!!!!!!!*/
        end
        if (in_rob_update_reorder != `ZERO_ROB_TAG) begin
            for (j = 1;j < `SLB_SIZE;j = j + 1) begin
                if (busy[j] == `TRUE) begin
                    if (reorder1[j] == in_rob_update_reorder) begin
                        reorder1[j] <= `ZERO_ROB_TAG;
                        value1[j] <= in_rob_update_value;
                        //if (j == 6 && in_rob_update_reorder == 11) begin
                            //debug_in = `TRUE;
                            //debug_value <= value1[6];
                            //if (in_rob_update_value == 5024) begin
                            //    value1[6] <= 5024;
                            //end
                            //$display("This is a test number: %b.", value1[6]);
                        //end
                    end
                    if (reorder2[j] == in_rob_update_reorder) begin
                        reorder2[j] <= `ZERO_ROB_TAG;
                        value2[j] <= in_rob_update_value;
                    end
                end
            end
        end
        /*if (in_rob_update_reorder_from_rs != `ZERO_ROB_TAG) begin
            for (j = 1;j < `SLB_SIZE;j = j + 1) begin
                if (busy[j] == `TRUE) begin
                    if (reorder1[j] == in_rob_update_reorder_from_rs) begin
                        reorder1[j] = `ZERO_ROB_TAG;
                        value1[j] = in_rob_update_value_from_rs;
                    end
                    if (reorder2[j] == in_rob_update_reorder_from_rs) begin
                        reorder2[j] = `ZERO_ROB_TAG;
                        value2[j] = in_rob_update_value_from_rs;
                    end
                end
            end
        end*/
        //if (debug_in == `TRUE) begin
        //    $display("This is a test number: %b.", value1[6]);
        //end
    end else if (rdy == `TRUE && in_slb_misbranch == `TRUE) begin
        head <= 0;
        tail <= 0;
        out_mem_get_data <= `FALSE;
        out_rob_reorder <= `ZERO_ROB_TAG;
        status <= IDLE;
        for (j = 0;j < `SLB_SIZE;j = j + 1) begin
            busy[j] <= `FALSE;
            address_ready[j] <= `FALSE;
            reorder1[j] = `ZERO_ROB_TAG;
            reorder2[j] = `ZERO_ROB_TAG;//!
        end
    end
    else begin
        //nothing to de when rdy == `FALSE;
    end
  end
endmodule