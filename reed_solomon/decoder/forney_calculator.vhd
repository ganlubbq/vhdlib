------------------------------------------------------------
-- Forney's algorithm calculator for finding error-values --
------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity forney_calculator is
  generic (
    GF_POLYNOMIAL   : std_logic_vector  := G709_GF_POLY;  -- irreducible, binary polynomial
    NO_OF_CORR_ERRS : natural           := 3              -- number of correctable errors
  );
  port (
    clk               : in  std_logic;
    rst               : in  std_logic;
    new_calc          : in  std_logic;
    err_roots_in      : in  std_logic_vector(NO_OF_CORR_ERRS*(GF_POLYNOMIAL'length-1)-1 downto 0);    -- highest order coefficient at MSBs, descending
    err_locations_in  : in  std_logic_vector(NO_OF_CORR_ERRS*(GF_POLYNOMIAL'length-1)-1 downto 0);    -- highest order coefficient at MSBs, descending
    err_eval_in       : in  std_logic_vector(2*NO_OF_CORR_ERRS*(GF_POLYNOMIAL'length-1)-1 downto 0);  -- highest order coefficient at MSBs, descending
    err_values_out    : out std_logic_vector(NO_OF_CORR_ERRS*(GF_POLYNOMIAL'length-1)-1 downto 0);    -- highest order coefficient at MSBs, descending
    ready             : out std_logic
  );
end entity;

architecture rtl of forney_calculator is
  constant M  : natural := GF_POLYNOMIAL'length-1;

  subtype gf_elem is std_logic_vector(M-1 downto 0);
  type gf_array_desc_t is array(natural range <>) of gf_elem;
  type calculator_state_t is (IDLE, CALCULATING);

  constant GF_ZERO  : gf_elem := (OTHERS => '0');
  constant GF_ONE   : gf_elem := (0 => '1', OTHERS => '0');

  constant NO_OF_COEFS  : natural := 1;

  signal calculator_state         : calculator_state_t;
  signal err_eval                 : std_logic_vector(2*NO_OF_CORR_ERRS*M-1 downto 0);
  signal err_roots                : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
  signal err_locations            : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
  signal err_values               : gf_array_desc_t(NO_OF_CORR_ERRS-1 downto 0);
  signal err_eval_coefs           : std_logic_vector(NO_OF_COEFS*M-1 downto 0);
  signal numerator_values         : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
  signal numerator_values_latch   : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
  signal denominator_values       : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
  signal denominator_products     : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
  signal denominator_values_latch : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
  signal term_product             : gf_elem;
  signal err_eval_shift_cnt       : natural range 0 to (2*NO_OF_CORR_ERRS)/NO_OF_COEFS;
  signal new_numerator_calc       : std_logic;
  signal clk_enable               : std_logic;

begin

  ------------------------------
  -- Component instantiations --
  ------------------------------

  numerator_calculator : entity work.gf_horner_evaluator(rtl)
    generic map (
      GF_POLYNOMIAL   => GF_POLYNOMIAL,
      NO_OF_PAR_EVALS => NO_OF_CORR_ERRS,
      NO_OF_COEFS     => NO_OF_COEFS,
      SYMBOL_WIDTH    => M
    )
    port map (
      clk           => clk,
      rst           => rst,
      clk_enable    => clk_enable,
      new_calc      => new_numerator_calc,
      coefficients  => err_eval_coefs,
      eval_values   => err_roots,
      start_values  => (OTHERS => '0'),
      result_values => numerator_values
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
        mul_a   => err_roots(err_roots'high-(i-1)*M downto err_roots'length-(i)*M),
        mul_b   => err_locations(err_locations'high-(i-1)*M downto err_locations'length-i*M),
        product => term_product
      );
  end generate gen_denominator_multipliers;

  ---------------
  -- Processes --
  ---------------

  clk_proc : process(clk, rst)
  begin
    if rst = '1' then
      calculator_state          <= IDLE;
      ready                     <= '0';
      clk_enable                <= '0';
      new_numerator_calc        <= '0';
      err_roots                 <= (OTHERS => '0');
      err_locations             <= (OTHERS => '0');
      err_eval                  <= (OTHERS => '0');
      err_values                <= (OTHERS => GF_ZERO);
      err_values_out            <= (OTHERS => '0');
      numerator_values_latch    <= (OTHERS => '0');
      denominator_values_latch  <= (OTHERS => '0');
      err_eval_shift_cnt        <= 0;

    elsif rising_edge(clk) then
      -- preassignments
      ready               <= '0';
      new_numerator_calc  <= '0';
      err_values_out      <= (OTHERS => '0');

      -- shift err_eval registers
      err_eval                                        <= (OTHERS => '0');
      err_eval(err_eval'high(1) downto M*NO_OF_COEFS) <= err_eval(err_eval'high(1)-M*NO_OF_COEFS downto 0); -- shift left

      if calculator_state = CALCULATING then

        if numerator_values_ready = '0' and err_eval_shift_cnt = (2*NO_OF_CORR_ERRS)/NO_OF_COEFS then
          numerator_values_latch  <= numerator_values;
          err_eval_shift_cnt      <= 1;
          numerator_values_ready  <= '1';
          calculator_state        <= IDLE; -- TODO: don't go idle until entire calculations is over
        else
          err_eval_shift_cnt      <= err_eval_shift_cnt + 1;
        end if;

        if denominator_values_ready = '0' begin -- TODO: check for number of shifts
          -- shift error locations left 1 position
          err_locations       <= err_locations_in(err_locations_in'high-M downto 0) &
                                 err_locations_in(err_locations_in'high downto err_locations_in'length-M);
          denominator_values  <= denominator_products;
        end
      end if;

      -- if new input is given then reset calculation
      if new_calc = '1' then
        -- read in new data; start calculation
        err_eval            <= err_eval_in;
        err_roots           <= err_roots_in;

        err_values          <= (OTHERS => GF_ZERO);
        ready               <= '0';
        clk_enable          <= '1';
        new_numerator_calc  <= '1';
        err_eval_shift_cnt  <= 0;
        calculator_state    <= CALCULATING;

        -- shift error locations left 1 position to begin with
        err_locations       <= err_locations_in(err_locations_in'high-M downto 0) &
                               err_locations_in(err_locations_in'high downto err_locations_in'length-M);
        denominator_values  <= err_locations_in;
      end if;

      -- set output and ready when calculation is over
      if calculator_state = IDLE then
        ready   <= '1';

        for i in err_values'range(1) loop
          err_values_out((i+1)*M-1 downto i*M)  <= err_values(i);
        end loop;
      end if;
    end if;
  end process clk_proc;

  -- drive input coefficients signal to gf_horner_evaluator
  err_eval_coefs  <= err_eval(err_eval'high(1) downto err_eval'length(1)-M*NO_OF_COEFS); -- coefficients in MSBs

end rtl;
