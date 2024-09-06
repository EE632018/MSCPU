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
        clk             : in std_logic;
        reset           : in std_logic;

        bus_addr_o      : out std_logic_vector(addr_w - 1 downto 0);
        bus_addr_i      : in std_logic_vector(num_of_cores * addr_w - 1 downto 0);
        
        cache_i         : in std_logic_vector(num_of_cores - 1 downto 0);
        busrd_i         : in std_logic_vector(num_of_cores - 1 downto 0);
        busupd_i        : in std_logic_vector(num_of_cores - 1 downto 0);
        flush_i         : in std_logic_vector(num_of_cores - 1 downto 0);
        update_i        : in std_logic_vector(num_of_cores - 1 downto 0);
        send_to_mem_i   : in std_logic_vector(num_of_cores - 1 downto 0);
        send_from_mem_o : out std_logic;

        busrd_o         : out std_logic_vector(num_of_cores - 1 downto 0);
        busupd_o        : out std_logic_vector(num_of_cores - 1 downto 0);
        cache_o         : out std_logic_vector(num_of_cores - 1 downto 0);
        --src_cache_o     : out std_logic; -- pretraga cache koja mi kaze kada da drugi pogledaju

        key_to_bus      : out std_logic_vector(num_of_cores - 1 downto 0); -- zakljucavanje magistrale od strane datog kontrolera
        lock_arbiter_i  : in std_logic_vector(num_of_cores - 1 downto 0); --

        data_to_core    : out std_logic_vector(word_size - 1 downto 0);
        data_from_core  : in std_logic_vector(num_of_cores * word_size - 1 downto 0);
        data_to_mem     : out std_logic_vector(word_size - 1 downto 0);
        data_from_mem   : in std_logic_vector(word_size - 1 downto 0) -- Ovde treba razmisliti o ubacivanju slanja bloka a ne samo reci u kes

    );
end arbiter;    

architecture Behavioral of arbiter is

    type state is (IDLE, LOCK);
    signal state_r, state_nxt : state   := IDLE;

    signal cnt_r, cnt_nxt   : std_logic_vector(1 downto 0);
    signal key_r, key_nxt   : std_logic_vector(num_of_cores - 1 downto 0);
    
begin

    process(clk, reset)
    begin
        if reset = '0' then
            state_r <= IDLE;
            cnt_r   <= (others => '0');
            key_r   <= (others => '0');
        elsif rising_edge(clk) then
            state_r <= state_nxt;
            cnt_r <= cnt_nxt;
            key_r <= key_nxt;
        end if;
    end process;

    process(state_r, lock_arbiter_i, cnt_r, key_r, busrd_i, busupd_i, update_i, flush_i, 
            cache_i, bus_addr_i, data_from_core,data_from_mem, send_to_mem_i)
    begin
        cnt_nxt <= cnt_r;
        key_nxt <= key_r;
        busrd_o   <= (others => '0');
        busupd_o  <= (others => '0');
        cache_o   <= (others => '0');
        bus_addr_o   <= (others => '0');
        data_to_core <= (others => '0');  
        data_to_mem  <= (others => '0');   
        send_from_mem_o <= '0';
        case state_r is
            when IDLE => 
                cnt_nxt <= "00";
                for i in 0 to num_of_cores - 1 loop
                    if lock_arbiter_i(i) = '1' then
                        key_nxt(i) <= '1';
                    else
                        key_nxt(i) <= '0';
                    end if;
                end loop;
                if lock_arbiter_i /= std_logic_vector(to_unsigned(0,num_of_cores)) then
                    state_nxt <= LOCK;
                else
                    state_nxt <= IDLE;
                end if;
            when LOCK => 
                cnt_nxt <= std_logic_vector(unsigned(cnt_r) + to_unsigned(1,num_of_cores));                
                if cnt_r = "11" then
                    state_nxt <= IDLE;
                else
                    state_nxt <= LOCK;
                end if;
                
                
                for i in 0 to num_of_cores - 1 loop
                    if key_r(i) = '1' then
                        -- bus
                        if(busrd_i(i) = '1' or busupd_i(i) = '1' or update_i(i) = '1' or flush_i(i) = '1')then
                            busrd_o(i) <= busrd_i(i);
                            busupd_o(i) <= busupd_i(i);
--                        else
--                            busrd_o(i)  <= '0';
--                            busupd_o(i) <= '0';
                        end if;
                        -- cache    
                        if(cache_i(i) = '1')then
                            cache_o(i) <= cache_i(i);
--                        else
--                            cache_o(i) <= '0';
                        end if;
        
                        -- data 
                        if(flush_i(i) = '1' or update_i(i) = '1')then
                            data_to_core <= data_from_core((i+1) * word_size - 1 downto i * word_size);
                        else
                            data_to_core <= data_from_mem;    
                        end if;
        
                        if(send_to_mem_i(i) = '1')then
                            data_to_mem <= data_from_core((i+1) * word_size - 1 downto i * word_size);
                            send_from_mem_o <= '1';
--                        else
--                            data_to_mem <= (others => '0');
--                            send_from_mem_o <= '0';    
                        end if;
                        -- addr
                        bus_addr_o <= bus_addr_i((i+1) * addr_w - 1 downto i * addr_w);
                    else
                        busrd_o(i)   <= '0';
                        busupd_o(i)  <= '0';
                        cache_o(i)   <= '0';
                          
                    end if;
                end loop;
        
            when others => 
        end case;
    end process;

--    process(lock_arbiter_i, busrd_i, busupd_i, update_i, flush_i, 
--            cache_i, bus_addr_i, data_from_core,data_from_mem, send_to_mem_i)
--    begin
    
--        for i in 0 to num_of_cores - 1 loop
--            if lock_arbiter_i(i) = '1' then
--                -- bus
--                if(busrd_i(i) = '1' or busupd_i(i) = '1' or update_i(i) = '1' or flush_i(i) = '1')then
--                    busrd_o(i) <= busrd_i(i);
--                    busupd_o(i) <= busupd_i(i);
--                else
--                    busrd_o(i)  <= '0';
--                    busupd_o(i) <= '0';
--                end if;
--                -- cache    
--                if(cache_i(i) = '1')then
--                    cache_o(i) <= cache_i(i);
--                else
--                    cache_o(i) <= '0';
--                end if;

--                -- data 
--                if(flush_i(i) = '1' or update_i(i) = '1')then
--                    data_to_core <= data_from_core((i+1) * word_size - 1 downto i * word_size);
--                else
--                    data_to_core <= data_from_mem;    
--                end if;

--                if(send_to_mem_i(i) = '1')then
--                    data_to_mem <= data_from_core((i+1) * word_size - 1 downto i * word_size);
--                    send_from_mem_o <= '1';
--                else
--                    data_to_mem <= (others => '0');
--                    send_from_mem_o <= '0';    
--                end if;
--                -- addr
--                bus_addr_o <= bus_addr_i((i+1) * addr_w - 1 downto i * addr_w);
--            else
--                busrd_o(i)   <= '0';
--                busupd_o(i)  <= '0';
--                cache_o(i)   <= '0';
--                bus_addr_o   <= (others => '0');
--                data_to_core <= (others => '0');  
--                data_to_mem  <= (others => '0');   
--                send_from_mem_o <= '0';  
--            end if;
--        end loop;
--    end process;

    key_to_bus <= key_r;
end Behavioral;