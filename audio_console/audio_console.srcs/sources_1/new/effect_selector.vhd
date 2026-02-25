library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity effect_selector is
    generic(
        JOYSTICK_LENGHT  : integer := 10
    );
    Port (
        aclk     : in STD_LOGIC;
        aresetn : in STD_LOGIC;

        effect : in STD_LOGIC;

        jstck_x : in STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0);
        jstck_y : in STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0);

        volume         : out STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0);
        balance     : out STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0);
        lfo_period     : out STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0)
    );
end effect_selector;

architecture Behavioral of effect_selector is
----Constant used when we reset the program, sets all value to the middle one----
    constant BASE_VALUE : std_logic_vector(JOYSTICK_LENGHT - 1 downto 0) := (JOYSTICK_LENGHT - 1 => '0', others => '1');

----Signals used as buffers----
    signal volume_b : std_logic_vector(JOYSTICK_LENGHT-1 downto 0);
    signal balance_b : std_logic_vector(JOYSTICK_LENGHT-1 downto 0);
    signal lfo_period_b : std_logic_vector(JOYSTICK_LENGHT-1 downto 0);
begin

    volume <= volume_b;
    lfo_period <= lfo_period_b;
    balance <= balance_b;

    BUTTON_SELECTOR : process (aclk)
    begin
        if rising_edge (aclk) then
            if aresetn = '0' then
                volume_b <= BASE_VALUE;
                balance_b <= BASE_VALUE;
                lfo_period_b <= BASE_VALUE;
            else
                if effect = '0' then
                    volume_b <= jstck_y;
                    balance_b <= jstck_x;
                    lfo_period_b <= lfo_period_b;
                else
                    volume_b <= volume_b;
                    balance_b <= balance_b;
                    lfo_period_b <= jstck_y;
                end if;
            end if;
        end if;
    end process;

end Behavioral;