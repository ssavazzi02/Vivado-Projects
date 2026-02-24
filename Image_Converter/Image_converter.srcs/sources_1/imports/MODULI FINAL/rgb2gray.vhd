---------- DEFAULT LIBRARIES -------
library IEEE;
	use IEEE.STD_LOGIC_1164.all;
	use IEEE.NUMERIC_STD.ALL;
	use IEEE.MATH_REAL.all;	-- For LOG **FOR A CONSTANT!!**
------------------------------------

---------- OTHER LIBRARIES ---------
-- NONE
------------------------------------

entity rgb2gray is
	Port (
		clk				: in std_logic;
		resetn			: in std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(7 downto 0);
		m_axis_tready	: in std_logic;
		m_axis_tlast	: out std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(7 downto 0);
		s_axis_tready	: out std_logic;
		s_axis_tlast	: in std_logic
	);
end rgb2gray;

--MOORE FSM, state diagram at bottom of the code


architecture Behavioral of rgb2gray is

    component division_lut is
        generic(
            NUMERATOR : integer := 43;
            BIT_SHIFT : integer := 7
        );
        port(
            rgb_sum : in  std_logic_vector(8 downto 0);
            final_result : out std_logic_vector(7 downto 0)            
        );
        end component;

	--three stage register to save red, green, blue
	--output is attached to a combinational logic to convert in gray
	type shift_reg_type is array (2 downto 0) of std_logic_vector(7 downto 0);
	signal shift_reg, next_shift_reg : shift_reg_type;

	type state_type is (WAIT_RED, WAIT_GREEN, WAIT_BLUE, WRITE, WRITE_LAST, DONE);
	signal state, next_state : state_type;

	--multiply the 3 values for 43/128 which is almost 1/3
	constant numerator : integer := 43;
	constant bit_shift : integer := integer(log2(real(128)));

	signal sum_result : unsigned(8 downto 0);
	--dimension of this array depends on the fraction used
	signal mul_result : unsigned(17 downto 0);

	

begin

	synchronous_logic : process(clk)
	begin
		if rising_edge(clk) then
			if resetn = '0' then
				state <= WAIT_RED;
				shift_reg <= (others => (others => '0'));
			else
				state <= next_state;
				shift_reg <= next_shift_reg;
			end if;
		end if;
	end process;

	next_state_logic : process(state, shift_reg, m_axis_tready, s_axis_tvalid, s_axis_tdata, s_axis_tlast)
	begin
		case (state) is

			--read red value
			--if tlast is valid I go into write last state (error case)
			when WAIT_RED =>
			    if s_axis_tvalid = '1' and s_axis_tlast ='1' then
			        next_state <= WRITE_LAST;
			        next_shift_reg(2) <= s_axis_tdata;
					next_shift_reg(1 downto 0) <= shift_reg(2 downto 1);
					
				elsif s_axis_tvalid = '1' then
					next_state <= WAIT_GREEN;
					next_shift_reg(2) <= s_axis_tdata;
					next_shift_reg(1 downto 0) <= shift_reg(2 downto 1);
				else
					next_state <= WAIT_RED;
					next_shift_reg <= shift_reg;
				end if;

			--read green value
			when WAIT_GREEN =>
			    if s_axis_tvalid = '1' and s_axis_tlast ='1' then
			        next_state <= WRITE_LAST;
			        next_shift_reg(2) <= s_axis_tdata;
					next_shift_reg(1 downto 0) <= shift_reg(2 downto 1);
					
				elsif s_axis_tvalid = '1' then
					next_state <= WAIT_BLUE;
					next_shift_reg(2) <= s_axis_tdata;
					next_shift_reg(1 downto 0) <= shift_reg(2 downto 1);
				else
					next_state <= WAIT_GREEN;
					next_shift_reg <= shift_reg;
				end if;

			--read blue value, if it is the last pixel go to write last otherwise go to write
			when WAIT_BLUE => 
				if s_axis_tvalid = '1' and s_axis_tlast ='1' then
					next_state <= WRITE_LAST;
					next_shift_reg(2) <= s_axis_tdata;
					next_shift_reg(1 downto 0) <= shift_reg(2 downto 1);

				elsif s_axis_tvalid = '1' then
					next_state <= WRITE;
					next_shift_reg(2) <= s_axis_tdata;
					next_shift_reg(1 downto 0) <= shift_reg(2 downto 1);

				else
					next_state <= WAIT_BLUE;
					next_shift_reg <= shift_reg;
				end if;

				-- write and then read following pixel
				when WRITE =>
					if m_axis_tready = '1' then
						next_state <= WAIT_RED;
					else
						next_state <= WRITE;
					end if;

					next_shift_reg <= shift_reg;

				--write last byte
				when WRITE_LAST =>
					if m_axis_tready = '1' then
						next_state <= DONE;
					else
						next_state <= WRITE_LAST;
					end if;

					next_shift_reg <= shift_reg;
				
				when DONE =>
					next_state <= DONE;
					next_shift_reg <= shift_reg;
		end case;	
	end process;

	--output logic
	m_axis_tvalid <= '1' when state = WRITE else
					 '1' when state = WRITE_LAST else '0';

	m_axis_tlast <= '1' when state = WRITE_LAST else '0';

	s_axis_tready <= '1' when state = WAIT_RED else
					 '1' when state = WAIT_GREEN else
					 '1' when state = WAIT_BLUE else '0';

	--conversion logic

	--bit padding to match the correct dimension of sum_result
	sum_result <= ("0" & unsigned(shift_reg(2))) + ("0" & unsigned(shift_reg(1))) + ("0" & unsigned(shift_reg(0)));
	-- send the basic rgb sum to the division module 
	LUT_INST : division_lut
	   generic map(
	       NUMERATOR => numerator,
	       BIT_SHIFT => bit_shift
	   )
	   port map(
	       rgb_sum => std_logic_vector(sum_result),
	       final_result => m_axis_tdata
	   );

end Behavioral;



--next state only if handshake is correctly happening
--otherwise state remains the same
--		 (start)
--    +-----------+			+----------+
--    |  WAIT_RED |-------->|WAIT_GREEN|
--    +-----------+			+----------+
--        ^						|
--        |						v
--    +-----------+			+---------+			+----------+	    +----+
--    |   WRITE   |<--------|WAIT_BLUE|-------->|WRITE_LAST|------->|DONE|
--    +-----------+			+---------+			+----------+		+----+