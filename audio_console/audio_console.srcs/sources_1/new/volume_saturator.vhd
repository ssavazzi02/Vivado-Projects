library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity volume_saturator is
	Generic (
		TDATA_WIDTH		: positive := 24;
		VOLUME_WIDTH	: positive := 10;
		VOLUME_STEP_2	: positive := 6;		-- i.e., number_of_steps = 2**(VOLUME_STEP_2)
		HIGHER_BOUND	: integer := 2**23-1;	-- Inclusive
		LOWER_BOUND		: integer := -2**23		-- Inclusive
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic
	);
end volume_saturator;

architecture Behavioral of volume_saturator is
--al posto di riscrivere la saturazione per entrambi i canali faccio una function
function saturate(
    input       : signed;
    upper_bound : integer;
    lower_bound : integer;
    out_len     : integer
) return signed is
begin
    if input > to_signed(upper_bound, input'length) then
        return to_signed(upper_bound, out_len);
    elsif input < to_signed(lower_bound, input'length) then
        return to_signed(lower_bound, out_len);
    else
        return resize(input, out_len);
    end if;
end function;


type state is (IDLE, READ_LEFT, READ_RIGHT, SATURATION, WRITE_LEFT, WRITE_RIGHT);
signal current_state : state;
signal s_left,s_right : signed(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0); --segnale in cui metto ingresso
signal m_left,m_right :signed(TDATA_WIDTH-1 downto 0);--segnale in cui metto uscita
signal sel : std_logic;--mi dice se sto scrivendo destro o sinistro



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
                sel<='0';
                s_left<=(others=>'0');
                s_right<=(others=>'0');
                m_left<=(others=>'0');
                m_right<=(others=>'0');
                m_axis_tvalid<='0';
                m_axis_tlast<='0';
        elsif rising_edge(aclk) then
            case current_state is
                        when IDLE =>
                                    current_state<=READ_LEFT;
                                    
                        when READ_LEFT =>           --alzo tready con il when fuori  
                                                    if s_axis_tvalid='1' and s_axis_tlast='0' then--decido che voglio solo pacchetti di dati prima sinistro poi destro, non guardo appositamente se mi arriva prima il destro o poi il sinistro
                                                        s_left<=signed(s_axis_tdata);
                                                        current_state<= READ_RIGHT; 
                                                        
                                                    else
                                                        current_state<=READ_LEFT;
                                                    end if;   
                         when READ_RIGHT =>
                                                    if s_axis_tvalid='1' and s_axis_tlast='1' then
                                                        s_right<=signed(s_axis_tdata);
                                                        current_state<= SATURATION;
                                                    else
                                                        current_state<=READ_RIGHT;
                                                    end if;
                         when SATURATION =>         -- uso funzione per saturare per evitare troppi calcoli e operazioni
                                                   -- function saturate(input, upper_bound, lower_bound,out_len)                                                    
                                                    m_left  <= saturate(s_left, HIGHER_BOUND, LOWER_BOUND, m_left'LENGTH);
                                                    m_right <= saturate(s_right, HIGHER_BOUND, LOWER_BOUND, m_right'LENGTH);
                                                     m_axis_tvalid<='1';
                                                    current_state<=WRITE_LEFT;
                                                    
                          when WRITE_LEFT => 
                                                    --con un when fuori setto uscita a m_left o m_right in base a come ho il sel                                                                                                            
                                                        if m_axis_tready='1' then
                                                             current_state<= WRITE_RIGHT;
                                                             sel<='1';--legge il dato sinistro allora preparo altro dato.
                                                             m_axis_tlast<='1';--stessa cosa preparo dato destro
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