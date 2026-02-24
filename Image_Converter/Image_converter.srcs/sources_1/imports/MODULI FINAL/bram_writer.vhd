library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram_writer is
    generic(
        ADDR_WIDTH: POSITIVE := 16
    );
    port (
        clk   : in std_logic;
        aresetn : in std_logic;

        s_axis_tdata : in std_logic_vector(7 downto 0);
        s_axis_tvalid : in std_logic;
        s_axis_tready : out std_logic; 
        s_axis_tlast : in std_logic;

        conv_addr: in std_logic_vector(ADDR_WIDTH-1 downto 0);
        conv_data: out std_logic_vector(6 downto 0);

        start_conv: out std_logic;
        done_conv: in std_logic;

        write_ok : out std_logic;
        overflow : out std_logic;
        underflow: out std_logic

    );
end entity bram_writer;

architecture rtl of bram_writer is

    component bram_controller is
        generic (
            ADDR_WIDTH: POSITIVE := 16
        );
        port(
            clk   : in std_logic;
            aresetn : in std_logic;
    
            addr: in std_logic_vector(ADDR_WIDTH-1 downto 0);
            dout: out std_logic_vector(7 downto 0);
            din: in std_logic_vector(7 downto 0);
            we: in std_logic
        );
    end component;
    
    --MOORE FSM, states diagram at the end of the code

    type state_type is (READ, BEGIN_CONV, CONVERSION, DONE);
    signal state, next_state : state_type;

    --signal that drives the blinker modules "100" => write ok, "010" => overflow, "001" => underflow 
    signal led_buffer, next_led_buf : std_logic_vector(2 downto 0);

    --signal to store the address of the bram in which to store data
    signal address_buf, next_addr_buf : unsigned(ADDR_WIDTH-1 downto 0);

    --auxiliary signal for communicating with the component
    signal component_address : std_logic_vector(ADDR_WIDTH-1 downto 0);
    
    signal component_dout : std_logic_vector(7 downto 0);

    signal component_write_enable : std_logic;
    
begin

 

    synchronous_logic : process(clk)
    begin
        if rising_edge(clk) then
            if aresetn = '0' then
                state <= READ;
                led_buffer <= "000";
                address_buf <= (others => '0');
            else
                state <= next_state;
                led_buffer <= next_led_buf;
                address_buf <= next_addr_buf;
            end if;
        end if;
    end process;


    next_state_logic : process(state, led_buffer, address_buf, s_axis_tdata, s_axis_tvalid, s_axis_tlast, done_conv)
    begin
        case (state) is
            when READ =>
                --correct dimension case
                if s_axis_tvalid = '1' and s_axis_tlast = '1' and address_buf = 2**ADDR_WIDTH - 1 then
                    next_state <= BEGIN_CONV;
                    next_led_buf <= "100";
                    next_addr_buf <= address_buf;
                
                --overflow case: convolve ignoring extra bytes
                elsif s_axis_tvalid = '1' and address_buf = 2**ADDR_WIDTH - 1 then
                    next_state <= BEGIN_CONV;
                    next_led_buf <= "010";
                    next_addr_buf <= address_buf;

                --underflow case: convolve and use the initialization values already stored inside de ram for the missing bytes
                elsif s_axis_tvalid = '1' and s_axis_tlast = '1' then
                    next_state <= BEGIN_CONV;
                    next_led_buf <= "001";
                    next_addr_buf <= address_buf;

                --normal case, I update the address after saving the corresponding data
                elsif s_axis_tvalid = '1' then
                    next_state <= READ;
                    next_led_buf <= led_buffer;
                    next_addr_buf <= address_buf + 1;

                else
                    next_state <= READ;
                    next_led_buf <= led_buffer;
                    next_addr_buf <= address_buf;
                end if;

            when BEGIN_CONV =>
                next_state <= CONVERSION;
                next_led_buf <= led_buffer;
                next_addr_buf <= address_buf;

            when CONVERSION =>
                if done_conv = '1'  then
                    next_state <= DONE;
                else
                    next_state <= CONVERSION;
                end if;

                next_led_buf <= led_buffer;
                next_addr_buf <= address_buf;

            when DONE =>
                next_state <= DONE;
                next_led_buf <= led_buffer;
                next_addr_buf <= address_buf;

        end case;
    end process;
    
    BRAM_INST : bram_controller
        generic map(
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map(
            clk => clk,
            aresetn => aresetn,
            addr => component_address,
            dout => component_dout,
            din => s_axis_tdata,
            we => component_write_enable
        );

    
    --output logic
    s_axis_tready <= '1' when state = READ else '0';
    
    conv_data <= component_dout(6 downto 0);

    start_conv <= '1' when state = BEGIN_CONV else '0';

    write_ok <= led_buffer(2);

    overflow <= led_buffer(1);

    underflow <= led_buffer(0);

    component_address <= conv_addr when state = CONVERSION else
                         conv_addr when state = BEGIN_CONV else
                         std_logic_vector(address_buf);

    component_write_enable <= '1' when state = READ else '0';


end architecture;


-- when the correct handshake doesn't happen the state doesn't change 

--            +----+
--            |READ|
--            +----+
--               |
--               |
--               V
--            +----------+
--            |BEGIN_CONV|
--            +----------+
--               |
--               |
--               V
--            +----------+
--            |CONVERSION|   
--            +----------+
--                |
--                |
--                V
--            +----+
--            |DONE|
--            +----+