library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity l1_controller_instruction is
    generic(
        index_bits      : integer := 2;
        set_offset_bits : integer := 2;
        tag_bits        : integer := 6
    );
    port(
        clk             : in std_logic;
        reset           : in std_logic;
        rd              : in std_logic; -- read request from processor
        proc_addr       : in std_logic_vector(tag_bits+index_bits+set_offset_bits-1 downto 0);
        index           : in std_logic_vector(index_bits - 1 downto 0); -- index of the addr requeste
        tag             : in std_logic_vector(tag_bits - 1 downto 0); -- tag of addr requested 
        instruction_loc : out std_logic_vector(index_bits+set_offset_bits - 1 downto 0); -- location of instruction in cache instruction array
        refill          : out std_logic; -- refill signal to cache
        read_from_bus   : out std_logic; -- read signal to cache
        mem_addr        : out std_logic_vector(tag_bits+index_bits+set_offset_bits-1 downto 0);
        stall           : out std_logic
        --stall_a         : in std_logic
    );
end l1_controller_instruction;

architecture Behavioral of l1_controller_instruction is

    -- user define types 
    type tag_array  is array (0 to 2**(index_bits+set_offset_bits) - 1) of std_logic_vector(tag_bits - 1 downto 0);
    type ptr_array is array (0 to 2**index_bits-1) of std_logic;
    -- fsm state of cache_controller
    type state is (IDLE, COMPARE_TAG, HIT_MISS, ALLOCATE_REFILL);
    
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
    signal instruction_loc_r, instruction_loc_nxt             : std_logic_vector(index_bits+set_offset_bits-1 downto 0);
    signal refill_r, refill_nxt                 : std_logic;
    signal update_r, update_nxt                 : std_logic;
    signal read_from_bus_r, read_from_bus_nxt   : std_logic;
    signal wr_req, rd_req                       : std_logic;
    signal mem_addr_r, mem_addr_nxt             : std_logic_vector(tag_bits + index_bits + set_offset_bits - 1 downto 0);

    signal tag_r, tag_nxt                       : std_logic_vector(tag_bits - 1 downto 0);
    signal index0_r,index0_nxt                  : std_logic_vector(index_bits + set_offset_bits - 1 downto 0);
    signal index1_r,index1_nxt                  : std_logic_vector(index_bits + set_offset_bits - 1 downto 0);
    signal index2_r,index2_nxt                  : std_logic_vector(index_bits + set_offset_bits - 1 downto 0);
    signal index3_r,index3_nxt                  : std_logic_vector(index_bits + set_offset_bits - 1 downto 0); 

    signal proc_addr_r, proc_addr_nxt           : std_logic_vector(tag_bits+index_bits+set_offset_bits-1 downto 0);
    signal stall_r, stall_nxt : std_logic;
begin

    -- wr and rd process request
    process(clk, reset)
    begin
        if reset = '0' then
            rd_req <= '0';
        elsif rising_edge(clk) then
            if state_r = IDLE then
                rd_req <= '0';
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
            stall_r         <= '0';
            hit_r           <= '0';
            miss_r          <= '0';
            tag_array_r     <= (others => (others => '0'));
            instruction_loc_r      <= (others => '0');
            s_ptr_r         <= (others => '0');
            l_ptr_r         <= (others => '0');
            r_ptr_r         <= (others => '0');
            tag_r           <= (others => '0');
            index0_r        <= (others => '0');
            index1_r        <= (others => '0');
            index2_r        <= (others => '0');
            index3_r        <= (others => '0');

            read_from_bus_r <= '0';
            refill_r        <= '0';
            mem_addr_r      <= (others => '0');
            proc_addr_r     <= (others => '0');
        elsif rising_edge(clk) then
            --if stall_a = '1' then
                state_r         <= state_nxt;
                stall_r         <= stall_nxt;
                hit_r           <= hit_nxt;
                miss_r          <= miss_nxt;
                tag_array_r     <= tag_array_nxt;
                instruction_loc_r      <= instruction_loc_nxt;
                s_ptr_r         <= s_ptr_nxt;
                l_ptr_r         <= l_ptr_nxt;
                r_ptr_r         <= r_ptr_nxt;
                tag_r           <= tag_nxt;
                index0_r        <= index0_nxt;
                index1_r        <= index1_nxt;
                index2_r        <= index2_nxt;
                index3_r        <= index3_nxt;
    
                read_from_bus_r <= read_from_bus_nxt;
                refill_r        <= refill_nxt;
                mem_addr_r      <= mem_addr_nxt;
                proc_addr_r     <= proc_addr_nxt;
            --end if;
        end if;
    end process;

    -- next state logic
    process(state_r, state_nxt, l_ptr_r, l_ptr_nxt, r_ptr_r, r_ptr_nxt,proc_addr,
            s_ptr_r, s_ptr_nxt, instruction_loc_r, instruction_loc_nxt, tag_array_r,
            tag_array_nxt, read_from_bus_r, read_from_bus_nxt, tag_r,
            tag_nxt, index0_r, index1_r, index2_r, index3_r, tag, rd,
            hit_nxt, refill_r, update_r, index, mem_addr_r,
            mem_addr_nxt, hit_r, miss_r, miss_nxt, proc_addr_r, stall_r)
    begin
        state_nxt         <= state_r;
        hit_nxt           <= '0';
        miss_nxt          <= '0';
        tag_array_nxt     <= tag_array_r;
        instruction_loc_nxt      <= instruction_loc_r;
        s_ptr_nxt         <= s_ptr_r;
        l_ptr_nxt         <= l_ptr_r;
        r_ptr_nxt         <= r_ptr_r;
        tag_nxt           <= tag_r;
        index0_nxt        <= index0_r;
        index1_nxt        <= index1_r;
        index2_nxt        <= index2_r;
        index3_nxt        <= index3_r;

        read_from_bus_nxt <= '0';
        refill_nxt        <= '0';
        mem_addr_nxt      <= mem_addr_r;
        proc_addr_nxt     <= proc_addr_r;  
        stall_nxt         <= '0';  

-- Case state explanation
-- 1. IDLE 
    -- init state, where all requests start processing
    -- checks for hit or miss happen in this state
    -- but no read data available here (if read hit)
-- 2. 

        case state_r is
            when IDLE               =>
                stall_nxt       <= '0';
                hit_nxt     <= '0';
                miss_nxt    <= '0';

                tag_nxt     <= tag;
                index0_nxt  <= index & "00";
                index1_nxt  <= index & "01";
                index2_nxt  <= index & "10";
                index3_nxt  <= index & "11";
                if rd = '1' then
                    stall_nxt <= '1';
                    state_nxt <= COMPARE_TAG;
                    proc_addr_nxt   <= proc_addr;
                end if;
            when COMPARE_TAG        =>
                if ((tag_r(tag_bits-1 downto 0) xor 
                     tag_array_r(to_integer(unsigned(index0_r)))(tag_bits-1 downto 0)) = "000000") then
                        instruction_loc_nxt <= index0_r;
                        hit_nxt      <= '1';
                elsif ((tag_r(tag_bits-1 downto 0) xor 
                      tag_array_r(to_integer(unsigned(index1_r)))(tag_bits-1 downto 0)) = "000000") then
                        instruction_loc_nxt <= index1_r;
                        hit_nxt      <= '1';
                elsif ((tag_r(tag_bits-1 downto 0) xor 
                    tag_array_r(to_integer(unsigned(index2_r)))(tag_bits-1 downto 0)) = "000000") then
                        instruction_loc_nxt <= index2_r;
                        hit_nxt      <= '1';
                elsif ((tag_r(tag_bits-1 downto 0) xor 
                    tag_array_r(to_integer(unsigned(index3_r)))(tag_bits-1 downto 0)) = "000000") then
                        instruction_loc_nxt <= index3_r;
                        hit_nxt      <= '1';   
                else
                    miss_nxt    <= '1';
                    if s_ptr_r(to_integer(unsigned(index))) = '0' then
                        s_ptr_nxt(to_integer(unsigned(index))) <= '1';
                        r_ptr_nxt(to_integer(unsigned(index))) <= not r_ptr_r(to_integer(unsigned(index)));
                        instruction_loc_nxt <= index & (not(s_ptr_r(to_integer(unsigned(index))))) & (not r_ptr_r(to_integer(unsigned(index))));
                    else
                        s_ptr_nxt(to_integer(unsigned(index))) <= '0';
                        l_ptr_nxt(to_integer(unsigned(index))) <= not l_ptr_r(to_integer(unsigned(index)));
                        instruction_loc_nxt <= index & (not(s_ptr_r(to_integer(unsigned(index))))) & (not l_ptr_r(to_integer(unsigned(index))));
                    end if;
                end if;
                
                stall_nxt <= '1';
                state_nxt <= HIT_MISS;
                mem_addr_nxt <= proc_addr_r;
        when HIT_MISS => 
                if hit_r = '1' then
                    if instruction_loc_nxt(1) = '1' then
                        s_ptr_nxt(to_integer(unsigned(index))) <= '1';
                        r_ptr_nxt(to_integer(unsigned(index))) <= instruction_loc_nxt(0);
                    else
                        s_ptr_nxt(to_integer(unsigned(index))) <= '0';
                        l_ptr_nxt(to_integer(unsigned(index))) <= instruction_loc_nxt(0);
                    end if;
                    stall_nxt <= '0';
                    state_nxt <= IDLE;
                elsif hit_r = '0' and miss_r = '1' then
                    read_from_bus_nxt   <= '1';
                    mem_addr_nxt        <= mem_addr_r;
                    refill_nxt          <= '1';
                    stall_nxt           <= '1';  
                    state_nxt           <= ALLOCATE_REFILL;
                else
                    read_from_bus_nxt   <= '0';
                    mem_addr_nxt        <= mem_addr_r;
                    refill_nxt          <= '0';
                    stall_nxt           <= '1';  
                    state_nxt           <= COMPARE_TAG;    
                end if;
            when ALLOCATE_REFILL    => 
                read_from_bus_nxt   <= '0';
                mem_addr_nxt        <= mem_addr_r;
                refill_nxt          <= '0';               
                tag_array_nxt(to_integer(unsigned(instruction_loc_r))) <= tag;
                stall_nxt     <= '0';
                state_nxt     <= IDLE;
            when others             => 
        end case;
    end process;

    instruction_loc         <= instruction_loc_r;
    refill                  <= refill_r;
    read_from_bus           <= read_from_bus_r;
    mem_addr                <= mem_addr_r;
    stall                   <= stall_r;
end Behavioral;