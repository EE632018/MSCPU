library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_cache_data is
    generic(
        loc_bits        : integer := 6; -- 64 entries
        offset_bits     : integer := 2; -- to choose one of four words
        word_size       : integer := 32; -- word size 
        addr_w          : integer := 10
    );

    --  Port ( );
end tb_cache_data;
    
architecture Behavioral of tb_cache_data is

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
        send_to_mem_o   : out std_logic;
        stall_a         : in std_logic;
        data_loc        : in std_logic_vector(loc_bits-1 downto 0); -- data_loc selection
        data_loc_bus_i  : in std_logic_vector(loc_bits-1 downto 0);
       
        data_from_bus   : in std_logic_vector(word_size - 1 downto 0);  -- data from memory
        data_from_proc  : in std_logic_vector(word_size - 1 downto 0); -- data from processor
        data_to_bus     : out std_logic_vector(word_size - 1 downto 0); -- evicted block data in case of a write miss
        
        data_to_proc    : out std_logic_vector(word_size - 1 downto 0); -- data to processor
        data_to_mem     : out std_logic_vector(word_size - 1 downto 0)
        
    );
    end component;

    signal clk_s            : std_logic;
    signal reset_s          : std_logic;
    signal cache_is         : std_logic;
    signal prrd_is          : std_logic;
    signal prrdmiss_is      : std_logic;
    signal prwr_is          : std_logic;
    signal prwrmiss_is      : std_logic;
    signal busrd_is         : std_logic;
    signal busupd_is        : std_logic;
    signal busrd_os         : std_logic;
    signal busupd_os        : std_logic;
    signal flush_os         : std_logic;
    signal update_os        : std_logic;
    signal send_to_mem_os   : std_logic;
    signal stall_as         : std_logic;
    signal data_loc_s       : std_logic_vector(loc_bits-1 downto 0);
    signal data_loc_bus_is  : std_logic_vector(loc_bits-1 downto 0);
    signal data_from_bus_s  : std_logic_vector(word_size-1 downto 0);
    signal data_from_proc_s : std_logic_vector(word_size - 1 downto 0);
    signal data_to_bus_s    : std_logic_vector(word_size - 1 downto 0);
    signal addr_from_bus_s  : std_logic_vector(addr_w - 1 downto 0);
    signal data_to_proc_s   : std_logic_vector(word_size - 1 downto 0);
    signal data_to_mem_s    : std_logic_vector(word_size - 1 downto 0);

begin

    dut_i: cache_data
    generic map(
        loc_bits    => loc_bits,
        offset_bits => offset_bits,
        word_size   => word_size,
        addr_w      => addr_w      
    )
    port map(
        clk             => clk_s,
        reset           => reset_s,
        cache_i         => cache_is,
        prrd_i          => prrd_is,
        prrdmiss_i      => prrdmiss_is,
        prwr_i          => prwr_is,
        prwrmiss_i      => prwrmiss_is,
        busrd_i         => busrd_is,
        busupd_i        => busupd_is,
        busrd_o         => busrd_os,
        busupd_o        => busupd_os,
        flush_o         => flush_os,
        update_o        => update_os,
        send_to_mem_o   => send_to_mem_os,
        --offset          => (others => '0'),
        stall_a         => stall_as,
        data_loc        => data_loc_s,
        data_loc_bus_i  => data_loc_bus_is, 
        data_from_bus   => data_from_bus_s,
        data_from_proc  => data_from_proc_s,
        data_to_bus     => data_to_bus_s,
        --addr_from_bus   => addr_from_bus_s,
        data_to_proc    => data_to_proc_s,
        data_to_mem     => data_to_mem_s   
    );

    process
    begin
        clk_s <= '1', '0' after 100 ns;
        wait for 200 ns;
    end process;

    process
    begin
        reset_s             <= '0';
        stall_as            <= '0';
        cache_is            <= '0';
        prrd_is             <= '0';
        prrdmiss_is         <= '0';
        prwr_is             <= '0';
        prwrmiss_is         <= '0';
        busrd_is            <= '0';
        busupd_is           <= '0';
        data_loc_s          <= std_logic_vector(TO_UNSIGNED(0,6));
        data_loc_bus_is     <= std_logic_vector(TO_UNSIGNED(0,6));
        data_from_bus_s     <= std_logic_vector(TO_UNSIGNED(0,32));    
        data_from_proc_s    <= std_logic_vector(TO_UNSIGNED(0,32));    
        --addr_from_bus_s     <= std_logic_vector(TO_UNSIGNED(0,10));    
        wait until rising_edge(clk_s);
        reset_s             <= '1';
        stall_as            <= '1';
        cache_is            <= '0';
        prrd_is             <= '1';
        prrdmiss_is         <= '0';
        prwr_is             <= '0';
        prwrmiss_is         <= '0';
        busrd_is            <= '0';
        busupd_is           <= '0';
        data_loc_s          <= std_logic_vector(TO_UNSIGNED(32,6));
        data_loc_bus_is     <= std_logic_vector(TO_UNSIGNED(12,6));
        data_from_bus_s     <= std_logic_vector(TO_UNSIGNED(432,32));    
        data_from_proc_s    <= std_logic_vector(TO_UNSIGNED(234,32));    
        --addr_from_bus_s     <= std_logic_vector(TO_UNSIGNED(32,10)); 
        wait until rising_edge(clk_s);  
        reset_s             <= '1';
        stall_as            <= '1';
        cache_is            <= '0';
        prrd_is             <= '0';
        prrdmiss_is         <= '1';
        prwr_is             <= '0';
        prwrmiss_is         <= '0';
        busrd_is            <= '0';
        busupd_is           <= '0';
        data_loc_s          <= std_logic_vector(TO_UNSIGNED(33,6));
        data_loc_bus_is     <= std_logic_vector(TO_UNSIGNED(12,6));
        data_from_bus_s     <= std_logic_vector(TO_UNSIGNED(432,32));    
        data_from_proc_s    <= std_logic_vector(TO_UNSIGNED(234,32)); 
        wait until rising_edge(clk_s);
        reset_s             <= '1';
        stall_as            <= '1';
        cache_is            <= '0';
        prrd_is             <= '0';
        prrdmiss_is         <= '0';
        prwr_is             <= '1';
        prwrmiss_is         <= '0';
        busrd_is            <= '0';
        busupd_is           <= '0';
        data_loc_s          <= std_logic_vector(TO_UNSIGNED(33,6));
        data_loc_bus_is     <= std_logic_vector(TO_UNSIGNED(12,6));
        data_from_bus_s     <= std_logic_vector(TO_UNSIGNED(432,32));    
        data_from_proc_s    <= std_logic_vector(TO_UNSIGNED(234,32)); 
        wait until rising_edge(clk_s); 
        reset_s             <= '1';
        stall_as            <= '1';
        cache_is            <= '0';
        prrd_is             <= '0';
        prrdmiss_is         <= '0';
        prwr_is             <= '0';
        prwrmiss_is         <= '0';
        busrd_is            <= '1';
        busupd_is           <= '0';
        data_loc_s          <= std_logic_vector(TO_UNSIGNED(33,6));
        data_loc_bus_is     <= std_logic_vector(TO_UNSIGNED(33,6));
        data_from_bus_s     <= std_logic_vector(TO_UNSIGNED(432,32));    
        data_from_proc_s    <= std_logic_vector(TO_UNSIGNED(234,32)); 
        wait until rising_edge(clk_s);  
        reset_s             <= '1';
        stall_as            <= '1';
        cache_is            <= '0';
        prrd_is             <= '0';
        prrdmiss_is         <= '0';
        prwr_is             <= '0';
        prwrmiss_is         <= '0';
        busrd_is            <= '0';
        busupd_is           <= '1';
        data_loc_s          <= std_logic_vector(TO_UNSIGNED(33,6));
        data_loc_bus_is     <= std_logic_vector(TO_UNSIGNED(12,6));
        data_from_bus_s     <= std_logic_vector(TO_UNSIGNED(432,32));    
        data_from_proc_s    <= std_logic_vector(TO_UNSIGNED(234,32)); 
        wait until rising_edge(clk_s);  
        reset_s             <= '1';
        stall_as            <= '1';
        cache_is            <= '1';
        prrd_is             <= '0';
        prrdmiss_is         <= '0';
        prwr_is             <= '1';
        prwrmiss_is         <= '0';
        busrd_is            <= '0';
        busupd_is           <= '0';
        data_loc_s          <= std_logic_vector(TO_UNSIGNED(33,6));
        data_loc_bus_is     <= std_logic_vector(TO_UNSIGNED(33,6));
        data_from_bus_s     <= std_logic_vector(TO_UNSIGNED(432,32));    
        data_from_proc_s    <= std_logic_vector(TO_UNSIGNED(234,32)); 
        wait until rising_edge(clk_s);  
        wait;
    end process;

end Behavioral;