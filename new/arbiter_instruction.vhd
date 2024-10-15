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
        clk                     : in std_logic;
        reset                   : in std_logic;
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

    signal instruction_addr_s, instruction_addr_r : std_logic_vector(addr_w-1 downto 0);
    signal instruction_rd_s, instruction_rd_r   : std_logic;
    signal instruction_from_bus_s, instruction_from_bus_r : std_logic_vector(block_size-1 downto 0);  


begin

    process(refill, read_from_bus, mem_addr, instruction_from_mem)
    begin
          instruction_addr_s <= (others => '0');
          instruction_rd_s   <= '0'; 
          instruction_from_bus_s <= (others => '0');
        for i in 0 to num_of_cores - 1 loop
            if read_from_bus(i) = '1' then
                instruction_addr_s <= mem_addr((i+1)*addr_w - 1 downto i*addr_w);
                instruction_rd_s   <= '1';
--            else
--                instruction_addr <= (others => '0');
--                instruction_rd   <= '0';    
            end if;

            if refill(i) = '1' then
                instruction_from_bus_s <= instruction_from_mem;
--            else
--                instruction_from_bus <= (others => '0');
            end if;
        end loop;
    end process;

    process(clk, reset)
    begin
        if reset = '0' then
            instruction_addr_r <= (others => '0');
            instruction_rd_r   <= '0'; 
            instruction_from_bus_r <= (others => '0');
        elsif rising_edge(clk) then
            instruction_addr_r <= instruction_addr_s;
            instruction_rd_r   <= instruction_rd_s; 
            instruction_from_bus_r <= instruction_from_bus_s;    
        end if;
    end process;

    instruction_addr <= instruction_addr_r;
    instruction_rd   <= instruction_rd_s; 
    instruction_from_bus <= instruction_from_bus_r;
end Behavioral;