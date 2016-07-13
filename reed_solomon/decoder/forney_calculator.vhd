------------------------------------------------------------
-- Forney's algorithm calculator for finding error-values --
------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity forney_calculator is
  generic (
    GF_POLYNOMIAL             : std_logic_vector  := BINARY_POLYNOMIAL_G709_GF; -- irreducible, binary polynomial
    NO_OF_CORRECTABLE_ERRORS  : natural           := 3                          -- number of correctable errors
  );
  port (
    clock               : in  std_logic;
    reset               : in  std_logic;
    new_calculation     : in  std_logic;
    error_roots         : in  std_logic_vector(NO_OF_CORRECTABLE_ERRORS*(GF_POLYNOMIAL'length-1)-1 downto 0);    -- highest order coefficient at MSBs, descending
    error_locations     : in  std_logic_vector(NO_OF_CORRECTABLE_ERRORS*(GF_POLYNOMIAL'length-1)-1 downto 0);    -- highest order coefficient at MSBs, descending
    error_evaluator     : in  std_logic_vector(NO_OF_CORRECTABLE_ERRORS*(GF_POLYNOMIAL'length-1)-1 downto 0);  -- highest order coefficient at MSBs, descending
    error_values        : out std_logic_vector(NO_OF_CORRECTABLE_ERRORS*(GF_POLYNOMIAL'length-1)-1 downto 0);    -- highest order coefficient at MSBs, descending
    ready               : out std_logic
  );
end entity;

architecture rtl of forney_calculator is
  constant M  : natural := GF_POLYNOMIAL'length-1;

  subtype gf_elem is std_logic_vector(M-1 downto 0);
  type gf_array_desc_t is array(natural range <>) of gf_elem;
  type calculator_state is (IDLE, CALCULATING);

  constant GF_ZERO  : gf_elem := (OTHERS => '0');
  constant GF_ONE   : gf_elem := (0 => '1', OTHERS => '0');

  constant NO_OF_COEFFICIENTS  : natural := 1;

  signal state                        : calculator_state;
  signal error_evaluator_registers    : std_logic_vector(NO_OF_CORRECTABLE_ERRORS*M-1 downto 0);
  signal error_roots_registers        : std_logic_vector(NO_OF_CORRECTABLE_ERRORS*M-1 downto 0);
  signal error_locations_registers    : std_logic_vector(NO_OF_CORRECTABLE_ERRORS*M-1 downto 0);
  signal error_values_registers       : gf_array_desc_t(NO_OF_CORRECTABLE_ERRORS-1 downto 0);
  signal error_evaluator_coefficients : std_logic_vector(NO_OF_COEFFICIENTS*M-1 downto 0);
  signal numerator_values             : std_logic_vector(NO_OF_CORRECTABLE_ERRORS*M-1 downto 0);
  signal numerator_values_latch       : std_logic_vector(NO_OF_CORRECTABLE_ERRORS*M-1 downto 0);
  signal denominator_values           : std_logic_vector(NO_OF_CORRECTABLE_ERRORS*M-1 downto 0);
  signal denominator_products         : std_logic_vector(NO_OF_CORRECTABLE_ERRORS*M-1 downto 0);
  signal denominator_values_latch     : std_logic_vector(NO_OF_CORRECTABLE_ERRORS*M-1 downto 0);
  signal term_product                 : gf_elem;
  signal error_eval_shift_count       : natural range 0 to (NO_OF_CORRECTABLE_ERRORS)/NO_OF_COEFFICIENTS;
  signal numerator_values_ready       : std_logic;
  signal denominator_values_ready     : std_logic;
  signal new_numerator_calculation    : std_logic;
  signal clock_enable                 : std_logic;

begin

  ------------------------------
  -- Component instantiations --
  ------------------------------

  numerator_calculator : entity work.gf_horner_evaluator(rtl)
    generic map (
      GF_POLYNOMIAL               => GF_POLYNOMIAL,
      NO_OF_PARALLEL_EVALUATIONS  => NO_OF_CORRECTABLE_ERRORS,
      NO_OF_COEFFICIENTS          => NO_OF_COEFFICIENTS,
      SYMBOL_WIDTH                => M
    )
    port map (
      clock             => clock,
      reset             => reset,
      clock_enable      => clock_enable,
      new_calculation   => new_numerator_calculation,
      coefficients      => error_evaluator_coefficients,
      evaluation_values => error_roots_registers,
      start_values      => (OTHERS => '0'),
      result_values     => numerator_values
    );

  -- generate two multipliers per error_location
  gen_denominator_multipliers : for i in 1 to NO_OF_CORRECTABLE_ERRORS generate
  begin
    feedback_multiplier : entity work.gf_multiplier(rtl)
      generic map (
        GF_POLYNOMIAL => GF_POLYNOMIAL
      )
      port map (
        multiplicand_a  => denominator_values(denominator_values'high-(i-1)*M downto denominator_values'length-i*M),
        multiplicand_b  => term_product,
        product         => denominator_products(denominator_products'high-(i-1)*M downto denominator_products'length-i*M)
      );

    term_multiplier : entity work.gf_multiplier(rtl)
      generic map (
        GF_POLYNOMIAL => GF_POLYNOMIAL
      )
      port map (
        multiplicand_a  => error_roots_registers(error_roots_registers'high-(i-1)*M downto error_roots_registers'length-(i)*M),
        multiplicand_b  => error_locations_registers(error_locations_registers'high-(i-1)*M downto error_locations_registers'length-i*M),
        product         => term_product
      );
  end generate gen_denominator_multipliers;

  ---------------
  -- Processes --
  ---------------

  clock_process : process(clock, reset)
  begin
    if reset = '1' then
      state                     <= IDLE;
      ready                     <= '0';
      clock_enable              <= '0';
      new_numerator_calculation <= '0';
      numerator_values_ready    <= '0';
      denominator_values_ready  <= '0';
      error_roots_registers     <= (OTHERS => '0');
      error_locations_registers <= (OTHERS => '0');
      error_evaluator_registers <= (OTHERS => '0');
      error_values_registers    <= (OTHERS => GF_ZERO);
      error_values              <= (OTHERS => '0');
      numerator_values_latch    <= (OTHERS => '0');
      denominator_values_latch  <= (OTHERS => '0');
      error_eval_shift_count    <= 0;

    elsif rising_edge(clock) then
      ready <= '0';
      new_numerator_calculation <= '0';
      error_values <= (OTHERS => '0');

      -- shift error_evaluator_registers registers
      error_evaluator_registers <= (OTHERS => '0');
      error_evaluator_registers(error_evaluator_registers'high(1) downto M*NO_OF_COEFFICIENTS) <= error_evaluator_registers(error_evaluator_registers'high(1)-M*NO_OF_COEFFICIENTS downto 0); -- shift left

      if state = CALCULATING then

        if numerator_values_ready = '0' and error_eval_shift_count = NO_OF_CORRECTABLE_ERRORS/NO_OF_COEFFICIENTS then
          numerator_values_latch <= numerator_values;
          error_eval_shift_count <= 1;
          numerator_values_ready <= '1';
          state <= IDLE; -- TODO: don't go idle until entire calculations is over
        else
          error_eval_shift_count <= error_eval_shift_count + 1;
        end if;

        if denominator_values_ready = '0' then -- TODO: check for number of shifts
          -- shift error locations left 1 position
          error_locations_registers <= error_locations(error_locations'high-M downto 0) & error_locations(error_locations'high downto error_locations'length-M);
          denominator_values <= denominator_products;
        end if;
      end if;

      -- if new input is given then reset calculation
      if new_calculation = '1' then
        -- read in new data; start calculation

        -- Reverse error evaluator polynomial 
        for i in 0 to NO_OF_CORRECTABLE_ERRORS-1 loop
          error_evaluator_registers((NO_OF_CORRECTABLE_ERRORS-i)*M-1 downto (NO_OF_CORRECTABLE_ERRORS-i-1)*M) <= error_evaluator((i+1)*M-1 downto i*M);
        end loop;

        error_roots_registers <= error_roots;

        error_values_registers <= (OTHERS => GF_ZERO);
        ready <= '0';
        clock_enable <= '1';
        new_numerator_calculation <= '1';
        error_eval_shift_count <= 0;
        state <= CALCULATING;

        -- shift error locations left 1 position to begin with
        error_locations_registers <= error_locations(error_locations'high-M downto 0) & error_locations(error_locations'high downto error_locations'length-M);
        denominator_values  <= error_locations;
      end if;

      -- set output and ready when calculation is over
      if state = IDLE then
        ready <= '1';

        for i in error_values_registers'range(1) loop
          error_values((i+1)*M-1 downto i*M) <= error_values_registers(i);
        end loop;
      end if;
    end if;
  end process clock_process;

  -- drive input coefficients signal to gf_horner_evaluator
  error_evaluator_coefficients <= error_evaluator_registers(error_evaluator_registers'high(1) downto error_evaluator_registers'length(1)-M*NO_OF_COEFFICIENTS); -- coefficients in MSBs

end rtl;
