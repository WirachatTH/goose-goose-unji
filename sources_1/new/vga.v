`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/22/2025 04:14:57 PM
// Design Name: 
// Module Name: vga
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module vga(
    input Clk_In,
    input Reset,
    output HS,
    output VS,
    output [9:0] x,
    output [9:0] y
    );
    
    // VESA Timing Parameters for 640x480 @ 60Hz (Pixel Clock ~25.175 MHz)
    // เราใช้ 25 MHz จาก Prescaler (100MHz/4)
    // H Timing (Total 800)
    parameter H_VISIBLE = 640;   // 0 - 639
    parameter H_FRONT   = 656;   // End of Visible: 640
    parameter H_SYNC    = 752;   // End of H_Sync: 656 + 96 = 752
    parameter H_TOTAL   = 800;   // End of H_Back: 752 + 48 = 800 (0-799)
    
    // V Timing (Total 525)
    parameter V_VISIBLE = 480;   // 0 - 479
    parameter V_FRONT   = 490;   // End of Visible: 480
    parameter V_SYNC    = 492;   // End of V_Sync: 490 + 2 = 492
    parameter V_TOTAL   = 525;   // End of V_Back: 492 + 33 = 525 (0-524)
    
    reg [9:0] xc, yc, xc_next, yc_next;
    reg [1:0] prescaler; 
    reg HS_reg;
    reg VS_reg;
    wire HS_next, VS_next;
    
    // HS is Active Low in the H_SYNC region
    assign HS_next = ~((xc >= H_FRONT) & (xc < H_SYNC));
    
    // VS is Active Low in the V_SYNC region
    assign VS_next = ~((yc >= V_FRONT) & (yc < V_SYNC));
    
    assign x = xc;
    assign y = yc;
    assign HS = HS_reg;
    assign VS = VS_reg;
    
    always @(posedge Clk_In) begin
        if (!Reset) begin // Active-Low Reset
            xc <= 0;
            yc <= 0;
            xc_next <= 0;
            yc_next <= 0;
            prescaler <= 0;
            HS_reg <= 0;
            VS_reg <= 0;
        end
        else begin
            prescaler <= prescaler + 1;
            
            // Pixel Clock = 25 MHz (100 MHz / 4)
            if (prescaler == 3) begin 
                prescaler <= 0;
                
                // --- Horizontal Counter Logic ---
                if (xc == (H_TOTAL - 1)) begin // xc == 799
                    xc_next <= 0;
                    
                    // --- Vertical Counter Logic ---
                    if (yc == (V_TOTAL - 1)) begin // yc == 524
                        yc_next <= 0;
                    end else begin
                        yc_next <= yc + 1;
                    end
                end else begin
                    xc_next <= xc + 1;
                    yc_next <= yc; // yc ไม่เปลี่ยนขณะที่ xc นับ
                end
            end
            
            // ? อัปเดตทุก Clock Edge (100MHz)
            xc <= xc_next;
            yc <= yc_next;
            HS_reg <= HS_next;
            VS_reg <= VS_next; // ? แก้ไข: ใช้ VS_next
        end
    end
    
endmodule
