library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity arbiter_instruction is
    generic(
        num_of_cores    : integer := 2;
        addr_w          : integer := 10;
        word_size       : integer := 32;
        block_size      : integer := 128
    );
    port (
        instruction_to_bus      : out std_logic_vector(num_of_cores * block_size-1 downto 0);  -- instruction from memory
        instruction_from_mem    : in std_logic_vector(block_size-1 downto 0);
        mem_addr                : in std_logic_vector(num_of_cores * addr_w - 1 downto 0);
        refill                  : in std_logic_vector(num_of_cores - 1 downto 0);
        addr_to_mem             : out std_logic_vector(addr_w - 1 downto 0);
        en                      : out std_logic
    );
end arbiter_instruction;

architecture Behavioral of arbiter_instruction is 


begin

    -- ARBITER FOR INSTRUCTIONS
    process(refill, instruction_from_mem, mem_addr)
    begin
        instruction_to_bus  <= (others => '0');
        addr_to_mem         <= (others => '0');
        en                  <= '0';
        --read_from_bus       <= (others => '0');
        for i in 0 to num_of_cores - 1 loop
            if (refill(i) = '1') then
                instruction_to_bus((i+1) * block_size - 1 downto i * block_size)<= instruction_from_mem;
                addr_to_mem                                                     <= mem_addr((i+1) * addr_w - 1 downto i * addr_w);
                en                                                              <= '1';     
                --read_from_bus(i)                                                <= '1';
            else
                instruction_to_bus((i+1) * word_size - 1 downto i * word_size)  <= (others => '0');
                addr_to_mem                                                     <= (others => '0');
                en                                                              <= '0';            
                --read_from_bus(i)                                                <= '0';
            end if;
        end loop;

    end process;

end Behavioral;