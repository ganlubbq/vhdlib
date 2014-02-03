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
    GF_POLYNOMIAL   : std_logic_vector := G709_GF_POLY; -- irreducible, binary polynomial
    TABLE_TYPE      : string           := INV_TABLE_TYPE
  );
  port (
    clk             : in  std_logic;
    elem_in         : in  std_logic_vector(GF_POLYNOMIAL'length-2 downto 0);
    elem_out        : out std_logic_vector(GF_POLYNOMIAL'length-2 downto 0)
  );

end entity;

architecture rtl of gf_lookup_table is
  constant M      : integer := GF_POLYNOMIAL'length-1;

  -- ROM table type
  type table_t is array(0 to 2**M-1) of std_logic_vector(M-1 downto 0);

  -- function to generate table contents
  function gen_table return table_t is
    variable index_elem : std_logic_vector(M-1 downto 0);
    variable value_elem : std_logic_vector(M-1 downto 0);
    variable ret        : table_t;
  begin

    if TABLE_TYPE = INV_TABLE_TYPE then
      ret(0)        := (OTHERS => '0'); -- inverse of 0 not defined
      ret(1)        := std_logic_vector(to_unsigned(1,M)); -- 1 = 1*1

      -- iterate over powers of primitive element
      for i in 1 to 2**M-2 loop
        index_elem  := prim_elem_exp(i, GF_POLYNOMIAL);
        value_elem  := prim_elem_exp(2**M-1-i, GF_POLYNOMIAL);
        ret(to_integer(unsigned(index_elem))) := value_elem;
      end loop;

    elsif TABLE_TYPE = LOG_TABLE_TYPE then
      ret(0)        := (OTHERS => '0'); -- logarithm of 0 not defined

      -- iterate over powers of primitive element
      for i in 0 to 2**M-2 loop
        index_elem  := prim_elem_exp(i, GF_POLYNOMIAL);
        value_elem  := std_logic_vector(to_unsigned(i,M));
        ret(to_integer(unsigned(index_elem))) := value_elem;
      end loop;

    elsif TABLE_TYPE = EXP_TABLE_TYPE then

      -- iterate over powers of primitive element
      for i in 0 to 2**M-1 loop
        index_elem  := std_logic_vector(to_unsigned(i,M));
        value_elem  := prim_elem_exp(i, GF_POLYNOMIAL);
        ret(to_integer(unsigned(index_elem))) := value_elem;
      end loop;
    end if;

    return ret;
  end function gen_table;

  constant table  : table_t := gen_table;

begin
  process(clk)
  begin
    if rising_edge(clk) then
      elem_out <= table(to_integer(unsigned(elem_in)));
    end if;
  end process;
end rtl;
