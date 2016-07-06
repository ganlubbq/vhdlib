------------------------------------------------------------------
-- Polynomial evaluation over GF(2^M) by use of Horner's scheme --
------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity gf_horner_evaluator is
  generic ( 
    -- Urreducible, binary polynomial.
    GF_POLYNOMIAL : std_logic_vector := BINARY_POLYNOMIAL_G709_GF;

    -- Number of polynomial evaluations done in parallel.
    -- If syndromes are to be calculated the evaluation_values signal should contain
    -- the values alpha^1 through alpha^NO_OF_PARALLEL_EVALUATIONS are used for evaluation.
    NO_OF_PARALLEL_EVALUATIONS : natural := 3;

    -- Number of coefficient symbols to process at a time; must divide polynomial degree (i.e. 0 remainder).
    NO_OF_COEFFICIENTS : natural := 3;

    -- Size of polynomial coefficient symbols.
    SYMBOL_WIDTH : natural := 8
  );
  port (
    clock           : in  std_logic;
    reset           : in  std_logic;
    clock_enable    : in  std_logic;
    new_calculation : in  std_logic;                     

    -- polynomial coefficients; highest order symbol on MSBs, descending.
    coefficients      : in  std_logic_vector(NO_OF_COEFFICIENTS*SYMBOL_WIDTH-1 downto 0);
    evaluation_values : in  std_logic_vector(NO_OF_PARALLEL_EVALUATIONS*(GF_POLYNOMIAL'length-1)-1 downto 0);
    start_values      : in  std_logic_vector(NO_OF_PARALLEL_EVALUATIONS*(GF_POLYNOMIAL'length-1)-1 downto 0);
    result_values     : out std_logic_vector(NO_OF_PARALLEL_EVALUATIONS*(GF_POLYNOMIAL'length-1)-1 downto 0)
  );
end entity;

architecture rtl of gf_horner_evaluator is
  constant M  : natural := GF_POLYNOMIAL'length-1;

  subtype gf_element is std_logic_vector(M-1 downto 0);
  type connection_array is array(1 to NO_OF_PARALLEL_EVALUATIONS, 1 to NO_OF_COEFFICIENTS) of gf_element;
  type gf_element_array is array(1 to NO_OF_PARALLEL_EVALUATIONS) of gf_element;

  constant GF_ZERO  : gf_element := (OTHERS => '0');

  signal connections            : connection_array;
  signal result_value_registers : gf_element_array;
  signal evaluation_value_wires : gf_element_array;

begin

  -- Horner scheme multipliers
  generate_parallel_evaluations : for j in 1 to NO_OF_PARALLEL_EVALUATIONS generate
  begin
    generate_horner_multipliers : for i in 0 to NO_OF_COEFFICIENTS-1 generate
    begin
      generate_top_multipliers : if i = 0 generate
      begin
        horner_multiplier : entity work.gf_horner_multiplier(rtl)
          generic map (
            GF_POLYNOMIAL => GF_POLYNOMIAL,
            SYMBOL_WIDTH  => SYMBOL_WIDTH
          )
          port map (
            coefficient       => coefficients(coefficients'high downto coefficients'length-SYMBOL_WIDTH),
            evaluation_value  => evaluation_values(evaluation_values'high-(j-1)*M downto evaluation_values'length-(j)*M),
            product_in        => evaluation_value_wires(j),
            product_out       => connections(j,i+1)
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
            coefficient       => coefficients(coefficients'high-i*SYMBOL_WIDTH downto coefficients'length-(i+1)*SYMBOL_WIDTH),
            evaluation_value  => evaluation_values(evaluation_values'high-(j-1)*M downto evaluation_values'length-(j)*M),
            product_in        => connections(j,i),
            product_out       => connections(j,i+1)
          );
      end generate generate_lower_multipliers;
    end generate generate_horner_multipliers;
  end generate generate_parallel_evaluations;

  -- Capture intermediate results at each rising clock edge.
  clock_process : process (clock, reset)
  begin
    if reset = '1' then
      result_value_registers <= (OTHERS => GF_ZERO);
    elsif rising_edge(clock) then
      if clock_enable = '1' then
        for i in 1 to NO_OF_PARALLEL_EVALUATIONS loop
          result_value_registers(i)  <= connections(i,NO_OF_COEFFICIENTS);
        end loop;
      end if;
    end if;
  end process clock_process;

  -- When a new calculation starts the input to the multipliers must the start values.
  -- When continuing an ongoing calculation the input to the multipliers must be their output from the previous interation.
  combinational_process : process(result_value_registers, new_calculation, start_values)
  begin
    for i in 1 to NO_OF_PARALLEL_EVALUATIONS loop
      if new_calculation = '1' then
        evaluation_value_wires(i) <= start_values(start_values'high-(i-1)*M downto start_values'length-i*M);
      else
        evaluation_value_wires(i) <= result_value_registers(i);
      end if;

      -- Output
      result_values(result_values'high-(i-1)*M downto result_values'length-i*M) <= result_value_registers(i);
    end loop;
  end process combinational_process;

end rtl;
