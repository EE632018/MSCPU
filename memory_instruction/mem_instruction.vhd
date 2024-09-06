library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils_pkg.all;

entity mem_instruction is 
    generic(
        block_size      : integer := 32;
        word_size       : integer := 32;
        addr_size       : integer := 10;
        size            : integer := 1024
    );
    port(
        clk                 : in std_logic;
        wr                  : in std_logic;
        en                  : in std_logic;
        addr                : in std_logic_vector(log2c(size) - 1 downto 0);    
        instruction_o       : out std_logic_vector(block_size - 1 downto 0);
        instruction_i       : in std_logic_vector(block_size - 1 downto 0);
        
        -- top ports
        wr_top              : in std_logic;
        en_top              : in std_logic;
        addr_top            : in std_logic_vector(log2c(size) - 1 downto 0);
        instruction_top_o   : out std_logic_vector(block_size - 1 downto 0);
        instruction_top_i   : in std_logic_vector(block_size - 1 downto 0)
            
    );

end mem_instruction;

architecture Behavioral of mem_instruction is

type ram is array (size-1 downto 0) of std_logic_vector(block_size - 1 downto 0);

signal instruction_mem : ram;

attribute ram_style:string;
attribute ram_style of instruction_mem: signal is "block";
signal addr_tmp : std_logic_vector(addr_size - 1 downto 0);
signal zero_tmp : std_logic_vector(1 downto 0);
signal cnt_delay_r, cnt_delay_nxt : std_logic_vector(2 downto 0);

type state is (IDLE,BUSY_READ);
signal wr_en : std_logic;
signal state_r, state_nxt : state := IDLE;

begin


process(clk)
begin
    if rising_edge(clk) then
        if en = '1' then
            if wr = '1' then
                instruction_mem(to_integer(unsigned(addr))) <= instruction_i;
            end if; 
        instruction_o <= instruction_mem(to_integer(unsigned(addr)));
        end if;
    end if;
    
    if rising_edge(clk) then
        if en_top = '1' then
            if wr_top = '1' then
                instruction_mem(to_integer(unsigned(addr_top))) <= instruction_top_i;
            end if; 
            instruction_top_o <= instruction_mem(to_integer(unsigned(addr_top)));
        end if;
    end if;
end process;

end Behavioral;