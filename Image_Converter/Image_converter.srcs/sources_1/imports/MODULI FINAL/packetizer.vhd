library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity packetizer is
    generic (
        HEADER: INTEGER :=16#FF#;
        FOOTER: INTEGER :=16#F1#
    );
    port (
        clk   : in std_logic;
        aresetn : in std_logic;

        s_axis_tdata : in std_logic_vector(7 downto 0);
        s_axis_tvalid : in std_logic;
        s_axis_tready : out std_logic;
        s_axis_tlast : in std_logic;

        m_axis_tdata : out std_logic_vector(7 downto 0);
        m_axis_tvalid : out std_logic;
        m_axis_tready : in std_logic
        
    );
end entity packetizer;

--MOORE FSM, state diagram at bottom of the code

architecture rtl of packetizer is

    --registers to save byte received
    signal memory, next_mem : std_logic_vector(7 downto 0);

    type state_type is (START, WRITE_HEADER, WRITE, READ, WRITE_LAST, WRITE_FOOTER, DONE,WRITE_HEAD_EXCEP);
    signal state, next_state : state_type;

begin

    synchronous_logic : process(clk, aresetn, next_state, next_mem)
    begin
        if rising_edge(clk) then
            if aresetn = '0' then
                state <= START;
                memory <= (others => '0');
            else
                state <= next_state;
                memory <= next_mem;
            end if;
        end if;
    end process;

    next_state_logic : process(state, memory, s_axis_tdata, s_axis_tvalid, s_axis_tlast, m_axis_tready)
    begin
        case (state) is
            --wait for the first valid data and save to the buffer
            -- transmitt the header to the next state
            --write head excep occurs when we have only 1 byte of information example: 0xFF -> 0x01(or whatever data) -> 0xF1 (verified via realterm)
            when START =>
                if s_axis_tvalid = '1' and s_axis_tlast='1' then
                    next_state <= WRITE_HEAD_EXCEP;
                    next_mem <= s_axis_tdata;
                elsif s_axis_tvalid = '1' then
                    next_state <= WRITE_HEADER;
                    next_mem <= s_axis_tdata;
                else
                    next_state <= START;
                    next_mem <= memory;
                end if;

            --send header and pass the first valid byte to the next state
            when WRITE_HEADER =>
                if m_axis_tready = '1' then
                    next_state <= WRITE;
                else
                    next_state <= WRITE_HEADER;
                end if;

                next_mem <= memory;
            
            --send the valid data
            when WRITE =>
                if m_axis_tready = '1' then
                    next_state <= READ;
                else
                    next_state <= WRITE;
                end if;

                next_mem <= memory;

            --read the valid data in input 
            -- if last valid data go to WRITE_LAST instead of WRITE
            when READ =>
                if s_axis_tvalid = '1' and s_axis_tlast = '1' then
                    next_state <= WRITE_LAST;
                    next_mem <= s_axis_tdata;
                
                elsif s_axis_tvalid = '1' then
                    next_state <= WRITE;
                    next_mem <= s_axis_tdata;

                else                   
                    next_state <= READ;
                    next_mem <= memory;
                end if;

            --write last valid data 
            when WRITE_LAST =>
                if m_axis_tready = '1' then
                    next_state <= WRITE_FOOTER;
                    next_mem <= std_logic_vector(to_unsigned(FOOTER,8));
                else
                    next_state <= WRITE_LAST;
                    next_mem <= memory;
                end if;

                
            
            --write footer
            when WRITE_FOOTER =>
                if m_axis_tready = '1' then
                    next_state <= DONE;
                else
                    next_state <= WRITE_FOOTER;
                end if;

                next_mem <= memory;
            
            when DONE =>
                next_state <= DONE;
                next_mem <= memory;
            WHEN WRITE_HEAD_EXCEP =>
                 next_state <= write_last;
                 next_mem<= memory;     
            end case;
    end process;


    --output logic
    m_axis_tdata <= std_logic_vector(to_unsigned(HEADER, 8)) when state = WRITE_HEADER else
                    std_logic_vector(to_unsigned(HEADER, 8)) when state = WRITE_HEAD_EXCEP else memory;
    s_axis_tready <= '1' when state = START else
                     '1' when state = READ else '0';
                     
    m_axis_tvalid <= '1' when state = WRITE_HEADER else
                     '1' when state = WRITE else
                     '1' when state = WRITE_LAST else
                     '1' when state = WRITE_FOOTER else
                     '1' when state = WRITE_HEAD_EXCEP else '0';
 
end architecture;


--next state happens if handshake is correctly happening
--otherwise the state remains the same
--    +-----------+
--    |   START   | -------> WRITE_HEAD_EXCEP ------> WRITE_LAST (the same state of below)
--    +-----------+                                         
--        |
--        v
--    +-------------+
--    | WRITE_HEADER|
--    +-------------+
--        |
--        v
--    +-----------+          +-----+
--    |   WRITE   | <------> |READ |
--    +-----------+          +-----+
--                              |     
--                              |
--                              v       
--                          +-------------+ 
--                          | WRITE LAST  |
--                          +-------------+
--                                  |                   
--                                  v                  
--                          +------------+     +----+
--                          |WRITE_FOOTER|---> |DONE|
--                          +------------+     +----+