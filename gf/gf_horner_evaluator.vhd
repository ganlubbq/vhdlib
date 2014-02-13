------------------------------------------------------------------
-- Polynomial evaluation over GF(2^M) by use of Horner's scheme --
------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity gf_horner_evaluator is
  generic (
    GF_POLYNOMIAL   : std_logic_vector  := G709_GF_POLY;  -- irreducible, binary polynomial
    NO_OF_PAR_EVALS : natural           := 3;             -- number of polynomial evaluations done in parallel
    SYNDROME_CALC   : boolean           := FALSE;         -- if FALSE the values on signal eval_values are used for evaluation
                                                          -- if TRUE the values alpha^1 through alpha^NO_OF_PAR_EVALS are used for evaluation
    NO_OF_COEFFS    : natural           := 3;             -- number of coefficient symbols to process at a time
    SYMBOL_WIDTH    : natural           := 8              -- size of polynomial coefficient symbols
  );
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;
    clk_enable    : in  std_logic;
    new_calc      : in  std_logic;
    coefficients  : in  std_logic_vector(SYMBOL_WIDTH*NO_OF_COEFFS-1 downto 0);                 -- polynomial coefficients; highest order symbol on MSBs, descending
    eval_values   : in  std_logic_vector(NO_OF_PAR_EVALS*(GF_POLYNOMIAL'length-1)-1 downto 0);
    start_values  : in  std_logic_vector(NO_OF_PAR_EVALS*(GF_POLYNOMIAL'length-1)-1 downto 0);
    result_values : out std_logic_vector(NO_OF_PAR_EVALS*(GF_POLYNOMIAL'length-1)-1 downto 0)
  );
end entity;

architecture rtl of gf_horner_evaluator is
  constant M  : natural := GF_POLYNOMIAL'length-1;

  subtype gf_elem       is std_logic_vector(M-1 downto 0);
  type connections_t    is array(1 to NO_OF_PAR_EVALS, 1 to NO_OF_COEFFS) of gf_elem;
  type gf_elements_t    is array(1 to NO_OF_PAR_EVALS) of gf_elem;
  type prim_elem_pows_t is array(1 to NO_OF_PAR_EVALS) of natural;

  constant GF_ZERO  : gf_elem := (OTHERS => '0');

  signal connections      : connections_t;
  signal result_value_regs  : gf_elements_t;
  signal eval_value_wires   : gf_elements_t;
  signal prim_elem_pows     : prim_elem_pows_t;

begin

  -- Horner scheme multipliers
  gen_parallel_evaluations : for j in 1 to NO_OF_PAR_EVALS generate
  begin
    gen_coefficients : for i in 0 to NO_OF_COEFFS-1 generate
    begin
      gen_top_multipliers : if i = 0 generate
      begin
        horner_multiplier : entity work.gf_horner_multiplier(rtl)
          generic map (
            GF_POLYNOMIAL => GF_POLYNOMIAL,
            PRIM_ELEM_POW => j,
            SYMBOL_WIDTH  => SYMBOL_WIDTH
          )
          port map (
            coefficient => coefficients(coefficients'high downto coefficients'length-SYMBOL_WIDTH),
            eval_value  => eval_values(eval_values'high downto eval_values'length-M),
            product_in  => eval_value_wires(j),
            product_out => connections(j,i+1)
          );
      end generate gen_top_multipliers;

      gen_lower_multipliers : if i > 0 generate
      begin
        horner_multiplier : entity work.gf_horner_multiplier(rtl)
          generic map (
            GF_POLYNOMIAL => GF_POLYNOMIAL,
            PRIM_ELEM_POW => j,
            SYMBOL_WIDTH  => SYMBOL_WIDTH
          )
          port map (
            coefficient => coefficients(coefficients'high-i*SYMBOL_WIDTH downto coefficients'length-(i+1)*SYMBOL_WIDTH),
            eval_value  => eval_values(eval_values'high-i*M downto eval_values'length-(i+1)*M),
            product_in  => connections(j,i),
            product_out => connections(j,i+1)
          );
      end generate gen_lower_multipliers;
    end generate gen_coefficients;
  end generate gen_parallel_evaluations;

  clk_proc : process (clk, rst)
  begin
    if rst = '1' then
      result_value_regs <= (OTHERS => GF_ZERO);
    elsif rising_edge(clk) then
      if clk_enable = '1' then
        for i in 1 to NO_OF_PAR_EVALS loop
          result_value_regs(i)  <= connections(i,NO_OF_COEFFS);
        end loop;
      end if;
    end if;
  end process clk_proc;

  comb_proc : process(result_value_regs, new_calc, start_values)
  begin
    for i in 1 to NO_OF_PAR_EVALS loop
      if new_calc = '1' then
        eval_value_wires(i) <= start_values(start_values'high-(i-1)*M downto start_values'length-i*M);
      else
        eval_value_wires(i) <= result_value_regs(i);
      end if;

      -- output
      result_values(result_values'high-(i-1)*M downto result_values'length-i*M) <= result_value_regs(i);
    end loop;
  end process comb_proc;

end rtl;
