--------------------------------------
-- GF(2^M) Horner scheme multiplier --
--------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity gf_horner_multiplier is
  generic (
    -- Irreducible, binary polynomial.
    GF_POLYNOMIAL : std_logic_vector := BINARY_POLYNOMIAL_G709_GF;

    -- Size of polynomial coefficients.
    SYMBOL_WIDTH : natural := 8
  );
  port (
    -- Coefficient of the polynomial being evaluated.
    coefficient : in std_logic_vector(SYMBOL_WIDTH-1 downto 0);

    -- Value that the polynomial is evaluated over.
    evaluation_value : in std_logic_vector(GF_POLYNOMIAL'length-2 downto 0);
    
    -- Output from iteration N-1 fed back into the multiplier.
    product_in : in std_logic_vector(GF_POLYNOMIAL'length-2 downto 0);
    
    -- Output of iteration N.
    product_out : out std_logic_vector(GF_POLYNOMIAL'length-2 downto 0)
  );
end entity;

architecture rtl of gf_horner_multiplier is

  constant M : natural := GF_POLYNOMIAL'length-1;

  signal product            : std_logic_vector(M-1 downto 0);
  signal padded_coefficient : std_logic_vector(M-1 downto 0);

begin

  -- a GF(2^M) multiplier
  gf_mul : entity work.gf_multiplier(rtl)
    generic map (
      GF_POLYNOMIAL => GF_POLYNOMIAL
    )
    port map (
      multiplicand_a  => evaluation_value,
      multiplicand_b  => product_in,
      product         => product
    );


  -- Pad coefficient before outputting as it may not have same symbol width as the calculated product.
  padding_process : process (coefficient)
  begin
    padded_coefficient                     <= (OTHERS => '0');
    padded_coefficient(coefficient'range)  <= coefficient;
  end process padding_process;

  product_out <= product XOR padded_coefficient;

end rtl;
