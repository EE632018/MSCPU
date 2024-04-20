library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity arbiter is
    generic(
        num_of_cores    : integer := 2;
        addr_w          : integer := 10;
        word_size       : integer := 32;
        block_size      : integer := 128
    );
    port (
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
end arbiter;

architecture Behavioral of arbiter is

    signal cache_s : std_logic_vector(num_of_cores - 1 downto 0);

begin


    process(busrd_i, cache_i, busupd_i, update_i, flush_i)
    begin
        stall_a <= (others => '1');
        busrd_o <= (others => '1');
        for i in 0 to num_of_cores-1 loop
            if(busrd_i(i) = '1' or cache_i(i) = '1' or busupd_i(i) = '1' or update_i(i) = '1' or flush_i(i) = '1')then
                stall_a(i) <= '0';
                busrd_o(i) <= busrd_i(i);
                cache_s(i) <= cache_i(i);
                busupd_o(i) <= busupd_i(i);
            else
                stall_a <= (others => '1');
                busrd_o <= (others => '0');
                cache_s <= (others => '0');
                busupd_o <= (others => '0');
            end if;
        end loop;
    end process;

    cache_o <= cache_s;


    process(flush_i, update_i, data_to_bus, data_from_mem)
    begin
        data_from_bus <= (others => '0');
        if(UNSIGNED(flush_i) /= 0 or UNSIGNED(update_i) /= 0)then
            for i in 0 to num_of_cores-1 loop
                if(flush_i(i) = '1')then
                    data_from_bus <= data_to_bus((i+1) * word_size - 1 downto i * word_size);
                end if;
            end loop;
        else
            data_from_bus <= data_from_mem;
        end if;
    end process;

    process(src_cache_i, bus_addr_i)
    begin
        bus_addr_o <= (others => '0');
        for i in 0 to num_of_cores-1 loop
            if(src_cache_i(i) = '1')then
                bus_addr_o <= bus_addr_i((i+1) * addr_w - 1 downto i * addr_w);
            end if;
        end loop;
    end process;

    process(send_to_mem_i, data_from_core)
    begin
        data_to_mem <= (others => '0');
        for i in 0 to num_of_cores-1 loop
            if(send_to_mem_i(i) = '1')then
                data_to_mem <= data_from_core((i+1) * word_size - 1 downto i * word_size);
            end if;
        end loop;
    end process;

    send_from_mem_o <= '1' when cache_s /= std_logic_vector(to_unsigned(0,num_of_cores)) else
                       '0';
end Behavioral;