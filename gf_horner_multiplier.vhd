---------------------------------
-- GF Horner scheme multiplier --
---------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity gf_horner_multiplier is
  generic (
    GF_POLYNOMIAL : std_logic_vector  := G709_GF_POLY;  -- irreducible, binary polynomial
    PRIM_ELEM_POW : integer           := 1;             -- exponent of primitive element of GF(2^M)
    SYMBOL_WIDTH  : integer           := 8              -- size of codeword coefficients
  );
  port (
    symbol        : in  std_logic_vector(SYMBOL_WIDTH-1 downto 0);
    product_in    : in  std_logic_vector(GF_POLYNOMIAL'length-2 downto 0);
    product_out   : out std_logic_vector(GF_POLYNOMIAL'length-2 downto 0)
  );
end entity;

architecture rtl of gf_horner_multiplier is

  constant M          : integer                         := GF_POLYNOMIAL'length-1;
  constant PRIM_ELEM  : std_logic_vector(M-1 downto 0)  := prim_elem_exp(PRIM_ELEM_POW, GF_POLYNOMIAL);

  signal product      : std_logic_vector(M-1 downto 0);
  signal symbol_pad   : std_logic_vector(M-1 downto 0);

begin

  gf_mul : entity work.gf_multiplier(rtl)
    generic map (
      GF_POLYNOMIAL  => GF_POLYNOMIAL
    )
    port map (
      mul_a       => PRIM_ELEM,
      mul_b       => product_in,
      product     => product
    );

  pad_proc : process (symbol)
  begin
    symbol_pad                <= (OTHERS => '0');
    symbol_pad(symbol'range)  <= symbol;
  end process pad_proc;

  product_out <= product XOR symbol_pad;

end rtl;
