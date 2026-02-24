library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity depacketizer is
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

        m_axis_tdata : out std_logic_vector(7 downto 0);
        m_axis_tvalid : out std_logic;
        m_axis_tready : in std_logic;
        m_axis_tlast : out std_logic
        
    );
end entity depacketizer;

--MOORE FSM, states diagram at the end of the code

-- shift register diagram
-- S_axis_tdata -> next_input_buffer (D of first flipflop)->input_buffer(Q of first flipflop)-> next_output_buffer(D second ff)-> output_buffer(Q second ff)-> m_axis_tdata  
   
architecture rtl of depacketizer is

    -- 2 stage shift register to properly handle the read of header, data, footer
    -- i must read the next one to know if it is either last data or a normal valid data
    signal input_buffer, output_buffer : std_logic_vector(7 downto 0);
    signal next_in_buf, next_out_buf : std_logic_vector(7 downto 0);

    type state_type is (START, FIRST_READ, WAIT_FOOTER, WRITE, WRITE_LAST, DONE);
    signal state, next_state : state_type;

begin

    synchronous_logic : process(clk)
    begin
        if rising_edge(clk) then
            if aresetn = '0' then
                state <= START;
                input_buffer <= (others => '0');
                output_buffer <= (others => '0');
            else
                state <= next_state;
                input_buffer <= next_in_buf;
                output_buffer <= next_out_buf;
            end if;
        end if;
    end process;

    next_state_logic : process(state, input_buffer, output_buffer, s_axis_tdata, s_axis_tvalid, m_axis_tready)
    begin
        case (state) is

            --wait for header in uart module
            when START =>               
                if s_axis_tvalid = '1' and to_integer(unsigned(s_axis_tdata)) = HEADER then
                    next_state <= FIRST_READ;
                else
                    next_state <= START;
                end if;

                next_in_buf <= input_buffer;
                next_out_buf <= output_buffer;
            
            -- wait for handshake before saving the input byte
            -- before sending the first byte i should wait for another read in order to shift the value in the register
            -- and know if the next byte is the footer
            when FIRST_READ =>
                if s_axis_tvalid = '1' then
                    next_state <= WAIT_FOOTER;
                    next_in_buf <= s_axis_tdata;
                else
                    next_state <= FIRST_READ;
                    next_in_buf <= input_buffer;
                end if;

                next_out_buf <= output_buffer;

            -- read another byte, shift the previous data in the second register in order to send it to the next stage
            when WAIT_FOOTER =>
                if s_axis_tvalid = '1' and to_integer(unsigned(s_axis_tdata)) = FOOTER then
                    next_state <= WRITE_LAST;
                    next_out_buf <= input_buffer;
                    next_in_buf <= input_buffer;

                elsif s_axis_tvalid = '1' then
                    next_state <= WRITE;
                    next_out_buf <= input_buffer;
                    next_in_buf <= s_axis_tdata;

                else
                    next_state <= WAIT_FOOTER;
                    next_out_buf <= output_buffer;
                    next_in_buf <= input_buffer;
                end if;
            
            --send byte and go back to read
            when WRITE =>
                if m_axis_tready = '1' then
                    next_state <= WAIT_FOOTER;
                else
                    next_state <= WRITE;
                end if;

                next_in_buf <= input_buffer;
                next_out_buf <= output_buffer;

            --send last byte and keep tlast high
            when WRITE_LAST =>
                if m_axis_tready = '1' then
                    next_state <= DONE;
                else
                    next_state <= WRITE_LAST;
                end if;

                next_in_buf <= input_buffer;
                next_out_buf <= output_buffer;

            when DONE =>
                next_state <= DONE;
                next_in_buf <= input_buffer;
                next_out_buf <= output_buffer;
        end case;

    end process;

    --output logic
    s_axis_tready <= '1' when state = START else
                     '1' when state = FIRST_READ else
                     '1' when state = WAIT_FOOTER else '0';

    m_axis_tdata <= output_buffer;

    m_axis_tvalid <= '1' when state = WRITE else
                     '1' when state = WRITE_LAST else '0';

    m_axis_tlast <= '1' when state = WRITE_LAST else '0';


end architecture;


--next state only if handshake is correctly happening
--otherwise state remains the same

--    +-----------+
--    |   START   |
--    +-----------+
--        |
--        v
--    +-----------+
--    | READ FIRST|
--    +-----------+
--        |
--        v
--    +-----------+          +-----+
--    |WAIT_FOOTER| <------> |WRITE|
--    +-----------+          +-----+
--        |     
--        |
--        v       
--    +-------------+ 
--    |   WRITE LAST|
--    +-------------+
--            |                   
--            v                  
--    +-----------+ 
--    |    DONE   |
--    +-----------+