library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sqrt is
    generic (
        G_IN_BW    : natural := 16; 
        G_OUT_BW   : natural := 16; 
        G_OUT_FRAC : natural := 8   
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        d_in      : in  std_logic_vector(G_IN_BW-1 downto 0);
        valid_in  : in  std_logic;
        d_out     : out std_logic_vector(G_OUT_BW-1 downto 0);
        valid_out : out std_logic
    );
end entity;

----------------------------------------------------------------
--                sekvencijalni
----------------------------------------------------------------
architecture Behavioral_sqrt_seq of sqrt is
    constant TOTAL_BITS : natural := G_IN_BW + (2 * G_OUT_FRAC);
    type state_type is (IDLE, COMPUTE, DONE);
    
    -- Registri stanja
    signal state, nxt_state : state_type;
    
    -- Registri podataka
    signal P, nxt_P         : unsigned(G_OUT_BW-1 downto 0);
    signal R, nxt_R         : unsigned(G_OUT_BW-1 downto 0); 
    signal X_reg, nxt_X     : unsigned(TOTAL_BITS-1 downto 0);
    signal count, nxt_count : natural range 0 to G_OUT_BW;

begin

    STATE_TRANSITION: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state     <= IDLE;
                P         <= (others => '0');
                R         <= (others => '0');
                X_reg     <= (others => '0');
                count     <= 0;
                -- Resetujemo i izlaze
                d_out     <= (others => '0');
                valid_out <= '0';
            else
                -- Standardni prelaz stanja
                state <= nxt_state;
                P     <= nxt_P;
                R     <= nxt_R;
                X_reg <= nxt_X;
                count <= nxt_count;

                if state = COMPUTE and nxt_state = DONE then
                    valid_out <= '1';
                    d_out     <= std_logic_vector(nxt_P);
                else
                    valid_out <= '0';

                end if;
            end if;
        end if;
    end process;

    NEXT_STATE_LOGIC: process(state, valid_in, d_in, P, R, X_reg, count)
        variable v_R    : unsigned(G_OUT_BW-1 downto 0);
        variable v_test : unsigned(G_OUT_BW-1 downto 0);
        variable v_bits : unsigned(1 downto 0);
    begin
        -- Default vrednosti
        nxt_state <= state;
        nxt_P     <= P;
        nxt_R     <= R;
        nxt_X     <= X_reg;
        nxt_count <= count;

        case state is
            when IDLE =>
                if valid_in = '1' then
                    nxt_X     <= unsigned(d_in) & to_unsigned(0, 2*G_OUT_FRAC);
                    nxt_P     <= (others => '0');
                    nxt_R     <= (others => '0');
                    nxt_count <= 0;
                    nxt_state <= COMPUTE;
                end if;

            when COMPUTE =>
                v_bits := X_reg(TOTAL_BITS-1 downto TOTAL_BITS-2);
                v_R    := R(G_OUT_BW-3 downto 0) & v_bits;
                v_test := P(G_OUT_BW-3 downto 0) & "01";

                if v_R >= v_test then
                    nxt_R <= v_R - v_test;
                    nxt_P <= P(G_OUT_BW-2 downto 0) & '1';
                else
                    nxt_R <= v_R;
                    nxt_P <= P(G_OUT_BW-2 downto 0) & '0';
                end if;
                
                nxt_X <= X_reg(TOTAL_BITS-3 downto 0) & "00";

                if count = G_OUT_BW - 1 then
                    nxt_state <= DONE;
                else
                    nxt_count <= count + 1;
                end if;

            when DONE =>
                nxt_state <= IDLE;

            when others =>
                nxt_state <= IDLE;
        end case;
    end process;

end architecture;


----------------------------------------------------------------
--                     pajplajn
----------------------------------------------------------------
architecture Behavioral_sqrt_pipelined of sqrt is

constant TOTAL_BITS : natural := G_IN_BW + (2 * G_OUT_FRAC);
    constant NUM_STAGES : natural := G_OUT_BW;

    type p_array_t is array (0 to NUM_STAGES) of unsigned(G_OUT_BW-1 downto 0);
    type r_array_t is array (0 to NUM_STAGES) of unsigned(G_OUT_BW+1 downto 0);
    type x_array_t is array (0 to NUM_STAGES) of unsigned(TOTAL_BITS-1 downto 0);
    type v_array_t is array (0 to NUM_STAGES) of std_logic;

    -- SIGNALI
    signal p_reg : p_array_t;
    signal r_reg : r_array_t;
    signal x_reg : x_array_t;
    signal v_reg : v_array_t;

    signal p_next : p_array_t; 
    signal r_next : r_array_t; 
    signal x_next : x_array_t; 
    signal v_next : v_array_t; 

begin


    COMB_LOGIC: process(p_reg, r_reg, x_reg, v_reg)
        variable v_bits : unsigned(1 downto 0);
        variable v_R    : unsigned(G_OUT_BW+1 downto 0);
        variable v_test : unsigned(G_OUT_BW-1 downto 0);
        
    begin
        p_next <= (others => (others => '0'));
        r_next <= (others => (others => '0'));
        x_next <= (others => (others => '0'));
        v_next <= (others => '0');

        for i in 0 to NUM_STAGES-1 loop
            

            v_bits := x_reg(i)(TOTAL_BITS-1 downto TOTAL_BITS-2);
            v_R    := r_reg(i)(G_OUT_BW-1 downto 0) & v_bits;
            v_test := p_reg(i)(G_OUT_BW-3 downto 0) & "01";

            if v_R >= v_test then
                -- Ako moze da se oduzme:
                r_next(i) <= v_R - v_test;
                p_next(i) <= p_reg(i)(G_OUT_BW-2 downto 0) & '1';
            else
                r_next(i) <= v_R;
                p_next(i) <= p_reg(i)(G_OUT_BW-2 downto 0) & '0';
                
            end if;

            x_next(i) <= x_reg(i)(TOTAL_BITS-3 downto 0) & "00";
            v_next(i) <= v_reg(i);

        end loop;
    end process;

    PROC_REGISTERS: process(clk)
    begin
    
        if rising_edge(clk) then
            if reset = '1' then
                for i in 0 to NUM_STAGES loop
                    p_reg(i) <= (others => '0');
                    r_reg(i) <= (others => '0');
                    x_reg(i) <= (others => '0');
                    v_reg(i) <= '0';
                end loop;
                
            else
                x_reg(0) <= unsigned(d_in) & to_unsigned(0, 2*G_OUT_FRAC);
                p_reg(0) <= (others => '0');
                r_reg(0) <= (others => '0');
                v_reg(0) <= valid_in;

                for i in 0 to NUM_STAGES-1 loop
                    p_reg(i+1) <= p_next(i);
                    r_reg(i+1) <= r_next(i);
                    x_reg(i+1) <= x_next(i);
                    v_reg(i+1) <= v_next(i);
                end loop;
            end if;
        end if;
    end process;


    d_out     <= std_logic_vector(p_reg(NUM_STAGES));
    valid_out <= v_reg(NUM_STAGES);
end architecture;
