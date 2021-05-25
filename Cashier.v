////////////////////////////////
//    EE303A Final Project    //
// Design your cashier module //
////////////////////////////////

`timescale 1ns / 1ps

module Sequential_multiplier(
    input wire [5:0]    counter,
    input wire [11:0]   item_price,
    input wire [2:0]    num_of_item,

    output reg [15:0]   result
);
    reg        [15:0]   first_cycle_result;
    reg        [15:0]   second_cycle_result;
    reg        [15:0]   third_cycle_result;

    parameter FIRST_MULTIPLICATION_CYCLE_1 = 5'd2, FIRST_MULTIPLICATION_CYCLE_2 = 5'd3, FIRST_MULTIPLICATION_CYCLE_3 = 5'd4;
    parameter SECOND_MULTIPLICATION_CYCLE_1 = 5'd5, SECOND_MULTIPLICATION_CYCLE_2 = 5'd6, SECOND_MULTIPLICATION_CYCLE_3 = 5'd7;
    parameter SECOND_MULTIPLICATION_RESULT_FETCH = 5'd8, RESULT_BACK_TO_INITIAL = 5'd9;
    parameter HIGH = 1'b1, LOW = 1'b0;

    //design of sequential multiplier
    always @(counter) begin

        if (counter === FIRST_MULTIPLICATION_CYCLE_1 || counter === SECOND_MULTIPLICATION_CYCLE_1) begin  // Only starts multiplications when the value of the counter is 1(the first multiplication starts) or 4(the second multiplication starts)

            if (counter === SECOND_MULTIPLICATION_CYCLE_1) // After 3 cycles have elapsed 1--->2---->3---->4, update the result
                result = first_cycle_result + second_cycle_result + third_cycle_result;

            if (num_of_item[0] === HIGH)
                first_cycle_result = {4'b0000,item_price};
            else if (num_of_item[0] === LOW)
                first_cycle_result = 0;
            
        end 

        else if (counter === FIRST_MULTIPLICATION_CYCLE_2 || counter === SECOND_MULTIPLICATION_CYCLE_2) begin

           if (num_of_item[1] === HIGH)
                second_cycle_result = {4'b0000,item_price};
           else if (num_of_item[1] === LOW)
                second_cycle_result = 0;

            second_cycle_result = second_cycle_result << 1; // This is needed , since the 4 MSB bits are zero, no info can be lost by shifting

        end

        else if (counter === FIRST_MULTIPLICATION_CYCLE_3 || counter === SECOND_MULTIPLICATION_CYCLE_3) begin

           if (num_of_item[2] === HIGH)
                third_cycle_result = {4'b0000,item_price};
           else if (num_of_item[2] === LOW)
                third_cycle_result = 0;

            third_cycle_result = third_cycle_result << 2; // This is needed , since the 4 MSB bits are zero, no info can be lost by shifting

        end

        else if (counter === SECOND_MULTIPLICATION_RESULT_FETCH)
            result = first_cycle_result + second_cycle_result + third_cycle_result; //  After 3 cycles have elapsed 4--->5---->6---->7, update the result

        else if (counter === RESULT_BACK_TO_INITIAL)
            result = 16'bx;


    end





endmodule



module Cashier (
    input  wire                     i_clk,
    input  wire                     i_rst,
    input  wire                     i_enable,
    input  wire [15:0]              i_payment,
    input  wire [11:0]              i_item1_price,
    input  wire [2:0]               i_item1_num,
    input  wire [11:0]              i_item2_price,
    input  wire [2:0]               i_item2_num,

    output reg                      o_busy,
    output reg                      o_valid,
    output reg                      o_paid,
    output reg  [15:0]              o_change
);

    ////////////////////////////
    // Design your logic here //
    ////////////////////////////

    reg [5:0]  num_cycles_till_result;
    reg [11:0] price;
    reg [2:0]  num;
    wire [15:0] mult_result;

    // Since the payment is guarenteed to be valid when enable is high, I will store it in register
    reg [15:0] store_payment;
    reg [11:0] store_item1_price;
    reg [2:0] store_item_1_num;
    reg [11:0] store_item2_price;
    reg [2:0] store_item_2_num;
    reg [15:0] multiply_result1;
    reg [15:0] multiply_result2;
    reg [15:0] total_price;

    parameter high = 1'b1, low = 1'b0;

    parameter start_first_multiplication = 5'd1, start_second_multiplication = 5'd4;
    parameter fetch_first_result = 5'd5, fetch_second_result = 5'd8;
    parameter before_final_cycle = 5'd8, final_cycle = 5'd9;

    




    Sequential_multiplier mult(.counter(num_cycles_till_result),.item_price(price),.num_of_item(num),.result(mult_result)); // Instantaited sequential multiplier

    always @(i_enable,i_item1_num,i_item1_price,i_payment,i_item2_num,i_item2_price) begin

        if (i_enable === high && o_busy !== high) begin
            store_payment = i_payment;
            store_item1_price = i_item1_price;
            store_item_1_num = i_item1_num;
            store_item2_price = i_item2_price;
            store_item_2_num = i_item2_num;
            num_cycles_till_result = 1; // Since TA's will assert the enable a little after clock edge, conflict doesn't occur :)
        end
    
    end


    always @(mult_result) begin
        
        if (num_cycles_till_result === fetch_first_result) begin
            multiply_result1 = mult_result;
            multiply_result2 = mult_result; // Incase the multiplication result doesn't change since the always block is trigered based on change, I store the same value in the 2nd register
        end

        else if (num_cycles_till_result === fetch_second_result) begin
            multiply_result2 = mult_result;
        end

    end




    always @(posedge i_clk) begin

        if (i_rst === high) begin
            o_busy   <= 0;
            o_valid  <= 0;
            o_paid   <= 0;
            o_change <= 0;
        end

        if (num_cycles_till_result === start_first_multiplication) begin
           o_busy <= 1;
           price <= store_item1_price; // This will start the first multiplication
           num <= store_item_1_num;
        end

        else if (num_cycles_till_result === start_second_multiplication) begin
            price <= store_item2_price;
            num <= store_item_2_num; // This will start the second multiplication
        end

        else if (num_cycles_till_result === before_final_cycle) begin
            o_busy <= 0;
            o_valid <= 1;

            if (store_payment !== 16'bx ) begin

                if (store_payment >= (multiply_result1 + multiply_result2) && (store_payment !== 16'b0)) begin
                    o_paid <= 1;
                    o_change <= store_payment - (multiply_result1 + multiply_result2);
                end
                
                else begin
                    o_paid <= 0;
                    o_change <= 0;
                end
            end
       
        end

        else if(num_cycles_till_result === final_cycle) begin
            o_valid <= 0;
            o_paid  <= 0;
            price <= 12'bx;
            num <= 3'bx;
        end


        if (num_cycles_till_result !== 5'bx) // If in operation, at the clk edge update this register
            num_cycles_till_result <= num_cycles_till_result + 1; 

    end




endmodule