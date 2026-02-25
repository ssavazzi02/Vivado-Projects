library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity all_pass_filter is
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
end all_pass_filter;

architecture Behavioral of all_pass_filter is


type state is (IDLE, READ_LEFT, READ_RIGHT, WRITE_LEFT, WRITE_RIGHT);
signal current_state : state;
signal s_left,s_right : std_logic_vector(TDATA_WIDTH-1 downto 0);
signal sel : std_logic;


begin

 s_axis_tready<='1' when current_state=READ_LEFT or current_state= READ_RIGHT
                       else
                   '0';
                   
   m_axis_tdata<=s_left when sel='0'--semplicemente quello che entra in s_left e s_right poi lo faccio uscire senza modificarlo
                  else
                  s_right when sel='1';
                  
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
                                    
                        when READ_LEFT =>--alzo con il when fuori il sready 
                                         --decido che voglio solo pacchetti di dati prima sinistro poi destro, non guardo appositamente se mi arriva prima il destro o poi il sinistro
                                                    if s_axis_tvalid='1' and s_axis_tlast='0' then
                                                        s_left<=s_axis_tdata;
                                                        current_state<= READ_RIGHT; 
                                                        
                                                    else
                                                        current_state<=READ_LEFT;
                                                    end if;   
                         when READ_RIGHT =>
                                                    if s_axis_tvalid='1' and s_axis_tlast='1' then
                                                        s_right<=s_axis_tdata;
                                                        current_state<=WRITE_LEFT;
                                                         m_axis_tvalid<='1';
                                                     else 
                                                     current_state<=READ_RIGHT;
                                                    end if;
                                                    
                          when WRITE_LEFT => 
                                                    --con un when fuori setto uscita a m_left o m_right in base a come ho il sel
                                                       
                                                        
                                                        if m_axis_tready='1' then
                                                             current_state<= WRITE_RIGHT;
                                                             sel<='1';--legge il dato sinistro allora preparo altro dato.
                                                             m_axis_tlast<='1';
                                                         else 
                                                             current_state<= WRITE_LEFT;
                                                         end if;
                          when WRITE_RIGHT =>
                                                        if m_axis_tready='1' then--leggo il dato
                                                            m_axis_tvalid<='0';
                                                            m_axis_tlast<='0';
                                                            sel<='0';--parto sempre a scrivere il left.
                                                            current_state<=IDLE; -- aspetto prossimo dato
                                                            
                                                         else 
                                                            current_state<= WRITE_RIGHT;
                                                         end if;
                                                         
                           when others => 
                                                        current_state<=IDLE;
                                                    
            end case;
        end if;
   end process; 


end Behavioral;