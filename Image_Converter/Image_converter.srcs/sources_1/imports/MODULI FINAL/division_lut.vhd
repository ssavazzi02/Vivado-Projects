library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity division_lut is
    generic(
        NUMERATOR : integer := 43;
        BIT_SHIFT : integer := 7
    );
    Port (
        rgb_sum : in  std_logic_vector(8 downto 0); 
        
        final_result : out std_logic_vector(7 downto 0)
     );
end division_lut;

architecture Behavioral of division_lut is 

    
    signal mul_result : unsigned(17 downto 0);
    
begin
    
    --implementing multiplication by 43/128
    mul_result <= unsigned(rgb_sum) * NUMERATOR;
	final_result <= std_logic_vector(mul_result(BIT_SHIFT + 7 downto BIT_SHIFT));


end Behavioral;