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
    GF_POLYNOMIAL   : std_logic_vector := G709_GF_POLY; -- irreducible, binary polynomial
    CORRECTABLE_ERR : integer := 3
  );
  port (
    clk               : in  std_logic;
    rst               : in  std_logic;
    new_calc          : in  std_logic;
    err_locator_in    : in  std_logic_vector(2*CORRECTABLE_ERR*(GF_POLYNOMIAL'length-1)-1 downto 0);  -- highest order coefficient at MSBs, descending
    ready             : out std_logic;                                                                -- when '1' the error locations have can be read from signal err_locations_out
    err_roots_out     : out std_logic_vector(CORRECTABLE_ERR*(GF_POLYNOMIAL'length-1)-1 downto 0);
    err_locations_out : out std_logic_vector(CORRECTABLE_ERR*(GF_POLYNOMIAL'length-1)-1 downto 0);
    bit_locations_out : out std_logic_vector(CORRECTABLE_ERR*(GF_POLYNOMIAL'length-1)-1 downto 0)
  );
end entity;

architecture rtl of chien_search is
  constant M              : integer := GF_POLYNOMIAL'length-1;

  subtype gf_elem         is std_logic_vector(M-1 downto 0);
  type gf_array_desc_t    is array(CORRECTABLE_ERR downto 0) of gf_elem;
  type gf_output_values_t is array(CORRECTABLE_ERR-1 downto 0) of gf_elem;
  type calculator_state_t is (IDLE, CALCULATING);

  constant GF_ZERO        : gf_elem := (OTHERS => '0');
  constant GF_MAX         : gf_elem := (OTHERS => '1');

  signal gammas           : gf_array_desc_t;                      -- polynomail terms of last evaluation
  signal gammas_new       : gf_array_desc_t;                      -- polynomial terms of current evaluation
  signal gammas_sum       : gf_elem;                              -- sum of polynomial terms
  signal err_roots        : gf_output_values_t;                   -- output array of error roots
  signal err_locations    : gf_output_values_t;                   -- output array of error locations
  signal bit_locations    : gf_output_values_t;                   -- output array of error bit locations
  signal k                : integer range 0 to CORRECTABLE_ERR-1; -- counter for found polynomial roots
  signal i                : unsigned(M-1 downto 0);               -- power of the primitive element, that the polynomial is evaluated over (i.e. a^i)
  signal calculator_state : calculator_state_t;
  signal root_found       : std_logic;
  signal root_n           : gf_elem;                              -- error bit location: found root of polynomial
  signal gf_elem_exp_in   : gf_elem;                              -- same as signal i, but cast to type gf_elem
  signal gf_elem_inv_in   : gf_elem;                              -- power of element which is inverse to a^i: 2^M-1-i
  signal gf_elem_exp_out  : gf_elem;                              -- error root: value of a^i
  signal gf_elem_inv_out  : gf_elem;                              -- error location: value of inverse element of a^i = a^(2^M-1-i)

begin

  -- One GF multiplier per term in the error locator
  gen_coef_multipliers : for j in 0 to CORRECTABLE_ERR generate
  begin
    coef_multiplier : entity work.gf_multiplier(rtl)
      generic map (
        GF_POLYNOMIAL => GF_POLYNOMIAL
      )
      port map (
        mul_a     => prim_elem_exp(j,GF_POLYNOMIAL),  -- primitive element to the jth power
        mul_b     => gammas(j),                       -- jth term of last polynomial evaluation
        product   => gammas_new(j)                    -- jth term of current polynomial evaluation
      );
  end generate gen_coef_multipliers;

  -- lookup table
  lookup_table : entity work.gf_lookup_table_dp(rtl)
    generic map (
      GF_POLYNOMIAL   => GF_POLYNOMIAL,
      TABLE_TYPE      => EXP_TABLE_TYPE
    )
    port map (
      clk             => clk,
      elem_in_a       => gf_elem_exp_in,
      elem_in_b       => gf_elem_inv_in,
      elem_out_a      => gf_elem_exp_out,
      elem_out_b      => gf_elem_inv_out
    );

  gf_elem_exp_in  <= std_logic_vector(i);
  gf_elem_inv_in  <= GF_MAX xor std_logic_vector(i);

  clk_proc : process (clk, rst)
  begin
    if rst = '1' then
      gammas            <= (OTHERS => GF_ZERO);
      err_roots         <= (OTHERS => GF_ZERO);
      err_locations     <= (OTHERS => GF_ZERO);
      bit_locations     <= (OTHERS => GF_ZERO);
      k                 <= 0;
      i                 <= (OTHERS => '0');
      root_n            <= (OTHERS => '0');
      calculator_state  <= IDLE;
      root_found        <= '0';
    elsif rising_edge(clk) then
      -- preassignments
      root_found        <= '0';

      if new_calc = '1' then
        k                 <= 0;                   -- zero roots found
        i                 <= (OTHERS => '0');     -- start search with polynomial evaluation over a^0
        root_n            <= (OTHERS => '0');
        calculator_state  <= CALCULATING;
        err_roots         <= (OTHERS => GF_ZERO);
        err_locations     <= (OTHERS => GF_ZERO);
        bit_locations     <= (OTHERS => GF_ZERO);

        for j in CORRECTABLE_ERR downto 0 loop
          -- read in coefficients of error locator polynomial
          gammas(j) <= err_locator_in((j+1)*M-1 downto j*M);
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

        -- set new gamma values
        gammas  <= gammas_new;
      end if;

      if root_found = '1' then
        err_roots(k)      <= gf_elem_exp_out;
        err_locations(k)  <= gf_elem_inv_out;
        bit_locations(k)  <= root_n;

        if k < CORRECTABLE_ERR-1 then
          k <= k + 1;
        end if;
      end if;

    end if;
  end process clk_proc;

  comb_proc : process( gammas,
                       err_roots,
                       err_locations,
                       bit_locations,
                       calculator_state,
                       rst
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
    for j in CORRECTABLE_ERR-1 downto 0 loop
      err_roots_out((j+1)*M-1 downto j*M)     <= err_roots(j);
      err_locations_out((j+1)*M-1 downto j*M) <= err_locations(j);
      bit_locations_out((j+1)*M-1 downto j*M) <= bit_locations(j);
    end loop;

    if calculator_state = IDLE and rst = '0' then
      ready <= '1';
    else
      ready <= '0';
    end if;

  end process comb_proc;

end rtl;
