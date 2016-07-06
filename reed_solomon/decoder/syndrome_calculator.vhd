------------------------------------------------
-- Syndrome calculator for Reed-Solomon codes --
------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity syndrome_calculator is
  generic (
    -- Irreducible, binary polynomial
    GF_POLYNOMIAL : std_logic_vector := BINARY_POLYNOMIAL_G709_GF;

    -- Number of coefficient symbols to process at a time. 
    -- Must divide polynomial degree (i.e. 0 remainder).
    NO_OF_COEFFICIENTS : natural := 3;

    -- Number of syndromes to calculate.
    NO_OF_SYNDROMES : natural := 6
  );
  port (
    clock           : in  std_logic;
    reset           : in  std_logic;
    clock_enable    : in  std_logic;
    new_calculation : in  std_logic;
    coefficients    : in  std_logic_vector(NO_OF_COEFFICIENTS*(GF_POLYNOMIAL'length-1)-1 downto 0);      -- polynomial coefficients; highest order symbol on MSBs, descending
    syndromes       : out std_logic_vector(NO_OF_SYNDROMES*(GF_POLYNOMIAL'length-1)-1 downto 0)
  );
end entity;

architecture rtl of syndrome_calculator is
  constant M  : natural := GF_POLYNOMIAL'length-1;

  -- generate the values of alpha^1 through alpha^NO_OF_SYNDROMES
  function generate_alpha_powers return std_logic_vector is
    variable alpha_powers : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0);
  begin
    for i in 1 to NO_OF_SYNDROMES loop
      alpha_powers(alpha_powers'high-(i-1)*M downto alpha_powers'length-i*M) := primitive_element_exponentiation(i, GF_POLYNOMIAL);
    end loop;

    return alpha_powers;
  end function generate_alpha_powers;

  constant alpha_powers : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0) := generate_alpha_powers;

begin

  ------------------------------
  -- Component instantiations --
  ------------------------------

  gf_horner_evaluator : entity work.gf_horner_evaluator(rtl)
    generic map (
      GF_POLYNOMIAL               => GF_POLYNOMIAL,
      NO_OF_PARALLEL_EVALUATIONS  => NO_OF_SYNDROMES,
      NO_OF_COEFFICIENTS          => NO_OF_COEFFICIENTS,
      SYMBOL_WIDTH                => M
    )
    port map (
      clock             => clock,
      reset             => reset,
      clock_enable      => clock_enable,
      new_calculation   => new_calculation,
      coefficients      => coefficients,
      evaluation_values => alpha_powers,
      start_values      => (OTHERS => '0'),
      result_values     => syndromes
    );
end rtl;
