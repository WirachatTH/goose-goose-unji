`timescale 1ns / 1ps

module randomizer(
    input Reset,
    input GameTick,
    output [15:0] randomize_value
    );
    
    reg [15:0] lfsr_reg;
    wire new_bit = lfsr_reg[15] ^ lfsr_reg[14] ^ lfsr_reg[12] ^ lfsr_reg[3]; 

    always @(posedge GameTick or negedge Reset) begin
        if (!Reset) begin
            lfsr_reg <= 16'hFEED; //Seed เริ่มต้น
        end else begin
            //Shift the LFSR
            lfsr_reg <= {lfsr_reg[14:0], new_bit};
        end
    end
    assign randomize_value = lfsr_reg;
endmodule
