library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity l1_controller_data is
    generic(
        index_bits      : integer := 2;
        set_offset_bits : integer := 2;
        tag_bits        : integer := 6
    );
    port(
        clk             : in std_logic;
        reset           : in std_logic;
        flush           : in std_logic;
        rd              : in std_logic; -- read request from processor
        wr              : in std_logic; -- write request from processor
        index           : in std_logic_vector(index_bits - 1 downto 0); -- index of the addr requeste
        tag             : in std_logic_vector(tag_bits - 1 downto 0) -- tag of addr requested
        data_rdy        : in std_logic; 
        data_loc        : out std_logic_vector(index_bits+set_offset_bits - 1 downto 0); -- location of data in cache data array
        refill          : out std_logic; -- refill signal to cache
        update          : out std_logic; -- update signal to cache
        read_from_mem   : out std_logic; -- read signal to cache
        write_to_mem    : out std_logic; -- write signak to cache
        mem_addr        : out std_logic_vector(tag_bits+index_bits+set_offset_bits-1 downto 0);
        stall           : out std_logic;
        hit             : out std_logic;
        miss            : out std_logic;
        cache_state     : out std_logic_vector(2 downto 0)
    );
end l1_controller_data;

architecture Behavioral of l1_controller_data is

    -- user define types 
    type tag_array  is array (0 to 2**(index_bits+set_offset_bits) - 1) of std_logic_vector(tag_bits downto 0);
    type ptr_array is array (0 to 2**index_bits-1) of std_logic;
    -- fsm state of cache_controller
    type state is (IDLE, COMPARE_TAG, ALLOCATE_REFILL, ALLOCATE_UPDATE, WRITE_BACK);
    
    signal state_r, state_nxt                   : state     := IDLE;
    signal tag_array_r, tag_array_nxt           : tag_array := (others => (others => '0'));
    -- base pointer for each set
    signal s_ptr_r, s_ptr_nxt                   : ptr_array := (others => '0');
    -- left pointer for each set
    signal l_ptr_r, l_ptr_nxt                   : ptr_array := (others => '0');
    -- right pointer for each set
    signal r_ptr_r, r_ptr_nxt                   : ptr_array := (others => '0');

    signal hit_r, hit_nxt                       : std_logic := '0';
    signal miss_r, miss_nxt                     : std_logic := '0';
    signal data_loc_r, data_loc_nxt             : std_logic_vector(index_bits+set_offset_bits-1 downto 0);
    signal refill_r, refill_nxt                 : std_logic;
    signal update_r, update_nxt                 : std_logic;
    signal read_from_mem_r, read_from_mem_nxt   : std_logic;
    signal write_to_mem_r, write_to_mem_nxt     : std_logic;
    signal wr_req, rd_req                       : std_logic;
    signal mem_addr_r, mem_addr_nxt             : std_logic_vector(tag_bits + set_offset_bits - 1 downto 0);

    signal tag_r, tag_nxt                       : std_logic_vector(tag_bits downto 0);
    signal index0_r,index0_nxt                  : std_logic_vector(index_bits + set_offset_bits - 1 downto 0);
    signal index1_r,index1_nxt                  : std_logic_vector(index_bits + set_offset_bits - 1 downto 0);
    signal index2_r,index2_nxt                  : std_logic_vector(index_bits + set_offset_bits - 1 downto 0);
    signal index3_r,index3_nxt                  : std_logic_vector(index_bits + set_offset_bits - 1 downto 0); 

    constant IDLE_C                             : std_logic_vector(2 downto 0) := "000";
    constant COMPARE_TAG_C                      : std_logic_vector(2 downto 0) := "001";
    constant WRITE_BACK_C                       : std_logic_vector(2 downto 0) := "010";
    constant ALLOCATE_REFILL_C                  : std_logic_vector(2 downto 0) := "011";
    constant ALLOCATE_UPDATE_C                  : std_logic_vector(2 downto 0) := "100";

begin

    -- cache_state signal 
    cache_state <= IDLE_C               when state_r = IDLE             else
                   COMPARE_TAG_C        when state_r = COMPARE_TAG      else
                   WRITE_BACK_C         when state_r = WRITE_BACK       else
                   ALLOCATE_REFILL_C    when state_r = ALLOCATE_REFILL  else
                   ALLOCATE_UPDATE_C    when state_r = ALLOCATE_UPDATE;

    -- wr and rd process request
    process(clk, reset)
    begin
        if reset = '0' then
            wr_req <= '0';
            rd_req <= '0';
        elsif rising_edge(clk) then
            if state_r = IDLE then
                wr_req <= '0';
                rd_req <= '0';
                if wr = '1' then
                    wr_req <= '1';
                end if;
                if rd = '1' then 
                    rd_req <= '1';
                end if;         
            end if ;
        end if;
    end process;

    -- init registers in system
    process(clk, reset) 
    begin
        if reset = '0' then
            state_r         <= IDLE;
            hit_r           <= '0';
            miss_r          <= '0';
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

            read_from_mem_r <= '0';
            write_to_mem_r  <= '0';
            refill_r        <= '0';
            update_r        <= '0';
            mem_addr_r      <= (others => '0');
        elsif rising_edge(clk) then
            if flush = '1' then
                tag_array_r     <= (others => (others => '0'));
                s_ptr_r         <= (others => '0');
                l_ptr_r         <= (others => '0');
                r_ptr_r         <= (others => '0'); 
            else
                state_r         <= state_nxt;
                hit_r           <= hit_nxt;
                miss_r          <= miss_nxt;
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

                read_from_mem_r <= read_from_mem_nxt;
                write_to_mem_r  <= write_to_mem_nxt;
                refill_r        <= refill_nxt;
                update_r        <= update_nxt;
                mem_addr_r      <= mem_addr_nxt;
            end if;
        end if;
    end process;

    -- next state logic
    process(state_r, state_nxt, l_ptr_r, l_ptr_nxt, r_ptr_r, r_ptr_nxt,
            s_ptr_r, s_ptr_nxt, data_loc_r, data_loc_nxt, tag_array_r,
            tag_array_nxt, read_from_mem_r, read_from_mem_nxt, tag_r,
            tag_nxt, index0_r, index1_r, index2_r, index3_r, tag, rd,
            wr, hit_nxt, data_rdy, refill_r, update_r, index, mem_addr_r,
            mem_addr_nxt, hit_r, miss_r)
    begin
        state_nxt         <= state_r;
        hit_nxt           <= hit_r;
        miss_nxt          <= miss_r;
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

        read_from_mem_nxt <= '0';
        write_to_mem_nxt  <= '0';
        refill_nxt        <= '0';
        update_nxt        <= '0';
        mem_addr_nxt      <= mem_addr_r;
        stall             <= '1';  

-- Case state explanation
-- 1. IDLE 
    -- init state, where all requests start processing
    -- checks for hit or miss happen in this state
    -- but no read data available here (if read hit)
-- 2. 

        case state_r is
            when IDLE               =>
                stall       <= '0';
                hit_nxt     <= '0';
                miss_nxt    <= '0';

                tag_nxt     <= '0' & tag;
                index0_nxt  <= index & "00";
                index1_nxt  <= index & "01";
                index2_nxt  <= index & "10";
                index3_nxt  <= index & "11";

                if rd = '1' or wr = '1' then
                    stall <= '1';
                    state_nxt <= COMPARE_TAG;
                end if;
            when COMPARE_TAG        =>
                if ((tag_r(tag_bits-1 downto 0) xor 
                     tag_array_r(to_integer(unsigned(index0_r)))(tag_bits-1 downto 0)) = "000000") then
                        data_loc_nxt <= index0_r;
                        hit_nxt      <= '1';
                elsif ((tag_r(tag_bits-1 downto 0) xor 
                    tag_array_r(to_integer(unsigned(index1_r)))(tag_bits-1 downto 0)) = "000000") then
                    data_loc_nxt <= index1_r;
                    hit_nxt      <= '1';
                elsif ((tag_r(tag_bits-1 downto 0) xor 
                    tag_array_r(to_integer(unsigned(index2_r)))(tag_bits-1 downto 0)) = "000000") then
                    data_loc_nxt <= index2_r;
                    hit_nxt      <= '1';
                elsif ((tag_r(tag_bits-1 downto 0) xor 
                    tag_array_r(to_integer(unsigned(index3_r)))(tag_bits-1 downto 0)) = "000000") then
                    data_loc_nxt <= index3_r;
                    hit_nxt      <= '1';   
                else
                    miss_nxt    <= '1';
                    if s_ptr_r(to_integer(unsigned(index))) = '0' then
                        s_ptr_nxt(to_integer(unsigned(index))) <= '1';
                        r_ptr_nxt(to_integer(unsigned(index))) <= not r_ptr_r(to_integer(unsigned(index)));
                        data_loc_nxt <= index & (not(s_ptr_r(to_integer(unsigned(index))))) & (not r_ptr_r(to_integer(unsigned(index))));
                    else
                        s_ptr_nxt(to_integer(unsigned(index))) <= '0';
                        l_ptr_nxt(to_integer(unsigned(index))) <= not l_ptr_r(to_integer(unsigned(index)));
                        data_loc_nxt <= index & (not(s_ptr_r(to_integer(unsigned(index))))) & (not l_ptr_r(to_integer(unsigned(index))));
                    end if;
                end if;

                if hit_nxt = '1'; then
                    -- set dirty bit
                    if wr_req = '1' then
                        update_nxt <= '1';
                        tag_array_nxt(to_integer(unsigned(data_loc_nxt)))(tag_bits) <= '1';
                    end if;
                    if data_loc_nxt(1) = '1' then
                        s_ptr_nxt(to_integer(unsigned(index))) <= '1';
                        r_ptr_nxt(to_integer(unsigned(index))) <= data_loc_nxt(0);
                    else
                        s_ptr_nxt(to_integer(unsigned(index))) <= '0';
                        l_ptr_nxt(to_integer(unsigned(index))) <= data_loc_nxt(0);
                    end if;

                    stall <= '0';
                    state_nxt <= IDLE;
                else
                    if tag_array_nxt(to_integer(unsigned(data_loc_nxt)))(tag_bits) = '1' then
                        write_to_mem_nxt <= '1';
                        state_nxt <= WRITE_BACK;
                    else
                        if wr_req = '1' then
                            update_nxt  <= '1';
                            state_nxt   <= ALLOCATE_UPDATE;
                        else
                            read_from_mem_nxt <= '1';
                            state_next        <= ALLOCATE_REFILL;
                        end if;
                    end if;    
                end if;
            when WRITE_BACK         =>
                mem_addr_nxt <= tag_array_r(to_integer(unsigned(data_loc_r)))(tag_bits-1 downto 0)&data_loc_r;
                if data_rdy = '1' then
                    if rd_req = '1' then
                        read_from_mem_nxt <= '1';
                        state_next <= ALLOCATE_REFILL;
                    elsif wr_req = '1' then
                        update_nxt <= '1';
                        state_nxt <= ALLOCATE_UPDATE;
                    end if;
                end if;
            when ALLOCATE_REFILL    =>
                write_to_mem_nxt <= '0';
                mem_addr_nxt    <= tag&data_loc_r;
                refill_nxt      <= '1';
                if data_rdy = '1' then
                    refill_nxt <= '1';
                    tag_array_nxt(to_integer(unsigned(data_loc_r))) <= '0' & tag;
                    stall <= '0';
                    state_nxt <= IDLE;
                end if;
            when ALLOCATE_UPDATE    =>
                tag_array_nxt(to_integer(unsigned(data_loc_r))) <= '1' & tag;
                stall <= '0';
                state_nxt <= IDLE;
            when others             => 
        end case;
    end process;

    data_loc        <= data_loc_r;
    refill          <= refill_r;
    update          <= update_r;
    read_from_mem   <= read_from_mem_r;
    write_to_mem    <= write_to_mem_r;
    mem_addr        <= mem_addr_r;
    hit             <= hit_nxt;
    miss            <= miss_r;
end Behavioral;