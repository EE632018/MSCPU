library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_top is
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

end cache_top;

architecture Behavioral of cache_top is 

    component cache_data
    generic(
        loc_bits        : integer := 6; -- 64 entries
        offset_bits     : integer := 2; -- to choose one of four words
        word_size       : integer := 32; -- word size 
        addr_w          : integer := 10
    );
    port(
        clk             : in std_logic; -- same as processor
        reset           : in std_logic;

        refill          : in std_logic;
        -- address location internal and external
        data_loc        : in std_logic_vector(5 downto 0);
        data_loc_bus_o  : in std_logic_vector(5 downto 0);

        -- data
        data_to_bus     : out std_logic_vector(word_size - 1 downto 0);
        data_from_bus   : in std_logic_vector(word_size - 1 downto 0);
        data_to_proc    : out std_logic_vector(word_size - 1 downto 0);
        data_from_proc  : in std_logic_vector(word_size - 1 downto 0);

        -- processor side request
        prrd_i          : in std_logic;
        prrdmiss_i      : in std_logic;
        prwr_i          : in std_logic;
        prwrmiss_i      : in std_logic;
        -- bus side request
        busrd_i         : in std_logic;
        busupd_i        : in std_logic;
        flush_i         : in std_logic;
        update_i        : in std_logic
    );
    end component;

    component cache_controller
    generic(
        index_bits      : integer := 4; -- bits used for sets, I have 64 enteries in cache separeted in 4 way, so 16 sets
        set_offset_bits : integer := 2; -- Each of sets has 4 lines that covers 16*4=64
        tag_bits        : integer := 6; -- Address is 10 bits so tag is 10 - 4 = 6
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
        refill      : out std_logic;

        -- Signals to cache
        data_loc        : out std_logic_vector(5 downto 0);
        data_loc_bus_o  : out std_logic_vector(5 downto 0);
        -- signali za dragon FSM
        cache_o         : out std_logic; -- there is this value in other cache
        prrd_o          : out std_logic;
        prrdmiss_o      : out std_logic;
        prwr_o          : out std_logic;
        prwrmiss_o      : out std_logic;
        busrd_o         : out std_logic;
        busupd_o        : out std_logic;
        flush_o         : out std_logic;
        update_o        : out std_logic;
        send_to_mem_o   : out std_logic;
        -- OVO je od strane drugog kora poslato 
        busrd_i         : in std_logic;
        busupd_i        : in std_logic;
        cache_i         : in std_logic;
        --src_cache_o     : out std_logic; -- pretraga cache koja mi kaze kada da drugi pogledaju

        key_to_bus      : in std_logic; -- zakljucavanje magistrale od strane datog kontrolera
        lock_arbiter_o  : out std_logic
    );
    end component;

    signal refill_s : std_logic;
    signal prrd_s, prrdmiss_s, prwr_s, prwrmiss_s : std_logic;
    signal data_loc_s, data_loc_bus_s : std_logic_vector(5 downto 0);
    signal busrd_s, busupd_s, flush_s, update_s : std_logic;

begin


    inst_cache_data: cache_data
    generic map(
        loc_bits        => 6, 
        offset_bits     => 2, 
        word_size       => 32,  
        addr_w          => 10
    )
    port map(
        clk             => clk,
        reset           => reset,

        refill          => refill_s,
        -- address location internal and external
        data_loc        => data_loc_s,
        data_loc_bus_o  => data_loc_bus_s,

        -- data
        data_to_bus     => data_to_bus,
        data_from_bus   => data_from_bus,
        data_to_proc    => data_to_proc, 
        data_from_proc  => data_from_proc,

        -- processor side request
        prrd_i          => prrd_s,
        prrdmiss_i      => prrdmiss_s,
        prwr_i          => prwr_s,
        prwrmiss_i      => prwrmiss_s,
        -- bus side request
        busrd_i         => busrd_i,
        busupd_i        => busupd_i,
        flush_i         => flush_s,
        update_i        => update_s
    );


    inst_cache_controller: cache_controller
    generic map(
        index_bits      => 4, -- bits used for sets, I have 64 enteries in cache separeted in 4 way, so 16 sets
        set_offset_bits => 2, -- Each of sets has 4 lines that covers 16*4=64
        tag_bits        => 6, -- Address is 10 bits so tag is 10 - 4 = 6
        addr_w          => 10
    )
    port map(
        clk         => clk,
        reset       => reset,

        -- Signals from/to processor
        proc_rd     => proc_rd,
        proc_wr     => proc_wr,
        proc_addr   => proc_addr,
        bus_addr_o  => bus_addr_o,
        bus_addr_i  => bus_addr_i,
        stall       => stall,
        refill      => refill_s,

        -- Signals to cache
        data_loc        => data_loc_s,
        data_loc_bus_o  => data_loc_bus_s,
        -- signali za dragon FSM
        cache_o         => cache_o, 
        prrd_o          => prrd_s,
        prrdmiss_o      => prrdmiss_s,
        prwr_o          => prwr_s,
        prwrmiss_o      => prwrmiss_s,
        busrd_o         => busrd_o,
        busupd_o        => busupd_o,
        flush_o         => flush_s,
        update_o        => update_s,
        send_to_mem_o   => send_to_mem_o,
        -- OVO je od strane drugog kora poslato 
        busrd_i         => busrd_i,
        busupd_i        => busupd_i,
        cache_i         => cache_i,
        --src_cache_o     : out std_logic; -- pretraga cache koja mi kaze kada da drugi pogledaju

        key_to_bus      => key_to_bus, -- zakljucavanje magistrale od strane datog kontrolera
        lock_arbiter_o  => lock_arbiter_o
    );

    flush_o <= flush_s;
    update_o <= update_s;
end Behavioral;