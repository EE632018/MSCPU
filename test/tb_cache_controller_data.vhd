library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_cache_controller_data is
    generic(
        index_bits      : integer := 4;
        set_offset_bits : integer := 2;
        tag_bits        : integer := 6;
        addr_w          : integer := 10
    );

    --  Port ( );
end tb_cache_controller_data;
    
architecture Behavioral of tb_cache_controller_data is

    component cache_controller 
    generic(
        index_bits      : integer := 4;
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
        stall_a     : in std_logic;

        -- Signals to cache
        data_loc        : out std_logic_vector(index_bits + set_offset_bits - 1 downto 0);
        data_loc_bus_o  : out std_logic_vector(index_bits + set_offset_bits - 1 downto 0);
        cache_o         : out std_logic; -- there is this value in other cache
        prrd_o          : out std_logic;
        prrdmiss_o      : out std_logic;
        prwr_o          : out std_logic;
        prwrmiss_o      : out std_logic;
        src_cache_o     : out std_logic -- pretraga cache koja mi kaze kada da drugi pogledaju

    );
    end component;

    signal clk_s            : std_logic;
    signal reset_s          : std_logic;
    signal proc_rd_s        : std_logic;
    signal proc_wr_s        : std_logic;
    signal proc_addr_s      : std_logic_vector(addr_w - 1 downto 0);
    signal bus_addr_os      : std_logic_vector(addr_w - 1 downto 0);
    signal bus_addr_is      : std_logic_vector(addr_w - 1 downto 0);
    signal stall_s          : std_logic;
    signal stall_as         : std_logic;
    signal data_loc_s       : std_logic_vector(index_bits + set_offset_bits - 1 downto 0);
    signal data_loc_bus_os  : std_logic_vector(index_bits + set_offset_bits - 1 downto 0);
    signal cache_os         : std_logic;
    signal prrd_os          : std_logic;
    signal prrdmiss_os      : std_logic;
    signal prwr_os          : std_logic;
    signal prwrmiss_os      : std_logic;
    signal src_cache_os     : std_logic;

begin

    dut_i: cache_controller
    generic map(
        index_bits      => index_bits,
        set_offset_bits => set_offset_bits,
        tag_bits        => tag_bits,
        addr_w          => addr_w
    )
    port map(
        clk                 => clk_s,
        reset               => reset_s,
        proc_rd             => proc_rd_s,
        proc_wr             => proc_wr_s,
        proc_addr           => proc_addr_s,
        bus_addr_o          => bus_addr_os,
        bus_addr_i          => bus_addr_is,
        stall               => stall_s,
        stall_a             => stall_as,
        data_loc            => data_loc_s,
        data_loc_bus_o      => data_loc_bus_os,
        cache_o             => cache_os,
        prrd_o              => prrd_os,
        prrdmiss_o          => prrdmiss_os,
        prwr_o              => prwr_os,
        prwrmiss_o          => prwrmiss_os,
        src_cache_o         => src_cache_os
    );

    process
    begin
        clk_s <= '1', '0' after 100 ns;
        wait for 200 ns;
    end process;

    process
    begin
        reset_s     <= '0';
        proc_rd_s   <= '0';
        proc_wr_s   <= '0';
        proc_addr_s <= (others => '0');
        bus_addr_is <= (others => '0');
        stall_as    <= '0';
        wait until rising_edge(clk_s);
        wait until rising_edge(clk_s);
        reset_s     <= '1';
        proc_rd_s   <= '1';
        proc_wr_s   <= '0';
        proc_addr_s <= std_logic_vector(to_unsigned(555,10));
        bus_addr_is <= std_logic_vector(to_unsigned(0,10));
        stall_as    <= '1';
        wait until rising_edge(clk_s);
        wait until rising_edge(clk_s);
        reset_s     <= '1';
        proc_rd_s   <= '1';
        proc_wr_s   <= '0';
        proc_addr_s <= std_logic_vector(to_unsigned(571,10));
        bus_addr_is <= std_logic_vector(to_unsigned(554,10));
        stall_as    <= '1';
        wait until rising_edge(clk_s);
        wait until rising_edge(clk_s);
        reset_s     <= '1';
        proc_rd_s   <= '1';
        proc_wr_s   <= '0';
        proc_addr_s <= std_logic_vector(to_unsigned(811,10));
        bus_addr_is <= std_logic_vector(to_unsigned(555,10));
        stall_as    <= '1';
        wait until rising_edge(clk_s);
        wait until rising_edge(clk_s);
        reset_s     <= '1';
        proc_rd_s   <= '1';
        proc_wr_s   <= '0';
        proc_addr_s <= std_logic_vector(to_unsigned(635,10));
        bus_addr_is <= std_logic_vector(to_unsigned(553,10));
        stall_as    <= '1';
                wait until rising_edge(clk_s);
                wait until rising_edge(clk_s);
        reset_s     <= '1';
        proc_rd_s   <= '1';
        proc_wr_s   <= '0';
        proc_addr_s <= std_logic_vector(to_unsigned(11,10));
        bus_addr_is <= std_logic_vector(to_unsigned(555,10));
        stall_as    <= '1';
        wait until rising_edge(clk_s);
        wait until rising_edge(clk_s);
        reset_s     <= '1';
        proc_rd_s   <= '1';
        proc_wr_s   <= '0';
        proc_addr_s <= std_logic_vector(to_unsigned(554,10));
        bus_addr_is <= std_logic_vector(to_unsigned(553,10));
        stall_as    <= '1';
                wait until rising_edge(clk_s);
                wait until rising_edge(clk_s);
        reset_s     <= '1';
        proc_rd_s   <= '1';
        proc_wr_s   <= '0';
        proc_addr_s <= std_logic_vector(to_unsigned(553,10));
        bus_addr_is <= std_logic_vector(to_unsigned(555,10));
        stall_as    <= '1';
        wait until rising_edge(clk_s);
        wait until rising_edge(clk_s);
        reset_s     <= '1';
        proc_rd_s   <= '1';
        proc_wr_s   <= '0';
        proc_addr_s <= std_logic_vector(to_unsigned(552,10));
        bus_addr_is <= std_logic_vector(to_unsigned(553,10));
        stall_as    <= '1';
                wait until rising_edge(clk_s);
                wait until rising_edge(clk_s);
        reset_s     <= '1';
        proc_rd_s   <= '1';
        proc_wr_s   <= '0';
        proc_addr_s <= std_logic_vector(to_unsigned(551,10));
        bus_addr_is <= std_logic_vector(to_unsigned(555,10));
        stall_as    <= '1';
        wait until rising_edge(clk_s);
        wait until rising_edge(clk_s);
        reset_s     <= '1';
        proc_rd_s   <= '1';
        proc_wr_s   <= '0';
        proc_addr_s <= std_logic_vector(to_unsigned(550,10));
        bus_addr_is <= std_logic_vector(to_unsigned(553,10));
        stall_as    <= '1';
        wait;
    end process;

end Behavioral;