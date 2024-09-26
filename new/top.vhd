library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils_pkg.all;

entity top is
    generic(
        num_of_cores    : integer := 2;
        addr_w          : integer := 10;
        word_size       : integer := 32;
        block_size      : integer := 32;
        size            : integer := 1024;
        init_pc_val     : integer := 0
    );
    port(
        clk                 : in std_logic;
        reset               : in std_logic;
        wr                  : in std_logic;
        en                  : in std_logic;

        -- mem instruction
        wr_top              : in std_logic;
        en_top              : in std_logic;
        addr_top            : in std_logic_vector(log2c(size) - 1 downto 0);
        instruction_top_o   : out std_logic_vector(block_size - 1 downto 0);
        instruction_top_i   : in std_logic_vector(block_size - 1 downto 0);
        -- mem data 
        wr_top_data         : in std_logic; -- read signal
        en_top_data         : in std_logic;
        addr_top_data       : in std_logic_vector(log2c(size) - 1 downto 0);
        data_top_i          : in std_logic_vector(word_size - 1 downto 0);
        data_top_o          : out std_logic_vector(word_size - 1 downto 0)   
    );
end top;

architecture Behavioral of top is 

    component core
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

        bus_addr_o      : out std_logic_vector(addr_w - 1 downto 0);
        bus_addr_i      : in std_logic_vector(num_of_cores * addr_w - 1 downto 0);
        
        cache_i         : in std_logic_vector(num_of_cores - 1 downto 0);
        busrd_i         : in std_logic_vector(num_of_cores - 1 downto 0);
        busupd_i        : in std_logic_vector(num_of_cores - 1 downto 0);
        flush_i         : in std_logic_vector(num_of_cores - 1 downto 0);
        update_i        : in std_logic_vector(num_of_cores - 1 downto 0);
        send_to_mem_i   : in std_logic_vector(num_of_cores - 1 downto 0);
        send_from_mem_o : out std_logic;

        busrd_o         : out std_logic_vector(num_of_cores - 1 downto 0);
        busupd_o        : out std_logic_vector(num_of_cores - 1 downto 0);
        cache_o         : out std_logic_vector(num_of_cores - 1 downto 0);
        --src_cache_o     : out std_logic; -- pretraga cache koja mi kaze kada da drugi pogledaju

        key_to_bus      : out std_logic_vector(num_of_cores - 1 downto 0); -- zakljucavanje magistrale od strane datog kontrolera
        lock_arbiter_i  : in std_logic_vector(num_of_cores - 1 downto 0); --

        data_to_core    : out std_logic_vector(word_size - 1 downto 0);
        data_from_core  : in std_logic_vector(num_of_cores * word_size - 1 downto 0);
        data_to_mem     : out std_logic_vector(word_size - 1 downto 0);
        data_from_mem   : in std_logic_vector(word_size - 1 downto 0) -- Ovde treba razmisliti o ubacivanju slanja bloka a ne samo reci u kes

    );
    end component;

    component arbiter_instruction
    generic(
        block_size      : integer := 32;
        addr_w          : integer := 10;
        num_of_cores    : integer := 2
    );
    port(
        refill                  : in std_logic_vector(num_of_cores - 1 downto 0);
        
        mem_addr                : in std_logic_vector(num_of_cores*addr_w-1 downto 0);
        instruction_from_bus    : out std_logic_vector(block_size-1 downto 0);

        instruction_from_mem    : in std_logic_vector(block_size-1 downto 0);
        instruction_addr        : out std_logic_vector(addr_w-1 downto 0);
        instruction_rd          : out std_logic;
        
        read_from_bus           : in std_logic_vector(num_of_cores-1 downto 0)
    );
    end component;

    component mem_instruction
    generic(
        block_size      : integer := 32;
        word_size       : integer := 32;
        addr_size       : integer := 10;
        size            : integer := 1024
    );
    port(
        clk                 : in std_logic;
        wr                  : in std_logic;
        en                  : in std_logic;
        addr                : in std_logic_vector(log2c(size) - 1 downto 0);    
        instruction_o       : out std_logic_vector(block_size - 1 downto 0);
        instruction_i       : in std_logic_vector(block_size - 1 downto 0);
        
        -- top ports
        wr_top              : in std_logic;
        en_top              : in std_logic;
        addr_top            : in std_logic_vector(log2c(size) - 1 downto 0);
        instruction_top_o   : out std_logic_vector(block_size - 1 downto 0);
        instruction_top_i   : in std_logic_vector(block_size - 1 downto 0)
            
    );
    end component;


    component mem_data
    generic(
        block_size      : integer := 128;
        word_size       : integer := 32;
        addr_size       : integer := 10;
        size            : integer := 1024
    );
    port(
        clk             : in std_logic;
        en              : in std_logic;
        send_from_mem_i : in std_logic; -- read signal
        addr            : in std_logic_vector(log2c(size) - 1 downto 0);
        data_i          : in std_logic_vector(word_size - 1 downto 0);
        data_o          : out std_logic_vector(word_size - 1 downto 0);
        
        -- top ports
        wr_top          : in std_logic; -- read signal
        en_top          : in std_logic;
        addr_top_data   : in std_logic_vector(log2c(size) - 1 downto 0);
        data_top_i      : in std_logic_vector(word_size - 1 downto 0);
        data_top_o      : out std_logic_vector(word_size - 1 downto 0)    
    );
    end component;


    signal bus_addr_os, instruction_addr_s : std_logic_vector(addr_w - 1 downto 0);
    signal bus_addr_is : std_logic_vector(num_of_cores * addr_w - 1 downto 0);
    signal cache_is, busrd_is, busupd_is, flush_is, update_is, send_to_mem_is, 
           busrd_os, busupd_os, cache_os, key_to_bus, lock_arbiter_is : std_logic_vector(num_of_cores - 1 downto 0); 
    signal send_from_mem_os : std_logic;
    signal data_to_core_s, data_to_mem_s, data_from_mem_s : std_logic_vector(word_size - 1 downto 0);  
    signal data_from_core_s : std_logic_vector(num_of_cores * word_size - 1 downto 0);   
    signal refill_s, read_from_bus_s : std_logic_vector(num_of_cores - 1 downto 0);  
    signal mem_addr_s : std_logic_vector(num_of_cores * addr_w - 1 downto 0);  
    signal instruction_rd_s : std_logic;
    signal instruction_from_bus_s, instruction_from_mem_s : std_logic_vector(word_size - 1 downto 0); 
begin

    inst_arbiter: arbiter
    generic map(
        num_of_cores    => 2,
        addr_w          => 10,
        word_size       => 32,
        block_size      => 128
    )
    port map(
        clk             => clk,
        reset           => reset,

        bus_addr_o      => bus_addr_os,
        bus_addr_i      => bus_addr_is,
        
        cache_i         => cache_is,
        busrd_i         => busrd_is,
        busupd_i        => busupd_is,
        flush_i         => flush_is,
        update_i        => update_is,
        send_to_mem_i   => send_to_mem_is,
        send_from_mem_o => send_from_mem_os,

        busrd_o         => busrd_os,
        busupd_o        => busupd_os,
        cache_o         => cache_os,

        key_to_bus      => key_to_bus,
        lock_arbiter_i  => lock_arbiter_is,

        data_to_core    => data_to_core_s,
        data_from_core  => data_from_core_s,
        data_to_mem     => data_to_mem_s,
        data_from_mem   => data_from_mem_s

    );

    inst_mem_data: mem_data
    generic map(
        block_size      => 32,
        word_size       => 32,
        addr_size       => 10,
        size            => 1024
    )
    port map(
        clk             => clk,
        en              => en,
        send_from_mem_i => send_from_mem_os,
        addr            => bus_addr_os,
        data_i          => data_to_mem_s,
        data_o          => data_from_mem_s,
        
        -- top ports
        wr_top          => wr_top_data,
        en_top          => en_top_data,
        addr_top_data   => addr_top_data,
        data_top_i      => data_top_i,
        data_top_o      => data_top_o
    );

    inst_arbiter_instr: arbiter_instruction
    generic map(
        block_size      => 32,
        addr_w          => 10,
        num_of_cores    => 2
    )
    port map(
        refill                  => refill_s, 
        mem_addr                => mem_addr_s,
        instruction_from_bus    => instruction_from_bus_s,

        instruction_from_mem    => instruction_from_mem_s,
        instruction_addr        => instruction_addr_s,
        instruction_rd          => instruction_rd_s,
        read_from_bus           => read_from_bus_s
    );


    inst_mem_instruction: mem_instruction
    generic map(
        block_size      => 32,
        word_size       => 32,
        addr_size       => 10,
        size            => 1024
    )
    port map(
        clk                 => clk,
        wr                  => wr,
        en                  => instruction_rd_s,
        addr                => instruction_addr_s,
        instruction_o       => instruction_from_mem_s,
        instruction_i       => instruction_from_bus_s,
        wr_top              => wr_top,
        en_top              => en_top,
        addr_top            => addr_top,
        instruction_top_o   => instruction_top_o,
        instruction_top_i   => instruction_top_i
    );


    inst_cores: for i in 0 to num_of_cores-1 generate
        core_inst: core
        generic map(
            addr_w          => 10,
            word_size       => 32,
            block_size      => 32,
            init_pc_val     => i*100
        )
        port map(
            clk             => clk,
            reset           => reset, 
            data_to_bus     => data_from_core_s((i+1)* word_size - 1 downto i*word_size),
            data_from_bus   => data_to_core_s,
            bus_addr_o      => bus_addr_is((i+1)* addr_w - 1 downto i*addr_w),
            bus_addr_i      => bus_addr_os,
            busrd_i         => busrd_os(i),
            busupd_i        => busupd_os(i),
            --flush_i         => ,
            --update_i        => ,
            cache_i         => cache_os(i),
            key_to_bus      => key_to_bus(i),
            cache_o         => cache_is(i),
            busrd_o         => busrd_is(i),
            busupd_o        => busupd_is(i),
            flush_o         => flush_is(i),
            update_o        => update_is(i),
            send_to_mem_o   => send_to_mem_is(i),
            lock_arbiter_o  => lock_arbiter_is(i),
            refill                  => refill_s(i),    
            mem_addr                => mem_addr_s((i+1)* addr_w - 1 downto i*addr_w),
            instruction_from_bus    => instruction_from_bus_s,
            read_from_bus           => read_from_bus_s(i)
            );
         end generate;   
end architecture;