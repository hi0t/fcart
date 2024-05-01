module fcart (
    input clk,
    output logic led
);
    logic [31:0] cnt;
    always_ff @(posedge clk) begin
        cnt <= cnt + 1;
        led <= cnt[31];
    end
endmodule
