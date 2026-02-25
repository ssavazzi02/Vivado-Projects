library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity led_level_controller is

    generic(
    
        NUM_LEDS        :   positive := 16;
        CHANNEL_LENGHT  :   positive := 24;
        refresh_time_ms :   positive := 1;
        clock_period_ns :   positive := 10
        
    );
    
    Port (
        
        aclk			:     in std_logic;
        aresetn			:     in std_logic;
        
        led             :     out std_logic_vector(NUM_LEDS-1 downto 0);        -- vettore corrispondente ai led da accendere/spegnere

        s_axis_tvalid	:     in std_logic;                                     -- sto ricevendo un dato valido
        s_axis_tdata	:     in std_logic_vector(CHANNEL_LENGHT-1 downto 0);   -- dato ricevuto
        s_axis_tlast    :     in std_logic;                                     -- sto ricevendo l'ultimo dato
        s_axis_tready	:     out std_logic                                     -- sono pronto a ricevere un dato

    );
    
end led_level_controller;

architecture Behavioral of led_level_controller is

    constant timing     :   integer :=  (refresh_time_ms * 1000000 / clock_period_ns); -- numero di clock da attendere 
    constant MAX_LEVEL  :   integer :=  NUM_LEDS - 1;                                  
    constant SHIFT_BITS :   integer :=  CHANNEL_LENGHT;
    
    signal clk_counter      :   integer range 0 to timing;              -- contatore per aggiornare i led ogni refresh_time_ms
    signal left_channel     :   signed(CHANNEL_LENGHT-1 downto 0);      -- dato relativo al canale audio sx
    signal right_channel    :   signed(CHANNEL_LENGHT-1 downto 0);      -- dato relativo al canale audio dx
    signal level            :   signed(4 downto 0);                     --
    signal led_temp         :   std_logic_vector(NUM_LEDS-1 downto 0);  -- segnale per la gestione dei led
    signal sum              :   signed (CHANNEL_LENGHT+1 downto 0);     -- segnale contenente la somma dei canali audio dx e sx
    

    type state is (IDLE, IN_LEFT, IN_RIGHT,MEAN, OUTPUT);   -- definizione dei vari stati che compongono la FSM
    signal current_state    :   state;                      -- segnale per la gestione degli stati della FSM
  
begin

    -- segnali in uscita
    led             <=  led_temp;
    s_axis_tready   <=  '1';
    
    process (aclk, aresetn)
    begin
    
        if aresetn = '0' then
            
            current_state   <=  IN_LEFT;
            
            clk_counter     <=  0;
            left_channel    <=  (others =>  '0');
            right_channel   <=  (others =>  '0');
            led_temp        <=  (others =>  '0');
            sum             <=  (others =>  '0');

                     
        elsif rising_edge(aclk) then
            
            -- aspetto ogni refresh_time
            if clk_counter = timing then
                
                -- gestione della FSM
                case current_state is
                    
                    -- stato di reset
                    when IDLE       =>
                    
                                        sum <=  (others=>'0');  -- resetto il segnale somma per acquisire nuovi dati
                                        
                                        current_state   <=  IN_LEFT;
                    
                    -- acquisizione dato canale audio sx
                    when IN_LEFT    =>  
                    
                                        if s_axis_tvalid = '1' and s_axis_tlast = '0' then
                                        
                                            -- prendo solo i valori positivi per fare una media corretta
                                            if signed(s_axis_tdata) < 0 then
                                            
                                                left_channel    <=  -(signed(s_axis_tdata));
                                                sum             <=  sum - signed(s_axis_tdata);
                                                
                                            else
                                            
                                                left_channel    <=  (signed(s_axis_tdata));
                                                sum             <=  sum + signed(s_axis_tdata);
                                                
                                            end if;  
                                            
                                            current_state   <=  IN_RIGHT; -- dato acquisito --> cambio stato
                                        
                                        else
                                                
                                            current_state   <=  IN_LEFT; -- non ho acquisito il dato --> rimango nello stato corrente
                                                  
                                        end if;
                                        
                    when IN_RIGHT   =>   
                                       
                                        if s_axis_tvalid = '1' and s_axis_tlast = '1' then
                                        
                                            -- prendo solo i valori positivi per fare una media corretta
                                            if signed(s_axis_tdata) < 0 then
                                            
                                                right_channel   <=  -(signed(s_axis_tdata));
                                                sum             <=  sum - signed(s_axis_tdata);
                                                
                                            else
                                            
                                                right_channel   <=  (signed(s_axis_tdata));
                                                sum             <=  sum + signed(s_axis_tdata);
                                                
                                            end if;
                                            
                                            current_state   <=  MEAN; -- dato acquisito --> cambio stato
                                            
                                        else
                                    
                                            current_state   <=  IN_RIGHT; -- non ho acquisito il dato --> rimango nello stato corrente
                                    
                                        end if;
                                        
                    when MEAN       =>         
                    
                                        level   <=  resize(shift_right(sum * MAX_LEVEL, SHIFT_BITS),5);
                                        
                                        -- x=(average of input)*15/2^23 cosi trovo il livello dei led, il due della media lo porto sotto 
                                        current_state <= OUTPUT;
                                        

                               
                    when OUTPUT     =>      
                                         
                                        for I in 0 to NUM_LEDS-1 loop 
                                        
                                            if level > I then
                                            
                                                led_temp(I) <=  '1';
                                            
                                            else
                                            
                                                led_temp(I) <=  '0';
                                            
                                            end if;
                                        
                                        end loop;
                                      
                                        clk_counter     <=  0;              -- resetto il contatore dei clock    
                                        current_state   <=  IDLE;           -- cambio stato
                                        
                    when others     =>      
                    
                                        current_state   <=  IDLE;                 
                
                end case;
             
            else
            
                clk_counter <= clk_counter + 1;
            
            end if;
            
        end if;
    
    end process;

end Behavioral;