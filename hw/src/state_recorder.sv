module state_recorder #(
    parameter MEM_DEPTH = 512
) (
    input logic reset,

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
    // 0x100 - 0x107: PPU Registers ($2000, $2001, $2005). Last written value.
    // 0x140 - 0x155: APU / IO Registers ($4000 - $4015). Last written value.
    //                Includes DMA ($4014)

    (* syn_ramstyle = "block_ram" *) logic [7:0] memory[0:MEM_DEPTH-1];

    // Internal state tracking
    logic [7:0] oam_ptr;
    logic write_toggle;

    // Write dogic (M2 domain)
    always_ff @(negedge m2 or posedge reset) begin
        if (reset) begin
            oam_ptr <= '0;
            write_toggle <= 0;
        end else begin
            // Reset write toggle on PPU STATUS read
            if (cpu_rw && cpu_addr == 'h2002) begin
                write_toggle <= 0;
            end else if (!cpu_rw) begin
                if (cpu_addr == 'h2004) begin
                    memory[{1'b0, oam_ptr}] <= cpu_data;  // Write to OAM Block (0x000-0x0FF)
                    oam_ptr <= oam_ptr + 1;  // Auto-increment
                end

                // PPU registers (offset 0x100 = 256)
                if ({cpu_addr[15:3], 3'b000} == 'h2000) begin
                    // 2000, 2001
                    if (cpu_addr[2:0] == 3'b000 || cpu_addr[2:0] == 3'b001) begin
                        memory[{8'b10000000, cpu_addr[0]}] <= cpu_data;
                    end
                    // 2003
                    if (cpu_addr[2:0] == 3'b011) begin
                        memory[9'b100000010] <= cpu_data;
                        oam_ptr <= cpu_data;  // Special handling for OAM ADDR
                    end
                    // 2005
                    if (cpu_addr[2:0] == 3'b101) begin
                        if (write_toggle == 0) begin
                            memory[9'b100000011] <= cpu_data;  // X
                        end else begin
                            memory[9'b100000100] <= cpu_data;  // Y
                        end
                        write_toggle <= !write_toggle;
                    end
                    // 2006 - Toggle scroll_sw
                    if (cpu_addr[2:0] == 3'b110) begin
                        write_toggle <= !write_toggle;
                    end
                end
            end

            /*// APU / IO registers
            // Map to 0x140 - 0x157 (offset 0x140 = 320)
            // 0x4000 & 0x1F = 0x00
            // 0x140 = 'b101000000. Use prefix 9'b10100xxxx
            else if (cpu_addr >= 'h4000 && cpu_addr <= 'h4015) begin
                memory[{4'b1010, cpu_addr[4:0]}] <= cpu_data;
            end*/
        end
    end

    // Read Logic
    always_ff @(negedge m2) begin
        read_data <= memory[read_addr];
    end

endmodule
