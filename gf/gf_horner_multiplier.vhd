--------------------------------------
-- GF(2^M) Horner scheme multiplier --
--------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity gf_horner_multiplier is
  generic (
    GF_POLYNOMIAL : std_logic_vector  := BINARY_POLYNOMIAL_G709_GF; -- irreducible, binary polynomial
    SYMBOL_WIDTH  : natural           := 8                          -- size of polynomial coefficients
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

  signal product          : std_logic_vector(M-1 downto 0);
  signal coefficient_pad  : std_logic_vector(M-1 downto 0);

begin

  -- a GF(2^M) multiplier
  gf_mul : entity work.gf_multiplier(rtl)
    generic map (
      GF_POLYNOMIAL => GF_POLYNOMIAL
    )
    port map (
      mul_a   => eval_value,
      mul_b   => product_in,
      product => product
    );

  pad_proc : process (coefficient)
  begin
    coefficient_pad                     <= (OTHERS => '0');
    coefficient_pad(coefficient'range)  <= coefficient;
  end process pad_proc;

  product_out <= product XOR coefficient_pad;

end rtl;
