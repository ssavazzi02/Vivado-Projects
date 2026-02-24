----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/16/2025 04:23:36 PM
-- Design Name: 
-- Module Name: img_conv_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity img_conv_tb is
--  Port ( );
end img_conv_tb;

architecture Behavioral of img_conv_tb is

    component img_conv is
        generic(
            LOG2_N_COLS: POSITIVE :=8;
            LOG2_N_ROWS: POSITIVE :=8
        );
        port (
    
            clk   : in std_logic;
            aresetn : in std_logic;
    
            m_axis_tdata : out std_logic_vector(7 downto 0);
            m_axis_tvalid : out std_logic; 
            m_axis_tready : in std_logic; 
            m_axis_tlast : out std_logic;
            
            conv_addr: out std_logic_vector(LOG2_N_COLS+LOG2_N_ROWS-1 downto 0);
            conv_data: in std_logic_vector(6 downto 0);
    
            start_conv: in std_logic;
            done_conv: out std_logic
            
        );
    end component;

    constant LOG2_N_COLS: POSITIVE :=2;
    constant LOG2_N_ROWS: POSITIVE :=2;

    type mem_type is array(0 to (2**LOG2_N_COLS)*(2**LOG2_N_ROWS)-1) of std_logic_vector(6 downto 0);

    signal mem : mem_type := (0=>"0000001",others => (others => '0'));

    signal clk   : std_logic :='0';
    signal aresetn : std_logic :='0';

    signal m_axis_tdata : std_logic_vector(7 downto 0);
    signal m_axis_tvalid : std_logic; 
    signal m_axis_tready : std_logic; 
    signal m_axis_tlast : std_logic;
    
    signal conv_addr: std_logic_vector(LOG2_N_COLS+LOG2_N_ROWS-1 downto 0);
    signal conv_data: std_logic_vector(6 downto 0);

    signal start_conv: std_logic;
    signal done_conv: std_logic;

begin

    m_axis_tready<='1';

    clk <= not clk after 5 ns;

    process (clk)
    begin
        if(rising_edge(clk)) then
            conv_data<=mem(to_integer(unsigned(conv_addr)));
        end if;
    end process;

    img_conv_inst: img_conv
     generic map(
        LOG2_N_COLS => LOG2_N_COLS,
        LOG2_N_ROWS => LOG2_N_ROWS
    )
     port map(
        clk => clk,
        aresetn => aresetn,
        m_axis_tdata => m_axis_tdata,
        m_axis_tvalid => m_axis_tvalid,
        m_axis_tready => m_axis_tready,
        m_axis_tlast => m_axis_tlast,
        conv_addr => conv_addr,
        conv_data => conv_data,
        start_conv => start_conv,
        done_conv => done_conv
    );

    process
    begin
        wait for 10 ns;
        aresetn<='1';
        wait until rising_edge(clk);
        start_conv<='1';
        wait until rising_edge(clk);
        start_conv<='0';
        wait;
    end process;


end Behavioral;
