library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity dragon_fsm is
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
end dragon_fsm;


architecture Behavioral of dragon_fsm is 

    type dragon is (IDLE, E, Sc, Sm, M);
    signal fsm_r, fsm_nxt : dragon;

begin

    process(clk, reset)
    begin
        if(reset = '0')then
            fsm_r <= IDLE;  
        elsif(rising_edge(clk)) then
            if (stall_a = '1') then
                fsm_r <= fsm_nxt;
            end if;            
        end if;
    end process;

    process(fsm_r, prrd_i, prrdmiss_i, prwr_i, prwrmiss_i, busrd_i, busupd_i,cache_i)
    begin

        fsm_nxt <= fsm_r;

        case(fsm_r) is
            when IDLE =>
                if prrdmiss_i = '1' and cache_i = '0' then
                    fsm_nxt <= E;
                elsif prrdmiss_i = '1' and cache_i = '1' then
                    fsm_nxt <= Sc;
                elsif prwrmiss_i = '1' and cache_i = '1' then
                    fsm_nxt <= Sm;
                elsif prwrmiss_i = '1' and cache_i = '0' then
                    fsm_nxt <= M;
                else
                    fsm_nxt <= IDLE;
                end if;
            when E =>
                if prwr_i = '1' then
                    fsm_nxt <= M;
                elsif busrd_i = '1' then
                    fsm_nxt <= Sc;
                elsif prrd_i = '1' then
                    fsm_nxt <= E;                
                end if;
            when Sc =>
                if prwr_i = '1' and cache_i = '1' then
                    fsm_nxt <= Sm;
                elsif prwr_i = '1' and cache_i = '0' then
                    fsm_nxt <= M;
                elsif prrd_i = '1' then
                    fsm_nxt <= Sc;  
                elsif busrd_i = '1' then
                    fsm_nxt <= Sc;              
                end if;
            when Sm =>
                if prwr_i = '1' and cache_i = '0' then
                    fsm_nxt <= M;
                elsif busupd_i = '1' then
                    fsm_nxt <= Sc;
                elsif busrd_i = '1' then
                    fsm_nxt <= Sm;
                elsif prwr_i = '1' and cache_i = '1' then
                    fsm_nxt <= Sm;
                elsif prrd_i = '1' then
                    fsm_nxt <= Sm;                
                end if;
            when M =>
                if busrd_i = '1' then
                    fsm_nxt <= Sm;
                elsif prwr_i = '1' then
                    fsm_nxt <= M;
                elsif prrd_i = '1' then
                    fsm_nxt <= M;                
                end if;
            when others =>
        end case;
    end process;

    process(fsm_r, prrd_i, prrdmiss_i, prwr_i, prwrmiss_i, busrd_i, busupd_i, cache_i)
    begin

        busrd_o       <= '0';
        busupd_o      <= '0';
        flush_o       <= '0';
        update_o      <= '0';
        send_to_mem_o <= '0';
        case(fsm_r) is
            when IDLE =>
                if(prrdmiss_i = '1') then
                    busrd_o     <= '1';
                elsif(prwrmiss_i = '1' and cache_i = '0') then
                    busrd_o     <= '1';
                elsif(prwrmiss_i = '1' and cache_i = '1') then
                    busrd_o     <= '1';    
                    busupd_o    <= '1';
                end if;
            when E =>
            when Sc =>
                if(prwr_i = '1' and cache_i = '1') then
                    busupd_o   <= '1';
                elsif (busupd_i = '1') then
                    update_o   <= '1';
                end if;
            when Sm =>
                if (prrdmiss_i = '1') then
                    send_to_mem_o <= '1';
                end if;
                if (prwr_i = '1') then
                    busupd_o    <= '1';
                elsif busrd_i = '1' then
                    flush_o     <= '1';
                end if;
            when M =>    
                if (prrdmiss_i = '1') then
                    send_to_mem_o <= '1';
                end if;    
                if (busrd_i = '1') then
                    flush_o     <= '1';
                end if;
            when others =>
        end case;
    end process;
end architecture;
