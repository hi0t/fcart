module vrc_irq (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] cpu_data_in,
    input  logic       wr_latch,
    input  logic       wr_ctrl,
    input  logic       wr_ack,
    output logic       irq,

    input logic sst_enable,
    input logic sst_we,
    input logic [5:0] sst_addr,
    input logic [7:0] sst_data_in,
    output logic [7:0] sst_data_out
);

    logic irq_mode, irq_enable, irq_enable_after_ack;
    logic irq_pending;
    logic [7:0] irq_latch;
    logic [7:0] irq_counter;
    logic [8:0] irq_prescaler;

    assign irq = !(irq_pending && irq_enable);

    always_ff @(negedge clk) begin
        if (reset) begin
            {irq_mode, irq_enable, irq_enable_after_ack} <= '0;
            irq_pending <= 1'b0;
        end else if (sst_enable) begin
            if (sst_we && sst_addr == 'd16) {irq_pending, irq_mode, irq_enable, irq_enable_after_ack} <= sst_data_in[3:0];
            if (sst_we && sst_addr == 'd17) irq_latch <= sst_data_in;
            if (sst_we && sst_addr == 'd18) irq_counter <= sst_data_in;
            if (sst_we && sst_addr == 'd19) irq_prescaler[7:0] <= sst_data_in;
            if (sst_we && sst_addr == 'd20) irq_prescaler[8] <= sst_data_in[0];
        end else begin
            // IRQ Counter Logic
            if (irq_enable) begin
                irq_prescaler <= (irq_prescaler == 9'd340) ? '0 : (irq_prescaler + 1'd1);

                if (irq_mode || irq_prescaler == 9'd113 || irq_prescaler == 9'd227 || irq_prescaler == 9'd340) begin
                    irq_counter <= (irq_counter == 8'hFF) ? irq_latch : (irq_counter + 1'd1);

                    if (irq_counter == 8'hFF) begin
                        irq_pending <= 1;
                    end
                end
            end

            if (wr_latch) begin
                irq_latch <= cpu_data_in;
            end else if (wr_ctrl) begin
                {irq_mode, irq_enable, irq_enable_after_ack} <= cpu_data_in[2:0];
                if (cpu_data_in[1]) begin
                    irq_counter   <= irq_latch;
                    irq_prescaler <= '0;
                end
            end else if (wr_ack) begin
                irq_pending <= 1'b0;
                irq_enable  <= irq_enable_after_ack;
            end
        end
    end

    assign sst_data_out = (sst_addr == 'd16) ? {4'b0, irq_pending, irq_mode, irq_enable, irq_enable_after_ack} :
                          (sst_addr == 'd17) ? irq_latch :
                          (sst_addr == 'd18) ? irq_counter :
                          (sst_addr == 'd19) ? irq_prescaler[7:0] :
                          (sst_addr == 'd20) ? {7'b0, irq_prescaler[8]} : 'hFF;
endmodule
