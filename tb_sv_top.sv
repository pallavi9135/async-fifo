`timescale 1ns/1ps
module tb_sv_top;
    import fifo_pkg::*;

    localparam int NUM = 200;

    logic wclk = 0, rclk = 0;
    always #5 wclk = ~wclk;
    always #7 rclk = ~rclk;

    fifo_if #(8) vif (wclk, rclk);

    async_fifo #(8, 4) dut (
        .wclk(wclk), .wrst_n(vif.wrst_n), .winc(vif.winc), .wdata(vif.wdata), .wfull(vif.wfull),
        .rclk(rclk), .rrst_n(vif.rrst_n), .rinc(vif.rinc), .rdata(vif.rdata), .rempty(vif.rempty)
    );

    // ---------------- Assertions ----------------
    int assert_fails = 0;

    property p_gray_w;
        @(posedge wclk) disable iff (!vif.wrst_n)
            $countones(dut.u_wptr_full.wptr ^ $past(dut.u_wptr_full.wptr)) <= 1;
    endproperty
    a_gray_w: assert property (p_gray_w)
        else begin assert_fails++; $display("[%0t] ASSERT FAIL: write pointer not gray", $time); end

    property p_gray_r;
        @(posedge rclk) disable iff (!vif.rrst_n)
            $countones(dut.u_rptr_empty.rptr ^ $past(dut.u_rptr_empty.rptr)) <= 1;
    endproperty
    a_gray_r: assert property (p_gray_r)
        else begin assert_fails++; $display("[%0t] ASSERT FAIL: read pointer not gray", $time); end

    // ---------------- Occupancy tracking + coverage ----------------
    int wcnt = 0, rcnt = 0, occ = 0, max_occ = 0;

    always @(posedge wclk) if (vif.winc && !vif.wfull)  wcnt++;
    always @(posedge rclk) if (vif.rinc && !vif.rempty) rcnt++;
    always @* occ = wcnt - rcnt;
    always @(posedge wclk) if (occ > max_occ) max_occ = occ;

    covergroup cg_fifo @(posedge wclk);
        cp_occ: coverpoint occ {
            bins empty = {0};
            bins low   = {[1:4]};
            bins mid   = {[5:11]};
            bins high  = {[12:15]};
            bins full  = {16};
        }
        cp_full: coverpoint vif.wfull;
        cp_winc: coverpoint vif.winc;
    endgroup
    cg_fifo cg = new();

    int b_empty = 0, b_low = 0, b_mid = 0, b_high = 0, b_full = 0;
    always @(posedge wclk) begin
        if      (occ == 0)  b_empty++;
        else if (occ <= 4)  b_low++;
        else if (occ <= 11) b_mid++;
        else if (occ <= 15) b_high++;
        else                b_full++;
    end

    // ---------------- Test ----------------
    initial begin
        mailbox #(fifo_txn)  g2d;
        mailbox #(bit [7:0]) wm, rm;
        fifo_gen  gen;
        fifo_wdrv wd;
        fifo_rdrv rd;
        fifo_wmon wmon;
        fifo_rmon rmon;
        fifo_scb  scb;

        g2d = new(); wm = new(); rm = new();
        gen  = new(g2d, NUM);
        wd   = new(vif, g2d);
        rd   = new(vif);
        wmon = new(vif, wm);
        rmon = new(vif, rm);
        scb  = new(wm, rm, NUM);

        vif.wrst_n = 0; vif.rrst_n = 0;
        vif.winc = 0;   vif.rinc = 0;
        repeat (5) @(posedge wclk);
        vif.wrst_n = 1; vif.rrst_n = 1;
        repeat (3) @(posedge wclk);

        // Start writer side first; reader is NOT started yet
        fork
            gen.run();
            wd.run();
            wmon.run();
            rmon.run();
        join_none

        // Let the FIFO fill up completely
        #1000;
        $display("[%0t] Starting reader: occ=%0d, wfull=%0b", $time, occ, vif.wfull);
        fork
            rd.run();
        join_none

        scb.run();
        #500;

        $display("-----------------------------------------");
        $display("Transactions: %0d, matched: %0d, errors: %0d", NUM, scb.matched, scb.errors);
        $display("Cycles with FIFO full: %0d", wmon.full_cycles);
        $display("Leftover in monitors (should be 0): %0d / %0d", wm.num(), rm.num());
        $display("Assertion failures: %0d", assert_fails);
        $display("Max occupancy: %0d", max_occ);
        $display("Functional coverage: %0.1f%%", cg.get_inst_coverage());
        $display("Occupancy hits: empty=%0d low=%0d mid=%0d high=%0d full=%0d", b_empty, b_low, b_mid, b_high, b_full);
        if (scb.errors == 0 && scb.matched == NUM && wm.num() == 0 && rm.num() == 0 && assert_fails == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED");
        $finish;
    end

    initial begin
        #200000;
        $display("TIMEOUT: testbench stuck");
        $finish;
    end
endmodule