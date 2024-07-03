module crc7 (
    input logic clk,
    input logic clear,
    input logic enable,
    input logic in,
    output logic [6:0] crc
);
    logic inv;
    assign inv = in ^ crc[6];

    always_ff @(posedge clk or posedge clear) begin
        if (clear) begin
            crc <= 0;
        end else begin
            if (enable) begin
                crc[6] <= crc[5];
                crc[5] <= crc[4];
                crc[4] <= crc[3];
                crc[3] <= crc[2] ^ inv;
                crc[2] <= crc[1];
                crc[1] <= crc[0];
                crc[0] <= inv;
            end
        end
    end

endmodule
