library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity top_ms is
    generic (
        num_of_cores    : integer := 2;
        word_size       : integer := 32;
        addr_w          : integer := 10;
        block_size      : integer := 128
    );
    port(
        clk             : in std_logic;
        reset           : in std_logic;
    );

end top_ms;

architecture Behavioral of top_ms is

    component core 
    generic(
        addr_w          : integer := 10;
        word_size       : integer := 32;
        block_size      : integer := 128
    );
    port (
        clk             : in std_logic;
        reset           : in std_logic;

        -- BUS <-> CACHE CONNECTION
        cache_i         : in std_logic;
        busrd_i         : in std_logic;
        busupd_i        : in std_logic;
        busrd_o         : out std_logic;
        busupd_o        : out std_logic;
        flush_o         : out std_logic;
        update_o        : out std_logic;
        send_to_mem_o   : out std_logic;
        data_from_bus   : in std_logic_vector(word_size - 1 downto 0);
        data_to_bus     : out std_logic_vector(word_size - 1 downto 0);
        data_to_mem     : out std_logic_vector(word_size - 1 downto 0);

        -- BUS <-> CACHE CONTROLLER CONNECTION
        bus_addr_o      : out std_logic_vector(addr_w - 1 downto 0);
        bus_addr_i      : in std_logic_vector(addr_w - 1 downto 0);
        cache_o         : out std_logic;

        -- CACHE INSTRUCTION 
        instruction_from_bus    : in std_logic_vector(block_size-1 downto 0);  -- instruction from memory
        read_from_bus           : out std_logic;
        mem_addr                : out std_logic_vector(addr_w - 1 downto 0);
        refill                  : out std_logic;
        stall_a                 : in std_logic; -- arbiter
        src_cache_o             : out std_logic
    );
    end component;

    component arbiter
    generic(
        num_of_cores    : integer := 2;
        addr_w          : integer := 10;
        word_size       : integer := 32;
        block_size      : integer := 128
    );
    port (
        clk             : in std_logic;
        reset           : in std_logic;

        cache_o         : out std_logic_vector(num_of_cores - 1 downto 0); --
        busrd_o         : out std_logic_vector(num_of_cores - 1 downto 0); --
        busupd_o        : out std_logic_vector(num_of_cores - 1 downto 0); --
        busrd_i         : in std_logic_vector(num_of_cores - 1 downto 0); --
        busupd_i        : in std_logic_vector(num_of_cores - 1 downto 0); --
        flush_i         : in std_logic_vector(num_of_cores - 1 downto 0);
        update_i        : in std_logic_vector(num_of_cores - 1 downto 0);
        send_to_mem_i   : in std_logic_vector(num_of_cores - 1 downto 0);
        send_from_mem_o : out std_logic; -- this is read enable signal, to read some data from main memory to some core

        data_from_bus   : out std_logic_vector(word_size - 1 downto 0);
        data_from_mem   : in std_logic_vector(word_size - 1 downto 0);
        data_to_mem     : out std_logic_vector(word_size - 1 downto 0);
        data_to_bus     : in std_logic_vector(num_of_cores * word_size - 1 downto 0);
        data_from_core  : in std_logic_vector(num_of_cores * word_size - 1 downto 0); -- ovo je signal iz cora koji se zove data_to_mem
        -- BUS <-> CACHE CONTROLLER CONNECTION
        bus_addr_o      : out std_logic_vector(addr_w - 1 downto 0);
        bus_addr_i      : in std_logic_vector(num_of_cores * addr_w - 1 downto 0);
        cache_i         : in std_logic_vector(num_of_cores - 1 downto 0);
        stall_a         : out std_logic_vector(num_of_cores - 1 downto 0);
        src_cache_i     : in std_logic_vector(num_of_cores - 1 downto 0);

        instruction_to_bus      : out std_logic_vector(block_size-1 downto 0);  -- instruction from memory
        instruction_from_mem    : in std_logic_vector(block_size-1 downto 0);
        read_from_bus           : in std_logic_vector(num_of_cores - 1 downto 0);
        mem_addr                : in std_logic_vector(num_of_cores * addr_w - 1 downto 0);
        refill                  : in std_logic_vector(num_of_cores - 1 downto 0);
        addr_to_mem             : out std_logic_vector(addr_w - 1 downto 0)
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
        send_from_mem_i : in std_logic; -- read signal
        addr            : in std_logic_vector(addr_size - 1 downto 0);
        data_i          : in std_logic_vector(word_size - 1 downto 0);
        data_o          : out std_logic_vector(word_size - 1 downto 0)    
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
        addr            : in std_logic_vector(addr_size - 1 downto 0);
        instruction_o   : out std_logic_vector(block_size - 1 downto 0)    
    );
    end component;

    signal cache_os         : std_logic_vector(num_of_cores - 1 downto 0); --
    signal busrd_os         : std_logic_vector(num_of_cores - 1 downto 0); --
    signal busupd_os        : std_logic_vector(num_of_cores - 1 downto 0); --
    signal busrd_is         : std_logic_vector(num_of_cores - 1 downto 0); --
    signal busupd_is        : std_logic_vector(num_of_cores - 1 downto 0); --
    signal flush_is         : std_logic_vector(num_of_cores - 1 downto 0);
    signal update_is        : std_logic_vector(num_of_cores - 1 downto 0);
    signal send_to_mem_is   : std_logic_vector(num_of_cores - 1 downto 0);
    signal send_from_mem_os : std_logic; -- this is read enable signal, to read some data from main memory to some core
    signal data_from_bus_s  : std_logic_vector(word_size - 1 downto 0);
    signal data_from_mem_s  : std_logic_vector(word_size - 1 downto 0);
    signal data_to_mem_s    : std_logic_vector(word_size - 1 downto 0);
    signal data_to_bus_s    : std_logic_vector(num_of_cores * word_size - 1 downto 0);
    signal data_from_core_s : std_logic_vector(num_of_cores * word_size - 1 downto 0); -- ovo je signal iz cora koji se zove data_to_mem
    signal bus_addr_os      : std_logic_vector(addr_w - 1 downto 0);
    signal bus_addr_is      : std_logic_vector(num_of_cores * addr_w - 1 downto 0);
    signal cache_is         : std_logic_vector(num_of_cores - 1 downto 0);
    signal stall_as         : std_logic_vector(num_of_cores - 1 downto 0);
    signal src_cache_is     : std_logic_vector(num_of_cores - 1 downto 0);
    signal instruction_to_bus_s      : std_logic_vector(block_size-1 downto 0);  -- instruction from memory
    signal instruction_from_mem_s    : std_logic_vector(block_size-1 downto 0);
    signal read_from_bus_s           : std_logic_vector(num_of_cores - 1 downto 0);
    signal mem_addr_s                : std_logic_vector(num_of_cores * addr_w - 1 downto 0);
    signal refill_s                  : std_logic_vector(num_of_cores - 1 downto 0);
    signal addr_to_mem_s             : std_logic_vector(addr_w - 1 downto 0);
begin

    inst_arbiter_data: arbiter
    generic map(
        num_of_cores    => 2,
        addr_w          => 10,
        word_size       => 32,
        block_size      => 128
    )
    port map(
        clk                     => clk, --
        reset                   => reset, --
        cache_o                 => cache_os, --
        busrd_o                 => busrd_os, --
        busupd_o                => busupd_os, --
        busrd_i                 => busrd_is, --
        busupd_i                => busupd_is, --
        flush_i                 => flush_is, --
        update_i                => update_is, --
        send_to_mem_i           => send_to_mem_is, --
        send_from_mem_o         => send_from_mem_os, --
        data_from_bus           => data_from_bus_s, --
        data_from_mem           => data_from_mem_s,
        data_to_mem             => data_to_mem_s,
        data_to_bus             => data_to_bus_s, --
        data_from_core          => data_from_core_s, -- 
        bus_addr_o              => bus_addr_os, --
        bus_addr_i              => bus_addr_is, --
        cache_i                 => cache_is, --
        stall_a                 => stall_as, --
        src_cache_i             => src_cache_is,--
        instruction_to_bus      => instruction_to_bus_s,
        instruction_from_mem    => instruction_from_mem_s,
        read_from_bus           => read_from_bus_s,
        mem_addr                => mem_addr_s,
        refill                  => refill_s, 
        addr_to_mem             => addr_to_mem_s
    );

    for i in 0 to num_of_cores - 1 generate
        core_inst: core
        generic map(
            addr_w          => 10,
            word_size       => 32,
            block_size      => 128
        )
        port map(
            clk                     => clk,
            reset                   => reset,
            cache_i                 => cache_os(i),
            busrd_i                 => busrd_os(i),
            busupd_i                => busupd_os(i),
            busrd_o                 => busrd_is(i),
            busupd_o                => busupd_is(i),
            flush_o                 => flush_is(i),
            update_o                => update_is(i),
            send_to_mem_o           => send_to_mem_is(i),
            data_from_bus           => data_from_bus_s,
            data_to_bus             => data_to_bus_s((i+1)* word_size - 1 downto i*word_size),
            data_to_mem             => data_from_core_s((i+1)* word_size - 1 downto i*word_size),
            bus_addr_o              => bus_addr_is(i * addr_w),
            bus_addr_i              => bus_addr_os,
            cache_o                 => cache_is(i),        
            instruction_from_bus    => instruction_to_bus_s,    
            read_from_bus           => read_from_bus(i),
            mem_addr                => mem_addr_s((i+1)* word_size - 1 downto i*word_size),
            refill                  => refill_s(i),
            stall_a                 => stall_as(i),
            src_cache_o             => src_cache_is(i)
        );    
    end generate;

    inst_data_mem: mem_data
    generic map(
        block_size      => 128,
        word_size       => 32,
        addr_size       => 10
    )
    port map(
        clk             => clk,
        reset           => reset,
        send_from_mem_i => send_from_mem_os,
        addr            => bus_addr_os,
        data_i          => data_to_mem_s,
        data_o          => data_from_mem_s    
    );

    inst_instruction_mem: mem_instruction
    generic map(
        block_size      => 128, 
        word_size       => 32,         
        addr_size       => 10     
    )
    port map(
        clk             => clk,
        reset           => reset,
        addr            => addr_to_mem_s,
        instruction_o   => instruction_from_mem_s    
    );

end Behavioral;