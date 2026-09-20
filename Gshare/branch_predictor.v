`timescale 1ns / 1ps

(* keep_hierarchy = "yes" *)
module pht_ram(
    input clk,
    input write_en,
    input [5:0] write_addr,
    input [1:0] write_data,
    input [5:0] read_addr_1,
    input [5:0] read_addr_2,
    output [1:0] read_data_1,
    output [1:0] read_data_2
    );
    
    (* ram_style = "distributed" *) reg [1:0] memory [0:63];
    
    assign read_data_1 = memory[read_addr_1];
    assign read_data_2 = memory[read_addr_2];
    
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
    input [5:0] EX_pred_index,
    input EX_valid,
    input EX_branch,
    input EX_branch_taken,
    output IF_pred_taken,
    output [31:0] IF_pred_target,
    output [5:0] IF_pred_index
    );
    
    (* keep = "true" *) reg [63:0] PHT_valid;
    reg [5:0] GHR;
    
    wire IF_branch;
    wire [31:0] IF_branch_imm;
    
    wire [1:0] IF_pht_data;
    wire [1:0] EX_pht_data;
    
    wire PHT_write_en;
    reg [1:0] PHT_write_data;
    
    assign IF_branch = (IF_instr[6:0] == 7'b1100011);
    assign IF_branch_imm = {{19{IF_instr[31]}},IF_instr[31],IF_instr[7],IF_instr[30:25],IF_instr[11:8],1'b0};
    
    assign IF_pred_index = IF_pc[7:2] ^ GHR;
    
    assign IF_pred_taken = (!rst && IF_branch && PHT_valid[IF_pred_index]) ? IF_pht_data[1] : 1'b0;
    assign IF_pred_target = (!rst && IF_branch) ? (IF_pc + IF_branch_imm) : 32'b0;
    
    assign PHT_write_en = !rst && EX_valid && EX_branch;
    
    always @(*) begin
        
        if(!PHT_valid[EX_pred_index]) begin
            if(EX_branch_taken) begin
                PHT_write_data = 2'b01;
            end
            else begin
                PHT_write_data = 2'b00;
            end
        end
        
        else if(EX_branch_taken) begin
            if(EX_pht_data != 2'b11) begin
                PHT_write_data = EX_pht_data + 2'b01;
            end
            else begin
                PHT_write_data = 2'b11;
            end
        end
        
        else begin
            if(EX_pht_data != 2'b00) begin
                PHT_write_data = EX_pht_data - 2'b01;
            end
            else begin
                PHT_write_data = 2'b00;
            end
        end
        
    end
    
    always @(posedge clk) begin
        
        if(rst) begin
            PHT_valid <= 64'b0;
            GHR <= 6'b0;
        end
        
        else if(EX_valid && EX_branch) begin
            PHT_valid[EX_pred_index] <= 1'b1;
            GHR <= {GHR[4:0],EX_branch_taken};
        end
        
    end
    
    pht_ram pht_ram_ (.clk(clk),
                      .write_en(PHT_write_en),
                      .write_addr(EX_pred_index),
                      .write_data(PHT_write_data),
                      .read_addr_1(IF_pred_index),
                      .read_addr_2(EX_pred_index),
                      .read_data_1(IF_pht_data),
                      .read_data_2(EX_pht_data));
    
endmodule