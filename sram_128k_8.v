// Partial, simplified but hopefully adequate Verilog implementation of:
// https://www.alliancememory.com/wp-content/uploads/pdf/AS6C1008feb2007.pdf

module sram_128k_8v(
  A0, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, A13, A14, A15, A16,
  DQ0, DQ1, DQ2, DQ3, DQ4, DQ5, DQ6, DQ7,
  CElow, CE2,
  WElow,
  OElow,
);

  // 1,048,576 bits (1MB) of RAM
  reg sram[1048576:0];

  // 131,072 words of 8 bits (128kx8)
  // 17 bit memory address; 2^17 = 131,072; references the numberth word
  // multiply by 8 to get the position in the register
  input A0, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, A13, A14, A15, A16;
  reg [17:0] address, previousAddress;

  // Data Inouts
  inout DQ0, DQ1, DQ2, DQ3, DQ4, DQ5, DQ6, DQ7;

  // Chip Enable Inputs
  input CElow, CE2;

  // Write Enable Input
  input WElow;

  // Output Enable Input
  input OElow;

  `ifdef SIM
    reg clk;
    initial clk = 0;
    always #1 clk = ~clk;
  `else
    // TODO implement synthesizable clock
  `endif

  // Read timing registers:

  // TRC (read cycle time) min 55ns -> wait this long after address valid before putting data in DQ*
  parameter TRC = 55;
  reg [5:0] trc <= TRC;

  // TOH (output hold from address change) min 10ns -> keep previous data on DQ* for this long
  parameter TOH = 10;
  reg [3:0] toh <= TOH;

  // Write timing registers:

  // TWC (write cycle time) min 55ns -> wait this long before writing DQ* data to sram
  parameter TWC = 55;
  reg [5:0] twc <= TWC;

  // TDW (data time to write overlap) min 25ns -> data has to be present this long
  parameter TDW = 25;
  reg [4:0] tdw <= TWD;

  // TWP (write pulse width) min 45ns -> write has to be low at least this long
  parameter TWP = 45;
  reg [5:0] twp <= TWP;

  always @ ( posedge clk ) begin
    if (!CElow && CE2)
      begin
        address <= {A0, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, A13, A14, A15, A16};

        // address controlled read
        if (WElow && !OElow)
          begin
            if (address != previousAddress)
              begin
                previousAddress <= address;
                trc <= TRC;
                toh <= TOH;
                twc <= TWC;
                tdw <= TDW;
                twp <= TWP;
              end

            if (trc == 0)
              begin
                assign DQ0 <= sram[address * 8];
                assign DQ1 <= sram[address * 8 + 1];
                assign DQ2 <= sram[address * 8 + 2];
                assign DQ3 <= sram[address * 8 + 3];
                assign DQ4 <= sram[address * 8 + 4];
                assign DQ5 <= sram[address * 8 + 5];
                assign DQ6 <= sram[address * 8 + 6];
                assign DQ7 <= sram[address * 8 + 7];
              end
            else if (trc > 0)
              trc <= trc - 1;

            if (toh == 0)
              begin
                assign DQ0 <= 0;
                assign DQ1 <= 0;
                assign DQ2 <= 0;
                assign DQ3 <= 0;
                assign DQ4 <= 0;
                assign DQ5 <= 0;
                assign DQ6 <= 0;
                assign DQ7 <= 0;
              end
            else if (toh > 0)
              toh <= toh - 1;
          end

          // WElow controlled write
          if (!WElow)
            begin
              if (twc == 0 && tdw == 0 && twp == 0)
                begin
                  sram[address * 8] <= DQ0;
                  sram[address * 8 + 1] <= DQ1;
                  sram[address * 8 + 2] <= DQ2;
                  sram[address * 8 + 3] <= DQ3;
                  sram[address * 8 + 4] <= DQ4;
                  sram[address * 8 + 5] <= DQ5;
                  sram[address * 8 + 6] <= DQ6;
                  sram[address * 8 + 7] <= DQ7;
                end
              else
                begin
                  sram[address * 8] <= 0;
                  sram[address * 8 + 1] <= 0;
                  sram[address * 8 + 2] <= 0;
                  sram[address * 8 + 3] <= 0;
                  sram[address * 8 + 4] <= 0;
                  sram[address * 8 + 5] <= 0;
                  sram[address * 8 + 6] <= 0;
                  sram[address * 8 + 7] <= 0;
                end

              if (twc > 0)
                twc <= twc - 1;

              if (tdw > 0 && twc <= TWC - TDW)
                tdw <= tdw - 1;

              if (twp > 0 && twc <= TWC - TWP)
                twp <= twp - 1;
            end
      end
  end
endmodule

// eventually use 2 8 bit SIPO shift register to enter address to reduce pin count
// can reduce number of address pins used in trade for less memory
// when doing reads, delay TAA (address access time + 1) after setting address
// when doing writes, delay TWHZ before setting data after WE# goes low before putting data in DQ*
