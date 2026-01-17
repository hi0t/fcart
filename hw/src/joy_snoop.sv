module joy_snoop (
    input logic m2,
    input logic [15:0] cpu_addr,
    input logic cpu_data,
    input logic cpu_rw,

    output logic [7:0] joy1
);

    logic [3:0] bit_cnt;
    logic strobe;
    logic [6:0] shift_reg;

    always_ff @(negedge m2) begin
        if (cpu_addr == 'h4016) begin
            // Snoop writes to $4016 for strobe
            if (!cpu_rw) begin
                strobe <= cpu_data;
                if (cpu_data) begin
                    bit_cnt <= '0;
                end
            end  // Snoop reads from $4016
            else if (!strobe && !bit_cnt[3]) begin
                shift_reg <= {shift_reg[5:0], cpu_data};
                bit_cnt   <= bit_cnt + 4'd1;

                if (bit_cnt == 4'd7) begin
                    joy1 <= {shift_reg, cpu_data};  // A, B, Sl, St, U, D, L, R
                end
            end
        end
    end
endmodule
