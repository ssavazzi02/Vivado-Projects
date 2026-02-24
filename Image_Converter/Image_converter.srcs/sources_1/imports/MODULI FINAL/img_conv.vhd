library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity img_conv is
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
end entity img_conv;

architecture rtl of img_conv is

    --MOORE FSM, states diagram at the end of the code
    
    type conv_mat_type is array(0 to 2, 0 to 2) of integer;
    constant conv_mat : conv_mat_type := ((-1,-1,-1),(-1,8,-1),(-1,-1,-1));

    constant max_column : integer := 2**LOG2_N_COLS - 1;

    constant max_row : integer := 2**LOG2_N_ROWS - 1;
    -- the pipeline state has been used to fix some timing issues occurring in the synthesis, we split the mult of the bram data
    -- from the add and mux
    type state_type is (START, SEND_ADDRESS, PIPELINE_STATE, UPDATE_RESULT, WRITE, WRITE_LAST, DONE);
    signal state, next_state : state_type;
    
    signal convolution_result, next_conv_res : signed(12 downto 0);
    
    -- signal used to split the mult from the add and mux in order to fix timing issues
    signal mul_result_buffer : signed(12 downto 0);

    --I browse the big bram matrix with two pairs of indexes: the coordinates of the center of the 3x3 submatrix I'm evaluating
    --and auxiliary indexes to reach the other values of the 3x3 submatrix
    signal main_col_index, next_main_col : integer range 0 to 2**LOG2_N_COLS - 1;
    signal main_row_index, next_main_row : integer range 0 to 2**LOG2_N_ROWS - 1;

    signal aux_col_index, next_aux_col : integer range -1 to 1;
    signal aux_row_index, next_aux_row : integer range -1 to 1;

    signal total_col_index : signed(LOG2_N_COLS + 1 downto 0);

    signal total_row_index : signed(LOG2_N_ROWS + 1 downto 0);

    --this signal are for checking the end of the acquisition of the values of the submatrix and the conditions for the aux indexes initialization
    signal increase_main_index_flag, go_to_last_flag : std_logic;
   
    signal matrix_on_top_flag, matrix_on_the_left_flag : std_logic;

begin

    synchronous_logic : process(clk)
    begin
        if rising_edge(clk) then
            if aresetn = '0' then
                state <= START;
                convolution_result <= (others => '0');
                main_col_index <= 0;
                main_row_index <= 0;
                aux_col_index <= 0;
                aux_row_index <= 0;
                mul_result_buffer <= (others => '0');

            else
                state <= next_state;
                convolution_result <= next_conv_res;
                main_col_index <= next_main_col;
                main_row_index <= next_main_row;
                aux_col_index <= next_aux_col;
                aux_row_index <= next_aux_row;
                mul_result_buffer <= signed("0" & conv_data) * to_signed(conv_mat(aux_row_index + 1, aux_col_index + 1), 5);

            end if;
        end if;
    end process;

    --ADDRESS LOGIC to manage the address sent to the bram

    total_col_index <= to_signed(main_col_index + aux_col_index, total_col_index'length);
    total_row_index <= to_signed(main_row_index + aux_row_index, total_row_index'length);

    conv_addr <= std_logic_vector(to_unsigned(main_col_index + aux_col_index + (max_row + 1) * (main_row_index + aux_row_index), LOG2_N_COLS+LOG2_N_ROWS));

    --I read the Bram by rows, from left to right and from top to bottom
    -- I check in order: I'm in the bottom right corner of the 3x3, I'm in the bottom center (near the right side of the big matrix), I'm on center right (near the bottom of the big matrix) 
    increase_main_index_flag <= '1' when (aux_col_index = 1 and aux_row_index = 1) or (aux_row_index = 1 and total_col_index = max_column) or (aux_col_index = 1 and total_row_index = max_row)
                                else '0';

    -- I check if I'm reading the very last value
    go_to_last_flag <= '1' when (main_col_index = max_column and main_row_index = max_row and aux_col_index = 0 and aux_row_index = 0) else '0';


    matrix_on_top_flag <= '1' when main_row_index = 0 else '0';

    matrix_on_the_left_flag <= '1' when main_col_index = 0 else '0';


    next_address_logic : process(state, main_col_index, main_row_index, aux_col_index, aux_row_index, total_col_index, increase_main_index_flag, go_to_last_flag, matrix_on_top_flag, matrix_on_the_left_flag)
    begin
        case (state) is
            when START =>
                next_main_col <= 0;
                next_main_row <= 0;
                next_aux_col <= 0;
                next_aux_row <= 0;

            when SEND_ADDRESS =>
                next_main_col <= main_col_index;
                next_main_row <= main_row_index;
                next_aux_col <= aux_col_index;
                next_aux_row <= aux_row_index;

            when UPDATE_RESULT =>
                if increase_main_index_flag = '1' then
                    if main_col_index = max_column then
                        next_main_col <= 0;
                        next_main_row <= main_row_index + 1;
                    else
                        next_main_col <= main_col_index + 1;
                        next_main_row <= main_row_index;
                    end if;

                    next_aux_col <= aux_col_index;
                    next_aux_row <= aux_row_index;

                elsif go_to_last_flag = '1' then
                    next_main_col <= main_col_index;
                    next_main_row <= main_row_index;
                    next_aux_col <= aux_col_index;
                    next_aux_row <= aux_row_index;

                else
                    next_main_col <= main_col_index;
                    next_main_row <= main_row_index;

                    if aux_col_index = 1 or total_col_index = max_column then
                        if matrix_on_the_left_flag = '1' then
                            next_aux_col <= 0;
                        else
                            next_aux_col <= -1;
                        end if;
                        
                        next_aux_row <= aux_row_index + 1;

                    else
                        next_aux_col <= aux_col_index + 1;
                        next_aux_row <= aux_row_index;

                    end if;
             
                end if;

            when WRITE =>
                next_main_col <= main_col_index;
                next_main_row <= main_row_index;

                if matrix_on_top_flag = '1' then
                    next_aux_col <= -1;
                    next_aux_row <= 0;

                elsif matrix_on_the_left_flag = '1' then
                    next_aux_col <= 0;
                    next_aux_row <= -1;

                else
                    next_aux_col <= -1;
                    next_aux_row <= -1;

                end if;

            when others =>
                next_main_col <= main_col_index;
                next_main_row <= main_row_index;
                next_aux_col <= aux_col_index;
                next_aux_row <= aux_row_index;
                
        end case;
    end process;


    
    next_state_logic : process(state, start_conv, go_to_last_flag, increase_main_index_flag, m_axis_tready)
    begin
        case (state) is
            when START =>
                if start_conv = '1' then
                    next_state <= SEND_ADDRESS;
                else
                    next_state <= START;
                end if;
            
            --at the beginning of this state I send an addess to the bram
            when SEND_ADDRESS =>
                next_state <= PIPELINE_STATE;
                
            when PIPELINE_STATE =>
                next_state <= update_result;

            -- in this state I update the convolution result
            when UPDATE_RESULT =>
                if increase_main_index_flag = '1' then
                    next_state <= WRITE;

                elsif go_to_last_flag = '1' then
                    next_state <= WRITE_LAST;

                else
                    next_state <= SEND_ADDRESS;

                end if;
               
            -- in this state I send the final result to the packetizer
            when WRITE =>
                if m_axis_tready = '1' then
                    next_state <= SEND_ADDRESS;
                else
                    next_state <= WRITE;
                end if;
            
            -- I send the last convolution result
            when WRITE_LAST =>
                if m_axis_tready = '1' then
                    next_state <= DONE;
                else 
                    next_state <= WRITE_LAST;
                end if;
            
            when DONE =>
                next_state <= START;
            
        
        end case;
    end process;

    --in this process I update the final result of the convolution
    next_conv_result_logic : process(state, convolution_result, conv_data, m_axis_tready, aux_row_index, aux_col_index,mul_result_buffer)
    begin
        case (state) is
            when UPDATE_RESULT =>

                next_conv_res <= convolution_result + mul_result_buffer;
                
            when WRITE => 
                if m_axis_tready = '1' then
                   next_conv_res  <= (others => '0');
                else
                    next_conv_res <= convolution_result;
                end if;

            when others =>
                next_conv_res <= convolution_result;

        end case;
    end process;


    --OUTPUT LOGIC

    m_axis_tdata <= (others => '0') when convolution_result( convolution_result'left ) = '1' else  -- convolution result < 0
                    (7 => '0', others => '1') when convolution_result(9 downto 7) /= "000" else -- convolution result > 127
                    std_logic_vector(convolution_result(7 downto 0)); -- normal case


    m_axis_tvalid <= '1' when state = WRITE else
                     '1' when state = WRITE_LAST else
                     '0';

    m_axis_tlast <= '1' when state = WRITE_LAST else '0';

    done_conv <= '1' when state = DONE else '0';


end architecture;


-- fsm diagram


--    +-----------+
--    |   START   |
--    +-----------+
--        |
--        v
--    +-----------+
--    | SEND ADDRESS| <-----
--    +-----------+         |
--        |                 |
--        v                 |
--    +-----------+         |    
--    |PIPELINE STATE|      |    
--    +-----------+         |   
--        |                 |
--        |                 ^  <----------------      
--        v                 |                 |  
--    +-------------+       |                 |
--    |   UPDATE    |       |    +-----+      |
--    +-------------+    ------> |WRITE|------|        
--            |                  +-----+  
--            v                  
--    +-----------+ 
--    | WRITE LAST|
--    +-----------+
--          |
--          |
--          |
--          v    
--    +-----------+ 
--    |    DONE   |
--    +-----------+