library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity cache_data is
    generic(
        loc_bits        : integer := 4; -- 16 entries
        offset_bits     : integer := 2; -- to choose one of four words
        block_size      : integer := 128; -- 32*4 
        mem_word_size   : integer := 32; -- word size of memory
        proc_word_size  : integer := 32; -- word size of processor
        blk_0_offset    : integer := 127; -- cache block --> | blk0 | blk1 | blk2 | blk3
        blk_1_offset    : integer := 95;
        blk_2_offset    : integer := 63;
        blk_3_offset    : integer := 31
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
        data_loc        : in std_logic_vector(loc_bits-1 downto 0); -- data_loc selection
        data_loc_bus_i  : in std_logic_vector(3 downto 0);
        offset          : in std_logic_vector(offset_bits-1 downto 0); -- offset selection
        
        data_from_bus   : in std_logic_vector(31 downto 0);  -- data from memory
        data_from_proc  : in std_logic_vector(31 downto 0); -- data from processor
        data_to_bus     : out std_logic_vector(31 downto 0); -- evicted block data in case of a write miss
        addr_from_bus   : in std_logic_vector(9 downto 0);
        data_to_proc    : out std_logic_vector(31 downto 0) -- data to processor
    );
end cache_data;

architecture Behavioral of cache_data is 

type ram is array (0 to 2**(loc_bits+offset_bits) - 1) of std_logic_vector(mem_word_size-1 downto 0);

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
    busrd_o         : out std_logic;
    busupd_o        : out std_logic;
    flush_o         : out std_logic;
    update_o        : out std_logic
);
end component;

type cache_cnt is array (0 to 2**(loc_bits+offset_bits) - 1) of std_logic;

signal cache_is         : cache_cnt; 
signal prrd_is          : cache_cnt;
signal prrdmiss_is      : cache_cnt;
signal prwr_is          : cache_cnt;
signal prwrmiss_is      : cache_cnt;
signal busrd_is         : cache_cnt;
signal busupd_is        : cache_cnt;
signal busrd_os         : cache_cnt;
signal busupd_os        : cache_cnt;
signal flush_os         : cache_cnt;
signal update_os        : cache_cnt;

signal cache : ram := (others => (others => '0'));

signal pos0 : std_logic_vector(loc_bits+offset_bits-1 downto 0); -- postion 0
signal pos0_bus : std_logic_vector(loc_bits+offset_bits-1 downto 0);
signal pos1 : std_logic_vector(loc_bits+offset_bits-1 downto 0); -- postion 1
signal pos2 : std_logic_vector(loc_bits+offset_bits-1 downto 0); -- postion 2
signal pos3 : std_logic_vector(loc_bits+offset_bits-1 downto 0); -- postion 3
signal pos4 : std_logic_vector(loc_bits+offset_bits-1 downto 0); -- postion 4

begin

    dragon_fsm_inst: for i in 0 to 2**loc_bits+offset_bits - 1 generate
        dragon_fsm_i : dragon_fsm
            port map(
                clk             => clk,
                reset           => reset,
                cache_i         => cache_is(i),
                prrd_i          => prrd_is(i),
                prrdmiss_i      => prrdmiss_is(i),
                prwr_i          => prwr_is(i), 
                prwrmiss_i      => prwrmiss_is(i),
                busrd_i         => busrd_is(i),
                busupd_i        => busupd_is(i),
                busrd_o         => busrd_os(i),
                busupd_o        => busupd_os(i),
                flush_o         => flush_os(i),
                update_o        => update_o(i)
            );

    pos0    <= data_loc & offset;
    pos0_bus <= data_loc_bus_i & addr_from_bus(1 downto 0);

    process(data_loc, offset)
    begin
        for i in 0 to 15
        loop
            for j in 0 to 3
            loop
                if(i == data_loc and j == offset) then
                    cache_is         <= cache_i;
                    prrd_is          <= prrd_i;
                    prrdmiss_is      <= prrdmiss_i;
                    prwr_is          <= prwr_i;
                    prwrmiss_is      <= prwrmiss_i;
                    busrd_is         <= busrd_i;
                    busupd_is        <= busupd_i;
                else
                    cache_is         <= '0';
                    prrd_is          <= '0';
                    prrdmiss_is      <= '0';
                    prwr_is          <= '0';
                    prwrmiss_is      <= '0';
                    busrd_is         <= '0';
                    busupd_is        <= '0';
                end if;
            end loop
        end loop;
    end

    process(pos0)
    begin
        busrd_o         <= busrd_os(pos0),
        busupd_o        <= busupd_os(pos0),
        flush_o         <= flush_os(pos0),
        update_o        <= update_o(pos0)
    end

    writing_process:process(clk)
                    begin
                        if rising_edge(clk)then
                            if prwr_is = '1' then
                                cache(to_integer(unsigned(pos0))) <= data_from_proc;
                            elsif prrdmiss_i = '1' then
                                cache(to_integer(unsigned(pos0))) <= data_from_bus;
                            end if;    
                        end if;
                    end process;
    
    read_process:process(clk)
                 begin
                    if rising_edge(clk) then
                        data_to_proc <= cache(to_integer(unsigned(pos0))); -- read from cache and send to processor

                        data_to_bus  <= cache(to_integer(unsigned(pos0_bus)));
                    end if;
                 end process;
end Behavioral;