module snd_dac (
    input logic clk,
    input logic m2,
    input logic [15:0] pcm_in,
    input logic [7:0] volume,
    output logic pdm_out
);

    logic [15:0] slow_data_prepared;

    always_ff @(posedge m2) begin
        // Temporary variable for multiplication result (top 16 bits of 24-bit product)
        logic signed [15:0] product;

        product = 16'((24'(signed'(pcm_in) * signed'({1'b0, volume}))) >>> 8);

        // Convert Signed PCM (-32768..+32767) to unsigned offset binary (0..65535).
        // Invert the MSB (now bit 15) to shift the zero-crossing point.
        slow_data_prepared <= {~product[15], product[14:0]};
    end


    logic [2:0] m2_sync;
    logic       new_sample_tick;
    assign new_sample_tick = (m2_sync[2:1] == 2'b01);

    always_ff @(posedge clk) begin
        m2_sync <= {m2_sync[1:0], m2};
    end

    logic [16:0] acc;
    logic [15:0] fast_data_in;

    always_ff @(posedge clk) begin
        if (new_sample_tick) begin
            fast_data_in <= slow_data_prepared;
        end

        // First-order delta-sigma modulation
        // Add the current audio value to the accumulator.
        // Explicitly pad with 0 to match widths.
        acc <= {1'b0, acc[15:0]} + {1'b0, fast_data_in};
        pdm_out <= acc[16];
    end

endmodule
