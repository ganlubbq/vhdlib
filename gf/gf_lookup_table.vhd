----------------------------------
-- GF(2^M) element lookup table --
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.vhdlib_package.all;

entity gf_lookup_table is
  generic (
    GF_POLYNOMIAL : std_logic_vector := BINARY_POLYNOMIAL_G709_GF; -- irreducible, binary polynomial
    TABLE_TYPE    : gf_table_type    := gf_table_type_inverse
  );
  port (
    clock       : in  std_logic;
    element_in  : in  std_logic_vector(GF_POLYNOMIAL'length-2 downto 0);
    element_out : out std_logic_vector(GF_POLYNOMIAL'length-2 downto 0)
  );

end entity;

architecture rtl of gf_lookup_table is
  constant M : natural := GF_POLYNOMIAL'length-1;

  -- look-up table type
  type table_matrix is array(0 to 2**M-1) of std_logic_vector(M-1 downto 0);

  -- function to generate table contents
  function gen_table return table_matrix is
    variable index_element  : std_logic_vector(M-1 downto 0);
    variable value_element  : std_logic_vector(M-1 downto 0);
    variable tmp_log_table  : table_matrix;
    variable return_table   : table_matrix;
  begin

    if TABLE_TYPE = gf_table_type_inverse then
      return_table(0) := (OTHERS => '0'); -- inverse of 0 not defined
      return_table(1) := std_logic_vector(to_unsigned(1,M)); -- 1 = 1*1

      for i in 1 to 2**M-2 loop
        index_element := primitive_element_exponentiation(i, GF_POLYNOMIAL); -- alpha^i
        value_element := primitive_element_exponentiation(2**M-1-i, GF_POLYNOMIAL); -- alpha^(2^M-1-i)
        return_table(to_integer(unsigned(index_element))) := value_element; -- alpha^i -> alpha^(2^M-1-i)
      end loop;
    end if;

    if TABLE_TYPE = gf_table_type_logarithm then
      return_table(0)  := (OTHERS => '0'); -- logarithm of 0 not defined

      for i in 0 to 2**M-2 loop
        index_element := primitive_element_exponentiation(i, GF_POLYNOMIAL); -- alpha^i
        value_element := std_logic_vector(to_unsigned(i,M)); -- i
        return_table(to_integer(unsigned(index_element))) := value_element; -- alpha^i -> i
      end loop;
    end if;

    if TABLE_TYPE = gf_table_type_exponent then
      for i in 0 to 2**M-1 loop
        index_element := std_logic_vector(to_unsigned(i,M)); -- i
        value_element := primitive_element_exponentiation(i, GF_POLYNOMIAL); -- alpha^i
        return_table(to_integer(unsigned(index_element))) := value_element; -- i -> alpha^i
      end loop;
    end if;

    if TABLE_TYPE = gf_table_type_zech_logarithm then
      -- first generate temporary logarithm table
      tmp_log_table(0) := (OTHERS => '0'); -- logarithm of 0 not defined

      for i in 0 to 2**M-2 loop
        index_element := primitive_element_exponentiation(i, GF_POLYNOMIAL); -- alpha^i
        value_element := std_logic_vector(to_unsigned(i,M)); -- i
        tmp_log_table(to_integer(unsigned(index_element))) := value_element; -- alpha^i -> i
      end loop;

      -- now generate the actual Zech's logarithm table
      return_table(0) := (OTHERS => '1'); -- Z(0) = -infinity
      return_table(2**M-1) := (OTHERS => '0'); -- Z(-infinity) = 0

      -- calculate alpha^i + 1 and look up log(alpha^i + 1) in the temporary table
      for i in 1 to 2**M-2 loop
        index_element := std_logic_vector(to_unsigned(i,M)); -- i
        value_element := primitive_element_exponentiation(i, GF_POLYNOMIAL); -- alpha^i
        value_element(0) := value_element(0) xor '1'; -- alpha^i + 1
        value_element := tmp_log_table(to_integer(unsigned(value_element))); -- log(alpha^i + 1)
        return_table(to_integer(unsigned(index_element))) := value_element; -- i -> log(alpha^i + 1)
      end loop;
    end if;

    return return_table;
  end function gen_table;

  constant table  : table_matrix := gen_table;

begin
  process(clock)
  begin
    if rising_edge(clock) then
      element_out <= table(to_integer(unsigned(element_in)));
    end if;
  end process;
end rtl;
