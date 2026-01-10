module snd_dac (
    input logic m2,
    input logic [15:0] pcm_in,
    input logic [7:0] volume,
    output logic pdm_out
);

    logic [16:0] acc;

    always_ff @(posedge m2) begin
        // Temporary variable for multiplication result (top 16 bits of 24-bit product)
        logic [15:0] product;

        // Apply volume
        product = 16'((24'(pcm_in) * 24'(volume)) >> 8);

        // First-order delta-sigma modulation running at M2 speed (~1.79 MHz)
        acc <= {1'b0, acc[15:0]} + {1'b0, product};
        pdm_out <= acc[16];
    end
endmodule
