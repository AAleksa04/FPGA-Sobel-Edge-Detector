library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_top_level is
end tb_top_level;

architecture Behavioral of tb_top_level is

    component top_level
        port (
            clk       : in  std_logic;
            reset_btn : in  std_logic;
            start_btn : in  std_logic;
            tx_out    : out std_logic
        );
    end component;

    signal clk       : std_logic := '0';
    signal reset_btn : std_logic := '0';
    signal start_btn : std_logic := '0';
    signal tx_out    : std_logic;

    constant CLK_PERIOD : time := 8 ns;

begin

    uut: top_level
        port map (
            clk       => clk,
            reset_btn => reset_btn,
            start_btn => start_btn,
            tx_out    => tx_out
        );

    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    stim_proc: process
    begin
        reset_btn <= '1';
        start_btn <= '0';
        wait for 100 ns;
        
        reset_btn <= '0';
        wait for 100 ns;

        start_btn <= '1';
        wait for 500 ns;
        start_btn <= '0';

        for i in 1 to 512 loop
            wait until falling_edge(tx_out);
            wait for 19 us; 
            if i mod 16 = 0 then
                report "Poslato " & integer'image(i) & " piksela..." severity note;
            end if;
        end loop;
        
        wait for 2 us;
        report "Prvi red (256 piksela) je poslato." severity failure;
        
        wait;
    end process;

end Behavioral;