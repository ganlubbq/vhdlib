------------------------------------------------------------------
-- Polynomial evaluation over GF(2^M) by use of Horner's scheme --
------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity gf_horner_evaluator is
  generic (
    GF_POLYNOMIAL   : std_logic_vector  := BINARY_POLYNOMIAL_G709_GF; -- irreducible, binary polynomial.
    NO_OF_PAR_EVALS : natural           := 3;                         -- number of polynomial evaluations done in parallel.
                                                                      -- if syndromes are to be calculated the eval_values signal should contain
                                                                      -- the values alpha^1 through alpha^NO_OF_PAR_EVALS are used for evaluation.
    NO_OF_COEFS     : natural           := 3;                         -- number of coefficient symbols to process at a time; must divide polynomial (i.e. 0 remainder).
    SYMBOL_WIDTH    : natural           := 8                          -- size of polynomial coefficient symbols.
  );
  port (
    clock           : in  std_logic;
    reset           : in  std_logic;
    clock_enable    : in  std_logic;
    new_calculation : in  std_logic;
    coefficients    : in  std_logic_vector(NO_OF_COEFS*SYMBOL_WIDTH-1 downto 0);                  -- polynomial coefficients; highest order symbol on MSBs, descending
    eval_values     : in  std_logic_vector(NO_OF_PAR_EVALS*(GF_POLYNOMIAL'length-1)-1 downto 0);
    start_values    : in  std_logic_vector(NO_OF_PAR_EVALS*(GF_POLYNOMIAL'length-1)-1 downto 0);
    result_values   : out std_logic_vector(NO_OF_PAR_EVALS*(GF_POLYNOMIAL'length-1)-1 downto 0)
  );
end entity;

architecture rtl of gf_horner_evaluator is
  constant M  : natural := GF_POLYNOMIAL'length-1;

  subtype gf_element    is std_logic_vector(M-1 downto 0);
  type connection_array is array(1 to NO_OF_PAR_EVALS, 1 to NO_OF_COEFS) of gf_element;
  type gf_element_array is array(1 to NO_OF_PAR_EVALS) of gf_element;

  constant GF_ZERO  : gf_element := (OTHERS => '0');

  signal connections        : connection_array;
  signal result_value_regs  : gf_element_array;
  signal eval_value_wires   : gf_element_array;

begin

  -- Horner scheme multipliers
  generate_parallel_evaluations : for j in 1 to NO_OF_PAR_EVALS generate
  begin
    generate_horner_multipliers : for i in 0 to NO_OF_COEFS-1 generate
    begin
      generate_top_multipliers : if i = 0 generate
      begin
        horner_multiplier : entity work.gf_horner_multiplier(rtl)
          generic map (
            GF_POLYNOMIAL => GF_POLYNOMIAL,
            SYMBOL_WIDTH  => SYMBOL_WIDTH
          )
          port map (
            coefficient => coefficients(coefficients'high downto coefficients'length-SYMBOL_WIDTH),
            eval_value  => eval_values(eval_values'high-(j-1)*M downto eval_values'length-(j)*M),
            product_in  => eval_value_wires(j),
            product_out => connections(j,i+1)
          );
      end generate generate_top_multipliers;

      generate_lower_multipliers : if i > 0 generate
      begin
        horner_multiplier : entity work.gf_horner_multiplier(rtl)
          generic map (
            GF_POLYNOMIAL => GF_POLYNOMIAL,
            SYMBOL_WIDTH  => SYMBOL_WIDTH
          )
          port map (
            coefficient => coefficients(coefficients'high-i*SYMBOL_WIDTH downto coefficients'length-(i+1)*SYMBOL_WIDTH),
            eval_value  => eval_values(eval_values'high-(j-1)*M downto eval_values'length-(j)*M),
            product_in  => connections(j,i),
            product_out => connections(j,i+1)
          );
      end generate generate_lower_multipliers;
    end generate generate_horner_multipliers;
  end generate generate_parallel_evaluations;

  clock_process : process (clock, reset)
  begin
    if reset = '1' then
      result_value_regs <= (OTHERS => GF_ZERO);
    elsif rising_edge(clock) then
      if clock_enable = '1' then
        for i in 1 to NO_OF_PAR_EVALS loop
          result_value_regs(i)  <= connections(i,NO_OF_COEFS);
        end loop;
      end if;
    end if;
  end process clock_process;

  combinational_process : process(result_value_regs, new_calculation, start_values)
  begin
    for i in 1 to NO_OF_PAR_EVALS loop
      if new_calculation = '1' then
        eval_value_wires(i) <= start_values(start_values'high-(i-1)*M downto start_values'length-i*M);
      else
        eval_value_wires(i) <= result_value_regs(i);
      end if;

      -- output
      result_values(result_values'high-(i-1)*M downto result_values'length-i*M) <= result_value_regs(i);
    end loop;
  end process combinational_process;

end rtl;
