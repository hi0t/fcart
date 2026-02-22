module snd_dac (
    input logic clk,
    input logic m2,
    /* verilator lint_off UNUSEDSIGNAL */
    input logic [15:0] pcm_in,
    /* verilator lint_on UNUSEDSIGNAL */
    input logic [6:0] volume,
    output logic pdm_out
);
    logic [16:0] acc;
    logic [15:0] product;
    logic [ 2:0] m2_sync;

    always_ff @(posedge clk) begin
        m2_sync <= {m2_sync[1:0], m2};
    end

    always_ff @(posedge clk) begin
        if (m2_sync[2:1] == 2'b10) begin
            // Apply volume (9-bit * 7-bit = 16-bit result)
            product <= pcm_in[15:7] * volume;
        end

        // First-order delta-sigma modulation running at 100 MHz speed
        acc <= {1'b0, acc[15:0]} + {1'b0, product};
        pdm_out <= !acc[16];
    end
endmodule
