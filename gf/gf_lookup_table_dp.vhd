--------------------------------------------
-- GF(2^M) element lookup table dual port --
--------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.vhdlib_package.all;

entity gf_lookup_table_dp is
  generic (
    GF_POLYNOMIAL   : std_logic_vector := BINARY_POLYNOMIAL_G709_GF; -- irreducible, binary polynomial
    TABLE_TYPE      : string           := INV_TABLE_TYPE
  );
  port (
    clock             : in  std_logic;
    element_in_a       : in  std_logic_vector(GF_POLYNOMIAL'length-2 downto 0);
    element_in_b       : in  std_logic_vector(GF_POLYNOMIAL'length-2 downto 0);
    element_out_a      : out std_logic_vector(GF_POLYNOMIAL'length-2 downto 0);
    element_out_b      : out std_logic_vector(GF_POLYNOMIAL'length-2 downto 0)
  );

end entity;

architecture rtl of gf_lookup_table_dp is
  constant M      : natural := GF_POLYNOMIAL'length-1;

  -- ROM table type
  type table_t is array(0 to 2**M-1) of std_logic_vector(M-1 downto 0);

  -- function to generate table contents
  function generate_table return table_t is
    variable index_element     : std_logic_vector(M-1 downto 0);
    variable value_element     : std_logic_vector(M-1 downto 0);
    variable tmp_log_table  : table_t;
    variable ret            : table_t;
  begin

    if TABLE_TYPE = INV_TABLE_TYPE then
      ret(0)  := (OTHERS => '0');                     -- inverse of 0 not defined
      ret(1)  := std_logic_vector(to_unsigned(1,M));  -- 1 = 1*1

      for i in 1 to 2**M-2 loop
        index_element  := primitive_element_exponentiation(i, GF_POLYNOMIAL);         -- alpha^i
        value_element  := primitive_element_exponentiation(2**M-1-i, GF_POLYNOMIAL);  -- alpha^(2^M-1-i)
        ret(to_integer(unsigned(index_element))) := value_element;    -- alpha^i -> alpha^(2^M-1-i)
      end loop;
    end if;

    if TABLE_TYPE = LOG_TABLE_TYPE then
      ret(0)  := (OTHERS => '0'); -- logarithm of 0 not defined

      for i in 0 to 2**M-2 loop
        index_element  := primitive_element_exponentiation(i, GF_POLYNOMIAL);       -- alpha^i
        value_element  := std_logic_vector(to_unsigned(i,M));    -- i
        ret(to_integer(unsigned(index_element))) := value_element;  -- alpha^i -> i
      end loop;
    end if;

    if TABLE_TYPE = EXP_TABLE_TYPE then
      for i in 0 to 2**M-1 loop
        index_element  := std_logic_vector(to_unsigned(i,M));    -- i
        value_element  := primitive_element_exponentiation(i, GF_POLYNOMIAL);       -- alpha^i
        ret(to_integer(unsigned(index_element))) := value_element;  -- i -> alpha^i
      end loop;
    end if;

    if TABLE_TYPE = ZECH_LOG_TABLE_TYPE then
      -- first generate temporary logarithm table
      tmp_log_table(0)  := (OTHERS => '0'); -- logarithm of 0 not defined

      for i in 0 to 2**M-2 loop
        index_element  := primitive_element_exponentiation(i, GF_POLYNOMIAL);                 -- alpha^i
        value_element  := std_logic_vector(to_unsigned(i,M));              -- i
        tmp_log_table(to_integer(unsigned(index_element))) := value_element;  -- alpha^i -> i
      end loop;

      -- now generate the actual Zech's logarithm table
      ret(0)      := (OTHERS => '1'); -- Z(0) = -infinity
      ret(2**M-1) := (OTHERS => '0'); -- Z(-infinity) = 0

      -- calculate alpha^i + 1 and look up log(alpha^i + 1) in the temporary table
      for i in 1 to 2**M-2 loop
        index_element    := std_logic_vector(to_unsigned(i,M));              -- i
        value_element    := primitive_element_exponentiation(i, GF_POLYNOMIAL);                 -- alpha^i
        value_element(0) := value_element(0) xor '1';                           -- alpha^i + 1
        value_element    := tmp_log_table(to_integer(unsigned(value_element))); -- log(alpha^i + 1)
        ret(to_integer(unsigned(index_element))) := value_element;              -- i -> log(alpha^i + 1)
      end loop;
    end if;

    return ret;
  end function generate_table;

  constant table  : table_t := generate_table;

begin
  process(clock)
  begin
    if rising_edge(clock) then
      element_out_a <= table(to_integer(unsigned(element_in_a)));
      element_out_b <= table(to_integer(unsigned(element_in_b)));
    end if;
  end process;
end rtl;
