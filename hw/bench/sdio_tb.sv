`timescale 1us / 1ns

module sdio_tb;
    initial begin
        $dumpfile("sdio.vcd");
        $dumpvars(0, sdio_tb);
        #128
        assert (has_response)
        else $fatal(1, "no response");
        $finish;
    end

    logic clk = 0;
    always #0.5 clk <= !clk;

    wire  cmd;
    logic cmd_set;
    assign cmd = cmd_set;
    sdio_bus bus (.clk(clk));
    sdio sdio (
        .cmd_sdio(cmd),
        .bus(bus)
    );

    always_ff @(posedge clk) begin
        bus.resp_valid <= 0;

        if (bus.req_valid) begin
            case (bus.req_cmd)
                'h3F: begin
                    bus.resp_arg   <= 'hF00FF00F;
                    bus.resp_valid <= 1;
                end
                default: bus.resp_valid <= 2;
            endcase
        end
    end

    // cmd = 0x3F, arg = 0xF0000F0F, crc = 0x05
    byte unsigned req[] = {'hFF, 'hFF, 'h7F, 'hF0, 'h00, 'h0F, 'h0F, 'h0B};
    byte unsigned resp[6];
    bit has_response = 0;
    initial begin
        @(posedge clk);
        foreach (req[i]) for (int j = 7; j >= 0; j--) #1 cmd_set = ((req[i] & (1 << j)) != 0);
        #2 cmd_set = 1'bz;
        wait (!cmd);
        has_response = 1;
        foreach (resp[i]) begin
            resp[i] = 0;
            for (int j = 7; j >= 0; j--) #1 resp[i] = {resp[i][6:0], cmd};
        end

        assert (bus.req_arg == 'hF0000F0F)
        else $fatal(1, "invalid req: %0h", bus.req_arg);

        assert ((resp[0] & 'hC0) == 0)
        else $fatal(1, "invalid start bit: %0h", (resp[0] & 'hC0));
        assert (resp[0] == 'h3F)
        else $fatal(1, "invalid command: %0h", resp[0]);
        assert ({resp[1], resp[2], resp[3], resp[4]} == 'hF00FF00F)
        else $fatal(1, "invalid arg: %0h", {resp[1], resp[2], resp[3], resp[4]});
        assert ((resp[5] >> 1) == 'h7D)
        else $fatal(1, "invalid crc: %0h", (resp[5] >> 1));
        assert ((resp[5] & 'h01) == 1)
        else $fatal(1, "invalid end bit: %0h", (resp[5] & 'h01));
    end
endmodule
