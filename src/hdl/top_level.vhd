library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_level is
    port (
        clk       : in  std_logic; -- 125 MHz
        reset_btn : in  std_logic; -- Taster for reset = BTN 0
        start_btn : in  std_logic; -- Taster for start = BTN 1
        tx_out    : out std_logic  --> RX USB
    );
end entity top_level;

architecture Behavioral of top_level is

    -- IMAGE_GRADIENT SIGNALS
    signal img_start        : std_logic;
    signal img_done         : std_logic;
    signal uart_rd_addr     : std_logic_vector(15 downto 0);
    signal uart_rd_data     : std_logic_vector(7 downto 0);
    
    -- UART_TX SIGNALS
    signal tx_dvalid        : std_logic;
    signal tx_data          : std_logic_vector(7 downto 0);
    signal tx_busy          : std_logic;
    signal par_en           : std_logic := '0';

    -- EDGE_DETEKTOR SIGNALS
    signal start_pulse      : std_logic;

    -- FSM STATE
    type state_type is (S_IDLE, S_WAIT_PROC, S_SET_ADDR, S_WAIT_RAM_1, S_WAIT_RAM_2, S_SEND_UART, S_WAIT_BUSY_HIGH, S_WAIT_BUSY_LOW);
    
    -- REGISTERS
    signal state_reg, state_next                 : state_type := S_IDLE;
    signal send_addr_cnt_reg, send_addr_cnt_next : integer range 0 to 65536 := 0;
    signal tx_data_reg, tx_data_next             : std_logic_vector(7 downto 0) := (others => '0');

begin

    btn_edge : entity work.edge_detector
        port map (
            clk       => clk,
            reset     => reset_btn,
            in_signal => start_btn,
            edge      => start_pulse
        );

    img_grad_inst : entity work.image_gradient
        port map (
            clk          => clk,
            reset        => reset_btn,
            start        => img_start,
            done         => img_done,
            debug_data   => open,
            debug_valid  => open, 
            uart_rd_addr => uart_rd_addr,
            uart_rd_data => uart_rd_data
        );

    uart_tx_inst : entity work.uart_tx
        generic map (
            CLK_FREQ => 125,
            SER_FREQ => 115200
        )
        port map (
            clk       => clk,
            rst       => reset_btn,
            tx        => tx_out,
            par_en    => par_en,
            tx_dvalid => tx_dvalid,
            tx_data   => tx_data,
            tx_busy   => tx_busy
        );

    uart_rd_addr <= std_logic_vector(to_unsigned(send_addr_cnt_reg, 16));
    tx_data      <= tx_data_reg;

    SEQ_PROC: process(clk)
    begin
        if rising_edge(clk) then
            if reset_btn = '1' then
                state_reg         <= S_IDLE;
                send_addr_cnt_reg <= 0;
                tx_data_reg       <= (others => '0');
            else
                state_reg         <= state_next;
                send_addr_cnt_reg <= send_addr_cnt_next;
                tx_data_reg       <= tx_data_next;
            end if;
        end if;
    end process SEQ_PROC;


    NEXT_STATE_LOGIC: process(state_reg, start_pulse, img_done, send_addr_cnt_reg, tx_busy)
    begin
        state_next <= state_reg;

        case state_reg is
            when S_IDLE =>
                if start_pulse = '1' then
                    state_next <= S_WAIT_PROC;
                end if;

            when S_WAIT_PROC =>
                if img_done = '1' then
                    state_next <= S_SET_ADDR;
                end if;

            when S_SET_ADDR =>
                if send_addr_cnt_reg = 65536 then
                    state_next <= S_IDLE; 
                else
                    state_next <= S_WAIT_RAM_1;
                end if;

            when S_WAIT_RAM_1 =>
                state_next <= S_WAIT_RAM_2;
                
            when S_WAIT_RAM_2 =>
                state_next <= S_SEND_UART;

            when S_SEND_UART =>
                state_next <= S_WAIT_BUSY_HIGH;

            when S_WAIT_BUSY_HIGH =>
                if tx_busy = '1' then
                    state_next <= S_WAIT_BUSY_LOW;
                end if;

            when S_WAIT_BUSY_LOW =>
                if tx_busy = '0' then
                    state_next <= S_SET_ADDR; 
                end if;
                
        end case;
    end process NEXT_STATE_LOGIC;


    OUTPUT_LOGIC: process(state_reg, send_addr_cnt_reg, tx_data_reg, uart_rd_data, start_pulse, tx_busy)
    begin
        img_start          <= '0';
        tx_dvalid          <= '0';
        send_addr_cnt_next <= send_addr_cnt_reg;
        tx_data_next       <= tx_data_reg;

        case state_reg is
            when S_IDLE =>
                send_addr_cnt_next <= 0;
                if start_pulse = '1' then
                    img_start <= '1'; 
                end if;

            when S_WAIT_PROC =>
                null; -- nema nista

            when S_SET_ADDR | S_WAIT_RAM_1 | S_WAIT_RAM_2 =>
                null; -- ceka se ram

            when S_SEND_UART =>
                tx_data_next <= uart_rd_data;
                tx_dvalid    <= '1';          

            when S_WAIT_BUSY_HIGH =>
                tx_dvalid <= '1'; 

            when S_WAIT_BUSY_LOW =>
                if tx_busy = '0' then
                    send_addr_cnt_next <= send_addr_cnt_reg + 1;
                end if;
                
        end case;
    end process OUTPUT_LOGIC;

end Behavioral;