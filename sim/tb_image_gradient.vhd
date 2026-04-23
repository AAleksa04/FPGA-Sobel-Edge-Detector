library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_image_gradient is
end tb_image_gradient;

architecture Behavioral of tb_image_gradient is

    component image_gradient
    port(
        clk         : in std_logic;
        reset       : in std_logic;
        start       : in std_logic;
        done        : out std_logic;
        debug_data  : out std_logic_vector(7 downto 0);
        debug_valid : out std_logic
    );
    end component;
    
    -- SIGNALI
    signal clk         : std_logic := '0';
    signal reset       : std_logic := '0';
    signal start       : std_logic := '0';
    signal done        : std_logic;
    signal debug_data  : std_logic_vector(7 downto 0);
    signal debug_valid : std_logic;

    -- Takt (100 MHz -> 10 ns)
    constant clk_period : time := 10 ns;
    
begin

    uut: image_gradient PORT MAP (
        clk         => clk,
        reset       => reset,
        start       => start,
        done        => done,
        debug_data  => debug_data,
        debug_valid => debug_valid
    );

    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    stim_proc: process
    begin		
        reset <= '1';
        wait for 100 ns;	
        reset <= '0';
        
        wait for clk_period*10;

        start <= '1';
        wait for clk_period; 
        start <= '0';

        wait until done = '1';
        wait for 200 ns;

        assert false report "SIMULACIJA GOTOVA! Proveriti cameraman1.dat" severity failure;
        
        wait;
    end process;


    write_to_file: process(clk)
        file results_file : text open write_mode is "cameraman1.dat";
        variable line_content : line;
    begin
        if rising_edge(clk) then
            if debug_valid = '1' then
                write(line_content, debug_data);
                writeline(results_file, line_content);
                
            end if;
        end if;
    end process;

end Behavioral;
