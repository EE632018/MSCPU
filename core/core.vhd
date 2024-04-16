library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity core is
    generic(
        addr_w          : integer := 10;
        word_size       : integer := 32
    );
    port (
        clk     : in std_logic;
        reset   : in std_logic;

        -- BUS <-> CACHE CONNECTION
        cache_i         : in std_logic;
        busrd_i         : in std_logic;
        busupd_i        : in std_logic;
        busrd_o         : out std_logic;
        busupd_o        : out std_logic;
        flush_o         : out std_logic;
        update_o        : out std_logic;
        data_from_bus   : in std_logic_vector(word_size - 1 downto 0);
        data_to_bus     : in std_logic_vector(word_size - 1 downto 0);

        -- BUS <-> CACHE CONTROLLER CONNECTION
        bus_addr_o      : out std_logic_vector(addr_w - 1 downto 0);
        bus_addr_i      : in std_logic_vector(addr_w - 1 downto 0);
        cache_o         : out std_logic
    );
end core;

architecture Behavioral of core is

    component TOP_RISCV
    port(
      -- Globalna sinhronizacija
      clk                 : in  std_logic;
      reset               : in  std_logic;
      -- Interfejs ka memoriji za instrukcije
      instr_mem_address_o : out std_logic_vector(31 downto 0);
      instr_mem_read_i    : in  std_logic_vector(31 downto 0);
      -- Interfejs ka memoriji za podatke
      data_mem_address_o  : out std_logic_vector(31 downto 0);
      data_mem_read_i     : in  std_logic_vector(31 downto 0);
      data_mem_write_o    : out std_logic_vector(31 downto 0);
      data_mem_we_o       : out std_logic_vector(3 downto 0);
      data_mem_rd_o       : out std_logic_vector(3 downto 0);
      stall_i             : in  std_logic 
    );
    end component;

    component top_data_cache
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
        data_to_proc    : out std_logic_vector(word_size - 1 downto 0); -- data to processor

        -- cache controller
        proc_rd         : in std_logic;
        proc_wr         : in std_logic;
        proc_addr       : in std_logic_vector(addr_w - 1 downto 0);
        bus_addr_o      : out std_logic_vector(addr_w - 1 downto 0);
        bus_addr_i      : in std_logic_vector(addr_w - 1 downto 0);
        stall           : out std_logic;
        cache_o         : out std_logic
    );
    end component;

    signal instr_mem_read_s     : std_logic_vector(31 downto 0);
    signal data_mem_address_s   : std_logic_vector(31 downto 0);
    signal data_mem_read_s      : std_logic_vector(31 downto 0);
    signal data_mem_write_s     : std_logic_vector(31 downto 0);
    signal data_mem_we_s        : std_logic_vector(3 downto 0);
    signal data_mem_rd_s        : std_logic_vector(3 downto 0);
    signal stall_s              : std_logic;
begin

    inst_cpu: TOP_RISCV
    port map(
      clk                 => clk,
      reset               => reset,
      instr_mem_address_o => open,
      instr_mem_read_i    => instr_mem_read_s,
      data_mem_address_o  => data_mem_address_s,
      data_mem_read_i     => data_mem_read_s,
      data_mem_write_o    => data_mem_write_s,
      data_mem_we_o       => data_mem_we_s,
      data_mem_rd_o       => data_mem_rd_s,
      stall_i             => stall_s
    );

    inst_cache: top_data_cache
    port map(
        clk             => clk,
        reset           => reset,
        -- cache data
        cache_i         => cache_i,
        busrd_i         => busrd_i,
        busupd_i        => busupd_i,
        busrd_o         => busrd_o,
        busupd_o        => busupd_o,
        flush_o         => flush_o,
        update_o        => update_o,
        data_from_bus   => data_from_bus,  
        data_from_proc  => data_mem_write_s, 
        data_to_bus     => data_to_bus, 
        data_to_proc    => data_mem_read_s, 

        -- cache controller
        proc_rd         => data_mem_rd_s(0),
        proc_wr         => data_mem_we_s(0),
        proc_addr       => data_mem_address_s(9 downto 0),
        bus_addr_o      => bus_addr_o,
        bus_addr_i      => bus_addr_i,
        stall           => stall_s,
        cache_o         => cache_o,
    );


end Behavioral;