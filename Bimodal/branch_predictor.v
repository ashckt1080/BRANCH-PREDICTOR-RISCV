`timescale 1ns / 1ps

(* keep_hierarchy = "yes" *)
module bht_ram(
    input clk,
    input write_en,
    input [5:0] write_addr,
    input [1:0] write_data,
    input [5:0] IF_addr,
    input [5:0] EX_addr,
    output [1:0] IF_data,
    output [1:0] EX_data
    );
    
    (* ram_style = "distributed" *) reg [1:0] memory [0:63];
    
    assign IF_data = memory[IF_addr];
    assign EX_data = memory[EX_addr];
    
    always @(posedge clk) begin
        if(write_en) begin
            memory[write_addr] <= write_data;
        end
    end
    
endmodule


module branch_predictor(
    input clk,
    input rst,
    input [31:0] IF_pc,
    input [31:0] IF_instr,
    input [31:0] EX_pc,
    input EX_valid,
    input EX_branch,
    input EX_branch_taken,
    output IF_pred_taken,
    output [31:0] IF_pred_target
    );
    
    (* keep = "true" *) reg [63:0] BHT_valid;
    
    wire IF_branch;
    wire [31:0] IF_branch_imm;
    wire [5:0] IF_index;
    wire [5:0] EX_index;
    wire [1:0] IF_bht_state;
    wire [1:0] EX_bht_state;
    wire BHT_write_en;
    reg [1:0] BHT_write_data;
    
    assign IF_branch = (IF_instr[6:0] == 7'b1100011);
    assign IF_branch_imm = {{19{IF_instr[31]}},IF_instr[31],IF_instr[7],IF_instr[30:25],IF_instr[11:8],1'b0};
    
    assign IF_index = IF_pc[7:2];
    assign EX_index = EX_pc[7:2];
    
    assign IF_pred_taken = (!rst && IF_branch && BHT_valid[IF_index]) ? IF_bht_state[1] : 1'b0;
    assign IF_pred_target = (!rst && IF_branch) ? (IF_pc + IF_branch_imm) : 32'b0;
    
    assign BHT_write_en = !rst && EX_valid && EX_branch;
    
    always @(*) begin
        
        if(!BHT_valid[EX_index]) begin
            if(EX_branch_taken) begin
                BHT_write_data = 2'b01;
            end
            else begin
                BHT_write_data = 2'b00;
            end
        end
        
        else if(EX_branch_taken) begin
            if(EX_bht_state != 2'b11) begin
                BHT_write_data = EX_bht_state + 2'b01;
            end
            else begin
                BHT_write_data = 2'b11;
            end
        end
        
        else begin
            if(EX_bht_state != 2'b00) begin
                BHT_write_data = EX_bht_state - 2'b01;
            end
            else begin
                BHT_write_data = 2'b00;
            end
        end
        
    end
    
    always @(posedge clk) begin
        
        if(rst) begin
            BHT_valid <= 64'b0;
        end
        
        else if(EX_valid && EX_branch) begin
            BHT_valid[EX_index] <= 1'b1;
        end
        
    end
    
    bht_ram bht_ram_ (.clk(clk),
                      .write_en(BHT_write_en),
                      .write_addr(EX_index),
                      .write_data(BHT_write_data),
                      .IF_addr(IF_index),
                      .EX_addr(EX_index),
                      .IF_data(IF_bht_state),
                      .EX_data(EX_bht_state));
    
endmodule