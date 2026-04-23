library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.RAM_definitions_PK.all;

entity image_gradient is
    port (
        clk          : in std_logic;
        reset        : in std_logic;
        start        : in std_logic;
        done         : out std_logic;
        debug_data   : out std_logic_vector(7 downto 0);
        debug_valid  : out std_logic;
        uart_rd_addr : in std_logic_vector(15 downto 0);
        uart_rd_data : out std_logic_vector(7 downto 0)
    );
end entity image_gradient;

architecture Behavioral of image_gradient is

    -- KONSTANTE
    constant IMG_WIDTH  : integer := 256;
    constant IMG_HEIGHT : integer := 256;
    constant RAM_DEPTH  : integer := 65536;
    constant ADDR_WIDTH : integer := 16; 
    
    -- SIGNALI ZA IM_RAM
    signal ram_addra : std_logic_vector(ADDR_WIDTH-1 downto 0); 
    signal ram_addrb : std_logic_vector(ADDR_WIDTH-1 downto 0); 
    signal ram_dina  : std_logic_vector(7 downto 0);
    signal ram_doutb : std_logic_vector(7 downto 0);
    signal ram_wea   : std_logic;
    signal ram_enb   : std_logic;
    
    -- SIGNALI ZA SQRT
    signal sqrt_din       : std_logic_vector(15 downto 0);
    signal sqrt_valid_in  : std_logic;
    signal sqrt_dout      : std_logic_vector(15 downto 0);
    signal sqrt_valid_out : std_logic;

    -- BAFERI ZA PROZOR
    type line_buffer_type is array (0 to 255) of unsigned(7 downto 0);
    signal line_buff_0 : line_buffer_type := (others => (others => '0')); 
    signal line_buff_1 : line_buffer_type := (others => (others => '0')); 

    signal p00, p01, p02 : signed(10 downto 0) := (others => '0'); 
    signal p10, p11, p12 : signed(10 downto 0) := (others => '0');
    signal p20, p21, p22 : signed(10 downto 0) := (others => '0');

    -- SOBEL MATEMATIKA
    signal Gx, Gy : signed(10 downto 0);

    -- BROJACI
    signal read_addr_cnt : integer range 0 to 65536 := 0; 
    signal out_pixel_cnt : integer range 0 to 65536 := 0; 
    signal read_col      : integer range 0 to 255 := 0;   

    -- SIGNALI ZA DETEKCIJU IVICA
    signal v_out_vec     : unsigned(15 downto 0);
    signal out_row       : unsigned(7 downto 0);
    signal out_col       : unsigned(7 downto 0);
    signal is_edge       : std_logic;

    -- KONTROLNI SIGNALI
    signal update_window_en : std_logic;
    signal calc_sobel_en    : std_logic;
    signal trig_sqrt_en     : std_logic;

    -- STANJA
    type state_type is (IDLE, READ_RAM, WAIT_RAM, UPDATE_WINDOW, CHECK_OUTPUT, 
                        CALC_SOBEL, TRIG_SQRT, WAIT_SQRT, WRITE_RESULT, 
                        WRITE_EDGE, FLUSH_OUTPUTS, FINISHED);
    signal state : state_type := IDLE;

begin

    im_ram_inst : entity work.im_ram
    generic map ( G_RAM_WIDTH => 8, G_RAM_DEPTH => RAM_DEPTH, G_RAM_PERFORMANCE => "LOW_LATENCY" )
    port map (
        addra => ram_addra, addrb => ram_addrb, dina => ram_dina, doutb => ram_doutb,
        clka => clk, wea => ram_wea, enb => ram_enb, rstb => reset, regceb => '1'
    );

    sqrt_inst : entity work.sqrt
    generic map ( G_IN_BW => 16, G_OUT_BW => 16, G_OUT_FRAC => 8 )
    port map (
        clk => clk, reset => reset, d_in => sqrt_din, valid_in => sqrt_valid_in,
        d_out => sqrt_dout, valid_out => sqrt_valid_out
    );

    v_out_vec <= to_unsigned(out_pixel_cnt, 16);
    out_row   <= v_out_vec(15 downto 8); 
    out_col   <= v_out_vec(7 downto 0);  
    is_edge   <= '1' when (out_row = 0) or (out_row = 255) or (out_col = 0) or (out_col = 255) else '0';


    STATE_TRANSITION: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= IDLE;
            else
                case state is
                    when IDLE =>
                        if start = '1' then state <= READ_RAM; end if;

                    when READ_RAM =>
                        if read_addr_cnt < 65536 then state <= WAIT_RAM;
                        else state <= FLUSH_OUTPUTS; end if;

                    when WAIT_RAM =>
                        state <= UPDATE_WINDOW;

                    when UPDATE_WINDOW =>
                        state <= CHECK_OUTPUT;

                    when CHECK_OUTPUT =>
                        if read_addr_cnt >= 258 then
                            if is_edge = '1' then state <= WRITE_EDGE;
                            else state <= CALC_SOBEL; end if;
                        else
                            state <= READ_RAM;
                        end if;

                    when CALC_SOBEL =>
                        state <= TRIG_SQRT;

                    when TRIG_SQRT =>
                        state <= WAIT_SQRT;

                    when WAIT_SQRT =>
                        if sqrt_valid_out = '1' then state <= WRITE_RESULT; end if;

                    when WRITE_RESULT =>
                        state <= READ_RAM;

                    when WRITE_EDGE =>
                        state <= READ_RAM;

                    when FLUSH_OUTPUTS =>
                        if out_pixel_cnt < 65536 then state <= FLUSH_OUTPUTS;
                        else state <= FINISHED; end if;

                    when FINISHED =>
                        if start = '0' then state <= IDLE; end if;
                        
                    when others => state <= IDLE;
                end case;
            end if;
        end if;
    end process;


    update_window_en <= '1' when state = UPDATE_WINDOW else '0';
    calc_sobel_en    <= '1' when state = CALC_SOBEL else '0';
    trig_sqrt_en     <= '1' when state = TRIG_SQRT else '0';


    ADDRESS_GENERATOR: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' or state = IDLE then
                read_addr_cnt <= 0;
                out_pixel_cnt <= 0;
                read_col <= 0;
            else
                -- Inkrementacija citanja
                if state = UPDATE_WINDOW then
                    read_addr_cnt <= read_addr_cnt + 1;
                    if read_col = 255 then read_col <= 0; else read_col <= read_col + 1; end if;
                end if;

                -- Inkrementacija upisa
                if (state = WRITE_RESULT) or (state = WRITE_EDGE) or (state = FLUSH_OUTPUTS and out_pixel_cnt < 65536) then
                    out_pixel_cnt <= out_pixel_cnt + 1;
                end if;
            end if;
        end if;
    end process;


    WINDOW_BUFFER: process(clk)
    begin
        if rising_edge(clk) then
            if update_window_en = '1' then
                p22 <= signed(resize(unsigned(ram_doutb), 11));        
                p12 <= signed(resize(line_buff_1(read_col), 11)); 
                p02 <= signed(resize(line_buff_0(read_col), 11)); 
                
                p21 <= p22; p11 <= p12; p01 <= p02;
                p20 <= p21; p10 <= p11; p00 <= p01;

                line_buff_1(read_col) <= unsigned(ram_doutb);
                line_buff_0(read_col) <= line_buff_1(read_col);
            end if;
        end if;
    end process;


    SOBEL: process(clk)
    begin
        if rising_edge(clk) then
            if calc_sobel_en = '1' then
                Gx <= (p02 + shift_left(p12, 1) + p22) - (p00 + shift_left(p10, 1) + p20);
                Gy <= (p00 + shift_left(p01, 1) + p02) - (p20 + shift_left(p21, 1) + p22);
            end if;
            
            if trig_sqrt_en = '1' then
                sqrt_valid_in <= '1';
            else
                sqrt_valid_in <= '0';
            end if;
        end if;
    end process;


    COMB_LOGIC: process(Gx, Gy)
        variable vx, vy : signed(7 downto 0);
        variable vsum : unsigned(15 downto 0);
    begin
        vx := resize(shift_right(Gx, 3), 8); 
        vy := resize(shift_right(Gy, 3), 8);
        vsum := unsigned(vx*vx) + unsigned(vy*vy);
        sqrt_din <= std_logic_vector(vsum);
    end process;


    OUTPUT_LOGIC: process(clk)
        variable v_round : unsigned(8 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                ram_wea <= '0';
                ram_enb <= '0';
                done <= '0';
                debug_valid <= '0';
                debug_data <= (others => '0');
            else
                -- Default vrednosti za impulse
                ram_wea <= '0';
                ram_enb <= '0';
                debug_valid <= '0';

                -- Za citanje
                if state = READ_RAM and read_addr_cnt < 65536 then
                    ram_addrb <= std_logic_vector(to_unsigned(read_addr_cnt, ADDR_WIDTH));
                    ram_enb <= '1';
                elsif state = FINISHED or state = IDLE then
                    ram_addrb <= uart_rd_addr;
                    ram_enb <= '1';
                end if;

                -- Upis i slanje sobela
                if state = WRITE_RESULT then
                    v_round := unsigned("0" & sqrt_dout(15 downto 8)) + ("00000000" & sqrt_dout(7));
                    if v_round > 255 then
                        ram_dina <= "11111111";
                        debug_data <= "11111111";
                    else
                        ram_dina <= std_logic_vector(v_round(7 downto 0));
                        debug_data <= std_logic_vector(v_round(7 downto 0));
                    end if;

                    ram_addra <= std_logic_vector(to_unsigned(out_pixel_cnt, ADDR_WIDTH));
                    ram_wea <= '1';
                    debug_valid <= '1';
                end if;

                -- Upis i slanje ivicnih
                if state = WRITE_EDGE or (state = FLUSH_OUTPUTS and out_pixel_cnt < 65536) then
                    ram_dina <= (others => '0');
                    ram_addra <= std_logic_vector(to_unsigned(out_pixel_cnt, ADDR_WIDTH));
                    ram_wea <= '1';
                    
                    debug_data <= (others => '0');
                    debug_valid <= '1'; 
                end if;

                -- Kraj
                if state = FINISHED then
                    done <= '1';
                else
                    done <= '0';
                end if;

            end if;
        end if;
    end process;
    
uart_rd_data <= ram_doutb;
end Behavioral;