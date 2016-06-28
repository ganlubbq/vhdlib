------------------------------------------------------------
-- Forney's algorithm calculator for finding error-values --
------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity forney_calculator is
  generic (
    GF_POLYNOMIAL   : std_logic_vector  := BINARY_POLYNOMIAL_G709_GF; -- irreducible, binary polynomial
    NO_OF_CORR_ERRS : natural           := 3                          -- number of correctable errors
  );
  port (
    clock               : in  std_logic;
    reset               : in  std_logic;
    new_calculation     : in  std_logic;
    error_roots_in      : in  std_logic_vector(NO_OF_CORR_ERRS*(GF_POLYNOMIAL'length-1)-1 downto 0);    -- highest order coefficient at MSBs, descending
    error_locations_in  : in  std_logic_vector(NO_OF_CORR_ERRS*(GF_POLYNOMIAL'length-1)-1 downto 0);    -- highest order coefficient at MSBs, descending
    error_eval_in       : in  std_logic_vector(2*NO_OF_CORR_ERRS*(GF_POLYNOMIAL'length-1)-1 downto 0);  -- highest order coefficient at MSBs, descending
    error_values_out    : out std_logic_vector(NO_OF_CORR_ERRS*(GF_POLYNOMIAL'length-1)-1 downto 0);    -- highest order coefficient at MSBs, descending
    ready               : out std_logic
  );
end entity;

architecture rtl of forney_calculator is
  constant M  : natural := GF_POLYNOMIAL'length-1;

  subtype gf_elem is std_logic_vector(M-1 downto 0);
  type gf_array_desc_t is array(natural range <>) of gf_elem;
  type calculator_state_t is (IDLE, CALCULATING);

  constant GF_ZERO  : gf_elem := (OTHERS => '0');
  constant GF_ONE   : gf_elem := (0 => '1', OTHERS => '0');

  constant NO_OF_COEFFICIENTS  : natural := 1;

  signal calculator_state           : calculator_state_t;
  signal error_eval                 : std_logic_vector(2*NO_OF_CORR_ERRS*M-1 downto 0);
  signal error_roots                : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
  signal error_locations            : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
  signal error_values               : gf_array_desc_t(NO_OF_CORR_ERRS-1 downto 0);
  signal error_eval_coefficients           : std_logic_vector(NO_OF_COEFFICIENTS*M-1 downto 0);
  signal numerator_values           : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
  signal numerator_values_latch     : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
  signal denominator_values         : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
  signal denominator_products       : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
  signal denominator_values_latch   : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
  signal term_product               : gf_elem;
  signal error_eval_shift_count     : natural range 0 to (2*NO_OF_CORR_ERRS)/NO_OF_COEFFICIENTS;
  signal new_numerator_calculation  : std_logic;
  signal clock_enable               : std_logic;

begin

  ------------------------------
  -- Component instantiations --
  ------------------------------

  numerator_calculator : entity work.gf_horner_evaluator(rtl)
    generic map (
      GF_POLYNOMIAL   => GF_POLYNOMIAL,
      NO_OF_PAR_EVALS => NO_OF_CORR_ERRS,
      NO_OF_COEFFICIENTS     => NO_OF_COEFFICIENTS,
      SYMBOL_WIDTH    => M
    )
    port map (
      clock           => clock,
      reset           => reset,
      clock_enable    => clock_enable,
      new_calculation => new_numerator_calculation,
      coefficients    => error_eval_coefficients,
      eval_values     => error_roots,
      start_values    => (OTHERS => '0'),
      result_values   => numerator_values
    );

  -- generate two multipliers per error_location
  gen_denominator_multipliers : for i in 1 to NO_OF_CORR_ERRS generate
  begin
    feedback_multiplier : entity work.gf_multiplier(rtl)
      generic map (
        GF_POLYNOMIAL => GF_POLYNOMIAL
      )
      port map (
        mul_a   => denominator_values(denominator_values'high-(i-1)*M downto denominator_values'length-i*M),
        mul_b   => term_product,
        product => denominator_products(denominator_products'high-(i-1)*M downto denominator_products'length-i*M)
      );

    term_multiplier : entity work.gf_multiplier(rtl)
      generic map (
        GF_POLYNOMIAL => GF_POLYNOMIAL
      )
      port map (
        mul_a   => error_roots(error_roots'high-(i-1)*M downto error_roots'length-(i)*M),
        mul_b   => error_locations(error_locations'high-(i-1)*M downto error_locations'length-i*M),
        product => term_product
      );
  end generate gen_denominator_multipliers;

  ---------------
  -- Processes --
  ---------------

  clock_process : process(clock, reset)
  begin
    if reset = '1' then
      calculator_state          <= IDLE;
      ready                     <= '0';
      clock_enable              <= '0';
      new_numerator_calculation <= '0';
      error_roots               <= (OTHERS => '0');
      error_locations           <= (OTHERS => '0');
      error_eval                <= (OTHERS => '0');
      error_values              <= (OTHERS => GF_ZERO);
      error_values_out          <= (OTHERS => '0');
      numerator_values_latch    <= (OTHERS => '0');
      denominator_values_latch  <= (OTHERS => '0');
      error_eval_shift_count    <= 0;

    elsif rising_edge(clock) then
      -- preassignments
      ready <= '0';
      new_numerator_calculation <= '0';
      error_values_out <= (OTHERS => '0');

      -- shift error_eval registers
      error_eval <= (OTHERS => '0');
      error_eval(error_eval'high(1) downto M*NO_OF_COEFFICIENTS) <= error_eval(error_eval'high(1)-M*NO_OF_COEFFICIENTS downto 0); -- shift left

      if calculator_state = CALCULATING then

        if numerator_values_ready = '0' and error_eval_shift_count = (2*NO_OF_CORR_ERRS)/NO_OF_COEFFICIENTS then
          numerator_values_latch <= numerator_values;
          error_eval_shift_count <= 1;
          numerator_values_ready <= '1';
          calculator_state <= IDLE; -- TODO: don't go idle until entire calculations is over
        else
          error_eval_shift_count <= error_eval_shift_count + 1;
        end if;

        if denominator_values_ready = '0' begin -- TODO: check for number of shifts
          -- shift error locations left 1 position
          error_locations <= error_locations_in(error_locations_in'high-M downto 0) &
                             error_locations_in(error_locations_in'high downto error_locations_in'length-M);
          denominator_values <= denominator_products;
        end
      end if;

      -- if new input is given then reset calculation
      if new_calculation = '1' then
        -- read in new data; start calculation
        error_eval <= error_eval_in;
        error_roots <= error_roots_in;

        error_values <= (OTHERS => GF_ZERO);
        ready <= '0';
        clock_enable <= '1';
        new_numerator_calculation <= '1';
        error_eval_shift_count <= 0;
        calculator_state <= CALCULATING;

        -- shift error locations left 1 position to begin with
        error_locations     <= error_locations_in(error_locations_in'high-M downto 0) &
                               error_locations_in(error_locations_in'high downto error_locations_in'length-M);
        denominator_values  <= error_locations_in;
      end if;

      -- set output and ready when calculation is over
      if calculator_state = IDLE then
        ready <= '1';

        for i in error_values'range(1) loop
          error_values_out((i+1)*M-1 downto i*M)  <= error_values(i);
        end loop;
      end if;
    end if;
  end process clock_process;

  -- drive input coefficients signal to gf_horner_evaluator
  error_eval_coefficients <= error_eval(error_eval'high(1) downto error_eval'length(1)-M*NO_OF_COEFFICIENTS); -- coefficients in MSBs

end rtl;
