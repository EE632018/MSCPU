library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_controller is
    generic(
        index_bits      : integer := 4; -- bits used for sets, I have 64 enteries in cache separeted in 4 way, so 16 sets
        set_offset_bits : integer := 2; -- Each of sets has 4 lines that covers 16*4=64
        tag_bits        : integer := 6; -- Address is 10 bits so tag is 10 - 4 = 6
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
        refill      : out std_logic;

        -- Signals to cache
        data_loc        : out std_logic_vector(5 downto 0);
        data_loc_bus_o  : out std_logic_vector(5 downto 0);
        -- signali za dragon FSM
        cache_o         : out std_logic; -- there is this value in other cache
        prrd_o          : out std_logic;
        prrdmiss_o      : out std_logic;
        prwr_o          : out std_logic;
        prwrmiss_o      : out std_logic;
        busrd_o         : out std_logic;
        busupd_o        : out std_logic;
        flush_o         : out std_logic;
        update_o        : out std_logic;
        send_to_mem_o   : out std_logic;
        -- OVO je od strane drugog kora poslato 
        busrd_i         : in std_logic;
        busupd_i        : in std_logic;
        cache_i         : in std_logic;
        --src_cache_o     : out std_logic; -- pretraga cache koja mi kaze kada da drugi pogledaju

        key_to_bus      : in std_logic; -- zakljucavanje magistrale od strane datog kontrolera
        lock_arbiter_o  : out std_logic
    );
end cache_controller;

architecture Behavioral of cache_controller is 

    type tag_array is array (0 to 2**(index_bits+set_offset_bits) - 1) of std_logic_vector(tag_bits + 2 downto 0); -- First three bits are Dragon FSM state, from 5 to 0 is addres of tag
    type ptr_array is array (0 to 2**index_bits-1) of std_logic;
    type state is (IDLE, COMPARE_TAG, CHECK_ARBITER, LOAD, UPDATE, COMPARE_FOR_NEIGHBOUR); --, COMPARE_FOR_NEIGHBOUR

    -- States of Dragon FSM are on upper 3 bits in tag_array 
    -- STATE E is represented as 000
    -- STATE Sc is represented as 001
    -- STATE Sm is represented as 010
    -- STATE M is represented as 011
    -- STATE IDLE is represented as 111

    signal state_r, state_nxt     : state     := IDLE;

    signal tag_array_r, tag_array_nxt     : tag_array := (others => (others => '1'));
    -- base pointer for each set
    signal s_ptr_r, s_ptr_nxt                   : ptr_array := (others => '0');
    -- left pointer for each set
    signal l_ptr_r, l_ptr_nxt                   : ptr_array := (others => '0');
    -- right pointer for each set
    signal r_ptr_r, r_ptr_nxt                   : ptr_array := (others => '0');

    signal tag_s, tag_r, tag_nxt                : std_logic_vector(tag_bits - 1 downto 0);
    signal index0_r,index0_nxt                  : std_logic_vector(5 downto 0);
    signal index_s                              : std_logic_vector(3 downto 0);
    signal index1_r,index1_nxt                  : std_logic_vector(5 downto 0);
    signal index2_r,index2_nxt                  : std_logic_vector(5 downto 0);
    signal index3_r,index3_nxt                  : std_logic_vector(5 downto 0); 
    signal data_loc_bus_s, data_loc_r, data_loc_nxt : std_logic_vector(5 downto 0);

    signal tag_s_bus, tag_bus                   : std_logic_vector(tag_bits - 1 downto 0);
    signal index_s_bus                          : std_logic_vector(3 downto 0);
    signal index0_bus                           : std_logic_vector(5 downto 0);
    signal index1_bus                           : std_logic_vector(5 downto 0);
    signal index2_bus                           : std_logic_vector(5 downto 0);
    signal index3_bus                           : std_logic_vector(5 downto 0);

    signal prrd_r, prrd_nxt                     : std_logic;
    signal prrdmiss_r, prrdmiss_nxt             : std_logic;
    signal prwr_r, prwr_nxt                     : std_logic;
    signal prwrmiss_r, prwrmiss_nxt             : std_logic;
    signal proc_rd_r, proc_rd_nxt               : std_logic;
    signal proc_wr_r, proc_wr_nxt               : std_logic;
    signal busrd_r, busrd_nxt                   : std_logic;
    signal busupd_r, busupd_nxt                 : std_logic;
    signal flush_r, flush_nxt                   : std_logic;
    signal update_r, update_nxt                 : std_logic;
    signal send_to_mem_r, send_to_mem_nxt       : std_logic;
    signal cache_r, cache_nxt                   : std_logic;
    signal refill_r, refill_nxt                 : std_logic;

    signal lock_arbiter                         : std_logic;

begin

    tag_s       <= proc_addr(9 downto 4);
    index_s     <= proc_addr(3 downto 0);
    tag_s_bus   <= bus_addr_i(9 downto 4);
    index_s_bus <= bus_addr_i(3 downto 0);
    bus_addr_o  <= proc_addr;

        -- process making registers
        process(clk, reset) 
        begin
            if reset = '0' then
                state_r         <= IDLE;
                tag_array_r     <= (others => (others => '1'));
                data_loc_r      <= (others => '0');
                s_ptr_r         <= (others => '0');
                l_ptr_r         <= (others => '0');
                r_ptr_r         <= (others => '0');
                tag_r           <= (others => '0');
                index0_r        <= (others => '0');
                index1_r        <= (others => '0');
                index2_r        <= (others => '0');
                index3_r        <= (others => '0');
                proc_rd_r       <= '0';
                proc_wr_r       <= '0';
                prrd_r          <= '0';
                prwr_r          <= '0';
                prrdmiss_r      <= '0';
                prwrmiss_r      <= '0';
                busrd_r         <= '0';
                busupd_r        <= '0';
                flush_r         <= '0';
                update_r        <= '0';
                cache_r         <= '0';
                send_to_mem_r   <= '0';
                refill_r        <= '0';    
            elsif rising_edge(clk) then
                --if (stall_a = '1') then
                    state_r         <= state_nxt;
                    tag_array_r     <= tag_array_nxt;
                    data_loc_r      <= data_loc_nxt;
                    s_ptr_r         <= s_ptr_nxt;
                    l_ptr_r         <= l_ptr_nxt;
                    r_ptr_r         <= r_ptr_nxt;
                    tag_r           <= tag_nxt;
                    index0_r        <= index0_nxt;
                    index1_r        <= index1_nxt;
                    index2_r        <= index2_nxt;
                    index3_r        <= index3_nxt;
                    proc_rd_r       <= proc_rd_nxt;
                    proc_wr_r       <= proc_wr_nxt;
                    prrd_r          <= prrd_nxt;
                    prwr_r          <= prwr_nxt; 
                    prrdmiss_r      <= prrdmiss_nxt;
                    prwrmiss_r      <= prwrmiss_nxt;
                    busrd_r         <= busrd_nxt;
                    busupd_r        <= busupd_nxt;
                    flush_r         <= flush_nxt;
                    update_r        <= update_nxt;
                    send_to_mem_r   <= send_to_mem_nxt;
                    cache_r         <= cache_nxt;
                    refill_r        <= refill_nxt;  
                --end if;
            end if;
        end process;
    
        process(state_r, state_nxt, l_ptr_r, l_ptr_nxt, r_ptr_r, r_ptr_nxt,
                s_ptr_r, s_ptr_nxt, data_loc_r, data_loc_nxt, tag_array_r,
                tag_array_nxt, tag_r, tag_nxt, index0_r, index1_r, index2_r,
                index3_r, tag_s, proc_rd,proc_wr, index_s, proc_rd_r, proc_wr_r,
                prrd_r, prrdmiss_r, prwr_r, prwrmiss_r, busrd_r, busupd_r, flush_r, update_r,
                send_to_mem_r, cache_r, refill_r, proc_rd_nxt, proc_wr_nxt, key_to_bus, cache_i,
                tag_s_bus, index_s_bus, tag_bus, index0_bus, index1_bus, index2_bus, index3_bus,
                cache_nxt, data_loc_bus_s, busrd_i, busupd_i)
        begin
            state_nxt         <= state_r;
            tag_array_nxt     <= tag_array_r;
            data_loc_nxt      <= data_loc_r;
            s_ptr_nxt         <= s_ptr_r;
            l_ptr_nxt         <= l_ptr_r;
            r_ptr_nxt         <= r_ptr_r;
            tag_nxt           <= tag_r;
            index0_nxt        <= index0_r;
            index1_nxt        <= index1_r;
            index2_nxt        <= index2_r;
            index3_nxt        <= index3_r;
    
            proc_rd_nxt       <= proc_rd_r;
            proc_wr_nxt       <= proc_wr_r;
            prrd_nxt          <= prrd_r;
            prrdmiss_nxt      <= prrdmiss_r;
            prwr_nxt          <= prwr_r;
            prwrmiss_nxt      <= prwrmiss_r;
            busrd_nxt         <= busrd_r;
            busupd_nxt        <= busupd_r;
            flush_nxt         <= flush_r;
            update_nxt        <= update_r;
            send_to_mem_nxt   <= send_to_mem_r;
            cache_nxt         <= cache_r;
            refill_nxt        <= refill_r;  
            lock_arbiter      <= '0';
            stall             <= '0';  
            data_loc_bus_s    <= (others => '0');
            tag_bus           <= (others => '0'); 
            index0_bus        <= (others => '0'); 
            index1_bus        <= (others => '0');
            index2_bus        <= (others => '0');
            index3_bus        <= (others => '0');
            
            case state_r is
                when IDLE               =>
    
                    tag_nxt     <= tag_s;
                    index0_nxt  <= index_s & "00";
                    index1_nxt  <= index_s & "01";
                    index2_nxt  <= index_s & "10";
                    index3_nxt  <= index_s & "11";
                    proc_rd_nxt <= proc_rd;
                    proc_wr_nxt <= proc_wr;
    
                    if proc_rd_nxt = '1' or proc_wr_nxt = '1' then
                        stall <= '1';
                        state_nxt <= COMPARE_TAG;
                    else 
                        stall <= '0';
                        state_nxt <= IDLE;    
                    end if;
                when COMPARE_TAG        =>
                    if ((tag_r(tag_bits-1 downto 0) xor 
                        tag_array_r(to_integer(unsigned(index0_r)))(tag_bits-1 downto 0)) = "000000") then
                            data_loc_nxt <= index0_r;
                            if proc_rd_r = '1' then
                                prrd_nxt <= '1';
                            elsif proc_wr_r = '1' then
                                prwr_nxt <= '1';
                            end if;
                        if data_loc_nxt(1) = '1' then
                            s_ptr_nxt(to_integer(unsigned(index_s))) <= '1';
                            r_ptr_nxt(to_integer(unsigned(index_s))) <= data_loc_nxt(0);
                        else
                            s_ptr_nxt(to_integer(unsigned(index_s))) <= '0';
                            l_ptr_nxt(to_integer(unsigned(index_s))) <= data_loc_nxt(0);
                        end if;
                    elsif ((tag_r(tag_bits-1 downto 0) xor 
                        tag_array_r(to_integer(unsigned(index1_r)))(tag_bits-1 downto 0)) = "000000") then
                        data_loc_nxt <= index1_r;
                        if proc_rd_r = '1' then
                            prrd_nxt <= '1';
                        elsif proc_wr_r = '1' then
                            prwr_nxt <= '1';
                        end if;
                        if data_loc_nxt(1) = '1' then
                            s_ptr_nxt(to_integer(unsigned(index_s))) <= '1';
                            r_ptr_nxt(to_integer(unsigned(index_s))) <= data_loc_nxt(0);
                        else
                            s_ptr_nxt(to_integer(unsigned(index_s))) <= '0';
                            l_ptr_nxt(to_integer(unsigned(index_s))) <= data_loc_nxt(0);
                        end if;
                    elsif ((tag_r(tag_bits-1 downto 0) xor 
                        tag_array_r(to_integer(unsigned(index2_r)))(tag_bits-1 downto 0)) = "000000") then
                        data_loc_nxt <= index2_r;
                        if proc_rd_r = '1' then
                            prrd_nxt <= '1';
                        elsif proc_wr_r = '1' then
                            prwr_nxt <= '1';
                        end if;
                        if data_loc_nxt(1) = '1' then
                            s_ptr_nxt(to_integer(unsigned(index_s))) <= '1';
                            r_ptr_nxt(to_integer(unsigned(index_s))) <= data_loc_nxt(0);
                        else
                            s_ptr_nxt(to_integer(unsigned(index_s))) <= '0';
                            l_ptr_nxt(to_integer(unsigned(index_s))) <= data_loc_nxt(0);
                        end if;
                    elsif ((tag_r(tag_bits-1 downto 0) xor 
                        tag_array_r(to_integer(unsigned(index3_r)))(tag_bits-1 downto 0)) = "000000") then
                        data_loc_nxt <= index3_r;
                        if proc_rd_r = '1' then
                            prrd_nxt <= '1';
                        elsif proc_wr_r = '1' then
                            prwr_nxt <= '1';
                        end if;   
                        if data_loc_nxt(1) = '1' then
                            s_ptr_nxt(to_integer(unsigned(index_s))) <= '1';
                            r_ptr_nxt(to_integer(unsigned(index_s))) <= data_loc_nxt(0);
                        else
                            s_ptr_nxt(to_integer(unsigned(index_s))) <= '0';
                            l_ptr_nxt(to_integer(unsigned(index_s))) <= data_loc_nxt(0);
                        end if;
                    else
                        if proc_rd_r = '1' then
                            prrdmiss_nxt <= '1';
                        elsif proc_wr_r = '1' then
                            prwrmiss_nxt <= '1';
                        end if;
                        if s_ptr_r(to_integer(unsigned(index_s))) = '0' then
                            s_ptr_nxt(to_integer(unsigned(index_s))) <= '1';
                            r_ptr_nxt(to_integer(unsigned(index_s))) <= not r_ptr_r(to_integer(unsigned(index_s)));
                            data_loc_nxt <= index_s & (not(s_ptr_r(to_integer(unsigned(index_s))))) & (not r_ptr_r(to_integer(unsigned(index_s))));
                        else
                            s_ptr_nxt(to_integer(unsigned(index_s))) <= '0';
                            l_ptr_nxt(to_integer(unsigned(index_s))) <= not l_ptr_r(to_integer(unsigned(index_s)));
                            data_loc_nxt <= index_s & (not(s_ptr_r(to_integer(unsigned(index_s))))) & (not l_ptr_r(to_integer(unsigned(index_s))));
                        end if;
                    end if;
                    
                    stall <= '1';
                    state_nxt <= CHECK_ARBITER;
                    lock_arbiter <= '1';           
                when CHECK_ARBITER => 

                    stall <= '1'; 
                    if key_to_bus = '1' then
                        if prrdmiss_r = '1' or prwrmiss_r = '1' then
                            state_nxt <= LOAD;
                        elsif prrd_r = '1' or prwr_r = '1' then
                            state_nxt <= UPDATE;
                        else
                            state_nxt <= CHECK_ARBITER;
                        end if;
                    else
                        state_nxt <= COMPARE_FOR_NEIGHBOUR; 
                        lock_arbiter <= '1';   
                    end if;
                
                when COMPARE_FOR_NEIGHBOUR => 
                    tag_bus    <= tag_s_bus; 
                    index0_bus <= index_s_bus & "00"; 
                    index1_bus <= index_s_bus & "01";
                    index2_bus <= index_s_bus & "10";
                    index3_bus <= index_s_bus & "11";
                    lock_arbiter <= '1';
                    
                    if ((tag_bus(tag_bits-1 downto 0) xor 
                        tag_array_r(to_integer(unsigned(index0_bus)))(tag_bits-1 downto 0)) = "000000") then
                            cache_nxt <= '1';
                            data_loc_bus_s <= index0_bus;
                    elsif ((tag_bus(tag_bits-1 downto 0) xor 
                            tag_array_r(to_integer(unsigned(index1_bus)))(tag_bits-1 downto 0)) = "000000") then
                            cache_nxt <= '1';
                            data_loc_bus_s <= index1_bus;
                    elsif ((tag_bus(tag_bits-1 downto 0) xor 
                            tag_array_r(to_integer(unsigned(index2_bus)))(tag_bits-1 downto 0)) = "000000") then
                            cache_nxt <= '1';
                            data_loc_bus_s <= index2_bus;
                    elsif ((tag_bus(tag_bits-1 downto 0) xor 
                            tag_array_r(to_integer(unsigned(index3_bus)))(tag_bits-1 downto 0)) = "000000") then
                            cache_nxt <= '1';
                            data_loc_bus_s <= index3_bus;
                    else
                        cache_nxt <= '0';
                        data_loc_bus_s <= "000000";                          
                    end if;
    
                    if cache_nxt = '1' then
                        case tag_array_r(to_integer(unsigned(data_loc_bus_s)))(8 downto 6) is
                            when "000" =>
                                if busrd_i = '1' then
                                    tag_array_nxt(to_integer(unsigned(data_loc_bus_s))) <= "001" & tag_bus;
                                end if;
                            when "001" =>
                                if busrd_i = '1' then
                                    tag_array_nxt(to_integer(unsigned(data_loc_bus_s))) <= "001" & tag_bus;
                                elsif busupd_i = '1' then
                                    tag_array_nxt(to_integer(unsigned(data_loc_bus_s))) <= "001" & tag_bus;
                                    update_nxt <= '1';   
                                end if;
                            when "010" =>  
                                if busupd_i = '1' then
                                    tag_array_nxt(to_integer(unsigned(data_loc_bus_s))) <= "001" & tag_bus;
                                    update_nxt <= '1'; 
                                elsif busrd_i = '1' then
                                    tag_array_nxt(to_integer(unsigned(data_loc_bus_s))) <= "010" & tag_bus;
                                    flush_nxt <= '1';    
                                end if;
                            when "011" =>
                                if busrd_i = '1' then
                                    tag_array_nxt(to_integer(unsigned(data_loc_bus_s))) <= "010" & tag_bus;
                                    flush_nxt <= '1';    
                                end if;    
                            when others =>
                        end case;
                    end if;
                    stall <= '1';
                    state_nxt <= CHECK_ARBITER;

                when LOAD =>
                    -- Deo modela koji radi load podatka ili iz memorije ili iz drugog kesa
                    if prrdmiss_r = '1' and cache_i = '0' then
                        tag_array_nxt(to_integer(unsigned(data_loc_r))) <= "000" & tag_r; -- E 
                        busrd_nxt <= '1';
                    elsif  prrdmiss_r = '1' and cache_i = '1' then   
                        tag_array_nxt(to_integer(unsigned(data_loc_r))) <= "001" & tag_r; -- Sc
                        busrd_nxt <= '1';
                    elsif prwrmiss_r = '1' and cache_i = '1' then
                        tag_array_nxt(to_integer(unsigned(data_loc_r))) <= "010" & tag_r; -- Sm
                        busrd_nxt <= '1';
                        busupd_nxt  <= '1';
                    elsif prwrmiss_r = '1' and cache_i = '0' then
                        tag_array_nxt(to_integer(unsigned(data_loc_r))) <= "011" & tag_r; -- M
                        busrd_nxt <= '1';
                    else
                        tag_array_nxt(to_integer(unsigned(data_loc_r))) <= tag_array_r(to_integer(unsigned(data_loc_r)));
                    end if;

                    if key_to_bus = '1' then
                        state_nxt <= LOAD;
                        stall <= '1';
                    else
                        state_nxt  <= IDLE;
                        refill_nxt <= '1';
                        stall      <= '0';
                    end if;

                    case tag_array_r(to_integer(unsigned(data_loc_r)))(8 downto 6) is
                        when "010" => 
                            if (prrdmiss_r = '1') then
                                send_to_mem_nxt <= '1';
                            end if;
                        when "011" => 
                            if (prrdmiss_r = '1') then
                                send_to_mem_nxt <= '1';
                            end if;
                        when others =>     
                    end case;    
                when UPDATE =>
                    -- Case for each state in dragon protocol
                    case tag_array_r(to_integer(unsigned(data_loc_r)))(8 downto 6) is
                        --E
                        when "000" => 
                            if prwr_r = '1' then
                                tag_array_nxt(to_integer(unsigned(data_loc_r))) <= "011" & tag_r;
                            elsif prrd_r = '1' then
                                tag_array_nxt(to_integer(unsigned(data_loc_r))) <= "000" & tag_r;
                            end if;          
                        -- Sc
                        when "001" =>
                            if prwr_r = '1' and cache_i = '1' then
                                tag_array_nxt(to_integer(unsigned(data_loc_r))) <= "010" & tag_r;
                                busupd_nxt <= '1';
                            elsif prwr_r = '1' and cache_i = '0' then
                                tag_array_nxt(to_integer(unsigned(data_loc_r))) <= "011" & tag_r;
                            elsif prrd_r = '1' then
                                tag_array_nxt(to_integer(unsigned(data_loc_r))) <= "001" & tag_r;
                            end if;        
                        --Sm
                        when "010" =>
                            if prwr_r = '1' and cache_i = '0' then
                                tag_array_nxt(to_integer(unsigned(data_loc_r))) <= "011" & tag_r;
                                busupd_nxt <= '1';
                            elsif prwr_r = '1' and cache_i = '1' then
                                tag_array_nxt(to_integer(unsigned(data_loc_r))) <= "010" & tag_r;
                                busupd_nxt <= '1';
                            elsif prrd_r = '1' then
                                tag_array_nxt(to_integer(unsigned(data_loc_r))) <= "010" & tag_r;
                            end if;
                        --M 
                        when "011" =>  
                            if prwr_r = '1' then
                                tag_array_nxt(to_integer(unsigned(data_loc_r))) <= "011" & tag_r;
                            elsif prrd_r = '1' then
                                tag_array_nxt(to_integer(unsigned(data_loc_r))) <= "011" & tag_r;
                            end if;
                        when others =>
                            tag_array_nxt(to_integer(unsigned(data_loc_r))) <= tag_array_r(to_integer(unsigned(data_loc_r)));
                    end case;    
                        
                    if key_to_bus = '1' then
                        state_nxt <= UPDATE;
                        stall <= '1';
                    else
                        state_nxt <= IDLE;
                        stall     <= '0';
                    end if;    
                when others => 
            end case;
        end process;


--    process (key_to_bus, tag_s_bus, index_s_bus, tag_bus, tag_array_r, cache_r, busrd_i, busupd_i,
--             data_loc_bus_s) 
--    begin
--            if key_to_bus = '0' then
--                tag_bus    <= tag_s_bus; 
--                index0_bus <= index_s_bus & "00"; 
--                index1_bus <= index_s_bus & "01";
--                index2_bus <= index_s_bus & "10";
--                index3_bus <= index_s_bus & "11";
                
--                if ((tag_bus(tag_bits-1 downto 0) xor 
--                    tag_array_r(to_integer(unsigned(index0_bus)))(tag_bits-1 downto 0)) = "000000") then
--                        cache_r <= '1';
--                        data_loc_bus_s <= index0_bus;
--                elsif ((tag_bus(tag_bits-1 downto 0) xor 
--                        tag_array_r(to_integer(unsigned(index1_bus)))(tag_bits-1 downto 0)) = "000000") then
--                        cache_r <= '1';
--                        data_loc_bus_s <= index1_bus;
--                elsif ((tag_bus(tag_bits-1 downto 0) xor 
--                        tag_array_r(to_integer(unsigned(index2_bus)))(tag_bits-1 downto 0)) = "000000") then
--                        cache_r <= '1';
--                        data_loc_bus_s <= index2_bus;
--                elsif ((tag_bus(tag_bits-1 downto 0) xor 
--                        tag_array_r(to_integer(unsigned(index3_bus)))(tag_bits-1 downto 0)) = "000000") then
--                        cache_r <= '1';
--                        data_loc_bus_s <= index3_bus;
--                else
--                    cache_r <= '0';
--                    data_loc_bus_s <= "000000";                          
--                end if;

--                if cache_r = '1' then
--                    case tag_array_r(to_integer(unsigned(data_loc_bus_s)))(8 downto 6) is
--                        when "000" =>
--                            if busrd_i = '1' then
--                                tag_array_r(to_integer(unsigned(data_loc_bus_s))) <= "001" & tag_bus;
--                            end if;
--                        when "001" =>
--                            if busrd_i = '1' then
--                                tag_array_r(to_integer(unsigned(data_loc_bus_s))) <= "001" & tag_bus;
--                            elsif busupd_i = '1' then
--                                tag_array_r(to_integer(unsigned(data_loc_bus_s))) <= "001" & tag_bus;
--                                update_r <= '1';   
--                            end if;
--                        when "010" =>  
--                            if busupd_i = '1' then
--                                tag_array_r(to_integer(unsigned(data_loc_bus_s))) <= "001" & tag_bus;
--                                update_r <= '1'; 
--                            elsif busrd_i = '1' then
--                                tag_array_r(to_integer(unsigned(data_loc_bus_s))) <= "010" & tag_bus;
--                                flush_r <= '1';    
--                            end if;
--                        when "011" =>
--                            if busrd_i = '1' then
--                                tag_array_r(to_integer(unsigned(data_loc_bus_s))) <= "010" & tag_bus;
--                                flush_r <= '1';    
--                            end if;    
--                        when others =>
--                    end case;
--                end if;
--            end if;    
--    end process;


    -- Izlazi zaregistrovani
    prrd_o          <= prrd_r;
    prrdmiss_o      <= prrdmiss_r;
    prwr_o          <= prwrmiss_r;
    prwrmiss_o      <= prwrmiss_r;
    busrd_o         <= busrd_r;
    busupd_o        <= busupd_r;
    flush_o         <= flush_r;
    update_o        <= update_r;
    send_to_mem_o   <= send_to_mem_r;
    cache_o         <= cache_r;
    refill          <= refill_r;
    data_loc_bus_o  <= data_loc_bus_s;
    data_loc        <= data_loc_r;
    lock_arbiter_o  <= lock_arbiter;                    
end architecture;