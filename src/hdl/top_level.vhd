library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_level is
    port (
        clk       : in  std_logic; -- Takt sa ploce (125 MHz)
        reset_btn : in  std_logic; -- Taster za reset
        start_btn : in  std_logic; -- Taster za start
        tx_out    : out std_logic  -- Pin koji ide na RX od USB-UART konvertora
    );
end entity top_level;

architecture Behavioral of top_level is

    -- SIGNALI ZA VEZU SA IMAGE_GRADIENT
    signal img_start        : std_logic := '0';
    signal img_done         : std_logic;
    signal uart_rd_addr     : std_logic_vector(15 downto 0) := (others => '0');
    signal uart_rd_data     : std_logic_vector(7 downto 0);
    
    -- SIGNALI ZA VEZU SA UART_TX
    signal tx_dvalid        : std_logic := '0';
    signal tx_data          : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_busy          : std_logic;
    signal par_en           : std_logic := '0'; -- Bez parnosti

    -- SIGNAL IZ TVOG EDGE DETEKTORA
    signal start_pulse      : std_logic;

    -- BROJAC ADRESA ZA SLANJE
    signal send_addr_cnt    : integer range 0 to 65536 := 0;

    -- STANJA GLAVNE MASINE
    type main_fsm_type is (S_IDLE, S_WAIT_PROC, S_SET_ADDR, S_WAIT_RAM_1, S_WAIT_RAM_2, S_SEND_UART, S_WAIT_BUSY_HIGH, S_WAIT_BUSY_LOW);
    signal state : main_fsm_type := S_IDLE;

begin

    -- 1. INSTANCIRANJE TVOG EDGE DETEKTORA
    start_btn_edge : entity work.edge_detector
        port map (
            clk       => clk,
            reset     => reset_btn,
            in_signal => start_btn,
            edge      => start_pulse
        );

    -- 2. INSTANCIRANJE MODULA ZA OBRADU
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

    -- 3. INSTANCIRANJE UART PREDAJNIKA
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

    -- 4. GLAVNA MASINA STANJA (ORKESTRACIJA)
    process(clk)
    begin
        if rising_edge(clk) then
            if reset_btn = '1' then
                state <= S_IDLE;
                img_start <= '0';
                tx_dvalid <= '0';
                send_addr_cnt <= 0;
            else
                img_start <= '0';
                
                case state is
                    when S_IDLE =>
                        send_addr_cnt <= 0;
                        -- Ovde sada slusamo ?isti impuls iz tvog detektora, a ne sirovi taster!
                        if start_pulse = '1' then
                            img_start <= '1'; 
                            state <= S_WAIT_PROC;
                        end if;

                    when S_WAIT_PROC =>
                        if img_done = '1' then
                            state <= S_SET_ADDR;
                        end if;

                    when S_SET_ADDR =>
                        if send_addr_cnt = 65536 then
                            state <= S_IDLE; 
                        else
                            uart_rd_addr <= std_logic_vector(to_unsigned(send_addr_cnt, 16));
                            state <= S_WAIT_RAM_1;
                        end if;

                    when S_WAIT_RAM_1 =>
                        state <= S_WAIT_RAM_2;
                        
                    when S_WAIT_RAM_2 =>
                        state <= S_SEND_UART;

                    when S_SEND_UART =>
                        tx_data <= uart_rd_data;
                        tx_dvalid <= '1'; 
                        state <= S_WAIT_BUSY_HIGH;

                    when S_WAIT_BUSY_HIGH =>
                        tx_dvalid <= '1'; 
                        if tx_busy = '1' then
                            tx_dvalid <= '0';
                            state <= S_WAIT_BUSY_LOW;
                        end if;

                    when S_WAIT_BUSY_LOW =>
                        if tx_busy = '0' then
                            send_addr_cnt <= send_addr_cnt + 1;
                            state <= S_SET_ADDR; 
                        end if;
                        
                end case;
            end if;
        end if;
    end process;

end Behavioral;