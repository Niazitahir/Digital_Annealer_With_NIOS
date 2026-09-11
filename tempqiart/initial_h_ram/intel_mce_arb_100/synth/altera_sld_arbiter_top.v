// (C) 2001-2025 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


//--------------------------------------------------------------------
//--
//--  Copyright (C) 1991-2015 Altera Corporation. All rights reserved.
//--
//--  Your use of Altera Corporation's design tools, logic functions  
//--  and other software and tools, and its AMPP partner logic  
//--  functions, and any output files from any of the foregoing  
//--  (including device programming or simulation files), and any  
//--  associated documentation or information are expressly subject  
//--  to the terms and conditions of the Altera Program License  
//--  Subscription Agreement, Altera MegaCore Function License  
//--  Agreement, or other applicable license agreement, including,  
//--  without limitation, that your use is for the sole purpose of  
//--  programming logic devices manufactured by Altera and sold by  
//--  Altera or its authorized distributors.  Please refer to the  
//--  applicable agreement for further details. 
//--
//--------------------------------------------------------------------

//-------------------------------------------------------------------
// Filename    : altera_sld_arbiter_top.v
//
// Description : Muxing user_read/write and ismce_read/write with user signals has priority.
//
// Limitation  : Meant for Stratix 10 and beyond
//
//-------------------------------------------------------------------

module altera_sld_arbiter_top
    #(
        parameter LATENCY = 2,
        parameter DATA_WIDTH = 32,
        parameter WIDTHAD = 8,
        parameter BYTE_ENABLE_WIDTH = 1
    )
    (
        // Clocks / Reset
        input clk,
        // reset not used but keep for future    
        input reset,

        // User mem signals
        input[WIDTHAD-1:0] uaddr,
        input[BYTE_ENABLE_WIDTH-1:0] ubyteena,
        input[DATA_WIDTH-1:0] uwdata,
        input urden,
        input uwren,
        input uaddressstall,
        output[DATA_WIDTH-1:0] urdata,

        // ISMCE mem signals to arbiter
        input [WIDTHAD-1:0]  ismce_addr,
        input [BYTE_ENABLE_WIDTH-1:0] ismce_byteena,
        input [DATA_WIDTH-1:0]  ismce_wdata,
        input                   ismce_wren,
        input                   ismce_rden,
        output[DATA_WIDTH-1:0]  ismce_rdata,
        output                  ismce_waitrequest,

        // Ram signals
        output[WIDTHAD-1:0] addr,
        output[BYTE_ENABLE_WIDTH-1:0] byteena,
        output[DATA_WIDTH-1:0] wdata,
        output rden,
        output wren,
        output addressstall,
        input[DATA_WIDTH-1:0] rdata
    );

altera_sld_arbiter #(
        .LATENCY           (LATENCY          ),
        .DATA_WIDTH        (DATA_WIDTH       ),
        .WIDTHAD           (WIDTHAD          ),
        .BYTE_ENABLE_WIDTH (BYTE_ENABLE_WIDTH)
    ) altera_sld_arbiter_inst  (
        .clk               (clk              ),
        .reset             (reset            ),
        .uaddr             (uaddr            ),
        .ubyteena          (ubyteena         ),
        .uwdata            (uwdata           ),
        .urden             (urden            ),
        .uwren             (uwren            ),
        .uaddressstall     (uaddressstall    ),
        .urdata            (urdata           ),
        .ismce_addr        (ismce_addr       ),
        .ismce_byteena     (ismce_byteena    ),
        .ismce_wdata       (ismce_wdata      ),
        .ismce_wren        (ismce_wren       ),
        .ismce_rden        (ismce_rden       ),
        .ismce_rdata       (ismce_rdata      ),
        .ismce_waitrequest (ismce_waitrequest),
        .addr              (addr             ),
        .byteena           (byteena          ),
        .wdata             (wdata            ),
        .rden              (rden             ),
        .wren              (wren             ),
        .addressstall      (addressstall     ),
        .rdata             (rdata            )
    );
    

endmodule 
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "KaCcZ9W53ZG+KOUC3MpOxTkG8JzVU+FMIR8JyDs33NK1wcErIABMqJM+BlBnaEf20FCKJ7ToOlAha/ltC5u0ZbClu2TybZQciMInF+iFoiagt+B91BK4dyi6GJUCXUDuBK9YH6nNlwSkR01tHuzzS5ZEiJtw78iQaS7cFEmJNjv/muideRZVdy13EnGEeyFpK62Cg4KcVOZTCHinGABXbAtq/uBBjPG6GClkBmeTng1wPRYgjGf7uYiVSb9Kmdf3R9U3zJCw+2a2bjs2ilLCsHjeZOG5rIezcpD6TOwCJ5qX0vNDXBm6KFcvCCG+CJzATX/Kik/1HNy8RjgLrTctJLUfNm//vmKOXqhvguJeCGErG7k01ob5hMNA5T1hvft/4wlOb7K0OI6EZo/do74cAQqz7+hH7OYvn3TtBoAFoSbn7x+lAgi2+xuwtCLOkEtkPZVEQZc6+/5Bm7p8MXkKg6ljWO+a9gxkzf2dfVEy4F3GUohovPOnnTynW/WKLn5OQztcIbKr+S0KBchqu59bcOyuyMdYwoeRBxXnppu+hhW5rfUJ9XG6lr1cnfJNCwt6NuH2WBn80gzVGd0OdOynXd2vdt8kBJcxK05GrW1RRRZb806pmYj6kodE0D3/gJGB+crLMUXG+i4jGjl0YxwxJZFg3tYW4We2KrFRkmzOfJQDW0aEISjaG6GRonqrhnxTgGSDQqTHa5FZw5YgAKZOiRlpsYFxpBD8c7WyWwnW/UY87JpBxJCJ17nwpouzrJS5WmhwGiZH+D0953jEANGvMwDGU0syB/1ULsDVYhheLD1j6uIeZiyKicaaUohTFIzvvzObKB4LNnbPT1No3NQhfrjhFPr7d6AEhY/L0cial3kD7OH04a7M9EvFWBEoAOZj/u0b6zIZAY/HknMhC3atB5bZlkbPaqIsyq/t6Hb/OsQIWzZjK/CFmDEm9WQjHww8712FbPj3foxKN3smtUPMH48MQmyxyOTqelWWu1ycwI/nhokDsIcpklJDNIqn9hT9"
`endif