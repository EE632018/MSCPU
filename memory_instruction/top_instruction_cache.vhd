library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_instruction_cache is
    generic(
        -- default from processor
        instruction_bus_w      : integer := 32;
        addr_bus_w      : integer := 32;
        -- default from cache controller
        index_bits      : integer := 2;
        tag_bits        : integer := 6;
        set_offset_bits : integer := 2;
        -- default from cache memory
        loc_bits        : integer := 4;
        offset_bits     : integer := 2;
        block_size      : integer := 128;
        -- default from memory
        addr_w          : integer := 10;
        word_size       : integer := 32;
        -- others generics
        tag_offset      : integer := 9;
        index_offset    : integer := 3;
        block_offset    : integer := 1 
    );
    port(
        clk             : in std_logic;
        reset           : in std_logic;
        addr            : in std_logic_vector(addr_bus_w - 1 downto 0);
        rinstruction    : out std_logic_vector(instruction_bus_w - 1 downto 0);
        flush           : in std_logic;
        rd              : in std_logic;
        stall           : out std_logic;
        rd_rdy          : out std_logic;
        hit             : out std_logic;
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
        instruction_from_mem    : in std_logic_vector(block_size-1 downto 0);  -- instruction from memory
        instruction_to_proc     : out std_logic_vector(proc_word_size-1 downto 0) -- instruction to processor
    );
    end component;

    component mem_instruction 
    generic(
        block_size      : integer := 128;
        word_size       : integer := 32;
        addr_size       : integer := 10
    );
    port(
        clk             : in std_logic;
        reset           : in std_logic;
        read_from_mem   : in std_logic; -- read signal
        addr            : in std_logic_vector(addr_size - 1 downto 0);
        instruction_o   : out std_logic_vector(block_size - 1 downto 0);
        instruction_rdy : out std_logic;
        rd_rdy          : out std_logic     
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
        flush           : in std_logic;
        rd              : in std_logic; -- read request from processor
        index           : in std_logic_vector(index_bits - 1 downto 0); -- index of the addr requeste
        tag             : in std_logic_vector(tag_bits - 1 downto 0) -- tag of addr requested
        instruction_rdy : in std_logic; 
        instruction_loc : out std_logic_vector(index_bits+set_offset_bits - 1 downto 0); -- location of instruction in cache instruction array
        refill          : out std_logic; -- refill signal to cache
        read_from_mem   : out std_logic; -- read signal to cache
        mem_addr        : out std_logic_vector(tag_bits+index_bits+set_offset_bits-1 downto 0);
        stall           : out std_logic;
        hit             : out std_logic
    );
    end component;

    -- interconnect signals
    signal addr_m: std_logic_vector(addr_w - 1 downto 0);

    -- for memory
    signal rd_rdy_s         : std_logic;
    signal instruction_rdy_s       : std_logic;
    signal instruction_from_mem_s  : std_logic_vector(block_size - 1 downto 0);
    signal instruction_to_mem_s    : std_logic_vector(block_size - 1 downto 0);
    signal rd_s             : std_logic;
    signal wr_s             : std_logic;
    signal addr_s           : std_logic_vector(tag_bits+index_bits+set_offset_bits-1 downto 0);

    -- for cache memory
    signal refill_s         : std_logic;
    signal update_s         : std_logic;
    signal instruction_loc_s       : std_logic_vector(index_bits+set_offset_bits - 1 downto 0);

begin

    addr_m <= addr(addr_w - 1 downto 0);

    inst_controller: l1_controller_instruction
    generic map(
        index_bits      => index_bits,
        set_offset_bits => set_offset_bits,
        tag_bits        => tag_bits
    );
    port map(
        clk             => clk,
        reset           => reset,
        flush           => flush,
        rd              => rd, 
        index           => addr_m(index_offset downto block_offset + 1),
        tag             => addr_m(tag_offset downto index_offset+1),
        instruction_rdy => instruction_rdy_s, 
        instruction_loc => instruction_loc_s, 
        refill          => refill_s,
        read_from_mem   => rd_s
        mem_addr        => addr_s,
        stall           => stall,
        hit             => hit
    );

    inst_mem: mem_instruction 
    generic map(
        block_size      => block_size,
        word_size       => word_size,
        addr_size       => addr_w
    );
    port map(
        clk             => clk,
        reset           => reset,
        read_from_mem   => rd_s,
        addr            => addr_s,
        instruction_o   => instruction_from_mem_s,
        instruction_rdy => instruction_rdy_s,
        rd_rdy          => rd_rdy_s     
    );

    rd_rdy  <= rd_rdy_s;

    inst_cache: cache_instruction
    generic map(
        loc_bits        => 4, -- 16 entries
        offset_bits     => 2, -- to choose one of four words
        block_size      => 128, -- 32*4 
        mem_word_size   => 32, -- word size of memory
        proc_word_size  => 32, -- word size of processor
        blk_0_offset    => 127, -- cache block --> | blk0 | blk1 | blk2 | blk3
        blk_1_offset    => 95,
        blk_2_offset    => 63,
        blk_3_offset    => 31
    );
    port map(
        clk                     => clk,
        refill                  => refill_s,
        instruction_loc         => instruction_loc_s,
        offset                  => addr_m(block_offset downto 0),
        instruction_from_mem    => instruction_from_mem_s, 
        instruction_to_proc     => rinstruction
    );

end Behavioral;top_instruction_cache