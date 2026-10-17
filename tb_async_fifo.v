`timescale 1ns/1ps
module tb_async_fifo;
    parameter DSIZE = 8, ASIZE = 4;
    localparam DEPTH = 1 << ASIZE;

    reg              wclk = 0, rclk = 0, wrst_n = 0, rrst_n = 0;
    reg              winc = 0, rinc = 0;
    reg  [DSIZE-1:0] wdata = 0;
    wire [DSIZE-1:0] rdata;
    wire             wfull, rempty;

    async_fifo #(DSIZE, ASIZE) dut (.wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wdata), .wfull(wfull),
                                    .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata), .rempty(rempty));

    always #5 wclk = ~wclk;
    always #7 rclk = ~rclk;

    reg [DSIZE-1:0] exp_mem [0:1023];
    integer wr_idx = 0, rd_idx = 0, errors = 0;
    reg wr_go = 0, rd_go = 0, rand_mode = 0;

    always @(negedge wclk) if (wrst_n) begin
        if (wr_go && !wfull && (!rand_mode || ($random & 1))) begin
            winc  = 1;
            wdata = $random;
            exp_mem[wr_idx % 1024] = wdata;
            wr_idx = wr_idx + 1;
        end else winc = 0;
    end

    always @(negedge rclk) if (rrst_n)
        rinc = rd_go && !rempty && (!rand_mode || ($random & 1));

    always @(posedge rclk) if (rrst_n && rinc && !rempty) begin
        if (rdata !== exp_mem[rd_idx % 1024]) begin
            errors = errors + 1;
            $display("ERROR @%0t: read #%0d got %h expected %h", $time, rd_idx, rdata, exp_mem[rd_idx % 1024]);
        end
        rd_idx = rd_idx + 1;
    end

    task check(input cond, input [255:0] msg);
        begin
            if (!cond) begin errors = errors + 1; $display("FAIL: %0s", msg); end
            else $display("PASS: %0s", msg);
        end
    endtask

    initial begin
        $dumpfile("async_fifo.vcd");
        $dumpvars(0, tb_async_fifo);

        #50; wrst_n = 1; rrst_n = 1;
        #50;
        check(rempty === 1'b1, "empty after reset");
        check(wfull  === 1'b0, "not full after reset");

        wr_go = 1;
        wait (wfull);
        #200;
        wr_go = 0;
        #100;
        check(wr_idx == DEPTH, "FIFO accepted exactly DEPTH words");
        check(wfull === 1'b1,  "full flag asserted");

        rd_go = 1;
        wait (rd_idx == DEPTH);
        #300;
        check(rempty === 1'b1, "empty flag asserted after drain");
        check(rd_idx == DEPTH, "no extra reads while empty");
        check(wfull  === 1'b0, "full flag cleared after drain");

        rand_mode = 1;
        wr_go = 1;
        wait (wr_idx >= 500);
        wr_go = 0;
        wait (rd_idx == wr_idx);
        #300;
        check(rempty === 1'b1, "empty after random traffic");

        $display("-----------------------------------------");
        $display("Words written: %0d, read: %0d, errors: %0d", wr_idx, rd_idx, errors);
        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("TESTS FAILED");
        $finish;
    end

    initial begin #2000000; $display("TIMEOUT"); $finish; end
endmodule