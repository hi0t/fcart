module state_recorder (
    input logic reset,
    input logic enable,

    // Sniffing interface (M2 Domain)
    input logic m2,
    input logic [15:0] cpu_addr,
    input logic [7:0] cpu_data,
    input logic cpu_rw,

    // Readout interface
    input  logic [8:0] read_addr,
    output logic [7:0] read_data
);

    // Memory Map:
    // 0x000 - 0x0FF: OAM Data (256 bytes). Updated via writes to $2004
    // 0x100 - 0x117: APU Registers ($4000 - $4017).
    // 0x118 - 0x11B: PPU Registers ($2000, $2005x2, $2001).

    (* syn_ramstyle = "block_ram" *) logic [7:0] memory[512];

    logic [7:0] oam_ptr;
    logic write_toggle;
    logic memory_we;
    logic [8:0] memory_addr;

    logic is_ppu_range;
    logic is_apu_range;
    logic [2:0] low_addr;

    assign low_addr = cpu_addr[2:0];
    // Capture PPU ($2000-$3FFF) - Handles mirrors
    assign is_ppu_range = (cpu_addr[15:13] == 3'b001);
    // Capture APU ($4000-$4017)
    assign is_apu_range = ({cpu_addr[15:5], 5'b0} == 'h4000) && (cpu_addr[4:3] != 2'b11);

    always_comb begin
        memory_we   = 0;
        memory_addr = '0;

        if (enable && !reset && !cpu_rw) begin
            if (is_ppu_range) begin
                case (low_addr)
                    3'b100: begin  // $2004 OAM Data
                        memory_we   = 1;
                        memory_addr = {1'b0, oam_ptr};
                    end

                    3'b000: begin  // $2000
                        memory_we   = 1;
                        memory_addr = 9'h118;
                    end

                    3'b101: begin  // $2005
                        memory_we   = 1;
                        memory_addr = (write_toggle == 0) ? 9'h119 : 9'h11A;
                    end

                    3'b001: begin  //$2001
                        memory_we   = 1;
                        memory_addr = 9'h11B;
                    end
                    default;
                endcase
            end else if (is_apu_range) begin
                // APU Registers $4000-$4017 -> 0x100-0x117
                memory_we   = 1;
                memory_addr = 9'h100 + {4'h0, cpu_addr[4:0]};
            end
        end
    end

    // RAM Block (Infers Block RAM)
    always_ff @(negedge m2) begin
        if (memory_we) begin
            memory[memory_addr] <= cpu_data;
        end
        read_data <= memory[read_addr];
    end

    // State Update Logic (M2 domain)
    always_ff @(negedge m2) begin
        if (reset) begin
            oam_ptr <= '0;
            write_toggle <= 0;
        end else if (enable && is_ppu_range) begin
            // PPU Register Range $2000-$2007
            if (cpu_rw) begin
                // $2002 Read: Reset write toggle
                if (low_addr == 3'b010) write_toggle <= 0;
            end else begin
                // Writes
                case (low_addr)
                    3'b011: oam_ptr <= cpu_data;           // $2003: Set OAM Pointer
                    3'b100: oam_ptr <= oam_ptr + 1;        // $2004: Write OAM Data (Inc Pointer)
                    3'b101,
                    3'b110: write_toggle <= !write_toggle; // $2005, $2006: Toggle
                    default;
                endcase
            end
        end
    end
endmodule
