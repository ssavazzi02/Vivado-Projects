library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity volume_multiplier is
	Generic (
		TDATA_WIDTH		: positive := 24;
		VOLUME_WIDTH	: positive := 10;
		VOLUME_STEP_2	: positive := 6		-- i.e., volume_values_per_step = 2**VOLUME_STEP_2
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic;

		volume			: in std_logic_vector(VOLUME_WIDTH-1 downto 0)
	);
end volume_multiplier;

architecture Behavioral of volume_multiplier is

constant POWER_2 : integer := 2**VOLUME_STEP_2;
constant MAX_NUMBER : integer := POWER_2 - 2**(VOLUME_STEP_2-1);

type state is (IDLE, READ_LEFT,READ_RIGHT, GAIN_1,GAIN_2, GAIN_3, DIVISION, WAIT_AMPL, WRITE_AMPL_LEFT, WRITE_AMPL_RIGHT);

signal s_left,s_right : signed(TDATA_WIDTH-1 downto 0);
signal m_left,m_right, resize_left, resize_right : signed(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);

signal current_state : state;
signal sel,prod : std_logic;--se 1 mando right, se 0 mando left
signal vol,exponential,ff_exponential : integer range -2**(VOLUME_WIDTH-1) to 2**(VOLUME_WIDTH-1);
 

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
                s_left<=(others=>'0');
                s_right<=(others=>'0');
                m_left<=(others=>'0');
                m_right<=(others=>'0');
                m_axis_tvalid<='0';
                m_axis_tlast<='0';
                current_state<=IDLE;
                vol<=0;
                sel<='0';
                prod<='0';
                
                
                
            elsif rising_edge(aclk) then
              
                case current_state is 
                                     when IDLE => current_state<=READ_LEFT;
                                      
                                     when READ_LEFT =>--alzero con il when fuori il sready 
                                                        --decido che voglio solo pacchetti di dati prima sinistro poi destro, non guardo appositamente se mi arriva prima il destro o poi il sinistro
                                                    if s_axis_tvalid='1' and s_axis_tlast='0' then
                                                        s_left<=signed(s_axis_tdata);
                                                        current_state<= READ_RIGHT; 
                                                        vol<=-(2**(VOLUME_WIDTH-1)) + to_integer(unsigned(volume));-- fisso valore con cui calcolo gain, portato nel range -512, + 512, tengo questo valore per la coppia di dati.
                                                    else
                                                        current_state<=READ_LEFT;
                                                    end if;   
                                     when READ_RIGHT =>
                                                    if s_axis_tvalid='1' and s_axis_tlast='1' then
                                                        s_right<=signed(s_axis_tdata);
                                                        current_state<= GAIN_1;
  
                                                    else
                                                        current_state<=READ_RIGHT;
                                                    end if; 
                                     when GAIN_1 =>
                                                         --creo il mio esponente del guadagno, il quale è sempre potenza di due, con il vol preso prima
                                                         --trovo il fattore di amplificazione, utilizzando la proprietà di troncamento  trovo il gain corretto
                                                         -- divido il calcolo in piu stati per poter andare a una frequenza piu alta, utilizzando calcoli piu semplici
--                                                         -- 2^(1+ (jstk -32)/2^6)
                                                           current_state<=DIVISION;
                                                           if vol>=0 then
                                                            
                                                            prod<='1';
                                                            ff_exponential<=(MAX_NUMBER + vol);
                                                            
--                                                         --  2^(-1 +(jstk +32)/2^6)
                                                          elsif vol< 0  then--prendo valore dell esponente positivo e poi quando faccio amplificazione divido per questo fattore
                                                            
                                                            prod<='0';
                                                            ff_exponential<=-(vol - MAX_NUMBER);
                                                        else
                                                            ff_exponential<=0;
                                                            prod<='1';
                                                            
                                                        end if;
                                     when DIVISION =>
                                                        exponential <= ff_exponential / POWER_2;
                                                        current_state <= WAIT_AMPL;                                                                                             
                                       
                                     when WAIT_AMPL => -- stadio che prepara il mio input, il resize aumenta solo la dimensione quindi non da problemi farlo prima della divisione
                                                        resize_left <= resize(s_left,m_left'LENGTH);
                                                        resize_right <= resize(s_right,m_left'LENGTH);
                                                        
                                                        if prod='1' then
                                     					  current_state <= GAIN_2;
                                     					else 
                                     					  current_state <= GAIN_3;
                                     					end if;
                                     when GAIN_2 =>
                                                    --ho un gain che è sempre potenza di due quindi uso shift_left per moltiplicare
                                                        m_left<=shift_left(resize_left,exponential);
                                                        m_right<=shift_left(resize_right,exponential);
                                                    
                                                        
                                                    
                                                      current_state<=WRITE_AMPL_LEFT;
                                                      --preparo dato sinistra in uscita
                                                      sel<='0';
                                                      m_axis_tvalid<='1'; 
                                                     
                                     when GAIN_3 =>     -- shift_right per dividere
                                                        m_right<=shift_right(resize_right,exponential);
                                                        m_left<=shift_right(resize_left,exponential);
                                                        
                                                    
                                                          current_state<=WRITE_AMPL_LEFT;
                                                          --preparo dato sinistra in uscita
                                                          sel<='0';
                                                          m_axis_tvalid<='1';   
--                                     
                                      
                                     when WRITE_AMPL_LEFT => 
                                                        --con un when fuori setto uscita a m_left o m_right in base a come ho il write
                                                        
                                                        if m_axis_tready='1' then
                                                             current_state<= WRITE_AMPL_RIGHT;
                                                             sel<='1';--legge il dato sinistro allora preparo altro dato.
                                                             m_axis_tlast<='1';
                                                         else 
                                                             current_state<= WRITE_AMPL_LEFT;
                                                         end if;
                                      when WRITE_AMPL_RIGHT =>
                                                        if m_axis_tready='1' then--leggo il dato
                                                            m_axis_tvalid<='0';
                                                            m_axis_tlast<='0';
                                                            sel<='0';--parto sempre a scrivere il left.
                                                            current_state<=IDLE; -- aspetto prossimo dato
                                                            
                                                         else 
                                                            current_state<= WRITE_AMPL_RIGHT;
                                                         end if;
                                        when others => 
                                                        current_state<=IDLE;
                                                    
                end case;
            end if;
        
        
        end process;
end Behavioral;