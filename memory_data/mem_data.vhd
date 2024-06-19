library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils_pkg.all;

entity mem_data is 
    generic(
        block_size      : integer := 128;
        word_size       : integer := 32;
        addr_size       : integer := 10;
        size            : integer := 1024
    );
    port(
        clk             : in std_logic;
        en              : in std_logic;
        send_from_mem_i : in std_logic; -- read signal
        addr            : in std_logic_vector(log2c(size) - 1 downto 0);
        data_i          : in std_logic_vector(word_size - 1 downto 0);
        data_o          : out std_logic_vector(word_size - 1 downto 0);
        
        -- top ports
        wr_top          : in std_logic; -- read signal
        en_top          : in std_logic;
        addr_top_data   : in std_logic_vector(log2c(size) - 1 downto 0);
        data_top_i      : in std_logic_vector(word_size - 1 downto 0);
        data_top_o      : out std_logic_vector(word_size - 1 downto 0)    
    );

end mem_data;

architecture Behavioral of mem_data is

type ram is array (size-1 downto 0) of std_logic_vector(word_size - 1 downto 0);

signal data_mem : ram;
attribute ram_style:string;
attribute ram_style of data_mem: signal is "block";

begin


process(clk)
begin
    if rising_edge(clk) then
        if en = '1' then
            if send_from_mem_i = '1' then
                data_mem(to_integer(unsigned(addr)))  <= data_i;
            end if;
            data_o <= data_mem(to_integer(unsigned(addr)));
        end if;        
    end if;
    
    if rising_edge(clk) then
        if en_top = '1' then
            if wr_top = '1' then
                data_mem(to_integer(unsigned(addr_top_data)))  <= data_top_i;
            end if;
            data_top_o <= data_mem(to_integer(unsigned(addr_top_data)));
        end if;        
    end if;
end process;



end Behavioral;