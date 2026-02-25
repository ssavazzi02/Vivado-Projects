library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity balance_controller is

	generic (
		TDATA_WIDTH       :   positive := 24;
		BALANCE_WIDTH     :   positive := 10;
		BALANCE_STEP_2    :   positive := 6		-- i.e., balance_values_per_step = 2**VOLUME_STEP_2
	);
	
	Port (
	
		aclk			:   in std_logic;
		aresetn			:   in std_logic;

		s_axis_tvalid	:   in std_logic;                                  -- sto ricevendo un dato valido
		s_axis_tdata	:   in std_logic_vector(TDATA_WIDTH-1 downto 0);   -- dato ricevuto
		s_axis_tready	:   out std_logic;                                 -- sono pronto a ricevere un dato
		s_axis_tlast	:   in std_logic;                                  -- sto ricevendo l'ultimo dato

		m_axis_tvalid	:   out std_logic;                                 -- sto trasmettendo un dato valido
		m_axis_tdata	:   out std_logic_vector(TDATA_WIDTH-1 downto 0);  -- dato trasmesso
		m_axis_tready	:   in std_logic;                                  -- il ricevente è pronto a ricevere
		m_axis_tlast	:   out std_logic;                                 -- sto inviando l'ultimo dato valido

		balance			:   in std_logic_vector(BALANCE_WIDTH-1 downto 0)  -- posizione sull'asse orizzontale del joystick che mi indica come bilanciare 
		                                                                                                                            
);

end balance_controller;

architecture Behavioral of balance_controller is
    
    constant BIAS                           :   integer := -512;                        -- costante che lo "shift" da fare al valore di balance per ottenere un valore nel range -512/+512
    
    type state is (IN_LEFT, IN_RIGHT, OUT_LEFT, OUT_RIGHT, BALANCING_1, BALANCING_2);   -- definizione dei vari stati che compongono la FSM
    
    signal current_state                    :   state;                                  -- segnale per la gestione degli stati della FSM
    signal left_channel,left_channel_out    :   signed(TDATA_WIDTH-1 downto 0);         -- segnali per la gestione dell'acquisizione/trasmissione del canale audio sinistro                         
    signal right_channel, right_channel_out :   signed(TDATA_WIDTH-1 downto 0);         -- segnali per la gestione dell'acquisizione/trasmissione del canale audio destro                         
    signal balance_direction                :   signed(BALANCE_WIDTH - 1 downto 0);     -- segnale che contiene il valore "shiftato" della posizione del joystick                              
    signal gain                             :   integer range -8 to 8;                  -- segnale che contiene il valore di attenuazione del canale audio selezionato
    signal last_data                        :   std_logic;                              -- flag per indicare che è stato trasmesso l'ultimo dato del pacchetto
    signal converted                        :   std_logic;                              -- flag per indicare la fine della processazione dei dati e quindi la loro trasmissione
    
begin
    
    -- segnali in uscita
    m_axis_tlast    <=  last_data;
    m_axis_tvalid   <=  converted;
    s_axis_tready   <=  '1' when current_state=IN_LEFT or current_state= IN_RIGHT
                            else
                        '0';
    
    process (aclk, aresetn) 
    begin
    
        if aresetn = '0' then
            
            current_state       <=  IN_LEFT;
            
            last_data           <=  '0';
            converted           <=  '0';
            left_channel_out    <=  (others => '0');
            left_channel        <=  (others => '0');
            right_channel       <=  (others => '0');
            right_channel_out   <=  (others => '0');
            balance_direction   <=  (others => '0');
       
        elsif rising_edge(aclk) then
            
            -- gesione della FSM
            case current_state is
                
                -- acquisizione dato canale audio sx
                when IN_LEFT         => 
                
                                        balance_direction <= to_signed(to_integer(unsigned(balance)) + BIAS, BALANCE_WIDTH); -- acquisizione della posizione del joystick portandola nel range -512/512
                                        
                                        
                                        if s_axis_tvalid = '1' and s_axis_tlast = '0' then -- se il dato è valido e non è l'ultimo del pacchetto --> è il canale audio sx
                                            
                                            left_channel    <=  (signed(s_axis_tdata)); -- acquisizione dato
                                            current_state   <=  IN_RIGHT;   -- dato acquisito --> cambio stato
                                    
                                        else 
                                            
                                            current_state   <=  IN_LEFT; -- non ho acquisito il dato --> rimango nello stato corrente
                                              
                                        end if;
                                        
                                        converted   <=  '0'; -- non ho ancora pronto il dato valido
                         
                -- acquisizione dato canale audio dx               
                when IN_RIGHT       => 
                
                                        if s_axis_tvalid = '1' and s_axis_tlast = '1' then  -- se il dato è valido e ed è l'ultimo del pacchetto --> è il canale audio dx
                                    
                                            right_channel <= (signed(s_axis_tdata));    -- acquisizione dato
                                            current_state <= BALANCING_1;   -- dato acquisito --> cambio stato
                                    
                                        else
                                    
                                            current_state <= IN_RIGHT;  -- non ho acquisito il dato --> rimango nello stato corrente
                                    
                                        end if;
                
                -- la fase di processazione dei dati è stata divisa su due stati per rispettare i vincoli relativi al tempo di setup
                -- prima fase di processazione --> acquisisco il valore dell'attenuazione in base alla posizione del joystick
                when BALANCING_1    =>  
                            
                                        if balance_direction(balance_direction'LEFT) = '0' then -- se il valore del signal relativo alla posizione del joystick è positivo
                                        
                                            gain    <=  ((to_integer(balance_direction) + 2**(BALANCE_STEP_2 - 1) - 1) / 2**(BALANCE_STEP_2));
                                        
                                        elsif balance_direction(balance_direction'LEFT) = '1' then  -- se il valore del signal relativo alla posizione del joystick è negativo
                                        
                                            gain    <=  ((- to_integer(balance_direction) + 2**(BALANCE_STEP_2 - 1) - 1) / 2**(BALANCE_STEP_2));
                                            
                                        else 
                                        
                                            gain    <=  1;
                                    
                                        end if;
                                        
                                        current_state   <=  BALANCING_2; -- cambio stato
                
                -- seconda fase di processazione --> attenuazione del canale audio                        
                when BALANCING_2    =>
                
                                        if balance_direction(balance_direction'LEFT) = '0' then -- se il valore del signal relativo alla posizione del joystick è positivo
                                        
                                            left_channel_out    <=  shift_right(left_channel,gain); -- attenuo il canale audio sx
                                            
                                            right_channel_out   <=  right_channel;  -- lascio invariato il canale dx
                                        
                                        elsif balance_direction(balance_direction'LEFT) = '1' then -- se il valore del signal relativo alla posizione del joystick è negativo
                                        
                                            right_channel_out   <=  shift_right(right_channel,gain); -- attenuo il canale audio dx
                                            
                                            left_channel_out    <=  left_channel;   -- lascio invariato il canale sx
                                            
                                        else 
                                            
                                            -- lascio invariati entrambi i canali audio
                                            left_channel_out    <=  left_channel;
                                            right_channel_out   <=  right_channel;
                                        
                                        end if;
                                    
                                        current_state   <=  OUT_LEFT;  -- cambio stato
                
                -- trasmissione canale sx
                when OUT_LEFT       =>    
                
                                        if m_axis_tready = '1' then -- se il ricevente è pronto, cambio stato --> trasmetto canale dx

                                            current_state   <=  OUT_RIGHT; -- cambio stato
                                        
                                        else
                                    
                                            current_state   <=  OUT_LEFT; -- rimango nello stato --> non cambio il dato in uscita
                                    
                                        end if;
                                        
                                        converted       <=  '1'; -- sto trasmettendo un dato valido
                                        
                                        m_axis_tdata    <=  std_logic_vector(left_channel_out); -- trasmetto canale sx
                                        
                                        last_data       <=  '0'; -- non sto trasmettendo l'ultimo dato del pacchetto
                
                when OUT_RIGHT      =>  
                
                                        if m_axis_tready = '1' then -- se il ricevente è pronto, cambio stato 
                                        
                                            current_state   <=  IN_LEFT;   -- cambio stato
                                        
                                        else
                                    
                                            current_state   <=  OUT_RIGHT; -- rimango nello stato 
                                    
                                        end if;
                                        
                                        m_axis_tdata    <=  std_logic_vector(right_channel_out); -- trasmetto canale dx
                                        
                                        last_data       <=  '1'; -- ho trasmesso l'ultimo dato del pacchetto
                
                when others         =>  
                
                                        current_state   <=  IN_LEFT;
            
            end case;
    
        end if;
    
    end process;

end Behavioral;