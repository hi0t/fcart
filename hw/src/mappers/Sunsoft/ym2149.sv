module ym2149 (
    input  logic         clk,
    input  logic         reset,
    input  logic [14:13] cpu_addr,
    input  logic [  7:0] cpu_data_in,
    input  logic         cpu_we,       // Write Enable
    output logic [ 15:0] audio_out,    // Mixed Audio Output 16-bit

    input logic sst_enable,
    input logic sst_we,
    input logic [5:0] sst_addr,
    input logic [7:0] sst_data_in,
    output logic [7:0] sst_data_out
);

    logic [7:0] regs[16];
    logic [3:0] selected_reg;

    // State
    logic [11:0] count_a, count_b, count_c;
    logic out_a, out_b, out_c;
    logic [ 4:0] count_noise;
    logic        out_noise;
    logic [16:0] lfsr_noise;
    logic [ 4:0] prescaler;

    // Volume Table (Approximate logarithmic)
    function automatic [11:0] get_vol(input [3:0] v);
        case (v)
            0: return 0;
            1: return 14;
            2: return 23;
            3: return 35;
            4: return 50;
            5: return 75;
            6: return 109;
            7: return 155;
            8: return 222;
            9: return 312;
            10: return 442;
            11: return 624;
            12: return 885;
            13: return 1247;
            14: return 1762;
            15: return 2477;
        endcase
    endfunction

    always_ff @(negedge clk) begin
        if (reset) begin
            regs <= '{default: 0};
            selected_reg <= 0;
            {count_a, count_b, count_c} <= '0;
            {out_a, out_b, out_c} <= '0;
            count_noise <= '0;
            out_noise <= '0;
            lfsr_noise <= 17'd1;
            prescaler <= '0;
        end else if (sst_enable) begin
            if (sst_we) begin
                case (sst_addr)
                    16: regs[0] <= sst_data_in;
                    17: regs[1] <= sst_data_in;
                    18: regs[2] <= sst_data_in;
                    19: regs[3] <= sst_data_in;
                    20: regs[4] <= sst_data_in;
                    21: regs[5] <= sst_data_in;
                    22: regs[6] <= sst_data_in;
                    23: regs[7] <= sst_data_in;
                    24: regs[8] <= sst_data_in;
                    25: regs[9] <= sst_data_in;
                    26: regs[10] <= sst_data_in;
                    27: regs[11] <= sst_data_in;
                    28: regs[12] <= sst_data_in;
                    29: regs[13] <= sst_data_in;
                    30: regs[14] <= sst_data_in;
                    31: regs[15] <= sst_data_in;
                    32: count_a[7:0] <= sst_data_in;
                    33: count_a[11:8] <= sst_data_in[3:0];
                    34: count_b[7:0] <= sst_data_in;
                    35: count_b[11:8] <= sst_data_in[3:0];
                    36: count_c[7:0] <= sst_data_in;
                    37: count_c[11:8] <= sst_data_in[3:0];
                    38: {out_a, out_b, out_c, out_noise} <= sst_data_in[3:0];
                    39: count_noise <= sst_data_in[4:0];
                    40: lfsr_noise[7:0] <= sst_data_in;
                    41: lfsr_noise[15:8] <= sst_data_in;
                    42: lfsr_noise[16] <= sst_data_in[0];
                    43: prescaler <= sst_data_in[4:0];
                    44: selected_reg <= sst_data_in[3:0];
                endcase
            end
        end else begin
            prescaler <= prescaler + 5'd1;

            // Sunsoft 5B Audio Register Mapping
            // C000: Register Select
            // E000: Data Write
            if (cpu_we) begin
                if (cpu_addr[14:13] == 2'b10) begin  // C000-DFFF
                    selected_reg <= cpu_data_in[3:0];
                end else if (cpu_addr[14:13] == 2'b11) begin  // E000-FFFF
                    regs[selected_reg] <= cpu_data_in;
                end
            end

            // Tone A (Div 8 -> Div 16 for Sunsoft 5B)
            if (prescaler[3:0] == 4'd15) begin
                if (count_a == 0) begin
                    count_a <= {regs[1][3:0], regs[0]};
                    out_a   <= ~out_a;
                end else begin
                    count_a <= count_a - 12'd1;
                end
            end

            // Tone B (Div 8 -> Div 16 for Sunsoft 5B)
            if (prescaler[3:0] == 4'd15) begin
                if (count_b == 0) begin
                    count_b <= {regs[3][3:0], regs[2]};
                    out_b   <= ~out_b;
                end else begin
                    count_b <= count_b - 12'd1;
                end
            end

            // Tone C (Div 8 -> Div 16 for Sunsoft 5B)
            if (prescaler[3:0] == 4'd15) begin
                if (count_c == 0) begin
                    count_c <= {regs[5][3:0], regs[4]};
                    out_c   <= ~out_c;
                end else begin
                    count_c <= count_c - 12'd1;
                end
            end

            // Noise (Div 16 -> Div 32 for Sunsoft 5B)
            if (prescaler == 5'd31) begin
                if (count_noise == 0) begin
                    count_noise <= regs[6][4:0];
                    lfsr_noise  <= {lfsr_noise[0] ^ lfsr_noise[3], lfsr_noise[16:1]};
                    out_noise   <= lfsr_noise[0];
                end else begin
                    count_noise <= count_noise - 5'd1;
                end
            end
        end
    end

    logic [3:0] vol_a, vol_b, vol_c;
    // Gimmick! does not use YM2149 envelope generator, logic removed for LUT optimization
    assign vol_a = regs[8][3:0];
    assign vol_b = regs[9][3:0];
    assign vol_c = regs[10][3:0];

    logic enable_tone_a, enable_tone_b, enable_tone_c;
    logic enable_noise_a, enable_noise_b, enable_noise_c;
    assign enable_tone_a  = !regs[7][0];
    assign enable_tone_b  = !regs[7][1];
    assign enable_tone_c  = !regs[7][2];
    assign enable_noise_a = !regs[7][3];
    assign enable_noise_b = !regs[7][4];
    assign enable_noise_c = !regs[7][5];

    logic a_on, b_on, c_on;
    assign a_on = (out_a | !enable_tone_a) & (out_noise | !enable_noise_a);
    assign b_on = (out_b | !enable_tone_b) & (out_noise | !enable_noise_b);
    assign c_on = (out_c | !enable_tone_c) & (out_noise | !enable_noise_c);

    logic [11:0] amp_a, amp_b, amp_c;
    assign amp_a = a_on ? get_vol(vol_a) : 12'd0;
    assign amp_b = b_on ? get_vol(vol_b) : 12'd0;
    assign amp_c = c_on ? get_vol(vol_c) : 12'd0;

    assign audio_out = ({4'b0, amp_a} + {4'b0, amp_b} + {4'b0, amp_c}) << 3;

    always_comb begin
        case (sst_addr)
            16: sst_data_out = regs[0];
            17: sst_data_out = regs[1];
            18: sst_data_out = regs[2];
            19: sst_data_out = regs[3];
            20: sst_data_out = regs[4];
            21: sst_data_out = regs[5];
            22: sst_data_out = regs[6];
            23: sst_data_out = regs[7];
            24: sst_data_out = regs[8];
            25: sst_data_out = regs[9];
            26: sst_data_out = regs[10];
            27: sst_data_out = regs[11];
            28: sst_data_out = regs[12];
            29: sst_data_out = regs[13];
            30: sst_data_out = regs[14];
            31: sst_data_out = regs[15];
            32: sst_data_out = count_a[7:0];
            33: sst_data_out = {4'b0, count_a[11:8]};
            34: sst_data_out = count_b[7:0];
            35: sst_data_out = {4'b0, count_b[11:8]};
            36: sst_data_out = count_c[7:0];
            37: sst_data_out = {4'b0, count_c[11:8]};
            38: sst_data_out = {4'b0, out_a, out_b, out_c, out_noise};
            39: sst_data_out = {3'b0, count_noise};
            40: sst_data_out = lfsr_noise[7:0];
            41: sst_data_out = lfsr_noise[15:8];
            42: sst_data_out = {7'b0, lfsr_noise[16]};
            43: sst_data_out = {3'b0, prescaler};
            44: sst_data_out = {4'b0, selected_reg};
            default: sst_data_out = 'hFF;
        endcase
    end
endmodule
