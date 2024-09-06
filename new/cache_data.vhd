library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_data is
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

end cache_data;


architecture Behavioral of cache_data is 
    type ram is array (0 to 2**(loc_bits) - 1) of std_logic_vector(word_size-1 downto 0);

    signal cache : ram := (others => (others => '0'));

begin

    writing_process:process(clk)
                    begin
                        if rising_edge(clk)then
                            if prwr_i = '1' then
                                cache(to_integer(unsigned(data_loc))) <= data_from_proc;
                            elsif refill = '1' then
                                cache(to_integer(unsigned(data_loc))) <= data_from_bus;
                            end if;    
                        end if;
                    end process;

    read_process:process(clk)
                 begin
                       if rising_edge(clk) then
                           data_to_proc <= cache(to_integer(unsigned(data_loc))); -- read from cache and send to processor
                           if update_i = '1' or flush_i = '1' or busupd_i = '1' or busrd_i = '1' then
                                data_to_bus  <= cache(to_integer(unsigned(data_loc_bus_o)));
                           end if; 
                       end if;
                 end process;
end Behavioral;