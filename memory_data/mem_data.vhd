library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mem_data is 
    generic(
        block_size      : integer := 128;
        word_size       : integer := 32;
        addr_size       : integer := 10
    );
    port(
        clk             : in std_logic;
        reset           : in std_logic;
        send_from_mem_i : in std_logic; -- read signal
        addr            : in std_logic_vector(addr_size - 1 downto 0);
        data_i          : in std_logic_vector(word_size - 1 downto 0);
        data_o          : out std_logic_vector(word_size - 1 downto 0)    
    );

end mem_data;

architecture Behavioral of mem_data is

type ram is array (0 to 2**addr_size - 1) of std_logic_vector(word_size - 1 downto 0);

signal data_mem : ram;

begin


process(clk, reset)
begin
    if reset = '0' then
        data_mem <= (others => (others => '0'));
    elsif rising_edge(clk) then
        if send_from_mem_i = '1' then
            data_mem(to_integer(unsigned(addr)))  <= data_i;
        end if;
    end if;

    data_o <= data_mem(to_integer(unsigned(addr)));
end process;


end Behavioral;