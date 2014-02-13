--------------------------------------
-- GF(2^M) Horner scheme multiplier --
--------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity gf_horner_multiplier is
  generic (
    GF_POLYNOMIAL : std_logic_vector  := G709_GF_POLY;  -- irreducible, binary polynomial
    PRIM_ELEM_POW : natural           := 1;             -- exponent of primitive element of GF(2^M)
    SYMBOL_WIDTH  : natural           := 8              -- size of codeword coefficients
  );
  port (
    coefficient : in  std_logic_vector(SYMBOL_WIDTH-1 downto 0);          -- coefficient of polynomial being evaluated
    eval_value  : in  std_logic_vector(GF_POLYNOMIAL'length-2 downto 0);  -- value that the polynomial is evaluated over
    product_in  : in  std_logic_vector(GF_POLYNOMIAL'length-2 downto 0);  -- output from last iteration
    product_out : out std_logic_vector(GF_POLYNOMIAL'length-2 downto 0)   -- output of this iteration
  );
end entity;

architecture rtl of gf_horner_multiplier is

  constant M          : natural                         := GF_POLYNOMIAL'length-1;
  constant PRIM_ELEM  : std_logic_vector(M-1 downto 0)  := prim_elem_exp(PRIM_ELEM_POW, GF_POLYNOMIAL);

  signal product          : std_logic_vector(M-1 downto 0);
  signal coefficient_pad  : std_logic_vector(M-1 downto 0);

begin

  gen_dyn_multiplier : if PRIM_ELEM_POW = 0 generate
    -- the value to evaluate the polynomial over can change
    gf_mul : entity work.gf_multiplier(rtl)
      generic map (
        GF_POLYNOMIAL => GF_POLYNOMIAL
      )
      port map (
        mul_a   => eval_value,
        mul_b   => product_in,
        product => product
      );
  end generate gen_dyn_multiplier;

  gen_const_multiplier : if PRIM_ELEM_POW > 0 generate
    -- the value to evaluate the polynomial over is constant
    gf_mul : entity work.gf_multiplier(rtl)
      generic map (
        GF_POLYNOMIAL => GF_POLYNOMIAL
      )
      port map (
        mul_a   => PRIM_ELEM,
        mul_b   => product_in,
        product => product
      );
  end generate gen_const_multiplier;

  pad_proc : process (coefficient)
  begin
    coefficient_pad                     <= (OTHERS => '0');
    coefficient_pad(coefficient'range)  <= coefficient;
  end process pad_proc;

  product_out <= product XOR coefficient_pad;

end rtl;
