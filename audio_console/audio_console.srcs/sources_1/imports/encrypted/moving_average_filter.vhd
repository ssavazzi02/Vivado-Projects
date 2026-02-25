library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity moving_average_filter is
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
end moving_average_filter;

architecture Behavioral of moving_average_filter is
--constant FILTER_ORDER : integer := (2**FILTER_ORDER_POWER);
--constant MAX_VALUE_DATA : integer := (2**TDATA_WIDTH -1);
--constant MIN_VALUE_DATA : integer := (2**TDATA_WIDTH);


--constant LOW_SUM : integer := -FILTER_ORDER*MIN_VALUE_DATA;--WORST CASE SUM ALL OF THEM THE MIN VALUE -(32*2^23)
--constant HIGH_SUM : integer := FILTER_ORDER*MAX_VALUE_DATA;--WORST CASE SUM ALL OF THEM MAX VALUE  32*(2^23-1)

type state is (IDLE, READ_LEFT, READ_RIGHT, FILTER, WRITE_LEFT, WRITE_RIGHT);
signal current_state : state;

type memory is array (2**FILTER_ORDER_POWER - 1 downto 0) of signed(TDATA_WIDTH-1 downto 0);--tipo di variabile in cui andrò a salvare tutti i dati precedenti per fare la media
signal mem_left, mem_right : memory;-- faccio average per destro e per sinistro separati

signal s_left,s_right,  m_left,m_right : signed(TDATA_WIDTH-1 downto 0);
signal sel, full : std_logic;-- full serve perche inizialmente non devo cancellare i dati quando ne inserisco di nuovi
signal count, selector, count_element: integer range 0 to 2**FILTER_ORDER_POWER-1;
signal sum_left,sum_right : signed (FILTER_ORDER_POWER+TDATA_WIDTH -1 downto 0); -- il worst case e quando sono tutti max value, 32*(2^23-1), o min value, -(32*2^23)
--quindi per avere un segnale che riesce a contenere tutto devo avere la somma del numero di bit degli elementi che si moltiplicano


begin

 s_axis_tready<='1' when current_state=READ_LEFT or current_state= READ_RIGHT
                       else
                   '0';
                   
 m_axis_tdata<=std_logic_vector(m_left) when sel='0'
                  else
                std_logic_vector(m_right) when sel='1';
                  
   process(aclk,aresetn)
    begin
        if aresetn='0' then
                current_state<=IDLE;
                sum_left <= (others => '0');
                sum_right <= (others => '0');
                sel<='0';
                mem_left<=(others=>(others=>'0'));
                mem_right<=(others=>(others=>'0'));
                s_left<=(others=>'0');
                s_right<=(others=>'0');
                m_left<=(others=>'0');
                m_right<=(others=>'0');
                m_axis_tvalid<='0';
                m_axis_tlast<='0';
                count<=0;
                count_element<=0;
                full<='0';
                
        elsif rising_edge(aclk) then
            case current_state is
                        when IDLE =>
                                    current_state<=READ_LEFT;
                                    
                        when READ_LEFT =>--alzo con il when fuori il sready 
                                                    if s_axis_tvalid='1' and s_axis_tlast='0' then
                        
                                                            mem_left(count)<=signed(s_axis_tdata);--inserisco in memoria il dato, anche sovrascrivendo
                                                            sum_left<= sum_left + resize(signed(s_axis_tdata),sum_left'LENGTH);--aggiugno alla somma di cui faccio la media il nuovo dato
                                                            current_state<= READ_RIGHT;
                                                             
                                                             if count_element< 2**FILTER_ORDER_POWER-1 then
                                                                count_element<=count_element + 1;
                                                                full<='0';
                                                             else
                                                                full<='1';
                                                             end if;
                                                        
                                                    else
                                                        current_state<=READ_LEFT;
                                                    end if;   
                         when READ_RIGHT =>
                                                    if s_axis_tvalid='1' and s_axis_tlast='1' then
                                                        mem_right(count)<=signed(s_axis_tdata);--salvo dato nella memoria, anche sovrascrivendo
                                                        sum_right<= sum_right + resize(signed(s_axis_tdata),sum_right'LENGTH); --sommo il dato alla somma di cui faccio la media
                                                        --current_state<= WAIT_STATE;
                                                        current_state<=FILTER;
                                                         
                                                     else 
                                                     current_state<=READ_RIGHT;
                                                    end if;
                         when FILTER =>             --divido la somma per il numero di elementi su cui faccio la media
                                                    -- Dentro il FILTER state
                                                    m_left  <= resize(sum_left(sum_left'high downto FILTER_ORDER_POWER), TDATA_WIDTH);
                                                    m_right <= resize(sum_right(sum_right'high downto FILTER_ORDER_POWER), TDATA_WIDTH);
                                                    
                                                    --setup, se ho la memoria piena, allora il prossimo ciclo sovrascrivo il dato piu vecchio quindi devo toglierlo dalla 
                                                    --somma cosi da mantenere la somma corretta. seguo il dato piu vecchio con selector
                                                    if full='1' then
                                                        
                                                        sum_left<=sum_left - mem_left(selector);
                                                        sum_right<=sum_right - mem_right(selector);
                                                        
                                                        if selector = 2**FILTER_ORDER_POWER-1 then -- aggiorno selector, che segue il dato piu vecchio, quindi lo tolgo dalla somma e prossimo ciclo aggiungo quello nuovo
                                                            selector<=0;
                                                        else
                                                            selector<= selector+1;
                                                        end if;
                                                        
                                                    end if;
                                                    
                                                    if count = 2**FILTER_ORDER_POWER-1 then -- aggiorno count, che segue dove inserisco il dato
                                                            count<=0;
                                                    else
                                                            count<= count+1;
                                                    end if;
                                                    
                                                    current_state<=WRITE_LEFT;
                                                    m_axis_tvalid<='1';
                                                    
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