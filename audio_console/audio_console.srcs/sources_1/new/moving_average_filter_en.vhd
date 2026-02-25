library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity moving_average_filter_en is
	generic (
		-- Filter order expressed as 2^(FILTER_ORDER_POWER)
		FILTER_ORDER_POWER	: integer := 5;

		TDATA_WIDTH		: positive := 24
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic;

		enable_filter	: in std_logic
	);
end moving_average_filter_en;

architecture Behavioral of moving_average_filter_en is

component all_pass_filter is
	generic (
		TDATA_WIDTH		: positive := 24
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic
	);
end component;

component moving_average_filter is
	generic (
		-- Filter order expressed as 2^(FILTER_ORDER_POWER)
		FILTER_ORDER_POWER	: integer := 5;

		TDATA_WIDTH			: positive := 24
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic
	);
end component;

signal data_out1, data_out2, data_in1, data_in2 : std_logic_vector (TDATA_WIDTH -1 downto 0);
signal valid1,valid2, last1,last2,ready1,ready2 , s_en: std_logic;   
begin
-- solo uno dei due filtri ottiene il dato valido in ingresso
-- il filtro attivo viene identificato sa s_en, il quale lo aggiorno solo quando non ho un valore in ingresso valido
-- prendo l uscita solo dal filtro attivo al momento
-- 1 filter, 2 all pass

data_in1 <= s_axis_tdata when s_en='1' else
            (others=>'0');
data_in2 <= s_axis_tdata when s_en='0' else
            (others=>'0');
m_axis_tdata<= data_out1 when s_en='1' else
                data_out2;
m_axis_tvalid<= valid1 when s_en='1' else
                valid2;
m_axis_tlast<= last1 when s_en='1' else
                last2 ;
s_axis_tready<= ready1 when s_en='1' else
                ready2 ;
     
     process(aclk,enable_filter)
     begin
            if aresetn='0' then--resetto ad all pass
            s_en<='0';
            elsif rising_edge(aclk) then
                if s_axis_tvalid='0' then
                    s_en<=enable_filter;--aggiorno il mio segnale, quindi cambio modulo di funzionamento solo ai clk, non in mezzo ai vari clk e solo quando non ho dati validi.
                end if;
            end if;
     end process;
                

	--MOVING AVERAGE FILTER
	filter_1: moving_average_filter
            generic map (
		-- Filter order expressed as 2^(FILTER_ORDER_POWER)
		FILTER_ORDER_POWER	=> FILTER_ORDER_POWER,

		TDATA_WIDTH			=> TDATA_WIDTH
	)
	Port map(
		aclk			=>aclk,
		aresetn			=>aresetn,

		s_axis_tvalid	=>s_axis_tvalid,
		s_axis_tdata	=>data_in1,
		s_axis_tlast	=>s_axis_tlast,
		s_axis_tready	=>ready1,

		m_axis_tvalid	=>valid1,
		m_axis_tdata	=>data_out1,
		m_axis_tlast	=>last1,
		m_axis_tready	=>m_axis_tready
	);
	
	--ALL PASS FILTER
    filter_2: all_pass_filter
            generic map (		

		TDATA_WIDTH			=> TDATA_WIDTH
	)
	Port map(
		aclk			=>aclk,
		aresetn			=>aresetn,

		s_axis_tvalid	=>s_axis_tvalid,
		s_axis_tdata	=>data_in2,
		s_axis_tlast	=>s_axis_tlast,
		s_axis_tready	=>ready2,

		m_axis_tvalid	=>valid2,
		m_axis_tdata	=>data_out2,
		m_axis_tlast	=>last2,
		m_axis_tready	=>m_axis_tready
	);
	
	
	
end Behavioral;