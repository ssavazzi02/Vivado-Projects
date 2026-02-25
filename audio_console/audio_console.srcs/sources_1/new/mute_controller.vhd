library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mute_controller is
	Generic (
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

		mute			: in std_logic
	);
end mute_controller;

architecture Behavioral of mute_controller is

type state is (IDLE, READ_LEFT,READ_RIGHT, OUT_LEFT,OUT_RIGHT);
signal current_state : state;

signal s_left,s_right : std_logic_vector(TDATA_WIDTH-1 downto 0);
signal sel : std_logic;

begin

 s_axis_tready<='1' when current_state=READ_LEFT or current_state= READ_RIGHT
                       else
                   '0';
 m_axis_tdata<=   s_left when sel='0'
                  else
                  s_right when sel='1'
                 ;
                  
                 
    process(aclk,aresetn)
    begin
        if aresetn='0' then
                current_state<=IDLE;
                sel<='0';
                s_left<=(others=>'0');
                s_right<=(others=>'0');
                m_axis_tvalid<='0';
                m_axis_tlast<='0';
               
        elsif rising_edge(aclk) then
            case current_state is 
                                when IDLE => 
                                            current_state<=READ_LEFT;
                                            
                                when READ_LEFT =>--alzerò con il when fuori il sready 
                                                    if s_axis_tvalid='1' and s_axis_tlast='0' then
                                                    
                                                        if mute='1' then--se sono in muto allora salvo nel segnale un vettore a 0
                                                            s_left<=(others=>'0');
                                                        else--altrimenti il dato corretto e lo do fuori
                                                            s_left<=s_axis_tdata;
                                                        end if;
                                                        current_state<= READ_RIGHT; 
                                                        
                                                    else
                                                        current_state<=READ_LEFT;
                                                    end if;   
                                when READ_RIGHT =>--stessa cosa del sinistro
                                                    if s_axis_tvalid='1' and s_axis_tlast='1' then
                                                        if mute='1' then
                                                            s_right<=(others=>'0');
                                                        else
                                                            s_right<=s_axis_tdata;
                                                        end if;
                                                        current_state<=OUT_LEFT;
                                                        m_axis_tvalid<='1';
                                                    else
                                                        current_state<=READ_RIGHT;
                                                    end if;
                          when OUT_LEFT=>
                                                if m_axis_tready='1' then
                                                             current_state<= OUT_RIGHT;
                                                             sel<='1';--legge il dato sinistro allora preparo altro dato.
                                                             m_axis_tlast<='1';
                                                         else 
                                                             current_state<= OUT_LEFT;
                                                         end if;
                          when OUT_RIGHT =>
                                                        if m_axis_tready='1' then--leggo il dato
                                                            m_axis_tvalid<='0';
                                                            m_axis_tlast<='0';
                                                            sel<='0';--parto sempre a scrivere il left.
                                                            current_state<=IDLE; -- aspetto prossimo dato
                                                            
                                                         else 
                                                            current_state<= OUT_RIGHT;
                                                         end if;
                                                         
                           when others => 
                                                        current_state<=IDLE;
            end case;
        end if;
    end process;
end Behavioral;