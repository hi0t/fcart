module fcart (
    input clk,
    output logic led
);
    logic [27:0] cnt;
    always_ff @(posedge clk) begin
        cnt <= cnt + 1;
        led <= cnt[27];
    end
endmodule
