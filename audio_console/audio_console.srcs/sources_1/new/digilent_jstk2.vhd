library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD;

entity digilent_jstk2 is
	generic (
		DELAY_US		: integer := 30;    -- Delay (in us) between two packets = 50 us
		CLKFREQ		 	: integer := 100_000_000;  -- Frequency of the aclk signal (in Hz) = 10 ns
		SPI_SCLKFREQ 	: integer := 5000 -- Frequency of the SPI SCLK clock signal (in Hz) = 200us
	);
	Port ( 
		aclk 			: in  STD_LOGIC;
		aresetn			: in  STD_LOGIC;

		-- Data going TO the SPI IP-Core (and so, to the JSTK2 module)
		m_axis_tvalid	: out STD_LOGIC;
		m_axis_tdata	: out STD_LOGIC_VECTOR(7 downto 0);
		m_axis_tready	: in STD_LOGIC;

		-- Data coming FROM the SPI IP-Core (and so, from the JSTK2 module)
		-- There is no tready signal, so you must be always ready to accept and use the incoming data, or it will be lost!
		s_axis_tvalid	: in STD_LOGIC;
		s_axis_tdata	: in STD_LOGIC_VECTOR(7 downto 0);

		-- Joystick and button values read from the module
		jstk_x			: out std_logic_vector(9 downto 0);
		jstk_y			: out std_logic_vector(9 downto 0);
		btn_jstk		: out std_logic;
		btn_trigger		: out std_logic;

		-- LED color to send to the module
		led_r			: in std_logic_vector(7 downto 0);
		led_g			: in std_logic_vector(7 downto 0);
		led_b			: in std_logic_vector(7 downto 0)
	);
end digilent_jstk2;

architecture Behavioral of digilent_jstk2 is

	-- Code for the SetLEDRGB command, see the JSTK2 datasheet.
constant CMDSETLEDRGB		: std_logic_vector(7 downto 0) := x"84";
constant WAIT_TIME_US       : integer RANGE 0 TO 500 := DELAY_US + 1000000/SPI_SCLKFREQ;
constant COUNTER_VALUE      : INTEGER RANGE 0 TO 50000 := WAIT_TIME_US*(CLKFREQ/1000000); -- 225us = 225*10-6 / Tclk = 225*10-6 * fclk = 25US + 1SPI CLK

	-- Do not forget that you MUST wait a bit between two packets. See the JSTK2 datasheet (and the SPI IP-Core README).
type my_state_out is (COMMAND, SENDING_R, SENDING_G, SENDING_B, SENDING_DUMMY, RECEIVER, WAITER);
signal state_out : my_state_out := COMMAND;

type my_state_in is (X_LOW, X_HIGH, Y_LOW, Y_HIGH, BUTTONS);
signal state_in : my_state_in := X_LOW;

signal counter_end: integer RANGE 0 TO 50000:= COUNTER_VALUE;
signal packet : integer RANGE 0 TO 5 := 0;
signal temp_x : std_logic_vector(9 DOWNTO 0);
signal temp_y : std_logic_vector(9 DOWNTO 0);

begin
-------------------------------------- OUTPUT LOGIC

    process (aclk, aresetn)
    
        begin
        
        if aresetn = '0' then
	       state_out <= COMMAND;
	    
        elsif rising_edge(aclk) then
                
        case (state_out) is
            
            when COMMAND => 
                           
                    m_axis_tdata <= CMDSETLEDRGB;   ------- COMMAND SENDING
                    counter_end <= COUNTER_VALUE;           ------- RESETTING WAITER COUNTER
                    m_axis_tvalid <= '1';           ------- VALID OUTPUT
                    
                    state_out <= RECEIVER;
                    packet <= packet + 1;                                                         
                 
            when SENDING_R =>                  
                    
                    m_axis_tdata <= led_r;          ------- SENDING R DUTY CYCLE
                    m_axis_tvalid <= '1';
                    
                    state_out <= RECEIVER;
                    packet <= packet + 1; 
                    
            when SENDING_G =>                  
                    
                    m_axis_tdata <= led_g;          ------- SENDING G DUTY CYCLE
                    m_axis_tvalid <= '1';
                    
                    state_out <= RECEIVER;
                    packet <= packet + 1;
            
            when SENDING_B =>                  
                    
                    m_axis_tdata <= led_b;          ------- SENDING B DUTY CYCLE
                    m_axis_tvalid <= '1';
                    
                    state_out <= RECEIVER;
                    packet <= packet + 1;
            
            when SENDING_DUMMY =>                  
                    
                    m_axis_tdata <= (Others => '1');          ------- SENDING DUMMY BIT
                    m_axis_tvalid <= '1';
                    
                    state_out <= RECEIVER;
                    packet <= packet + 1; 
                    
            when RECEIVER =>
                    
                    if m_axis_tready = '1' then
                        m_axis_tvalid <= '0';                 ------- WHEN THE HANDSHAKE IS DONE WE CHANGE THE DATA SO TO NOT HAVE SPURIOS READINGS I PUT OUT INVALID
                        
                        case (packet) is                      ------- DEPENDING ON THE VALUE OF THE PACKET I KNOW WHICH WAS THE LAST DATA SENT
                            
                            when 1 => 
                                state_out <= SENDING_R;
                                
                            when 2 => 
                                state_out <= SENDING_G;
                            
                            when 3 => 
                                state_out <= SENDING_B;
                            
                            when 4 => 
                                state_out <= SENDING_DUMMY;
                            
                            when 5 => 
                                state_out <= WAITER;
                                packet <= 0;
                                
                            when Others =>
                                state_out <= WAITER;
                            
                            end case;
                      
                      end if;
                     
            when WAITER =>
                    
                    if counter_end = 0 then                  ------ IF THE WAIT IS OVER RESTART THE DATA SENDING
                        state_out <= COMMAND;                    
                    else 
                        counter_end <= counter_end - 1;      ------ IF NOT KEEP WAITING            
                    end if;
            
            end case;
            
        end if; 
               
    end process;
 
 -------------------------------------- OUTPUT LOGIC
   
    process (aclk, aresetn)
    
        begin
        
        if aresetn = '0' then
	       state_in <= X_LOW;
           temp_x <= (others => '0');
           temp_y <= (others => '0');
           jstk_x <= (others => '0');
           jstk_y <= (others => '0');
           btn_trigger <= '0';
           btn_jstk <= '0';
	    
        elsif rising_edge(aclk) then
        
            if s_axis_tvalid = '1' then
               
            case (state_in) is                 ------ SINCE I DON'T HAVE A READY SIGNAL, I MUST CYCLE WHEN VALID IS HIGH
            
                when X_LOW => 
                           
                        
                            temp_x(7 DOWNTO 0) <= s_axis_tdata;   ----- I'M USING TEMPORARY STORAGES TO NOT HAVE SPURIOUS VALUES
                            state_in <= X_HIGH;
                       
            
                when X_HIGH => 
                           
                            temp_x(9 DOWNTO 8) <= s_axis_tdata(1 DOWNTO 0);
                            state_in <= Y_LOW;
          
                when Y_LOW => 
                           
                        
                            temp_y(7 DOWNTO 0) <= s_axis_tdata;
                            state_in <= Y_HIGH;
                        
                when Y_HIGH => 
                                              
                            temp_y (9 DOWNTO 8) <= s_axis_tdata(1 DOWNTO 0);
                            state_in <= BUTTONS;
                       
                when BUTTONS => 
                           
                            btn_jstk <= s_axis_tdata(0);
                            btn_trigger <= s_axis_tdata(1);
                            jstk_x <= temp_x;
                            jstk_y <= temp_y;
                            state_in <= X_LOW;
                                              
                end case;      
            
            end if;
        
        end if;
        
        end process;       
                          
end architecture;