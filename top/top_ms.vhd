library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity top_ms is
    generic (
        num_of_cores    : integer := 2
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
        src_cache_i     : in std_logic_vector(num_of_cores - 1 downto 0)
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
        read_from_mem   : in std_logic; -- read signal
        addr            : in std_logic_vector(addr_size - 1 downto 0);
        instruction_o   : out std_logic_vector(block_size - 1 downto 0)    
    );
    end component;
begin


end Behavioral;