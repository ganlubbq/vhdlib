--------------------------------------
-- Generic, parallel CRC calculator --
--------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity crc_gen_par is
  generic (
    POLYNOMIAL : std_logic_vector := "100000100110000010001110110110111"; -- default is CRC32
    DATA_WIDTH : integer := 8
  );
  port (
    crc_in   : in  std_logic_vector(POLYNOMIAL'length-2 downto 0); -- remainder is 1 bit shorter than divisor polynomial
    dat_in   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    crc_out  : out std_logic_vector(POLYNOMIAL'length-2 downto 0)
  );

end entity;

architecture rtl of crc_gen_par is

  type dat_in_matrix_t is array(crc_out'range) of std_logic_vector(dat_in'length - 1 downto 0);
  type crc_in_matrix_t is array(crc_out'range) of std_logic_vector(crc_in'length - 1 downto 0);
  signal dat_in_matrix : dat_in_matrix_t;
  signal crc_in_matrix : crc_in_matrix_t;

  pure function xor_reduce(slv : in std_logic_vector) return std_logic is
    variable r : std_logic;
  begin
    r := '0';

    for i in slv'range loop
      r := slv(i) XOR r;
    end loop;

    return r;
  end;

  pure function rem_of_single_bit (bit_offset : integer) return std_logic_vector is
    variable v : std_logic_vector(DATA_WIDTH + POLYNOMIAL'length - 2 downto 0);
    constant REM_LEN : integer := POLYNOMIAL'length - 1;
  begin
    v := (OTHERS => '0');
    v(v'high-bit_offset) := '1';

    for i in v'high downto REM_LEN loop
      if v(i) = '1' then
        v(i downto i-REM_LEN) := v(i downto i-REM_LEN) XOR POLYNOMIAL;
      end if;
    end loop;

    return v(REM_LEN-1 downto 0);
  end function rem_of_single_bit;

begin

  -- generate enable signal matrix
  xor_en : for i in crc_out'range generate
  begin

    crc_in_en : for j in crc_in'range generate
      signal rem_vec : std_logic_vector(crc_out'range);
    begin
      rem_vec <= rem_of_single_bit(crc_in'high-j);
      crc_in_matrix(i)(j) <= rem_vec(i);
    end generate crc_in_en;

    dat_in_en : for j in dat_in'range generate
      signal rem_vec : std_logic_vector(crc_out'range);
    begin
      rem_vec <= rem_of_single_bit(dat_in'high-j);
      dat_in_matrix(i)(j) <= rem_vec(i);
    end generate dat_in_en;

  end generate xor_en;

  -- CRC output from gating enable signal matrix and input signals
  crc_out_proc : process(dat_in, crc_in, dat_in_matrix, crc_in_matrix)
  begin
    for n in crc_out'range loop
      crc_out(n) <= xor_reduce((dat_in_matrix(n) and dat_in) & (crc_in_matrix(n) and crc_in));
    end loop;
  end process crc_out_proc;

end rtl;
