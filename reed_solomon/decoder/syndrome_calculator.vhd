------------------------------------------------
-- Syndrome calculator for Reed-Solomon codes --
------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity syndrome_calculator is
  generic (
    GF_POLYNOMIAL   : std_logic_vector  := G709_GF_POLY;  -- irreducible, binary polynomial
    NO_OF_COEFS     : natural           := 3;             -- number of coefficient symbols to process at a time; must divide polynomial (i.e. 0 remainder).
    NO_OF_SYNDROMES : natural           := 6              -- number of syndromes to calculate
  );
  port (
    clk             : in  std_logic;
    rst             : in  std_logic;
    clk_enable      : in  std_logic;
    new_calc        : in  std_logic;
    coefficients    : in  std_logic_vector(NO_OF_COEFS*(GF_POLYNOMIAL'length-1)-1 downto 0);      -- polynomial coefficients; highest order symbol on MSBs, descending
    syndromes       : out std_logic_vector(NO_OF_SYNDROMES*(GF_POLYNOMIAL'length-1)-1 downto 0)
  );
end entity;

architecture rtl of syndrome_calculator is
  constant M  : natural := GF_POLYNOMIAL'length-1;

  -- generate the values of alpha^1 through alpha^NO_OF_SYNDROMES
  function gen_alpha_powers return std_logic_vector is
    variable ret_vec : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0);
  begin
    for i in 1 to NO_OF_SYNDROMES loop
      ret_vec(ret_vec'high-(i-1)*M downto ret_vec'length-i*M) :=  prim_elem_exp(i, GF_POLYNOMIAL);
    end loop;

    return ret_vec;
  end function gen_alpha_powers;

  constant alpha_powers : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0)  := gen_alpha_powers;

begin

  ------------------------------
  -- Component instantiations --
  ------------------------------

  gf_horner_evaluator : entity work.gf_horner_evaluator(rtl)
    generic map (
      GF_POLYNOMIAL   => GF_POLYNOMIAL,
      NO_OF_PAR_EVALS => NO_OF_SYNDROMES,
      NO_OF_COEFS     => NO_OF_COEFS,
      SYMBOL_WIDTH    => M
    )
    port map (
      clk           => clk,
      rst           => rst,
      clk_enable    => clk_enable,
      new_calc      => new_calc,
      coefficients  => coefficients,
      eval_values   => alpha_powers,
      start_values  => (OTHERS => '0'),
      result_values => syndromes
    );
end rtl;
