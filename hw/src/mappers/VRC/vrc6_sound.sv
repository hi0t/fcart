module vrc6_sound (
    input  logic        clk,          // M2 Clock
    input  logic        reset,
    input  logic [15:0] cpu_addr,
    input  logic [ 7:0] cpu_data_in,
    input  logic        cpu_we,       // Write Enable
    output logic [15:0] audio_out     // Mixed Audio Output 16-bit
);

    // Channel state
    logic mode0, mode1;
    logic [3:0] vol0, vol1;
    logic [5:0] vol2;
    logic [2:0] duty0, duty1;
    logic [11:0] freq0, freq1, freq2;
    logic [11:0] div0, div1;
    logic [12:0] div2;
    logic en0, en1, en2;
    logic [3:0] duty0cnt, duty1cnt;
    logic [2:0] duty2cnt;
    logic [7:0] acc;

    // State update on M2 falling edge (matches mapper timing)
    always_ff @(negedge clk) begin
        if (reset) begin
            {en0, en1, en2} <= '0;
        end else begin
            // Register writes
            if (cpu_we) begin
                case (cpu_addr)
                    16'h9000: {mode0, duty0, vol0} <= cpu_data_in;
                    16'h9001: freq0[7:0] <= cpu_data_in;
                    16'h9002: {en0, freq0[11:8]} <= {cpu_data_in[7], cpu_data_in[3:0]};

                    16'hA000: {mode1, duty1, vol1} <= cpu_data_in;
                    16'hA001: freq1[7:0] <= cpu_data_in;
                    16'hA002: {en1, freq1[11:8]} <= {cpu_data_in[7], cpu_data_in[3:0]};

                    16'hB000: vol2 <= cpu_data_in[5:0];
                    16'hB001: freq2[7:0] <= cpu_data_in;
                    16'hB002: {en2, freq2[11:8]} <= {cpu_data_in[7], cpu_data_in[3:0]};
                    default;
                endcase
            end

            // Pulse 1
            if (en0) begin
                if (div0 != 12'd0) div0 <= div0 - 12'd1;
                else begin
                    div0     <= freq0;
                    duty0cnt <= duty0cnt + 4'd1;
                end
            end

            // Pulse 2
            if (en1) begin
                if (div1 != 12'd0) div1 <= div1 - 12'd1;
                else begin
                    div1     <= freq1;
                    duty1cnt <= duty1cnt + 4'd1;
                end
            end

            // Sawtooth
            if (en2) begin
                if (div2 != 13'd0) div2 <= div2 - 13'd1;
                else begin
                    div2 <= {freq2, 1'b1};
                    if (duty2cnt == 3'd6) begin
                        duty2cnt <= 3'd0;
                        acc      <= 8'd0;
                    end else begin
                        duty2cnt <= duty2cnt + 3'd1;
                        acc      <= acc + {2'b0, vol2};
                    end
                end
            end
        end
    end

    // Wave generation
    logic       duty0_active;
    logic       duty1_active;
    logic [3:0] ch0;
    logic [3:0] ch1;
    logic [4:0] ch2;
    logic [5:0] exp_audio;

    always_comb begin
        duty0_active = (duty0cnt <= {1'b0, duty0}) || mode0;
        duty1_active = (duty1cnt <= {1'b0, duty1}) || mode1;

        ch0 = (duty0_active && en0) ? vol0 : 4'd0;
        ch1 = (duty1_active && en1) ? vol1 : 4'd0;
        ch2 = en2 ? acc[7:3] : 5'd0;

        // Simple unsigned mix: sum 6-bit DAC and scale to 16 bits
        exp_audio = {2'b0, ch0} + {2'b0, ch1} + {1'b0, ch2};
        audio_out = {exp_audio, 10'b0};
    end
endmodule
