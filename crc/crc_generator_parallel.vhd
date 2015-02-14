--------------------------------------
-- Generic, parallel CRC calculator --
--------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity crc_generator_parallel is
  generic (
    POLYNOMIAL : std_logic_vector := BINARY_POLYNOMIAL_CRC32; -- binary CRC polynomial
    DATA_WIDTH : natural          := 8
  );
  port (
    crc_in  : in  std_logic_vector(POLYNOMIAL'length-2 downto 0);
    data_in : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    crc_out : out std_logic_vector(POLYNOMIAL'length-2 downto 0)
  );

end entity;

architecture rtl of crc_generator_parallel is

  type data_in_matrix_t is array(crc_out'range) of std_logic_vector(data_in'range);
  type crc_in_matrix_t is array(crc_out'range) of std_logic_vector(crc_in'range);

  function generator_data_in_xor_matrix return data_in_matrix_t is
    variable remainder_vector : std_logic_vector(crc_out'range);
    variable return_matrix : data_in_matrix_t;
  begin
    for j in data_in'range loop
      remainder_vector := single_bit_polynomial_division(j+POLYNOMIAL'length, POLYNOMIAL);
      for i in crc_out'range loop
        return_matrix(i)(j) := remainder_vector(i);
      end loop;
    end loop;

    return return_matrix;
  end function generator_data_in_xor_matrix;

  function generator_crc_in_xor_matrix return crc_in_matrix_t is
    variable remainder_vector : std_logic_vector(crc_out'range);
    variable return_matrix : crc_in_matrix_t;
  begin
    for j in crc_in'range loop
      remainder_vector := single_bit_polynomial_division(j+DATA_WIDTH+1, POLYNOMIAL);
      for i in crc_out'range loop
        return_matrix(i)(j) := remainder_vector(i);
      end loop;
    end loop;

    return return_matrix;
  end function generator_crc_in_xor_matrix;

  constant DATA_IN_MATRIX : data_in_matrix_t := generator_data_in_xor_matrix;
  constant CRC_IN_MATRIX : crc_in_matrix_t := generator_crc_in_xor_matrix;

begin

  -- CRC output from gating enable signal matrix and input signals
  crc_out_xor : for n in crc_out'range generate
  begin
    crc_out(n) <= xor_reduce((DATA_IN_MATRIX(n) and data_in) & (CRC_IN_MATRIX(n) and crc_in));
  end generate crc_out_xor;

end rtl;
