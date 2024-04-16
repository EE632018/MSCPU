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
        -- cache data
        cache_i         : in std_logic;
        busrd_i         : in std_logic;
        busupd_i        : in std_logic;
        busrd_o         : out std_logic;
        busupd_o        : out std_logic;
        flush_o         : out std_logic;
        update_o        : out std_logic;
        data_from_bus   : in std_logic_vector(word_size - 1 downto 0);  -- data from memory
        data_from_proc  : in std_logic_vector(word_size - 1 downto 0); -- data from processor
        data_to_bus     : out std_logic_vector(word_size - 1 downto 0); -- evicted block data in case of a write miss
        data_to_proc    : out std_logic_vector(word_size - 1 downto 0) -- data to processor

        -- cache controller
        proc_rd         : in std_logic;
        proc_wr         : in std_logic;
        proc_addr       : in std_logic_vector(addr_w - 1 downto 0);
        bus_addr_o      : out std_logic_vector(addr_w - 1 downto 0);
        bus_addr_i      : in std_logic_vector(addr_w - 1 downto 0);
        stall           : out std_logic;
        cache_o         : out std_logic
    );
end top_data_cache;


architecture Behavioral of top_data_cache is

    component cache_data
    generic(
        loc_bits        : integer := 4; -- 16 entries
        offset_bits     : integer := 2; -- to choose one of four words
        word_size       : integer := 32; -- word size 
        addr_w          : integer := 10
    );
    port(
        clk             : in std_logic; -- same as processor
        reset           : in std_logic;
        -- dragon fsm signals 
        cache_i         : in std_logic; -- there is this value in other cache
        prrd_i          : in std_logic;
        prrdmiss_i      : in std_logic;
        prwr_i          : in std_logic;
        prwrmiss_i      : in std_logic;
        busrd_i         : in std_logic;
        busupd_i        : in std_logic;
        busrd_o         : out std_logic;
        busupd_o        : out std_logic;
        flush_o         : out std_logic;
        update_o        : out std_logic;
        data_loc        : in std_logic_vector(loc_bits-1 downto 0); -- data_loc selection
        data_loc_bus_i  : in std_logic_vector(loc_bits-1 downto 0);
        offset          : in std_logic_vector(offset_bits-1 downto 0); -- offset selection
        
        data_from_bus   : in std_logic_vector(word_size - 1 downto 0);  -- data from memory
        data_from_proc  : in std_logic_vector(word_size - 1 downto 0); -- data from processor
        data_to_bus     : out std_logic_vector(word_size - 1 downto 0); -- evicted block data in case of a write miss
        addr_from_bus   : in std_logic_vector(addr_w - 1 downto 0);
        data_to_proc    : out std_logic_vector(word_size - 1 downto 0) -- data to processor
    );
    end component;

    component cache_controller
    generic(
        index_bits      : integer := 2;
        set_offset_bits : integer := 2;
        tag_bits        : integer := 6;
        addr_w          : integer := 10
    );

    port(
        clk         : in std_logic;
        reset       : in std_logic;
        -- Signals from/to processor
        proc_rd     : in std_logic;
        proc_wr     : in std_logic;
        proc_addr   : in std_logic_vector(addr_w - 1 downto 0);
        bus_addr_o  : out std_logic_vector(addr_w - 1 downto 0);
        bus_addr_i  : in std_logic_vector(addr_w - 1 downto 0);
        stall       : out std_logic;
        -- Signals to cache
        data_loc        : out std_logic_vector(index_bits + set_offset_bits - 1 downto 0);
        data_loc_bus_o  : out std_logic_vector(index_bits + set_offset_bits - 1 downto 0);
        cache_o         : out std_logic; -- there is this value in other cache
        prrd_o          : out std_logic;
        prrdmiss_o      : out std_logic;
        prwr_o          : out std_logic;
        prwrmiss_o      : out std_logic
    );
    end component;

    signal prrd_s, prrdmiss_s : std_logic;
    signal prwr_s, prwrmiss_s : std_logic;
    signal data_loc_s         : std_logic_vector(index_bits + set_offset_bits - 1 downto 0);
    signal data_loc_bus_s     : std_logic_vector(index_bits + set_offset_bits - 1 downto 0);    
begin

    inst_cache_data: cache_data
    port map(
        clk             => clk,
        reset           => reset, 
        cache_i         => cache_i,
        prrd_i          => prrd_s,
        prrdmiss_i      => prrdmiss_s,
        prwr_i          => prwr_s,
        prwrmiss_i      => prwrmiss_s,
        busrd_i         => busrd_i,
        busupd_i        => busupd_i,
        busrd_o         => busrd_o,
        busupd_o        => busupd_o,
        flush_o         => flush_o,
        update_o        => update_o,
        data_loc        => data_loc_s,
        data_loc_bus_i  => data_loc_bus_s,
        offset          => proc_addr(1 downto 0),
        data_from_bus   => data_from_bus,
        data_from_proc  => data_from_proc,
        data_to_bus     => data_to_bus,
        addr_from_bus   => bus_addr_i,
        data_to_proc    => data_to_proc
    );

    inst_cache_controller: cache_controller
    port map(
        clk             => clk,
        reset           => reset,
        proc_rd         => proc_rd,
        proc_wr         => proc_wr,
        proc_addr       => proc_addr,
        bus_addr_o      => bus_addr_o,
        bus_addr_i      => bus_addr_i,
        stall           => stall,
        data_loc        => data_loc_s,
        data_loc_bus_o  => data_loc_bus_s,
        cache_o         => cache_o, 
        prrd_o          => prrd_s,
        prrdmiss_o      => prrdmiss_s,
        prwr_o          => prwr_s,
        prwrmiss_o      => prwrmiss_s
    );

end Behavioral;