package fifo_pkg;

    class fifo_txn;
        rand bit [7:0]    data;
        rand int unsigned gap;   // idle cycles before this write
        constraint c_gap { gap dist {0 := 6, [1:3] :/ 4}; }
    endclass

    class fifo_gen;
        mailbox #(fifo_txn) g2d;
        int num;
        function new(mailbox #(fifo_txn) m, int n);
            g2d = m; num = n;
        endfunction
        task run();
            fifo_txn t;
            repeat (num) begin
                t = new();
                if (!t.randomize()) $error("randomize failed");
                g2d.put(t);
            end
        endtask
    endclass

    class fifo_wdrv;
        virtual fifo_if #(8) vif;
        mailbox #(fifo_txn) g2d;
        function new(virtual fifo_if #(8) v, mailbox #(fifo_txn) m);
            vif = v; g2d = m;
        endfunction
        task run();
            fifo_txn t;
            @(negedge vif.wclk);
            forever begin
                g2d.get(t);
                repeat (t.gap) begin
                    vif.winc = 0;
                    @(negedge vif.wclk);
                end
                while (vif.wfull) begin
                    vif.winc = 0;
                    @(negedge vif.wclk);
                end
                vif.winc  = 1;
                vif.wdata = t.data;
                @(negedge vif.wclk);
                if (g2d.num() == 0) vif.winc = 0;
            end
        endtask
    endclass

    class fifo_rdrv;
    bit pause = 0;
        virtual fifo_if #(8) vif;
        function new(virtual fifo_if #(8) v);
            vif = v;
        endfunction
        task run();
            @(negedge vif.rclk);
            forever begin
                if (!vif.rempty && ($urandom_range(0,3) != 0)) vif.rinc = 1;
                else                                            vif.rinc = 0;
                @(negedge vif.rclk);
            end
        endtask
    endclass

    class fifo_wmon;
        virtual fifo_if #(8) vif;
        mailbox #(bit [7:0]) mbx;
        int full_cycles = 0;
        function new(virtual fifo_if #(8) v, mailbox #(bit [7:0]) m);
            vif = v; mbx = m;
        endfunction
        task run();
            forever begin
                @(posedge vif.wclk);
                if (vif.wfull) full_cycles++;
                if (vif.winc && !vif.wfull) mbx.put(vif.wdata);
            end
        endtask
    endclass

    class fifo_rmon;
        virtual fifo_if #(8) vif;
        mailbox #(bit [7:0]) mbx;
        function new(virtual fifo_if #(8) v, mailbox #(bit [7:0]) m);
            vif = v; mbx = m;
        endfunction
        task run();
            forever begin
                @(posedge vif.rclk);
                if (vif.rinc && !vif.rempty) mbx.put(vif.rdata);
            end
        endtask
    endclass

    class fifo_scb;
        mailbox #(bit [7:0]) wmbx, rmbx;
        int num, matched = 0, errors = 0;
        function new(mailbox #(bit [7:0]) w, mailbox #(bit [7:0]) r, int n);
            wmbx = w; rmbx = r; num = n;
        endfunction
        task run();
            bit [7:0] exp, got;
            repeat (num) begin
                rmbx.get(got);
                wmbx.get(exp);
                if (got === exp) matched++;
                else begin
                    errors++;
                    $display("[%0t] SCB FAIL: got 0x%0h expected 0x%0h", $time, got, exp);
                end
            end
        endtask
    endclass

endpackage
