-----------------------------------------
-- Chien search for codes over GF(2^M) --
-----------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.vhdlib_package.all;

entity chien_search is
  generic (
    GF_POLYNOMIAL   : std_logic_vector  := BINARY_POLYNOMIAL_G709_GF; -- irreducible, binary polynomial
    NO_OF_CORR_ERRS : natural           := 3;
    NO_OF_SYNDROMES : natural           := 6
  );
  port (
    clock               : in  std_logic;
    reset               : in  std_logic;
    new_calculation     : in  std_logic;
    error_locator_in    : in  std_logic_vector(NO_OF_SYNDROMES*(GF_POLYNOMIAL'length-1)-1 downto 0);  -- highest order coefficient at MSBs, descending
    ready               : out std_logic;                                                              -- when '1' the module is ready for new input and any possible output from the previous calculation can be read
    error_roots_out     : out std_logic_vector(NO_OF_CORR_ERRS*(GF_POLYNOMIAL'length-1)-1 downto 0);
    error_locations_out : out std_logic_vector(NO_OF_CORR_ERRS*(GF_POLYNOMIAL'length-1)-1 downto 0);
    sym_locations_out   : out std_logic_vector(NO_OF_CORR_ERRS*(GF_POLYNOMIAL'length-1)-1 downto 0)   -- locations of erroneous symbols in codeword
  );
end entity;

architecture rtl of chien_search is
  constant M              : natural := GF_POLYNOMIAL'length-1;

  subtype gf_elem         is std_logic_vector(M-1 downto 0);
  type gf_array_desc_t    is array(NO_OF_CORR_ERRS downto 0) of gf_elem;
  type gf_output_values_t is array(NO_OF_CORR_ERRS-1 downto 0) of gf_elem;
  type calculator_state_t is (IDLE, CALCULATING);

  constant GF_ZERO        : gf_elem := (OTHERS => '0');
  constant GF_MAX         : gf_elem := (OTHERS => '1');

  signal gammas                 : gf_array_desc_t;                      -- polynomail terms of last evaluation
  signal gammas_new             : gf_array_desc_t;                      -- polynomial terms of current evaluation
  signal gammas_sum             : gf_elem;                              -- sum of polynomial terms
  signal error_roots            : gf_output_values_t;                   -- output array of error locator roots
  signal error_locations        : gf_output_values_t;                   -- output array of error locations
  signal error_symbol_locations : gf_output_values_t;                   -- output array of error symbol locations
  signal k                      : natural range 0 to NO_OF_CORR_ERRS-1; -- counter for found polynomial roots
  signal i                      : unsigned(M-1 downto 0);               -- power of the primitive element, that the polynomial is evaluated over (i.e. a^i)
  signal calculator_state       : calculator_state_t;
  signal root_found             : std_logic;
  signal root_n                 : gf_elem;                              -- error symbol location: found root of polynomial
  signal gf_element_exp_in      : gf_elem;                              -- same as signal i, but cast to type gf_elem
  signal gf_element_inv_in      : gf_elem;                              -- power of element which is inverse to a^i: 2^M-1-i
  signal gf_element_exp_out     : gf_elem;                              -- error root: value of a^i
  signal gf_element_inv_out     : gf_elem;                              -- error location: value of inverse element of a^i = a^(2^M-1-i)

begin

  -- One GF multiplier per term in the error locator
  gen_coef_multipliers : for j in 0 to NO_OF_CORR_ERRS generate
  begin
    coef_multiplier : entity work.gf_multiplier(rtl)
      generic map (
        GF_POLYNOMIAL => GF_POLYNOMIAL
      )
      port map (
        multiplicand_a  => primitive_element_exponentiation(j,GF_POLYNOMIAL), -- primitive element to the jth power
        multiplicand_b  => gammas(j),                                         -- jth term of last polynomial evaluation
        product         => gammas_new(j)                                      -- jth term of current polynomial evaluation
      );
  end generate gen_coef_multipliers;

  -- lookup table
  lookup_table : entity work.gf_lookup_table_dp(rtl)
    generic map (
      GF_POLYNOMIAL   => GF_POLYNOMIAL,
      TABLE_TYPE      => gf_table_type_exponent
    )
    port map (
      clock             => clock,
      element_in_a       => gf_element_exp_in,
      element_in_b       => gf_element_inv_in,
      element_out_a      => gf_element_exp_out,
      element_out_b      => gf_element_inv_out
    );

  gf_element_exp_in  <= std_logic_vector(i);
  gf_element_inv_in  <= GF_MAX xor std_logic_vector(i);

  clock_proc : process (clock, reset)
  begin
    if reset = '1' then
      gammas            <= (OTHERS => GF_ZERO);
      error_roots         <= (OTHERS => GF_ZERO);
      error_locations     <= (OTHERS => GF_ZERO);
      error_symbol_locations     <= (OTHERS => GF_ZERO);
      k                 <= 0;
      i                 <= (OTHERS => '0');
      root_n            <= (OTHERS => '0');
      calculator_state  <= IDLE;
      root_found        <= '0';
    elsif rising_edge(clock) then
      root_found        <= '0';

      if new_calculation = '1' then
        k                       <= 0;                   -- zero roots found
        i                       <= (OTHERS => '0');     -- start search with polynomial evaluation over a^0
        root_n                  <= (OTHERS => '0');
        calculator_state        <= CALCULATING;
        error_roots             <= (OTHERS => GF_ZERO);
        error_locations         <= (OTHERS => GF_ZERO);
        error_symbol_locations  <= (OTHERS => GF_ZERO);

        for j in NO_OF_CORR_ERRS downto 0 loop
          -- read in coefficients of error locator polynomial
          gammas(j) <= error_locator_in((j+1)*M-1 downto j*M);
        end loop;
      end if;

      if calculator_state = CALCULATING then
        if i = 2**M-1 then
          calculator_state  <= IDLE;
        else
          i <= i + 1;
        end if;

        if i /= 2**M-1 and gammas_sum = GF_ZERO then
          -- a^i is a root of the error locator polynomial
          root_found  <= '1';

          if std_logic_vector(i) = GF_ZERO then
            root_n  <= GF_MAX;  -- a^0 = a^(2^M-1)
          else
            root_n  <= std_logic_vector(i);
          end if;
        end if;

        gammas  <= gammas_new;
      end if;

      if root_found = '1' then
        error_roots(k) <= gf_element_exp_out;
        error_locations(k) <= gf_element_inv_out;
        error_symbol_locations(k) <= root_n;

        if k < NO_OF_CORR_ERRS-1 then
          k <= k + 1;
        end if;
      end if;

    end if;
  end process clock_proc;

  comb_proc : process( gammas,
                       error_roots,
                       error_locations,
                       error_symbol_locations,
                       calculator_state,
                       reset
                     )
    variable var_gammas_sum   : gf_elem;
  begin
    -- add multiplication products together
    var_gammas_sum    := GF_ZERO;
    for j in gammas'range(1) loop
      var_gammas_sum := gammas(j) XOR var_gammas_sum;
    end loop;
    gammas_sum        <= var_gammas_sum;

    -- output calculated values
    for j in NO_OF_CORR_ERRS-1 downto 0 loop
      error_roots_out((j+1)*M-1 downto j*M)     <= error_roots(j);
      error_locations_out((j+1)*M-1 downto j*M) <= error_locations(j);
      sym_locations_out((j+1)*M-1 downto j*M)   <= error_symbol_locations(j);
    end loop;

    if calculator_state = IDLE and reset = '0' then
      ready <= '1';
    else
      ready <= '0';
    end if;

  end process comb_proc;

end rtl;
