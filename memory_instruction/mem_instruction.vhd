library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mem_instruction is 
    generic(
        block_size      : integer := 128;
        word_size       : integer := 32;
        addr_size       : integer := 10
    );
    port(
        clk             : in std_logic;
        reset           : in std_logic;
        read_from_mem   : in std_logic; -- read signal
        addr            : in std_logic_vector(addr_size - 1 downto 0);
        instruction_o   : out std_logic_vector(block_size - 1 downto 0)    
    );

end mem_instruction;

architecture Behavioral of mem_instruction is

type ram is array (0 to 2**addr_size - 1) of std_logic_vector(word_size - 1 downto 0);

signal instruction_mem : ram;
signal addr_tmp : std_logic_vector(addr_size - 1 downto 0);
signal zero_tmp : std_logic_vector(1 downto 0);
signal cnt_delay_r, cnt_delay_nxt : std_logic_vector(2 downto 0);

type state is (IDLE,BUSY_READ);
signal wr_en : std_logic;
signal state_r, state_nxt : state := IDLE;

begin

zero_tmp <= "00";
addr_tmp <= addr(addr_size - 1 downto 2)&zero_tmp;

process(clk, reset)
begin
    if reset = '0' then
        instruction_mem <= (others => (others => '0'));
    end if;
    
    instruction_o(31 downto 0) <= instruction_mem(to_integer(unsigned(addr_tmp)+3));
    instruction_o(63 downto 32) <= instruction_mem(to_integer(unsigned(addr_tmp)+2));
    instruction_o(95 downto 64) <= instruction_mem(to_integer(unsigned(addr_tmp)+1));
    instruction_o(127 downto 96) <= instruction_mem(to_integer(unsigned(addr_tmp)));
end process;

process(clk, reset)
begin
    if reset = '0' then
        state_r     <= IDLE;
        cnt_delay_r <= (others => '0');
    elsif rising_edge(clk) then
        state_r     <= state_nxt;
        cnt_delay_r <= cnt_delay_nxt;
    end if;
end process;

process(state_r, state_nxt, read_from_mem, cnt_delay_r)
begin
    cnt_delay_nxt   <= cnt_delay_r;
    state_nxt       <= state_r;
    instruction_rdy <= '0';
    rd_rdy          <= '0';

    case state_r is
        when IDLE       => 
            if read_from_mem = '1' then
                state_nxt <= BUSY_READ;
            end if;
        when BUSY_READ  =>
            cnt_delay_nxt <= std_logic_vector(unsigned(cnt_delay_r) + to_unsigned(1,3));
            if (cnt_delay_r = "101")then
                cnt_delay_nxt   <= (others => '0');
                instruction_rdy        <= '1';
                rd_rdy          <= '1';
                state_nxt       <= IDLE;
            end if;
        when others     => 
            cnt_delay_nxt   <= "000";
            state_nxt       <= IDLE;
            instruction_rdy <= '0';
            rd_rdy          <= '0';
            wr_en           <= '0';
        end case;
end process;

end Behavioral;