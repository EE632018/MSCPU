library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_dragon_fsm is
    --  Port ( );
end tb_dragon_fsm;
    
architecture Behavioral of tb_dragon_fsm is
    
    component dragon_fsm
        port(
            clk             : in std_logic; -- same as processor
            reset           : in std_logic;
            cache_i         : in std_logic; -- there is this value in other cache
            prrd_i          : in std_logic;
            prrdmiss_i      : in std_logic;
            prwr_i          : in std_logic;
            prwrmiss_i      : in std_logic;
            busrd_i         : in std_logic;
            busupd_i        : in std_logic;
            stall_a         : in std_logic;
            busrd_o         : out std_logic;
            busupd_o        : out std_logic;
            flush_o         : out std_logic;
            update_o        : out std_logic;
            send_to_mem_o   : out std_logic
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
    signal stall_as         : std_logic;
    signal busrd_os         : std_logic;
    signal busupd_os        : std_logic;
    signal flush_os         : std_logic;
    signal update_os        : std_logic;
    signal send_to_mem_os   : std_logic;

begin


    dut_test: dragon_fsm
    port map (
        clk             => clk_s, -- same as processor
        reset           => reset_s,
        cache_i         => cache_is, -- there is this value in other cache
        prrd_i          => prrd_is,
        prrdmiss_i      => prrdmiss_is,
        prwr_i          => prwr_is,
        prwrmiss_i      => prwrmiss_is,
        busrd_i         => busrd_is,
        busupd_i        => busupd_is,
        stall_a         => stall_as,
        busrd_o         => busrd_os,
        busupd_o        => busupd_os,
        flush_o         => flush_os,
        update_o        => update_os,
        send_to_mem_o   => send_to_mem_os
    );

    process
    begin
        clk_s <= '1', '0' after 100 ns;
        wait for 200 ns;
    end process;


    process
    begin
        reset_s         <= '0';
        cache_is        <= '0';
        prrd_is         <= '0';
        prrdmiss_is     <= '0';
        prwr_is         <= '0';
        prwrmiss_is     <= '0';
        busrd_is        <= '0';
        busupd_is       <= '0';
        stall_as        <= '0';
        wait until rising_edge(clk_s); -- 
        reset_s         <= '1';
        stall_as        <= '1';
        cache_is        <= '0';
        prrd_is         <= '1';
        prrdmiss_is     <= '0';
        prwr_is         <= '0';
        prwrmiss_is     <= '0';
        busrd_is        <= '0';
        busupd_is       <= '0';
        wait until rising_edge(clk_s); --
        reset_s         <= '1';
        stall_as        <= '1';
        cache_is        <= '0';
        prrd_is         <= '0';
        prrdmiss_is     <= '0';
        prwr_is         <= '1';
        prwrmiss_is     <= '0';
        busrd_is        <= '0';
        busupd_is       <= '0';
        wait until rising_edge(clk_s); --
        reset_s         <= '1';
        stall_as        <= '1';
        cache_is        <= '0';
        prrd_is         <= '0';
        prrdmiss_is     <= '0';
        prwr_is         <= '0';
        prwrmiss_is     <= '0';
        busrd_is        <= '1';
        busupd_is       <= '0';
        wait until rising_edge(clk_s); -- Go to E state
        reset_s         <= '1';
        stall_as        <= '1';
        cache_is        <= '0';
        prrd_is         <= '0';
        prrdmiss_is     <= '1';
        prwr_is         <= '0';
        prwrmiss_is     <= '0';
        busrd_is        <= '0';
        busupd_is       <= '0';
        wait until rising_edge(clk_s); -- stay in E
        stall_as        <= '1';
        cache_is        <= '0';
        prrd_is         <= '1';
        prrdmiss_is     <= '0';
        prwr_is         <= '0';
        prwrmiss_is     <= '0';
        busrd_is        <= '0';
        busupd_is       <= '0';
        wait until rising_edge(clk_s); -- go to state Sc
        stall_as        <= '1';
        cache_is        <= '0';
        prrd_is         <= '0';
        prrdmiss_is     <= '0';
        prwr_is         <= '0';
        prwrmiss_is     <= '0';
        busrd_is        <= '1';
        busupd_is       <= '0';
        wait until rising_edge(clk_s); -- go to state Sm
        stall_as        <= '1';
        cache_is        <= '0';
        prrd_is         <= '0';
        prrdmiss_is     <= '0';
        prwr_is         <= '1';
        prwrmiss_is     <= '0';
        busrd_is        <= '0';
        busupd_is       <= '0';
        wait until rising_edge(clk_s); -- Other proccessor needs value go to Sm
        stall_as        <= '1';
        cache_is        <= '1';
        prrd_is         <= '0';
        prrdmiss_is     <= '0';
        prwr_is         <= '0';
        prwrmiss_is     <= '0';
        busrd_is        <= '1';
        busupd_is       <= '0';
        wait until rising_edge(clk_s); -- Other processor changed value go to Sm state
        stall_as        <= '1';
        cache_is        <= '0';
        prrd_is         <= '0';
        prrdmiss_is     <= '0';
        prwr_is         <= '1';
        prwrmiss_is     <= '0';
        busrd_is        <= '0';
        busupd_is       <= '0';    
        wait until rising_edge(clk_s); -- Other processor changed value go to Sm state
        stall_as        <= '1';
        cache_is        <= '1';
        prrd_is         <= '0';
        prrdmiss_is     <= '0';
        prwr_is         <= '1';
        prwrmiss_is     <= '0';
        busrd_is        <= '0';
        busupd_is       <= '0';    
        wait;
    end process;
end Behavioral;