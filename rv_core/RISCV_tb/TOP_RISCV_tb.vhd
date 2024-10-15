library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.txt_util.all;
use work.utils_pkg.all;

entity TOP_RISCV_tb is
-- port ();
end entity;


architecture Behavioral of TOP_RISCV_tb is
   -- Operand za pristup asemblerskom kodu programa
   file RISCV_instructions: text open read_mode is "C:\MSCPU\rv_core\RISCV_tb\test_source_codes\for_bin.txt";
   --file RISCV_instructions: text open read_mode is "/home/dejan/RV32IM/RISCV_tb/test_source_codes/R_B_U_J_I_bin.txt";   
   
   -- Globalni signali
   signal clk: std_logic:='0';
   signal reset: std_logic;       
   -- Signali memorije za instrukcije
   signal ena_instr_s,enb_instr_s: std_logic;
   signal wea_instr_s,web_instr_s: std_logic;
   signal addra_instr_s,addrb_instr_s: std_logic_vector(9 downto 0);
   signal dina_instr_s,dinb_instr_s:std_logic_vector(31 downto 0);
   signal douta_instr_s,doutb_instr_s:std_logic_vector(31 downto 0);
   signal addrb_instr_32_s:std_logic_vector(31 downto 0);
   -- Signali memorije za podatke
   signal ena_data_s,enb_data_s: std_logic;
   signal wea_data_s,web_data_s:std_logic;
   signal addra_data_s,addrb_data_s: std_logic_vector(9 downto 0);
   signal dina_data_s,dinb_data_s:std_logic_vector(31 downto 0);
   signal douta_data_s,doutb_data_s:std_logic_vector(31 downto 0);
   signal addra_data_32_s:std_logic_vector(31 downto 0);
   
   
   component top 
    generic(
        num_of_cores    : integer := 2;
        addr_w          : integer := 10;
        word_size       : integer := 32;
        block_size      : integer := 32;
        size            : integer := 1024;
        init_pc_val     : integer := 0;
        start_point     : integer := 5
    );
    port(
        clk                 : in std_logic;
        reset               : in std_logic;
        wr                  : in std_logic;
        en                  : in std_logic;

        -- mem instruction
        wr_top              : in std_logic;
        en_top              : in std_logic;
        addr_top            : in std_logic_vector(log2c(size) - 1 downto 0);
        instruction_top_o   : out std_logic_vector(block_size - 1 downto 0);
        instruction_top_i   : in std_logic_vector(block_size - 1 downto 0);
        -- mem data 
        wr_top_data         : in std_logic; -- read signal
        en_top_data         : in std_logic;
        addr_top_data       : in std_logic_vector(log2c(size) - 1 downto 0);
        data_top_i          : in std_logic_vector(word_size - 1 downto 0);
        data_top_o          : out std_logic_vector(word_size - 1 downto 0)   
    );
   end component;

begin

    dut_inst: top
    generic map(
        num_of_cores    => 2,
        addr_w          => 10,
        word_size       => 32,
        block_size      => 32,
        size            => 1024,
        init_pc_val     => 0,
        start_point     => 5
    )
    port map(
        clk                 => clk,
        reset               => reset,
        wr                  => '1',
        en                  => '1',

        -- mem instruction
        wr_top              => wea_instr_s,
        en_top              => ena_instr_s,
        addr_top            => addra_instr_s,
        instruction_top_o   => douta_instr_s,
        instruction_top_i   => dina_instr_s,
        -- mem data 
        wr_top_data         => wea_data_s, -- read signal
        en_top_data         => ena_data_s,
        addr_top_data       => addra_data_s,
        data_top_i          => dina_data_s,
        data_top_o          => douta_data_s   
    );

   -- Memorija za instrukcije
   -- Pristup A : Koristi se za inicijalizaciju memorije za instrukcije
   -- Pristup B : Koristi se za citanje instrukcija od strane procesora 
 

   -- Memorija za podatke
   -- Pristup A : Koristi procesor kako bi upisivao i citao podatke
   -- Pristup B : Ne koristi se
	-- Konstante:

	-- Instanca:
   -- Top Modul - RISCV procesor jezgro
   
   ena_instr_s <= '1';
   -- Inicijalizacija memorije za instrukcije
   -- Program koji ce procesor izvrsavati se ucitava u memoriju
   read_file_proc:process
      variable row: line;
      variable i: integer:= 0;
   begin
      reset <= '0';
      --reset <= '1' after 180 ns;
      wea_instr_s <= '1';
      wea_data_s  <= '1';
      ena_data_s  <= '1';
      while (not endfile(RISCV_instructions))loop         
         readline(RISCV_instructions, row);
         addra_instr_s <= std_logic_vector(to_unsigned(i, 10));
         dina_instr_s <= to_std_logic_vector(string(row));         
         i := i + 4;
         wait until rising_edge(clk);
      end loop;
      reset <= '1';
      wea_instr_s <= '0';
      --reset <= '0' after 20 ns;
      
      --reset <= '0' after 40*200ns;
      wait;
   end process;

   -- klok signal generator
   clk_proc: process
   begin
      clk <= '1', '0' after 100 ns;
      wait for 200 ns;
   end process;
   
end architecture;