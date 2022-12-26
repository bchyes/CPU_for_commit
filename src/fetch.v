module fetcher(
    input clk,
    input rst,
    input rdy,
    //Fetcher has got instr from Mem
    input in_mem_get_instr, //bool
    input [`DATA_WIDTH] in_mem_instr,

    input in_slb_idle,
    input in_rob_idle,
    input in_rs_idle,
    //input in_decode_idle,//for get reorder in decode (I can't solve it)

    //Output instr for next stage.
    output reg [`DATA_WIDTH] out_instr,
    output reg [`DATA_WIDTH] out_pc,
    output reg out_decode_get_instr,
    //Ask Mem to get instr from pc.
    output reg out_mem_get_instr, //bool
    output reg [`DATA_WIDTH] out_mem_pc,

    input in_bp_jump,
    output reg out_decode_jump,
    output [`BP_BRANCH_TAG] out_bp_tag,

    input in_fetcher_misbranch,
    input [`DATA_WIDTH] in_fetcher_misbranch_pc
);
    localparam IDLE = 2'b0,WAIT_MEM = 2'b1,WAIT_IDLE = 2'b10;//WAIT_IDLE -> RS,ROB,SLB
    reg [2:0] state;
    reg [24:0] icache_tag [(`ICACHE_SIZE-1):0]; //??? how to know 24
    reg [`DATA_WIDTH] icache_instr [(`ICACHE_SIZE-1):0];
    reg icache_valid [(`ICACHE_SIZE-1):0];
    reg [`DATA_WIDTH] pc;
    wire next_idle;
    assign next_idle = in_slb_idle && in_rs_idle && in_rob_idle /*&& in_decode_idle*/;//

    reg wait_reorder_for_icache;

    reg debug;

    assign out_bp_tag = pc[`BP_HASH_TAG];

    wire [`DATA_WIDTH] debug_icache;
    assign debug_icache = icache_instr[44];

    integer i;
    always @(posedge clk) begin
        if (rst == `TRUE) begin
            state <= IDLE;
            pc <= `ZERO_DATA;
            out_mem_get_instr <= `FALSE;
            out_mem_pc <= `ZERO_DATA;
            out_instr <= `ZERO_DATA;
            out_pc <= `ZERO_DATA;
            out_decode_get_instr <= `FALSE;
            debug <= `FALSE;
            for (i = 1;i < `ICACHE_SIZE;i = i + 1) begin
                icache_valid[i] <= `FALSE;
            end
            wait_reorder_for_icache <= `FALSE;
        end else if (rdy == `TRUE) begin
            out_mem_get_instr <= `FALSE;
            out_decode_get_instr <= `FALSE;
            debug <= `FALSE;
            out_decode_jump <= `FALSE;//?
            wait_reorder_for_icache <= `FALSE;//?? sometime it can't return to false
            if (in_fetcher_misbranch == `TRUE) begin
                pc <= in_fetcher_misbranch_pc;
                state <= IDLE;
                out_mem_get_instr <= `FALSE;
                out_mem_pc <= `ZERO_DATA;
                out_instr <= `ZERO_DATA;
                out_pc <= `ZERO_DATA;
                out_decode_get_instr <= `FALSE;
                //in_mem_instr <= `ZERO_DATA;
                debug <= `FALSE;
                for (i = 1;i < `ICACHE_SIZE;i = i + 1) begin
                    icache_valid[i] <= `FALSE;
                end
            end else begin
                if (next_idle == `FALSE) begin
                    state <= WAIT_IDLE;
                end else if (state == IDLE) begin
                    if (icache_valid[pc[`ICACHE_TAG_WIDTH]] == `TRUE && icache_tag[pc[`ICACHE_INDEX_WIDTH]] == pc[`ICACHE_TAG_WIDTH]) begin
                        if (wait_reorder_for_icache == `TRUE) begin
                            wait_reorder_for_icache <= `FALSE;
                            debug <= `TRUE;
                            out_instr <= icache_instr[pc[`ICACHE_INDEX_WIDTH]];
                            out_pc <= pc;
                            out_decode_get_instr <= `TRUE;
                            if (next_idle == `TRUE) begin
                                
                                state = IDLE;
                                if (icache_instr[pc[`ICACHE_INDEX_WIDTH]][`OPCODE_WIDTH] == 7'b1101111) begin //JAL
                                    pc <= pc + {{12{icache_instr[pc[`ICACHE_INDEX_WIDTH]][31]}}, icache_instr[pc[`ICACHE_INDEX_WIDTH]][19:12], icache_instr[pc[`ICACHE_INDEX_WIDTH]][20], icache_instr[pc[`ICACHE_INDEX_WIDTH]][30:25], icache_instr[pc[`ICACHE_INDEX_WIDTH]][24:21], 1'b0};
                                end else if (icache_instr[pc[`ICACHE_INDEX_WIDTH]][`OPCODE_WIDTH] == 7'b1100011) begin //B_type
                                    if (in_bp_jump == `TRUE) begin
                                        out_decode_jump <= `TRUE;
                                        pc <= pc + {{20{icache_instr[pc[`ICACHE_INDEX_WIDTH]][31]}}, icache_instr[pc[`ICACHE_INDEX_WIDTH]][7], icache_instr[pc[`ICACHE_INDEX_WIDTH]][30:25], icache_instr[pc[`ICACHE_INDEX_WIDTH]][11:8], 1'b0};
                                        //out_decode_bp_tag <= pc[`BP_HASH_TAG];
                                    end else begin
                                        out_decode_jump <= `FALSE;
                                        pc <= pc + 4;
                                        //out_decode_bp_tag <= pc[`BP_HASH_TAG];
                                    end
                                end else begin
                                    pc <= pc + 4;
                                end
                            end else begin
                                state = WAIT_IDLE;
                            end
                        end else begin
                            wait_reorder_for_icache <= `TRUE;
                        end
                    end else begin
                        state = WAIT_MEM;
                        out_mem_get_instr <= `TRUE;
                        out_mem_pc <= pc;
                    end
                end else if (state == WAIT_MEM) begin
                    if (in_mem_get_instr == `TRUE) begin
                        out_instr <= in_mem_instr;
                        out_pc <= pc;
                        out_decode_get_instr <= `TRUE;
                        icache_valid[pc[`ICACHE_INDEX_WIDTH]] <= `TRUE;
                        icache_tag[pc[`ICACHE_INDEX_WIDTH]] <= pc[`ICACHE_TAG_WIDTH];
                        icache_instr[pc[`ICACHE_INDEX_WIDTH]] <= in_mem_instr;
                        if (next_idle == `TRUE) begin
                            
                            state = IDLE;
                            if (in_mem_instr[`OPCODE_WIDTH] == 7'b1101111) begin //JAL
                                pc <= pc + {{12{in_mem_instr[31]}}, in_mem_instr[19:12], in_mem_instr[20], in_mem_instr[30:25], in_mem_instr[24:21], 1'b0};
                            end else if (in_mem_instr[`OPCODE_WIDTH] == 7'b1100011) begin //B_type
                                if (in_bp_jump == `TRUE) begin
                                    out_decode_jump <= `TRUE;
                                    pc <= pc + {{20{in_mem_instr[31]}}, in_mem_instr[7], in_mem_instr[30:25], in_mem_instr[11:8], 1'b0};
                                    //out_decode_bp_tag <= pc[`BP_HASH_TAG];
                                end else begin
                                    out_decode_jump <= `FALSE;
                                    pc <= pc + 4;
                                    //out_decode_bp_tag <= pc[`BP_HASH_TAG];
                                end
                            end else begin
                                pc <= pc + 4;
                            end
                        end else begin
                        state = WAIT_IDLE;
                        end
                    end
                end else if (state == WAIT_IDLE && next_idle == `TRUE) begin
                    state <= IDLE;
                    /*if (next_idle == `TRUE) begin
                        
                        state <= IDLE;
                        if (out_instr[`OPCODE_WIDTH] == 7'b1101111) begin //JAL
                            pc <= pc + {{12{out_instr[31]}}, out_instr[19:12], out_instr[20], out_instr[30:25], out_instr[24:21], 1'b0};
                        end else if (out_instr[`OPCODE_WIDTH] == 7'b1100011) begin //B_type
                            if (in_bp_jump == `TRUE) begin
                                    out_decode_jump <= `TRUE;
                                    pc <= pc + {{20{out_instr[31]}}, out_instr[7], out_instr[30:25], out_instr[11:8], 1'b0};
                                    //out_decode_bp_tag <= pc[`BP_HASH_TAG];
                                end else begin
                                    out_decode_jump <= `FALSE;
                                    pc <= pc + 4;
                                    //out_decode_bp_tag <= pc[`BP_HASH_TAG];
                                end
                        end else begin
                            pc <= pc + 4;
                        end
                    end*/
                    //wait_reorder_for_icache <= `TRUE;
                    out_decode_get_instr <= `TRUE;
                    //!!!!!!!!!!!!!!!!!!!!!!!!!!! to solve the problem about halt.
                end
            end
        end else begin
            //nothing to do when rdy == `FALSE
        end
    end
endmodule