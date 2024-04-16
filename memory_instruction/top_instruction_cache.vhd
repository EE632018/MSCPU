library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_instruction_cache is
    generic(
        -- default from processor
        instruction_bus_w       : integer := 32;
        addr_bus_w              : integer := 32;
        -- default from cache controller
        index_bits              : integer := 2;
        tag_bits                : integer := 6;
        set_offset_bits         : integer := 2;
        -- default from cache memory
        loc_bits                : integer := 4;
        offset_bits             : integer := 2;
        block_size              : integer := 128;
        -- default from memory
        addr_w                  : integer := 10;
        word_size               : integer := 32
    
    );
    port(
        clk                     : in std_logic;
        reset                   : in std_logic;
        rd                      : in std_logic;
        addr                    : in std_logic_vector(addr_w - 1 downto 0);

        instruction_to_proc     : out std_logic_vector(word_size-1 downto 0); -- instruction to processor
        instruction_from_bus    : in std_logic_vector(block_size-1 downto 0);  -- instruction from memory
        read_from_bus           : out std_logic;

        mem_addr                : out std_logic_vector(tag_bits+index_bits+set_offset_bits-1 downto 0);
        stall                   : out std_logic
    );
end top_instruction_cache;


architecture Behavioral of top_instruction_cache is

    component cache_instruction
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
        clk                     : in std_logic; -- same as processor
        refill                  : in std_logic; -- miss, refill cache using instruction from memory
        instruction_loc         : in std_logic_vector(loc_bits-1 downto 0); -- instruction_loc selection
        offset                  : in std_logic_vector(offset_bits-1 downto 0); -- offset selection
        instruction_from_bus    : in std_logic_vector(block_size-1 downto 0);  -- instruction from memory
        instruction_to_proc     : out std_logic_vector(proc_word_size-1 downto 0) -- instruction to processor
    );
    end component;

    component l1_controller_instruction
    generic(
        index_bits      : integer := 2;
        set_offset_bits : integer := 2;
        tag_bits        : integer := 6
    );
    port(
        clk             : in std_logic;
        reset           : in std_logic;
        rd              : in std_logic; -- read request from processor
        proc_addr       : in std_logic_vector(tag_bits+index_bits+set_offset_bits-1 downto 0);
        index           : in std_logic_vector(index_bits - 1 downto 0); -- index of the addr requeste
        tag             : in std_logic_vector(tag_bits - 1 downto 0); -- tag of addr requested 
        instruction_loc : out std_logic_vector(index_bits+set_offset_bits - 1 downto 0); -- location of instruction in cache instruction array
        refill          : out std_logic; -- refill signal to cache
        read_from_bus   : out std_logic; -- read signal to cache
        mem_addr        : out std_logic_vector(tag_bits+index_bits+set_offset_bits-1 downto 0);
        stall           : out std_logic
    );
    end component;

    signal refill_s             : std_logic;
    signal instruction_loc_s    : std_logic_vector(index_bits+set_offset_bits - 1 downto 0);

begin

    inst_cache_instruction: cache_instruction
    port map(
        clk                     => clk,
        refill                  => refill_s,
        instruction_loc         => instruction_loc_s,
        offset                  => addr(1 downto 0),
        instruction_from_bus    => instruction_from_bus,
        instruction_to_proc     => instruction_to_proc
    );

    inst_cache_controller: l1_controller_instruction
    port map(
        clk             => clk,
        reset           => reset,
        rd              => rd,
        proc_addr       => addr,
        index           => addr(3 downto 2),
        tag             => addr(9 downto 4), 
        instruction_loc => instruction_loc_s,
        refill          => refill_s,
        read_from_bus   => read_from_bus,
        mem_addr        => mem_addr,
        stall           => stall
    );

end Behavioral;