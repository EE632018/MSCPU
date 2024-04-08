library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity core is
    port (
        clk     : in std_logic;
        reset   : in std_logic;
    );
end core;

architecture Behavioral of core is

    --instance of component

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
            data_mem_we_o       : out std_logic_vector(3 downto 0)
        );  
    end component;

    component top_data_cache is
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
    end component;

    component top_instruction_cache is
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
    end component;

    signal instruction_addr_s, data_addr_s, rdata_s, wdata_s, rinstrction_s : std_logic_vector(31 downto 0);
    signal rd_s : std_logic;
    signal we_s : std_logic_vector(3 downto 0);
begin


    inst_rv: TOP_RISCV
    port map(
            -- Globalna sinhronizacija
            clk                 => clk,
            reset               => reset,
            -- Interfejs ka memoriji za instrukcije
            instr_mem_address_o => instruction_addr_s, 
            instr_mem_read_i    => rinstrction_s,
            -- Interfejs ka memoriji za podatke
            data_mem_address_o  => data_addr_s,
            data_mem_read_i     => rdata_s,
            data_mem_write_o    => wdata_s,
            data_mem_we_o       => we_s,
        );
    
    inst_L1_data: top_data_cache
    port map(
            clk                 => clk,
            reset               => reset,
            addr                => data_addr_s,
            rdata               => rdata_s,
            wdata               => wdata_s,
            flush               => '0',
            rd                  => rd_s,
            wr                  => we_s(0),
            stall               => open,
            rd_rdy              => open,
            hit                 => open,
            miss                => open,
            cache_state         => open
        );

    inst_L1_instruction: top_instruction_cache
    port map(   
            clk                 => clk,
            reset               => reset,
            addr                => instruction_addr_s,
            rinstruction        => rinstrction_s,
            flush               => '0',
            rd                  => '1',
            stall               => open,
            rd_rdy              => open,
            hit                 => open
    );

end Behavioral;