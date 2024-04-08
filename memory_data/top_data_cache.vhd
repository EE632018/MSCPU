library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_data_cache is
    generic(
        -- default from processor
        data_bus_w      : integer := 32;
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
        rdata           : out std_logic_vector(data_bus_w - 1 downto 0);
        wdata           : in std_logic_vector(data_bus_w - 1 downto 0);
        flush           : in std_logic;
        rd              : in std_logic;
        wr              : in std_logic;
        stall           : out std_logic;
        rd_rdy          : out std_logic;
        hit             : out std_logic;
        miss            : out std_logic;
        cache_state     : out std_logic_vector(2 downto 0)
    );
end top_data_cache;


architecture Behavioral of top_data_cache is

    component cache_data 
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
        data_loc        : in std_logic_vector(loc_bits-1 downto 0); -- index selection
        offset          : in std_logic_vector(offset_bits-1 downto 0); -- offset selection
        data_from_mem   : in std_logic_vector(block_size-1 downto 0);  -- data from memory
        data_from_proc  : in std_logic_vector(proc_word_size-1 downto 0); -- data from processor
        data_to_mem     : out std_logic_vector(block_size-1 downto 0); -- evicted block data in case of a write miss
        data_to_proc    : out std_logic_vector(proc_word_size-1 downto 0) -- data to processor
    );
    end component;

    component mem_data 
    generic(
        block_size      : integer := 128;
        word_size       : integer := 32;
        addr_size       : integer := 10
    );
    port(
        clk             : in std_logic;
        reset           : in std_logic;
        read_from_mem   : in std_logic; -- read signal
        write_to_mem    : in std_logic; -- write signal
        addr            : in std_logic_vector(addr_size - 1 downto 0);
        data_i          : in std_logic_vector(block_size - 1 downto 0);
        data_o          : out std_logic_vector(block_size - 1 downto 0);
        data_rdy        : out std_logic;
        rd_rdy          : out std_logic     
    );
    end component;

    component l1_controller_data
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
        wr              : in std_logic; -- write request from processor
        index           : in std_logic_vector(index_bits - 1 downto 0); -- index of the addr requeste
        tag             : in std_logic_vector(tag_bits - 1 downto 0) -- tag of addr requested
        data_rdy        : in std_logic; 
        data_loc        : out std_logic_vector(index_bits+set_offset_bits - 1 downto 0); -- location of data in cache data array
        refill          : out std_logic; -- refill signal to cache
        update          : out std_logic; -- update signal to cache
        read_from_mem   : out std_logic; -- read signal to cache
        write_to_mem    : out std_logic; -- write signak to cache
        mem_addr        : out std_logic_vector(tag_bits+index_bits+set_offset_bits-1 downto 0);
        stall           : out std_logic;
        hit             : out std_logic;
        miss            : out std_logic;
        cache_state     : out std_logic_vector(2 downto 0)
    );
    end component;

    -- interconnect signals
    signal addr_m: std_logic_vector(addr_w - 1 downto 0);

    -- for memory
    signal rd_rdy_s         : std_logic;
    signal data_rdy_s       : std_logic;
    signal data_from_mem_s  : std_logic_vector(block_size - 1 downto 0);
    signal data_to_mem_s    : std_logic_vector(block_size - 1 downto 0);
    signal rd_s             : std_logic;
    signal wr_s             : std_logic;
    signal addr_s           : std_logic_vector(tag_bits+index_bits+set_offset_bits-1 downto 0);

    -- for cache memory
    signal refill_s         : std_logic;
    signal update_s         : std_logic;
    signal data_loc_s       : std_logic_vector(index_bits+set_offset_bits - 1 downto 0);

begin

    addr_m <= addr(addr_w - 1 downto 0);

    inst_controller: l1_controller_data
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
        wr              => wr,
        index           => addr_m(index_offset downto block_offset + 1),
        tag             => addr_m(tag_offset downto index_offset+1),
        data_rdy        => data_rdy_s, 
        data_loc        => data_loc_s, 
        refill          => refill_s,
        update          => update_s,
        read_from_mem   => rd_s
        write_to_mem    => wr_s,
        mem_addr        => addr_s,
        stall           => stall,
        hit             => hit,
        miss            => miss,
        cache_state     => cache_state
    );

    inst_mem: mem_data 
    generic map(
        block_size      => block_size,
        word_size       => word_size,
        addr_size       => addr_w
    );
    port map(
        clk             => clk,
        reset           => reset,
        read_from_mem   => rd_s,
        write_to_mem    => wr_s,
        addr            => addr_s,
        data_i          => data_to_mem_s,
        data_o          => data_from_mem_s,
        data_rdy        => data_rdy_s,
        rd_rdy          => rd_rdy_s     
    );

    rd_rdy  <= rd_rdy_s;

    inst_cache: cache_data
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
        clk             => clk,
        refill          => refill_s,
        update          => update_s,
        data_loc        => data_loc_s,
        offset          => addr_m(block_offset downto 0),
        data_from_mem   => data_from_mem_s, 
        data_from_proc  => wdata,
        data_to_mem     => data_to_mem_s,
        data_to_proc    => rdata
    );

end Behavioral;top_data_cache