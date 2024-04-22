library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_controller is
    generic(
        index_bits      : integer := 2;
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
end cache_controller;


architecture Behavioral of cache_controller is

    type tag_array  is array (0 to 2**(index_bits+set_offset_bits) - 1) of std_logic_vector(tag_bits-1 downto 0);
    type ptr_array is array (0 to 2**index_bits-1) of std_logic;
    type state is (IDLE, COMPARE_TAG);
    signal state_r, state_nxt                   : state     := IDLE;

    signal tag_array_r, tag_array_nxt           : tag_array := (others => (others => '0'));
    -- base pointer for each set
    signal s_ptr_r, s_ptr_nxt                   : ptr_array := (others => '0');
    -- left pointer for each set
    signal l_ptr_r, l_ptr_nxt                   : ptr_array := (others => '0');
    -- right pointer for each set
    signal r_ptr_r, r_ptr_nxt                   : ptr_array := (others => '0');

    signal tag_s, tag_r, tag_nxt                : std_logic_vector(tag_bits - 1 downto 0);
    signal index0_r,index0_nxt                  : std_logic_vector(index_bits + set_offset_bits - 1 downto 0);
    signal index_s                              : std_logic_vector(1 downto 0);
    signal index1_r,index1_nxt                  : std_logic_vector(index_bits + set_offset_bits - 1 downto 0);
    signal index2_r,index2_nxt                  : std_logic_vector(index_bits + set_offset_bits - 1 downto 0);
    signal index3_r,index3_nxt                  : std_logic_vector(index_bits + set_offset_bits - 1 downto 0); 
    signal data_loc_bus_s, data_loc_r, data_loc_nxt : std_logic_vector(index_bits+set_offset_bits-1 downto 0);

    signal tag_s_bus, tag_bus                   : std_logic_vector(tag_bits - 1 downto 0);
    signal index_s_bus                          : std_logic_vector(1 downto 0);
    signal index0_bus                           : std_logic_vector(index_bits + set_offset_bits - 1 downto 0);
    signal index1_bus                           : std_logic_vector(index_bits + set_offset_bits - 1 downto 0);
    signal index2_bus                           : std_logic_vector(index_bits + set_offset_bits - 1 downto 0);
    signal index3_bus                           : std_logic_vector(index_bits + set_offset_bits - 1 downto 0);

    signal prrd_s          : std_logic;
    signal prrdmiss_s      : std_logic;
    signal prwr_s          : std_logic;
    signal prwrmiss_s      : std_logic;
begin

    tag_s       <= proc_addr(9 downto 4);
    index_s     <= proc_addr(3 downto 2);
    tag_s_bus   <= bus_addr_i(9 downto 4);
    index_s_bus <= bus_addr_i(3 downto 2);
    bus_addr_o  <= proc_addr; 



    -- process making registers
    process(clk, reset) 
    begin
        if reset = '0' then
            state_r         <= IDLE;
            tag_array_r     <= (others => (others => '0'));
            data_loc_r      <= (others => '0');
            s_ptr_r         <= (others => '0');
            l_ptr_r         <= (others => '0');
            r_ptr_r         <= (others => '0');
            tag_r           <= (others => '0');
            index0_r        <= (others => '0');
            index1_r        <= (others => '0');
            index2_r        <= (others => '0');
            index3_r        <= (others => '0');
        elsif rising_edge(clk) then
            if (stall_a = '1') then
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
            end if;
        end if;
    end process;

    process(state_r, state_nxt, l_ptr_r, l_ptr_nxt, r_ptr_r, r_ptr_nxt,
            s_ptr_r, s_ptr_nxt, data_loc_r, data_loc_nxt, tag_array_r,
            tag_array_nxt,  tag_r,tag_nxt, index0_r, index1_r, index2_r,
            index3_r, tag_s, proc_rd,proc_wr, index_s)
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

        prrd_s            <= '0';
        prrdmiss_s        <= '0';
        prwr_s            <= '0';
        prwrmiss_s        <= '0';
        stall             <= '0';  

        case state_r is
            when IDLE               =>

                tag_nxt     <= tag_s;
                index0_nxt  <= index_s & "00";
                index1_nxt  <= index_s & "01";
                index2_nxt  <= index_s & "10";
                index3_nxt  <= index_s & "11";

                if proc_rd = '1' or proc_wr = '1' then
                    stall <= '1';
                    state_nxt <= COMPARE_TAG;
                end if;
            when COMPARE_TAG        =>
                if ((tag_r(tag_bits-1 downto 0) xor 
                    tag_array_r(to_integer(unsigned(index0_r)))(tag_bits-1 downto 0)) = "000000") then
                        data_loc_nxt <= index0_r;
                        if proc_rd = '1' then
                            prrd_s <= '1';
                        elsif proc_wr = '1' then
                            prwr_s <= '1';
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
                    if proc_rd = '1' then
                        prrd_s <= '1';
                    elsif proc_wr = '1' then
                        prwr_s <= '1';
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
                    if proc_rd = '1' then
                        prrd_s <= '1';
                    elsif proc_wr = '1' then
                        prwr_s <= '1';
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
                    if proc_rd = '1' then
                        prrd_s <= '1';
                    elsif proc_wr = '1' then
                        prwr_s <= '1';
                    end if;   
                    if data_loc_nxt(1) = '1' then
                        s_ptr_nxt(to_integer(unsigned(index_s))) <= '1';
                        r_ptr_nxt(to_integer(unsigned(index_s))) <= data_loc_nxt(0);
                    else
                        s_ptr_nxt(to_integer(unsigned(index_s))) <= '0';
                        l_ptr_nxt(to_integer(unsigned(index_s))) <= data_loc_nxt(0);
                    end if;
                else
                    if proc_rd = '1' then
                        prrdmiss_s <= '1';
                    elsif proc_wr = '1' then
                        prwrmiss_s <= '1';
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
                stall <= '0';
                tag_array_nxt(to_integer(unsigned(data_loc_nxt))) <=tag_r;
                state_nxt <= IDLE;
            when others => 
        end case;
    end process;

    process(index_s_bus, tag_array_r, tag_s_bus, tag_bus, index0_bus, index1_bus, index2_bus, index3_bus) 
    begin
        tag_bus    <= tag_s_bus; 
        index0_bus <= index_s_bus & "00"; 
        index1_bus <= index_s_bus & "01";
        index2_bus <= index_s_bus & "10";
        index3_bus <= index_s_bus & "11";
        

        if ((tag_bus(tag_bits-1 downto 0) xor 
             tag_array_r(to_integer(unsigned(index0_bus)))(tag_bits-1 downto 0)) = "000000") then
                cache_o <= '1';
                data_loc_bus_s <= index0_bus;
        elsif ((tag_bus(tag_bits-1 downto 0) xor 
                tag_array_r(to_integer(unsigned(index1_bus)))(tag_bits-1 downto 0)) = "000000") then
                 cache_o <= '1';
                 data_loc_bus_s <= index1_bus;
        elsif ((tag_bus(tag_bits-1 downto 0) xor 
                tag_array_r(to_integer(unsigned(index2_bus)))(tag_bits-1 downto 0)) = "000000") then
                 cache_o <= '1';
                 data_loc_bus_s <= index2_bus;
        elsif ((tag_bus(tag_bits-1 downto 0) xor 
                tag_array_r(to_integer(unsigned(index3_bus)))(tag_bits-1 downto 0)) = "000000") then
                 cache_o <= '1';
                 data_loc_bus_s <= index3_bus;
        else
            cache_o <= '0';
            data_loc_bus_s <= "0000";                          
        end if;
    end process;

    data_loc_bus_o  <= data_loc_bus_s;
    data_loc        <= data_loc_r;
    prrd_o          <= prrd_s;
    prwr_o          <= prwr_s;
    prrdmiss_o      <= prrdmiss_s;
    prwrmiss_o      <= prwrmiss_s;

    src_cache_o <= '1' when (prwr_s = '1' or prwrmiss_s = '1' or prrdmiss_s = '1') else
                   '0';

end Behavioral;