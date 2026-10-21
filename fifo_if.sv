interface fifo_if #(parameter DSIZE = 8) (input logic wclk, input logic rclk);
    logic             wrst_n = 0, rrst_n = 0;
    logic             winc = 0, rinc = 0;
    logic [DSIZE-1:0] wdata = '0, rdata;
    logic             wfull, rempty;

    // Write side: TB drives winc/wdata, samples wfull
    clocking wcb @(posedge wclk);
        default input #1step output #1;
        output winc, wdata;
        input  wfull;
    endclocking

    // Read side: TB drives rinc, samples rdata/rempty
    clocking rcb @(posedge rclk);
        default input #1step output #1;
        output rinc;
        input  rdata, rempty;
    endclocking
endinterface
