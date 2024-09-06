library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity arbiter_instruction is
    generic(
        block_size      : integer := 32;
        addr_w          : integer := 10;
        num_of_cores    : integer := 2
    );
    port(
        refill                  : in std_logic_vector(num_of_cores - 1 downto 0);
        
        mem_addr                : in std_logic_vector(num_of_cores*addr_w-1 downto 0);
        instruction_from_bus    : out std_logic_vector(block_size-1 downto 0);

        instruction_from_mem    : in std_logic_vector(block_size-1 downto 0);
        instruction_addr        : out std_logic_vector(addr_w-1 downto 0);
        instruction_rd          : out std_logic;
        
        read_from_bus           : in std_logic_vector(num_of_cores-1 downto 0)
    );

end arbiter_instruction;

architecture Behavioral of arbiter_instruction is

begin

    process(refill, read_from_bus, mem_addr, instruction_from_mem)
    begin
          instruction_addr <= (others => '0');
          instruction_rd   <= '0'; 
          instruction_from_bus <= (others => '0');
        for i in 0 to num_of_cores - 1 loop
            if read_from_bus(i) = '1' then
                instruction_addr <= mem_addr((i+1)*addr_w - 1 downto i*addr_w);
                instruction_rd   <= '1';
--            else
--                instruction_addr <= (others => '0');
--                instruction_rd   <= '0';    
            end if;

            if refill(i) = '1' then
                instruction_from_bus <= instruction_from_mem;
--            else
--                instruction_from_bus <= (others => '0');
            end if;
        end loop;
    end process;
end Behavioral;