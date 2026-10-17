module sync_r2w #(parameter ASIZE = 4) (
    input  wire             wclk, wrst_n,
    input  wire [ASIZE:0]   rptr,
    output reg  [ASIZE:0]   wq2_rptr
);
    reg [ASIZE:0] wq1_rptr;
    always @(posedge wclk or negedge wrst_n)
        if (!wrst_n) begin wq2_rptr <= 0; wq1_rptr <= 0; end
        else         begin wq2_rptr <= wq1_rptr; wq1_rptr <= rptr; end
endmodule

module sync_w2r #(parameter ASIZE = 4) (
    input  wire             rclk, rrst_n,
    input  wire [ASIZE:0]   wptr,
    output reg  [ASIZE:0]   rq2_wptr
);
    reg [ASIZE:0] rq1_wptr;
    always @(posedge rclk or negedge rrst_n)
        if (!rrst_n) begin rq2_wptr <= 0; rq1_wptr <= 0; end
        else         begin rq2_wptr <= rq1_wptr; rq1_wptr <= wptr; end
endmodule

module fifo_mem #(parameter DSIZE = 8, parameter ASIZE = 4) (
    input  wire              wclk,
    input  wire              wclken,
    input  wire              wfull,
    input  wire [ASIZE-1:0]  waddr, raddr,
    input  wire [DSIZE-1:0]  wdata,
    output wire [DSIZE-1:0]  rdata
);
    localparam DEPTH = 1 << ASIZE;
    reg [DSIZE-1:0] mem [0:DEPTH-1];
    assign rdata = mem[raddr];
    always @(posedge wclk)
        if (wclken && !wfull) mem[waddr] <= wdata;
endmodule

module wptr_full #(parameter ASIZE = 4) (
    input  wire             wclk, wrst_n, winc,
    input  wire [ASIZE:0]   wq2_rptr,
    output reg              wfull,
    output wire [ASIZE-1:0] waddr,
    output reg  [ASIZE:0]   wptr
);
    reg  [ASIZE:0] wbin;
    wire [ASIZE:0] wbin_next, wgray_next;
    wire           wfull_val;

    assign waddr      = wbin[ASIZE-1:0];
    assign wbin_next  = wbin + (winc & ~wfull);
    assign wgray_next = (wbin_next >> 1) ^ wbin_next;
    assign wfull_val  = (wgray_next == {~wq2_rptr[ASIZE:ASIZE-1], wq2_rptr[ASIZE-2:0]});

    always @(posedge wclk or negedge wrst_n)
        if (!wrst_n) begin wbin <= 0; wptr <= 0; end
        else         begin wbin <= wbin_next; wptr <= wgray_next; end

    always @(posedge wclk or negedge wrst_n)
        if (!wrst_n) wfull <= 1'b0;
        else         wfull <= wfull_val;
endmodule

module rptr_empty #(parameter ASIZE = 4) (
    input  wire             rclk, rrst_n, rinc,
    input  wire [ASIZE:0]   rq2_wptr,
    output reg              rempty,
    output wire [ASIZE-1:0] raddr,
    output reg  [ASIZE:0]   rptr
);
    reg  [ASIZE:0] rbin;
    wire [ASIZE:0] rbin_next, rgray_next;
    wire           rempty_val;

    assign raddr      = rbin[ASIZE-1:0];
    assign rbin_next  = rbin + (rinc & ~rempty);
    assign rgray_next = (rbin_next >> 1) ^ rbin_next;
    assign rempty_val = (rgray_next == rq2_wptr);

    always @(posedge rclk or negedge rrst_n)
        if (!rrst_n) begin rbin <= 0; rptr <= 0; end
        else         begin rbin <= rbin_next; rptr <= rgray_next; end

    always @(posedge rclk or negedge rrst_n)
        if (!rrst_n) rempty <= 1'b1;
        else         rempty <= rempty_val;
endmodule

module async_fifo #(parameter DSIZE = 8, parameter ASIZE = 4) (
    input  wire             wclk, wrst_n, winc,
    input  wire [DSIZE-1:0] wdata,
    output wire             wfull,
    input  wire             rclk, rrst_n, rinc,
    output wire [DSIZE-1:0] rdata,
    output wire             rempty
);
    wire [ASIZE-1:0] waddr, raddr;
    wire [ASIZE:0]   wptr, rptr, wq2_rptr, rq2_wptr;

    sync_r2w   #(ASIZE) u_sync_r2w (.wclk(wclk), .wrst_n(wrst_n), .rptr(rptr), .wq2_rptr(wq2_rptr));
    sync_w2r   #(ASIZE) u_sync_w2r (.rclk(rclk), .rrst_n(rrst_n), .wptr(wptr), .rq2_wptr(rq2_wptr));
    fifo_mem   #(DSIZE, ASIZE) u_mem (.wclk(wclk), .wclken(winc), .wfull(wfull),
                                      .waddr(waddr), .raddr(raddr), .wdata(wdata), .rdata(rdata));
    wptr_full  #(ASIZE) u_wptr_full (.wclk(wclk), .wrst_n(wrst_n), .winc(winc),
                                     .wq2_rptr(wq2_rptr), .wfull(wfull), .waddr(waddr), .wptr(wptr));
    rptr_empty #(ASIZE) u_rptr_empty (.rclk(rclk), .rrst_n(rrst_n), .rinc(rinc),
                                      .rq2_wptr(rq2_wptr), .rempty(rempty), .raddr(raddr), .rptr(rptr));
endmodule
