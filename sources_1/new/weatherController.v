`timescale 1ns / 1ps

module weatherController(
    input Reset,
    input GameTick,
    input [2:0] currentState,
    output reg [2:0] currentWeather
    );
    
    parameter sunny = 3'b000;
    parameter rainy = 3'b001;
    parameter snowy = 3'b010;
    
    parameter duration = 1800; //1800 GameTicks per season
    
    parameter startState = 3'b000;
    parameter gameState = 3'b001;
    
    reg [12:0] timer;
    
    always @(posedge GameTick or negedge Reset) begin
        if (!Reset) begin
            currentWeather <= sunny;
            timer <= 13'd0;
        end else begin
            if (currentState == gameState) begin
                if (timer >= duration) begin
                    timer <= 13'd0;
                    
                    case(currentWeather)
                        sunny : currentWeather <= rainy;
                        rainy : currentWeather <= snowy;
                        snowy : currentWeather <= sunny;
                        default : currentWeather <= sunny;
                    endcase
                end else begin
                    timer <= timer + 13'd1;
                end
            end else if (currentState == startState) begin
                currentWeather <= sunny;
                timer <= 13'd0;
            end else begin
                timer <= timer;
            end
        end
    end
    
endmodule
