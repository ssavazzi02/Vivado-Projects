library ieee;
use ieee.std_logic_1164.all;

Library xpm;
use xpm.vcomponents.all;

entity bram_controller is
    generic (
        ADDR_WIDTH: POSITIVE :=16
    );
    port (
        clk   : in std_logic;
        aresetn : in std_logic;

        addr: in std_logic_vector(ADDR_WIDTH-1 downto 0);
        dout: out std_logic_vector(7 downto 0);
        din: in std_logic_vector(7 downto 0);
        we: in std_logic
    );
end entity bram_controller;

architecture rtl of bram_controller is

begin

-- xpm_memory_spram: Single Port RAM
-- Xilinx Parameterized Macro, version 2020.2

xpm_memory_spram_inst : xpm_memory_spram
generic map (
   ADDR_WIDTH_A => ADDR_WIDTH,      -- DECIMAL
   AUTO_SLEEP_TIME => 0,            -- DECIMAL
   BYTE_WRITE_WIDTH_A => 8,         -- DECIMAL
   CASCADE_HEIGHT => 0,             -- DECIMAL
   ECC_MODE => "no_ecc",            -- String
   MEMORY_INIT_FILE => "none",      -- String
   MEMORY_INIT_PARAM => "0",        -- String
   MEMORY_OPTIMIZATION => "true",   -- String
   MEMORY_PRIMITIVE => "block",     -- String
   MEMORY_SIZE => (2**ADDR_WIDTH)*8,-- DECIMAL
   MESSAGE_CONTROL => 0,            -- DECIMAL
   READ_DATA_WIDTH_A => 8,          -- DECIMAL
   READ_LATENCY_A => 1,             -- DECIMAL
   READ_RESET_VALUE_A => "0",       -- String
   RST_MODE_A => "SYNC",            -- String
   SIM_ASSERT_CHK => 0,             -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
   USE_MEM_INIT => 1,               -- DECIMAL
   WAKEUP_TIME => "disable_sleep",  -- String
   WRITE_DATA_WIDTH_A => 8,         -- DECIMAL
   WRITE_MODE_A => "read_first"     -- String
)
port map (
   dbiterra => open,                  -- 1-bit output: Status signal to indicate double bit error occurrence
                                     -- on the data output of port A.

   douta => dout,                    -- READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
   sbiterra => open,                 -- 1-bit output: Status signal to indicate single bit error occurrence
                                     -- on the data output of port A.

   addra => addr,                    -- ADDR_WIDTH_A-bit input: Address for port A write and read operations.
   clka => clk,                      -- 1-bit input: Clock signal for port A.
   dina => din,                      -- WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
   ena => '1',                       -- 1-bit input: Memory enable signal for port A. Must be high on clock
                                     -- cycles when read or write operations are initiated. Pipelined
                                     -- internally.

   injectdbiterra => '0',            -- 1-bit input: Controls double bit error injection on input data when
                                     -- ECC enabled (Error injection capability is not available in
                                     -- "decode_only" mode).

   injectsbiterra => '0',            -- 1-bit input: Controls single bit error injection on input data when
                                     -- ECC enabled (Error injection capability is not available in
                                     -- "decode_only" mode).

   regcea => '1',                    -- 1-bit input: Clock Enable for the last register stage on the output
                                     -- data path.

   rsta => (not aresetn),            -- 1-bit input: Reset signal for the final port A output register
                                     -- stage. Synchronously resets output port douta to the value specified
                                     -- by parameter READ_RESET_VALUE_A.

   sleep => '0',                     -- 1-bit input: sleep signal to enable the dynamic power saving feature.
   wea(0) => we                      -- WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                     -- for port A input data port dina. 1 bit wide when word-wide writes
                                     -- are used. In byte-wide write configurations, each bit controls the
                                     -- writing one byte of dina to address addra. For example, to
                                     -- synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                     -- is 32, wea would be 4'b0010.

);

-- End of xpm_memory_spram_inst instantiation

end architecture;