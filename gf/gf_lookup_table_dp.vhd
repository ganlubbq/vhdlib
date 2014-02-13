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
    GF_POLYNOMIAL   : std_logic_vector := G709_GF_POLY; -- irreducible, binary polynomial
    TABLE_TYPE      : string           := INV_TABLE_TYPE
  );
  port (
    clk             : in  std_logic;
    elem_in_a       : in  std_logic_vector(GF_POLYNOMIAL'length-2 downto 0);
    elem_in_b       : in  std_logic_vector(GF_POLYNOMIAL'length-2 downto 0);
    elem_out_a      : out std_logic_vector(GF_POLYNOMIAL'length-2 downto 0);
    elem_out_b      : out std_logic_vector(GF_POLYNOMIAL'length-2 downto 0)
  );

end entity;

architecture rtl of gf_lookup_table_dp is
  constant M      : natural := GF_POLYNOMIAL'length-1;

  -- ROM table type
  type table_t is array(0 to 2**M-1) of std_logic_vector(M-1 downto 0);

  -- function to generate table contents
  function gen_table return table_t is
    variable index_elem     : std_logic_vector(M-1 downto 0);
    variable value_elem     : std_logic_vector(M-1 downto 0);
    variable tmp_log_table  : table_t;
    variable ret            : table_t;
  begin

    if TABLE_TYPE = INV_TABLE_TYPE then
      ret(0)  := (OTHERS => '0');                     -- inverse of 0 not defined
      ret(1)  := std_logic_vector(to_unsigned(1,M));  -- 1 = 1*1

      for i in 1 to 2**M-2 loop
        index_elem  := prim_elem_exp(i, GF_POLYNOMIAL);         -- alpha^i
        value_elem  := prim_elem_exp(2**M-1-i, GF_POLYNOMIAL);  -- alpha^(2^M-1-i)
        ret(to_integer(unsigned(index_elem))) := value_elem;    -- alpha^i -> alpha^(2^M-1-i)
      end loop;
    end if;

    if TABLE_TYPE = LOG_TABLE_TYPE then
      ret(0)  := (OTHERS => '0'); -- logarithm of 0 not defined

      for i in 0 to 2**M-2 loop
        index_elem  := prim_elem_exp(i, GF_POLYNOMIAL);       -- alpha^i
        value_elem  := std_logic_vector(to_unsigned(i,M));    -- i
        ret(to_integer(unsigned(index_elem))) := value_elem;  -- alpha^i -> i
      end loop;
    end if;

    if TABLE_TYPE = EXP_TABLE_TYPE then
      for i in 0 to 2**M-1 loop
        index_elem  := std_logic_vector(to_unsigned(i,M));    -- i
        value_elem  := prim_elem_exp(i, GF_POLYNOMIAL);       -- alpha^i
        ret(to_integer(unsigned(index_elem))) := value_elem;  -- i -> alpha^i
      end loop;
    end if;

    if TABLE_TYPE = ZECH_LOG_TABLE_TYPE then
      -- first generate temporary logarithm table
      tmp_log_table(0)  := (OTHERS => '0'); -- logarithm of 0 not defined

      for i in 0 to 2**M-2 loop
        index_elem  := prim_elem_exp(i, GF_POLYNOMIAL);                 -- alpha^i
        value_elem  := std_logic_vector(to_unsigned(i,M));              -- i
        tmp_log_table(to_integer(unsigned(index_elem))) := value_elem;  -- alpha^i -> i
      end loop;

      -- now generate the actual Zech's logarithm table
      ret(0)      := (OTHERS => '1'); -- Z(0) = -infinity
      ret(2**M-1) := (OTHERS => '0'); -- Z(-infinity) = 0

      -- calculate alpha^i + 1 and look up log(alpha^i + 1) in the temporary table
      for i in 1 to 2**M-2 loop
        index_elem    := std_logic_vector(to_unsigned(i,M));              -- i
        value_elem    := prim_elem_exp(i, GF_POLYNOMIAL);                 -- alpha^i
        value_elem(0) := value_elem(0) xor '1';                           -- alpha^i + 1
        value_elem    := tmp_log_table(to_integer(unsigned(value_elem))); -- log(alpha^i + 1)
        ret(to_integer(unsigned(index_elem))) := value_elem;              -- i -> log(alpha^i + 1)
      end loop;
    end if;

    return ret;
  end function gen_table;

  constant table  : table_t := gen_table;

begin
  process(clk)
  begin
    if rising_edge(clk) then
      elem_out_a <= table(to_integer(unsigned(elem_in_a)));
      elem_out_b <= table(to_integer(unsigned(elem_in_b)));
    end if;
  end process;
end rtl;
