--------------------------------------
-- Generic, parallel CRC calculator --
--------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity crc_gen_par is
  generic (
    POLYNOMIAL : std_logic_vector := CRC32_POLY; -- binary CRC polynomial
    DATA_WIDTH : integer := 8
  );
  port (
    crc_in   : in  std_logic_vector(POLYNOMIAL'length-2 downto 0); -- remainder is 1 bit shorter than divisor polynomial
    dat_in   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    crc_out  : out std_logic_vector(POLYNOMIAL'length-2 downto 0)
  );

end entity;

architecture rtl of crc_gen_par is

  type dat_in_matrix_t is array(crc_out'range) of std_logic_vector(dat_in'range);
  type crc_in_matrix_t is array(crc_out'range) of std_logic_vector(crc_in'range);

  function gen_dat_in_xor_matrix return dat_in_matrix_t is
    variable rem_vec : std_logic_vector(crc_out'range);
    variable ret_mat : dat_in_matrix_t;
  begin
    for j in dat_in'range loop
      rem_vec := single_bit_poly_div(j+POLYNOMIAL'length, POLYNOMIAL);
      for i in crc_out'range loop
        ret_mat(i)(j) := rem_vec(i);
      end loop;
    end loop;

    return ret_mat;
  end function gen_dat_in_xor_matrix;

  function gen_crc_in_xor_matrix return crc_in_matrix_t is
    variable rem_vec : std_logic_vector(crc_out'range);
    variable ret_mat : crc_in_matrix_t;
  begin
    for j in crc_in'range loop
      rem_vec := single_bit_poly_div(j+DATA_WIDTH+1, POLYNOMIAL);
      for i in crc_out'range loop
        ret_mat(i)(j) := rem_vec(i);
      end loop;
    end loop;

    return ret_mat;
  end function gen_crc_in_xor_matrix;

  constant DAT_IN_MATRIX : dat_in_matrix_t := gen_dat_in_xor_matrix;
  constant CRC_IN_MATRIX : crc_in_matrix_t := gen_crc_in_xor_matrix;

begin

  -- CRC output from gating enable signal matrix and input signals
  crc_out_xor : for n in crc_out'range generate
  begin
    crc_out(n) <= xor_reduce((DAT_IN_MATRIX(n) and dat_in) & (CRC_IN_MATRIX(n) and crc_in));
  end generate crc_out_xor;

end rtl;
