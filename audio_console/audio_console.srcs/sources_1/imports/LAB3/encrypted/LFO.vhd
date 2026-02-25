library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity LFO is
    generic(
        CHANNEL_LENGHT  : integer := 24;
        JOYSTICK_LENGHT  : integer := 10;
        CLK_PERIOD_NS   : integer := 10;
        TRIANGULAR_COUNTER_LENGHT    : integer := 10 -- Triangular wave period length
    );
    Port (
        
            aclk			: in std_logic;
            aresetn			: in std_logic;
            
            lfo_period      : in std_logic_vector(JOYSTICK_LENGHT-1 downto 0);
            
            lfo_enable      : in std_logic;
    
            s_axis_tvalid	: in std_logic;
            s_axis_tdata	: in std_logic_vector(CHANNEL_LENGHT-1 downto 0);
            s_axis_tlast    : in std_logic;
            s_axis_tready	: out std_logic;
    
            m_axis_tvalid	: out std_logic;
            m_axis_tdata	: out std_logic_vector(CHANNEL_LENGHT-1 downto 0);
            m_axis_tlast	: out std_logic;
            m_axis_tready	: in std_logic
        );
end entity LFO;

architecture Behavioral of LFO is

----USEFUL CONSTANT TO EASE THE CODE----
	constant LFO_COUNTER_BASE_PERIOD_US : integer := 1000; -- Base period of the LFO counter in us (when the joystick is at the center)
	constant ADJUSTMENT_FACTOR : integer := 90; -- Multiplicative factor to scale the LFO period properly with the joystick y position
	
	constant COUNTER_BASE : integer := LFO_COUNTER_BASE_PERIOD_US/CLK_PERIOD_NS * 1000; -- Number of clk cycles i need when we are in the starting position of the joystick
	
	constant MULTIPLICATION_BITS : integer := CHANNEL_LENGHT+TRIANGULAR_COUNTER_LENGHT +1; -- Number of bits needed for the multiplication
	
	constant PIPELINE_OPERATIONS : integer := 3; --Cycles of clk needed to complete the pipeline that changes the period of the lfo
	
	constant BIAS : integer := 512; -- Helpful constant to bring the joystick to zero when in starting position

--TYPES: ONE FOR THE STATE AND ONE USED TO CLARIFY THE "reverse" SIGNAL----
	type state_t is (TX_WAIT_LEFT, TX_WAIT_RIGHT, MULTIPLICATION_STATE, SHIFTER_STATE, RX_WAIT_LEFT, RX_WAIT_RIGHT);
	type reverse_t is (no, yes);
	
----SIGNAL USED IN THE LOGIC PROCESS (FSM)----
	signal state : state_t := TX_WAIT_LEFT;
	----To get the right value for the LFO we multiply the value for the step and then we just shift to the right of TRIANGULAR_COUNTER_LENGHT bit
	signal data_left, data_right : std_logic_vector (CHANNEL_LENGHT-1 downto 0) := (others => '0'); --Signals used to store data
	signal last_l, last_r : std_logic := '0'; -- Signals use to store the s_axis_tlast bit
	signal data_long_l, data_long_r : signed(MULTIPLICATION_BITS downto 0); -- Signals used to store the data that we get from the multiplication, one bit more for the sign
	
	
----SIGNAL USED IN THE COUNTER PROCESS----
	signal clk_counter 		: integer range 0 to 146079;						-- Clk counter
	signal period 			: integer range 54010 to 146079;					-- Clks we need to count to change step
	signal step 			: integer range 0 to 2**TRIANGULAR_COUNTER_LENGHT;	-- Number of steps we have in our function
	signal adjust 			: integer range -512 to 511;						-- First operation to get to period with pipeline
	signal multiplication 	: integer range -46080 to 45990;					-- Second operation to get to period with pipeline
	
	signal reverse  		: reverse_t;										-- Signal to know if we are going up or down the steps
	signal pipeline 		: integer range 0 to PIPELINE_OPERATIONs;			-- Signal to count if we did do every operation for the right value of period
	signal lfo_period_old 	: std_logic_vector(JOYSTICK_LENGHT-1 downto 0);		-- Signal to know if the lfo_period data changed

begin  

----PROCESS FOR THE COUNTER LOGIC TO GET THE MULTIPLICATION FACTOR----

	COUNTER : process(aclk)
	begin
		if rising_edge(aclk) then 
			if aresetn = '0' then
				period <= COUNTER_BASE;
				lfo_period_old <= std_logic_vector(to_unsigned(BIAS, JOYSTICK_LENGHT));
				step <= 2**TRIANGULAR_COUNTER_LENGHT;
				adjust <= 0;
				reverse <= no;
				multiplication <= 0;
				pipeline <= PIPELINE_OPERATIONS;
				
			elsif lfo_enable = '1' then		---- Checks if we exectute the Counter_logic of leave it in IDLE ----
				CLK_COUNTER_ENDED : if clk_counter = period then
					
					clk_counter <= 0;
					---- Checks when we reach the end of one side of the triangle and goes the other way. The number of steps top to bottom is 2**TRIANGULAR_COUNTER_LENGHT - 1 ----
					REVERSE_LOGIC : if reverse = no then
						step <= step - 1;
						if step = 1 then						
							reverse <= yes;							
						end if;										
					else
						step <= step + 1;
						if step = 2**TRIANGULAR_COUNTER_LENGHT - 1 then
							reverse <= no;
						end if;
					end if;
					
				else 
					clk_counter <= clk_counter + 1;
					---- Logic for the pipeline. To avoid the repetition each time, "pipeline" helps me understand when to execute this logic and when this logic ended ----
					PIPERLINE_LOGIC : if pipeline /= PIPELINE_OPERATIONS then 
					
						adjust <= (to_integer(unsigned(lfo_period_old)) - BIAS);
						
						multiplication <= ADJUSTMENT_FACTOR*adjust;
						
						period <= COUNTER_BASE - multiplication - 1;
						
						pipeline <= pipeline + 1;

					end if;
					---- Checks if lfo_period changed to start the pipeline that changes the period; as a choice to avoid more logic the counter is reset ----
					CHECK_LFO_CHANGED : if lfo_period /= lfo_period_old then
						pipeline <= 0;
						clk_counter <= 0;
						lfo_period_old <= lfo_period;
					end if;
					
				end if;	
				
			else
			---- Logic when we have lfo_enable = '0'. As a choice clk_counter and step are reset to the values 0 and 2**TRIANGULAR_COUNTER_LENGHT ----
				clk_counter <= 0;
				step <= 2**TRIANGULAR_COUNTER_LENGHT;
				
				PIPERLINE_LOGIC_2 : if pipeline /= PIPELINE_OPERATIONS then 
								
					adjust <= (to_integer(unsigned(lfo_period_old)) - BIAS);
					
					multiplication <= ADJUSTMENT_FACTOR*adjust;
					
					period <= COUNTER_BASE - multiplication - 1;
					
					pipeline <= pipeline + 1;

				end if;
				
				CHECK_LFO_CHANGED_2 : if lfo_period /= lfo_period_old then
					pipeline <= 0;
					lfo_period_old <= lfo_period;
				end if;
			
			end if;
		end if;
	end process;

-----------------Logic to change s_axis_tready and m_axis_tvalid-------------------------

	s_axis_tready <= '1' when state = TX_WAIT_LEFT or state = TX_WAIT_RIGHT else '0'; 
	m_axis_tvalid <= '1' when state = RX_WAIT_LEFT or state = RX_WAIT_RIGHT else '0';
	
-----------------------------------------------------------------------------------------

-------------------------------------------------STATE LOGIC------------------------------------------------------
----As a group choice we decided to handle the left and right channel together so we wait to acquire both data----

	LOGIC_PROCESS : process (aclk, aresetn)
	begin 
		if rising_edge(aclk) then
			if aresetn = '0' then
				state <= TX_WAIT_LEFT;
				last_l <= '0';
				last_r <= '0';
			else
				case state is
				----State to aquire the left channel data----
					when TX_WAIT_LEFT =>		
						if s_axis_tvalid = '1' then
							data_left <= s_axis_tdata;
							state <= TX_WAIT_RIGHT;
							last_l <= s_axis_tlast;
						end if;
				----State to aquire the right channel data----	
					when TX_WAIT_RIGHT =>
						if s_axis_tvalid = '1' then
							data_right <= s_axis_tdata;
							
						----If we have lfo_enable high we process datas otherwise we just bring them to the output----
							if lfo_enable = '1' then
								state <= MULTIPLICATION_STATE;
							else 
								state <= RX_WAIT_LEFT;
							end if;
							last_r <= s_axis_tlast;
						end if;	
				
				----State to multiply the data to reach the designated value----
					when MULTIPLICATION_STATE => 
	
						data_long_l <= signed(data_left) * to_signed(step, TRIANGULAR_COUNTER_LENGHT + 2);
						data_long_r <= signed(data_right) * to_signed(step, TRIANGULAR_COUNTER_LENGHT + 2);
						
						state <= SHIFTER_STATE;
				
				----State to shift the longer data we have and get the right value for the lfo----	
					when SHIFTER_STATE => 
						
						data_left <= std_logic_vector(resize(shift_right(signed(data_long_l), TRIANGULAR_COUNTER_LENGHT), CHANNEL_LENGHT));
						data_right <= std_logic_vector(resize(shift_right(signed(data_long_r), TRIANGULAR_COUNTER_LENGHT), CHANNEL_LENGHT));
						
						state <= RX_WAIT_LEFT;
					
				----Output state for the left channel----	
					when RX_WAIT_LEFT => 
						m_axis_tdata <= data_left;
						m_axis_tlast <= last_l;
						if m_axis_tready = '1' then
							state <= RX_WAIT_RIGHT;
						end if;
				
				----Output state for the right channel----	
					when RX_WAIT_RIGHT => 
						m_axis_tdata <= data_right;
						m_axis_tlast <= last_r;
						if m_axis_tready = '1' then
							state <= TX_WAIT_LEFT;
						end if;
					
				end case;
			
			
			end if;
		end if;
	end process;
	

end architecture;