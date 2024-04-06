library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity cache_memory is
    generic(
        loc_bits        : integer := 4; -- 16 entries
        offset_bits     : integer := 2; -- to choose one of four words
        block_size      : integer := 128; -- 32*4 
        mem_word_size   : integer := 32; -- word size of memory
        proc_word_size  : integer := 32; -- word size of processor
        blk_0_offset    : integer := 127; -- cache block --> | blk0 | blk1 | blk2 | blk3
        blk_1_offset    : integer := 95;
        blk_2_offset    : integer := 63;
        blk_3_offset    : integer := 31
    );
    port(
        clk             : in std_logic; -- same as processor
        refill          : in std_logic; -- miss, refill cache using data from memory
        update          : in std_logic; -- hit, update, cache using date from processor
        index           : in std_logic_vector(loc_bits-1 downto 0); -- index selection
        offset          : in std_logic_vector(offset_bits-1 downto 0); -- offset selection
        data_from_mem   : in std_logic_vector(block_size-1 downto 0);  -- data from memory
        data_from_proc  : in std_logic_vector(proc_word_size-1 downto 0); -- data from processor
        data_to_mem     : out std_logic_vector(block_size-1 downto 0); -- evicted block data in case of a write miss
        data_to_proc    : out std_logic_vector(proc_word_size-1 downto 0) -- data to processor
    );
end cache_memory;

architecture Behavioral of cache_memory is 

type ram is array (0 to 2**(loc_bits+offset_bits) - 1) of std_logic_vector(mem_word_size-1 downto 0);

signal cache : ram := (others => (others => '0'));

signal pos0 : std_logic_vector(loc_bits+offset_bits-1 downto 0); -- postion 0
signal pos1 : std_logic_vector(loc_bits+offset_bits-1 downto 0); -- postion 1
signal pos2 : std_logic_vector(loc_bits+offset_bits-1 downto 0); -- postion 2
signal pos3 : std_logic_vector(loc_bits+offset_bits-1 downto 0); -- postion 3
signal pos4 : std_logic_vector(loc_bits+offset_bits-1 downto 0); -- postion 4

begin

    pos0 <= index & offset;
    pos1 <= index & "00";
    pos2 <= index & "01";
    pos3 <= index & "10";
    pos4 <= index & "11";

    writing_process:process(clk)
                    begin
                        if rising_edge(clk)then
                            if update = '1' then
                                cache(to_integer(unsigned(pos0))) <= data_from_proc;
                            elsif refill = '1' then
                                cache(to_integer(unsigned(pos1))) <= data_from_mem(blk_0_offset downto blk_1_offset+1);
                                cache(to_integer(unsigned(pos2))) <= data_from_mem(blk_1_offset downto blk_2_offset+1);
                                cache(to_integer(unsigned(pos3))) <= data_from_mem(blk_2_offset downto blk_3_offset+1);
                                cache(to_integer(unsigned(pos4))) <= data_from_mem(blk_3_offset downto 0);
                            end if;    
                        end if;
                    end process;
    
    read_process:process(clk)
                 begin
                    if rising_edge(clk) then
                        data_to_proc <= cache(to_integer(unsigned(pos0))); -- read from cache and send to processor

                        data_to_mem(blk_0_offset downto blk_1_offset+1) <= cache(to_integer(unsigned(pos1)));
                        data_to_mem(blk_1_offset downto blk_2_offset+1) <= cache(to_integer(unsigned(pos2)));
                        data_to_mem(blk_2_offset downto blk_3_offset+1) <= cache(to_integer(unsigned(pos3)));
                        data_to_mem(blk_3_offset downto 0)              <= cache(to_integer(unsigned(pos4)));
                    end if;
                 end process;
end Behavioral;