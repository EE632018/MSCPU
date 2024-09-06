library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity core is
    generic(
        addr_w          : integer := 10;
        word_size       : integer := 32;
        block_size      : integer := 32;
        init_pc_val     : integer := 2
    );
    port (
        clk             : in std_logic;
        reset           : in std_logic;

        -- Arbiter connection 
        data_to_bus     : out std_logic_vector(word_size - 1 downto 0);
        data_from_bus   : in std_logic_vector(word_size - 1 downto 0);
        bus_addr_o      : out std_logic_vector(addr_w - 1 downto 0);
        bus_addr_i      : in std_logic_vector(addr_w - 1 downto 0);

        busrd_i         : in std_logic;
        busupd_i        : in std_logic;
        --flush_i         : in std_logic;
        --update_i        : in std_logic;
        cache_i         : in std_logic;
        key_to_bus      : in std_logic; -- zakljucavanje magistrale od strane datog kontrolera
        cache_o         : out std_logic;
        busrd_o         : out std_logic;
        busupd_o        : out std_logic;
        flush_o         : out std_logic;
        update_o        : out std_logic;
        send_to_mem_o   : out std_logic;
        lock_arbiter_o  : out std_logic;

        -- Instruction arbiter
        refill                  : out std_logic;
        mem_addr                : out std_logic_vector(addr_w-1 downto 0);
        instruction_from_bus    : in std_logic_vector(block_size-1 downto 0);
        read_from_bus           : out std_logic
        );
end core;

architecture Behavioral of core is

    component TOP_RISCV
    generic (
        init_pc_val     : integer := 2
    );
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


    component top_instruction_cache
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
        block_size              : integer := 32;
        -- default from memory
        addr_w                  : integer := 10;
        word_size               : integer := 32
    
    );
    port(
        clk                     : in std_logic;
        reset                   : in std_logic;
        rd                      : in std_logic;
        addr                    : in std_logic_vector(addr_w - 1 downto 0);
        refill                  : out std_logic;
        instruction_to_proc     : out std_logic_vector(word_size-1 downto 0); -- instruction to processor
        instruction_from_bus    : in std_logic_vector(block_size-1 downto 0);  -- instruction from memory
        read_from_bus           : out std_logic;
        mem_addr                : out std_logic_vector(tag_bits+index_bits+set_offset_bits-1 downto 0);
        stall                   : out std_logic
        --stall_a                 : in std_logic
    );
    end component;

    component cache_top
    generic(
        loc_bits        : integer := 6; -- 64 entries
        offset_bits     : integer := 2; -- to choose one of four words
        word_size       : integer := 32; -- word size 
        addr_w          : integer := 10
    );
    port(
        clk             : in std_logic; -- same as processor
        reset           : in std_logic;

        data_to_bus     : out std_logic_vector(word_size - 1 downto 0);
        data_from_bus   : in std_logic_vector(word_size - 1 downto 0);
        data_to_proc    : out std_logic_vector(word_size - 1 downto 0);
        data_from_proc  : in std_logic_vector(word_size - 1 downto 0);

        proc_rd         : in std_logic;
        proc_wr         : in std_logic;
        proc_addr       : in std_logic_vector(addr_w - 1 downto 0);
        bus_addr_o      : out std_logic_vector(addr_w - 1 downto 0);
        bus_addr_i      : in std_logic_vector(addr_w - 1 downto 0);
        stall           : out std_logic;

        busrd_i         : in std_logic;
        busupd_i        : in std_logic;
        --flush_i         : in std_logic;
        --update_i        : in std_logic;
        cache_i         : in std_logic;
        key_to_bus      : in std_logic; -- zakljucavanje magistrale od strane datog kontrolera
        cache_o         : out std_logic;
        busrd_o         : out std_logic;
        busupd_o        : out std_logic;
        flush_o         : out std_logic;
        update_o        : out std_logic;
        send_to_mem_o   : out std_logic;
        lock_arbiter_o  : out std_logic
    );
    end component;

    signal instr_mem_address_s, instr_mem_read_s : std_logic_vector(31 downto 0);
    signal data_mem_address_s, data_mem_read_s, data_mem_write_s : std_logic_vector(31 downto 0);
    signal data_mem_we, data_mem_rd : std_logic_vector(3 downto 0);
    signal stall_s, stall_a, stall_i, stall_d : std_logic;

begin

    inst_cpu: TOP_RISCV
    generic map(
        init_pc_val     => 2
    )
    port map(
      -- Globalna sinhronizacija
      clk                 => clk,
      reset               => reset,
      -- Interfejs ka memoriji za instrukcije
      instr_mem_address_o => instr_mem_address_s,
      instr_mem_read_i    => instr_mem_read_s,
      -- Interfejs ka memoriji za podatke
      data_mem_address_o  => data_mem_address_s,
      data_mem_read_i     => data_mem_read_s,
      data_mem_write_o    => data_mem_write_s,
      data_mem_we_o       => data_mem_we,
      data_mem_rd_o       => data_mem_rd,
      stall_i             => stall_s 
    );

    inst_instruction_cache: top_instruction_cache
    generic map(
        -- default from processor
        instruction_bus_w       => 32,
        addr_bus_w              => 32,
        -- default from cache controller
        index_bits              => 2,
        tag_bits                => 6,
        set_offset_bits         => 2,
        -- default from cache memory
        loc_bits                => 4,
        offset_bits             => 2,
        block_size              => 32,
        -- default from memory
        addr_w                  => 10,
        word_size               => 32
    
    )
    port map(
        clk                     => clk,
        reset                   => reset,
        rd                      => data_mem_rd(0),
        addr                    => instr_mem_address_s(9 downto 0), 
        refill                  => refill,
        read_from_bus           => read_from_bus,
        instruction_to_proc     => instr_mem_read_s,
        instruction_from_bus    => instruction_from_bus,
        mem_addr                => mem_addr, 
        stall                   => stall_i 
        --stall_a                 => stall_a
    );

    inst_cache_data: cache_top
    generic map(
        loc_bits        => 6, 
        offset_bits     => 2, 
        word_size       => 32, 
        addr_w          => 10
    )
    port map(
        clk             => clk,
        reset           => reset,

        data_to_bus     => data_to_bus,
        data_from_bus   => data_from_bus,
        data_to_proc    => data_mem_read_s,
        data_from_proc  => data_mem_write_s,

        proc_rd         => data_mem_rd(0),
        proc_wr         => data_mem_we(0),
        proc_addr       => data_mem_address_s(9 downto 0),
        
        bus_addr_o      => bus_addr_o,
        bus_addr_i      => bus_addr_i,
        stall           => stall_d, 

        busrd_i         => busrd_i, 
        busupd_i        => busupd_i, 
        --flush_i         => flush_i, 
        --update_i        => update_i, 
        cache_i         => cache_i,
        key_to_bus      => key_to_bus,  
        cache_o         => cache_o, 
        busrd_o         => busrd_o, 
        busupd_o        => busupd_o, 
        flush_o         => flush_o,
        update_o        => update_o, 
        send_to_mem_o   => send_to_mem_o,
        lock_arbiter_o  => lock_arbiter_o
    );

    stall_s <= stall_i or stall_d;
end Behavioral;