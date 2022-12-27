`include "constant.v"
module memCtrl(
    input clk,
    input rst,
    input rdy,
    input io_buffer_full,
    
    input [`RAM_DATA_WIDTH] mem_din,
    output reg [`RAM_DATA_WIDTH] mem_dout,
    output reg [`RAM_ADDRESS_WIDTH] mem_a,
    output reg mem_wr, // 0 for read, 1 for write

    output reg [`DATA_WIDTH] out_data,

    //instr
    input in_mem_get_instr, // can get instr
    input [`RAM_ADDRESS_WIDTH] in_mem_get_address,
    output reg out_mem_get_instr, //have output instr

    //load
    input in_mem_get_data,
    input [2:0] in_mem_get_size,
    input [`RAM_ADDRESS_WIDTH] in_mem_get_address_from_slb,
    input in_slb_signed,

    output reg out_mem_get_data,
    //output reg [`DATA_WIDTH] out_slb_data

    //save
    input in_mem_save_data,
    input [2:0] in_mem_save_size,
    input [`RAM_ADDRESS_WIDTH] in_mem_get_address_from_rob,
    input [`DATA_WIDTH] in_mem_save_data_value,

    input in_mem_misbranch,
    
    output reg out_mem_save_data

);
    reg [3:0] stage; //the cycle that datas read/write
    reg [2:0] status; // below status
    localparam IDLE = 0,FETCHER_READ = 1,SLB_READ = 2,ROB_WRITE = 3/*,IO_READ = 4*/;
    wire [2:0] buffered_status;

    assign buffered_status = (wb_is_empty == `FALSE) ? ROB_WRITE :
                                (slb_flag == `TRUE) ? SLB_READ :
                                    (fetcher_flag == `TRUE) ? FETCHER_READ : IDLE;

    reg fetcher_flag; //can get instr
    reg slb_flag; //can load data
    
    //write buffer from reorder buffer to store data
    wire wb_is_empty;
    wire wb_is_full;
    reg [`WB_TAG_WIDTH] head;
    reg [`WB_TAG_WIDTH] tail;
    reg [`DATA_WIDTH] wb_data [(`WB_SIZE-1):0];
    reg [`DATA_WIDTH] wb_addr [(`WB_SIZE-1):0];
    reg [2:0] wb_size [(`WB_SIZE-1):0];
    wire [`WB_TAG_WIDTH] nextPtr = (tail + 1) % (`WB_SIZE);
    wire [`WB_TAG_WIDTH] nowPtr = (head + 1) % (`WB_SIZE);
    assign wb_is_empty = (head == tail) ? `TRUE : `FALSE;
    assign wb_is_full = (nextPtr == head) ? `TRUE : `FALSE;

    wire disable_to_write = (io_buffer_full == `TRUE || wait_uart != 0) && (wb_addr[nowPtr][17:16] == 2'b11);
    reg [1:0] wait_uart;
    wire [7:0] buffered_write_data;

    assign buffered_write_data = (stage == 0) ? wb_data[nowPtr][7:0] :
                                    (stage == 1) ? wb_data[nowPtr][15:8] :
                                        (stage == 2) ? wb_data[nowPtr][23:16] : wb_data[nowPtr][31:24];

    reg rob_flag;


  always @(posedge clk) begin
    if (rst == `TRUE) begin
        out_mem_get_instr <= `FALSE;
        fetcher_flag <= `FALSE;
        mem_a <= `ZERO_DATA;
        out_mem_get_data <= `FALSE;
        slb_flag <= `FALSE;
        out_data <= `ZERO_DATA;
        stage <= 0; //?
        status <= IDLE;
        head <= 0;
        tail <= 0;
        wait_uart <= 0;
        rob_flag <= `FALSE;
        mem_wr <= `FALSE;
    end else if (rdy ==`TRUE && in_mem_misbranch == `FALSE) begin
        //out_data <= `ZERO_DATA;
        mem_wr <= `FALSE;
        out_mem_get_instr <= `FALSE;
        if (in_mem_get_instr == `TRUE) fetcher_flag <= `TRUE;
        out_mem_get_data <= `FALSE;
        if (in_mem_get_data == `TRUE) slb_flag <= `TRUE;
        out_mem_save_data <= `FALSE;
        if (in_mem_save_data == `TRUE || rob_flag == `TRUE) begin
            if (wb_is_full == `FALSE) begin
                rob_flag <= `FALSE;
                wb_addr[nextPtr] <= in_mem_get_address_from_rob;
                wb_data[nextPtr] <= in_mem_save_data_value;
                wb_size[nextPtr] <= in_mem_save_size;
                tail <= nextPtr;
                out_mem_save_data <= `TRUE;//!!
            end else begin 
                rob_flag <= `TRUE;
            end
        end
        mem_a <= mem_a + 1;
        stage <= stage + 1;
        /*if (disable_to_write == `TRUE) begin
            stage <= 0; //
        end*/
        wait_uart <= wait_uart - ((wait_uart == 0) ? 0 : 1);
        case (status) 
            ROB_WRITE:begin
                /*if (disable_to_write == `TRUE) begin
                    stage <= 0;
                    mem_a <= `ZERO_DATA; //`ZERO_RAM_ADDRESS
                end else */begin
                    if (stage == 0) begin //!
                        mem_a <= wb_addr[nowPtr];
                    end 
                    mem_wr <= `TRUE;//
                    mem_dout <= buffered_write_data;
                    if (stage == wb_size[nowPtr] - 1) begin //!!!!!!!!!!!!!!!!!!!!! cover the latter ram
                        head <= nowPtr;
                        stage <= 0;
                        if (nowPtr == tail) begin
                            status <= IDLE;
                        end else begin //else is missing !!
                            status <= ROB_WRITE;
                            //?if(wb_addr[nowPtr] == `IO_ADDRESS) wait_uart <= 2; 
                        end
                    end
                end
            end
            SLB_READ:begin
                case(in_mem_get_size) 
                    1:begin
                        case (stage)
                            1:begin 
                                if (in_slb_signed == `TRUE) begin
                                    out_data <= $signed(mem_din);
                                end else begin
                                    out_data <= mem_din;
                                end
                                stage <= 0;
                                out_mem_get_data <= `TRUE;
                                slb_flag <= `FALSE;
                                status <= buffered_status;
                                if (wb_is_empty == `FALSE) begin
                                    status <= ROB_WRITE;
                                    mem_a <= `ZERO_DATA;
                                end else if (fetcher_flag == `TRUE) begin
                                    status <= FETCHER_READ;
                                    mem_a <= in_mem_get_address;
                                end
                            end
                        endcase
                    end
                    2:begin
                        case (stage)
                            1:begin
                                out_data[7:0] <= mem_din;
                                slb_flag <= `FALSE;
                            end
                            2:begin 
                                if (in_slb_signed == `TRUE) begin
                                    out_data <= $signed({mem_din,out_data[7:0]});
                                end else begin
                                    out_data <= {mem_din,out_data[7:0]};
                                end
                                stage <= 0;
                                out_mem_get_data <= `TRUE;
                                status <= buffered_status;
                                if (wb_is_empty == `FALSE) begin
                                    status <= ROB_WRITE;
                                    mem_a <= `ZERO_DATA;
                                end else if (fetcher_flag == `TRUE) begin
                                    status <= FETCHER_READ;
                                    mem_a <= in_mem_get_address;
                                end
                            end
                        endcase
                    end
                    4:begin
                        case (stage)
                            1:begin
                                out_data[7:0] <= mem_din;
                                slb_flag <= `FALSE;
                            end
                            2:begin
                                out_data[15:8] <= mem_din;
                            end
                            3:begin
                                out_data[23:16] <= mem_din;
                            end
                            4:begin 
                                out_data[31:24] <= mem_din;
                                stage <= 0;
                                out_mem_get_data <= `TRUE;
                                status <= buffered_status;
                                if (wb_is_empty == `FALSE) begin
                                    status <= ROB_WRITE;
                                    mem_a <= `ZERO_DATA;
                                end else if (fetcher_flag == `TRUE) begin
                                    status <= FETCHER_READ;
                                    mem_a <= in_mem_get_address;
                                end
                            end
                        endcase
                    end
                endcase
            end
            FETCHER_READ:begin
                case (stage)
                    1: begin out_data[7:0] <= mem_din; fetcher_flag <= `FALSE;end
                    2: begin out_data[15:8] <= mem_din;  end
                    3: begin out_data[23:16] <= mem_din;  end
                    4: begin 
                        out_data[31:24] <= mem_din;  
                        stage <= 0;
                        //fetcher_flag <= `FALSE;
                        out_mem_get_instr <= `TRUE;
                        status <= buffered_status;
                        if (wb_is_empty == `FALSE) begin
                            status <= ROB_WRITE;
                            mem_a <= `ZERO_DATA;
                        end else if (slb_flag == `TRUE) begin
                            status <= SLB_READ;
                            mem_a <= in_mem_get_address_from_slb;
                        end
                    end
                endcase
            end
            IDLE:begin
                stage <= 0;
                out_data <= 0;
                status <= buffered_status;
                mem_a <= (buffered_status == ROB_WRITE) ? `ZERO_DATA :
                            (buffered_status == SLB_READ) ? in_mem_get_address_from_slb :
                                (buffered_status == FETCHER_READ) ? in_mem_get_address : `ZERO_DATA; // `ZERO_RAM_ADDRESS
            end
        endcase
    end else if (rdy == `TRUE && in_mem_misbranch == `TRUE) begin
        out_data <= `ZERO_DATA;
        out_mem_get_data <= `FALSE;
        out_mem_get_instr <= `FALSE;
        out_mem_save_data <= `FALSE;
        stage <= 0;
        status <= IDLE;
        mem_wr <= `FALSE;
        fetcher_flag <= `FALSE; //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! modify sp in statement_test (3:30)
        slb_flag <= `FALSE; //?
    end else begin

    end
  end
endmodule