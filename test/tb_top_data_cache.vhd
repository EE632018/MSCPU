library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity tb_top_data_cache is
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
        word_size       : integer := 32
        );
--  Port ( );
end tb_top_data_cache;

architecture Behavioral of tb_top_data_cache is

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
        word_size       : integer := 32
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
        send_to_mem_o   : out std_logic;
        data_from_bus   : in std_logic_vector(word_size - 1 downto 0);  -- data from memory
        data_from_proc  : in std_logic_vector(word_size - 1 downto 0); -- data from processor
        data_to_bus     : out std_logic_vector(word_size - 1 downto 0); -- evicted block data in case of a write miss
        data_to_proc    : out std_logic_vector(word_size - 1 downto 0); -- data to processor
        data_to_mem     : out std_logic_vector(word_size - 1 downto 0);
        -- cache controller
        proc_rd         : in std_logic;
        proc_wr         : in std_logic;
        proc_addr       : in std_logic_vector(addr_w - 1 downto 0);
        bus_addr_o      : out std_logic_vector(addr_w - 1 downto 0);
        bus_addr_i      : in std_logic_vector(addr_w - 1 downto 0);
        stall           : out std_logic;
        stall_a         : in std_logic;
        cache_o         : out std_logic;
        src_cache_o     : out std_logic
    );
    end component;

    signal clk_s            : std_logic;
    signal reset_s          : std_logic;
    signal cache_is         : std_logic;
    signal busrd_is         : std_logic;
    signal busupd_is        : std_logic;
    signal busrd_os         : std_logic;
    signal busupd_os        : std_logic;
    signal flush_os         : std_logic;
    signal update_os        : std_logic;
    signal send_to_mem_os   : std_logic;
    signal data_from_bus_s  : std_logic_vector(word_size - 1 downto 0);  -- data from memory
    signal data_from_proc_s : std_logic_vector(word_size - 1 downto 0); -- data from processor
    signal data_to_bus_s    : std_logic_vector(word_size - 1 downto 0); -- evicted block data in case of a write miss
    signal data_to_proc_s   : std_logic_vector(word_size - 1 downto 0); -- data to processor
    signal data_to_mem_s    : std_logic_vector(word_size - 1 downto 0);
    signal proc_rd_s        : std_logic;
    signal proc_wr_s        : std_logic;
    signal proc_addr_s      : std_logic_vector(addr_w - 1 downto 0);
    signal bus_addr_os      : std_logic_vector(addr_w - 1 downto 0);
    signal bus_addr_is      : std_logic_vector(addr_w - 1 downto 0);
    signal stall_s          : std_logic;
    signal stall_as         : std_logic;
    signal cache_os         : std_logic;
    signal src_cache_os     : std_logic;


begin

    dut_inst: top_data_cache
    generic map(
        data_bus_w      => data_bus_w,
        addr_bus_w      => addr_bus_w,
        index_bits      => index_bits,
        tag_bits        => tag_bits,
        set_offset_bits => set_offset_bits,
        loc_bits        => loc_bits,
        offset_bits     => offset_bits,
        addr_w          => addr_w,
        word_size       => word_size
    )
    port map(
        clk             => clk_s,
        reset           => reset_s,
        cache_i         => cache_is,
        busrd_i         => busrd_is,
        busupd_i        => busupd_is,
        busrd_o         => busrd_os,
        busupd_o        => busupd_os,
        flush_o         => flush_os,
        update_o        => update_os,
        send_to_mem_o   => send_to_mem_os,
        data_from_bus   => data_from_bus_s,
        data_from_proc  => data_from_proc_s,
        data_to_bus     => data_to_bus_s,
        data_to_proc    => data_to_proc_s,
        data_to_mem     => data_to_mem_s,
        proc_rd         => proc_rd_s,
        proc_wr         => proc_wr_s,
        proc_addr       => proc_addr_s,
        bus_addr_o      => bus_addr_os,
        bus_addr_i      => bus_addr_is,
        stall           => stall_s,
        stall_a         => stall_as,
        cache_o         => cache_os,
        src_cache_o     => src_cache_os
    );


    process
    begin
        clk_s <= '1', '0' after 100 ns;
        wait for 200 ns;
    end process;

    process
    begin
        reset_s             <= '1';
        cache_is            <= '0';
        busrd_is            <= '0';
        busupd_is           <= '0';
        data_from_bus_s     <= std_logic_vector(to_unsigned(0,32));
        data_from_proc_s    <= std_logic_vector(to_unsigned(0,32));
        proc_rd_s           <= '0';
        proc_wr_s           <= '0';
        proc_addr_s         <= std_logic_vector(to_unsigned(0,10));
        bus_addr_is         <= std_logic_vector(to_unsigned(0,10));
        stall_as            <= '0';
        wait until rising_edge(clk_s);
        reset_s             <= '0';
        cache_is            <= '0';
        busrd_is            <= '0';
        busupd_is           <= '0';
        data_from_bus_s     <= std_logic_vector(to_unsigned(1024,32));
        data_from_proc_s    <= std_logic_vector(to_unsigned(1024,32));
        proc_rd_s           <= '1';
        proc_wr_s           <= '0';
        proc_addr_s         <= std_logic_vector(to_unsigned(555,10));
        bus_addr_is         <= std_logic_vector(to_unsigned(0,10));
        stall_as            <= '1';
        wait until rising_edge(clk_s);
        reset_s             <= '0';
        cache_is            <= '0';
        busrd_is            <= '0';
        busupd_is           <= '0';
        data_from_bus_s     <= std_logic_vector(to_unsigned(1024,32));
        data_from_proc_s    <= std_logic_vector(to_unsigned(1024,32));
        proc_rd_s           <= '1';
        proc_wr_s           <= '0';
        proc_addr_s         <= std_logic_vector(to_unsigned(555,10));
        bus_addr_is         <= std_logic_vector(to_unsigned(0,10));
        stall_as            <= '1';
        wait until rising_edge(clk_s);
        wait;
    end process;

end Behavioral;
