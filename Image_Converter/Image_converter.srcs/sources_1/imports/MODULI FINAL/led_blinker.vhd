library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity led_blinker is
    generic (
        CLK_PERIOD_NS: POSITIVE :=10;
        BLINK_PERIOD_MS : POSITIVE :=1000;
        N_BLINKS : POSITIVE := 4
    );
    port (
        clk   : in std_logic;
        aresetn : in std_logic;
        start_blink : in std_logic;
        led: out std_logic
    );
end entity led_blinker;

architecture rtl of led_blinker is
    constant PERIOD_RATIO : integer:= (BLINK_PERIOD_MS/CLK_PERIOD_NS)*10**3;
    signal count : integer := 0;
    signal control_on : std_logic := '1';
    signal blink_counter : integer := 0;

begin
--blink 4 times with period 1 second
    process(clk)
    begin
        if rising_edge(clk) then
            if aresetn = '0' then
                led <= '0';
                count <= 0;
                control_on <= '1';
                blink_counter <= 0;
                
            elsif start_blink = '1' then
            --if blinked 4 times reset
                if blink_counter = N_BLINKS*2 then
                    led <= '0';
                    count <= 0;  
                                      
                else
                
                    if count = BLINK_PERIOD_MS * PERIOD_RATIO then
                        count <= 0;
                        control_on <= not control_on;
                        blink_counter <= blink_counter+1;
                        
                    else
                    
                        if control_on = '1' then
                            led <= '1';
                            count <= count+1;
                            
                        elsif control_on = '0' then
                        
                            led <= '0';
                            count <= count+1;
                            
                        end if;
                        
                    end if;
                    
                end if;
                
            else
            
                led <= '0';
                count <= 0;
                control_on <= '1';
                blink_counter <= 0;
                
            end if;
            
        end if;
        
    end process;
      
    

end architecture;