----------------------------------------------------------------------
-- Berlekamp-Massey calculator for finding error-locator polynomial --
----------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity berlekamp_massey_calculator is
  generic (
    -- Irreducible, binary polynomial.
    GF_POLYNOMIAL   : std_logic_vector  := BINARY_POLYNOMIAL_G709_GF;
    NO_OF_SYNDROMES : natural           := 6
  );
  port (
    clock             : in  std_logic;
    reset             : in  std_logic;

    -- When '1' a new calculation is started with the given syndromes.
    new_calculation   : in  std_logic;

    -- Lowest order syndrome at MSBs, ascending.
    syndromes_in      : in  std_logic_vector(NO_OF_SYNDROMES*(GF_POLYNOMIAL'length-1)-1 downto 0);
    
    -- When '1' the calculated error-locator polynomial is ready.
    ready             : out std_logic;
   
    -- Error-locator polyonomial. Highest order coefficient at MSBs, descending.
    error_locator_out : out std_logic_vector(NO_OF_SYNDROMES*(GF_POLYNOMIAL'length-1)-1 downto 0)
  );
end entity;

architecture rtl of berlekamp_massey_calculator is
  constant M              : natural := GF_POLYNOMIAL'length-1;

  subtype gf_element      is std_logic_vector(M-1 downto 0);
  type gf_array_desc_t    is array(NO_OF_SYNDROMES-1 downto 0) of gf_element;
  type calculator_state_t is (IDLE, CALCULATING);

  constant GF_ZERO  : gf_element := (OTHERS => '0');
  constant GF_ONE   : gf_element := (0 => '1', OTHERS => '0');

  signal L                        : natural range 0 to NO_OF_SYNDROMES; -- current number of assumed errors
  signal n                        : natural range 0 to NO_OF_SYNDROMES;
  signal k                        : natural range 1 to NO_OF_SYNDROMES;
  signal d                        : gf_element;         -- Discrepancy.
  signal d_inv                    : gf_element;         -- GF inverse of d.
  signal d_prev                   : gf_element;         -- Previous value of d.
  signal d_prev_inv               : gf_element;         -- GF inverse of d_prev.
  signal use_d_prev_inv           : std_logic;          -- When '1' use d_prev_inv for next calculation step, otherwise use d_inv.
  signal d_multiplicand_a_inputs  : gf_array_desc_t;
  signal d_multiplicand_b_inputs  : gf_array_desc_t;
  signal d_multiplicand_outputs   : gf_array_desc_t;
  signal inv_mux                  : gf_element;
  signal d_d_prev_inv             : gf_element;
  signal cx                       : gf_array_desc_t;
  signal cx_new                   : gf_array_desc_t;    -- cx_new = cx - d_d_prev_inv * cx_prev
  signal cx_adj_inputs            : gf_array_desc_t;
  signal cx_adj_outputs           : gf_array_desc_t;
  signal cx_prev                  : gf_array_desc_t;
  signal syndromes                : gf_array_desc_t;
  signal calculator_state         : calculator_state_t;

begin

  ------------------------------
  -- Component instantiations --
  ------------------------------

  discrepancy_multipliers : for i in cx'range(1) generate -- TODO: could range be decreased?
  begin
    discrepancy_multiplier : entity work.gf_multiplier(rtl)
      generic map (
        GF_POLYNOMIAL => GF_POLYNOMIAL
      )
      port map (
        multiplicand_a  => d_multiplicand_a_inputs(i),
        multiplicand_b  => d_multiplicand_b_inputs(i),
        product         => d_multiplicand_outputs(i)
      );
  end generate discrepancy_multipliers;

  cx_adjustment_multipliers : for i in cx'range(1) generate -- TODO: could range be decreased?
  begin
    cx_adjustment_multiplier : entity work.gf_multiplier(rtl)
      generic map (
        GF_POLYNOMIAL => GF_POLYNOMIAL
      )
      port map (
        multiplicand_a  => cx_adj_inputs(i),
        multiplicand_b  => d_d_prev_inv,
        product         => cx_adj_outputs(i)
      );
  end generate cx_adjustment_multipliers;

  d_b_inv_multiplier : entity work.gf_multiplier(rtl)
    generic map (
      GF_POLYNOMIAL => GF_POLYNOMIAL
    )
    port map (
      multiplicand_a  => d,
      multiplicand_b  => inv_mux,
      product         => d_d_prev_inv
    );

  inverse_d_prev_table : entity work.gf_lookup_table(rtl)
    generic map (
      GF_POLYNOMIAL => GF_POLYNOMIAL,
      TABLE_TYPE    => gf_table_type_inverse
    )
    port map (
      clock       => clock,
      element_in   => d_prev,
      element_out  => d_prev_inv
    );

  inverse_d_table : entity work.gf_lookup_table(rtl)
    generic map (
      GF_POLYNOMIAL => GF_POLYNOMIAL,
      TABLE_TYPE    => gf_table_type_inverse
    )
    port map (
      clock       => clock,
      element_in   => d,
      element_out  => d_inv
    );

  ---------------
  -- Processes --
  ---------------

  clock_process : process(clock, reset)
  begin
    if reset = '1' then
      use_d_prev_inv    <= '0';
      L                 <= 0;
      n                 <= 0;
      k                 <= 1;
      d_prev            <= GF_ONE;
      cx                <= (0 => GF_ONE, OTHERS => GF_ZERO);
      cx_prev           <= (0 => GF_ONE, OTHERS => GF_ZERO);
      syndromes         <= (OTHERS => GF_ZERO);

      calculator_state  <= IDLE;
      ready             <= '0';
      error_locator_out   <= (OTHERS => '0');
    elsif rising_edge(clock) then

      -- preassignments
      ready           <= '0';
      use_d_prev_inv  <= '1';

      if calculator_state = CALCULATING then
        -- increment iterator and cycle syndromes 1 to the left
        n             <= n + 1;
        syndromes(0)  <= syndromes(syndromes'high(1));
        syndromes(syndromes'high(1) downto 1) <= syndromes(syndromes'high(1)-1 downto 0);

        -- evaluate newly calculated discrepancy
        if d = GF_ZERO then
          k               <= k + 1;
        elsif 2*L <= n then
          cx_prev         <= cx;
          L               <= n + 1 - L;
          d_prev          <= d;
          cx              <= cx_new;
          k               <= 1;
          use_d_prev_inv  <= '0';
        else
          cx              <= cx_new;
          k               <= k + 1;
        end if;

        -- check if iteration is over
        if n = NO_OF_SYNDROMES-1 then
          calculator_state  <= IDLE;
        end if;
      end if;

      -- if new input is given then reset algorithm
      if new_calculation = '1' then
        L       <= 0;
        n       <= 0;
        k       <= 1;
        d_prev  <= GF_ONE;
        cx      <= (0 => GF_ONE, OTHERS => GF_ZERO);
        cx_prev <= (0 => GF_ONE, OTHERS => GF_ZERO);

        -- read in syndromes so they are ascending but shifted 1 to the left
        for i in syndromes'high(1) downto 1 loop
          syndromes(i)    <= syndromes_in(i*M-1 downto (i-1)*M);
        end loop;
        syndromes(0)      <= syndromes_in(syndromes_in'high downto syndromes_in'length-M);

        calculator_state  <= CALCULATING;
      end if;

      -- set output and ready when calculation is over
      if calculator_state = IDLE then
        ready           <= '1';
        for i in cx'range(1) loop
          error_locator_out((i+1)*M-1 downto i*M)  <= cx(i);
        end loop;
      else
        error_locator_out <= (OTHERS => '0');
      end if;
    end if;
  end process clock_process;

  comb_process : process(  d_multiplicand_a_inputs,
                        d_multiplicand_b_inputs,
                        d_multiplicand_outputs,
                        syndromes,
                        L,
                        k,
                        cx_prev,
                        cx,
                        cx_adj_inputs,
                        cx_adj_outputs,
                        use_d_prev_inv,
                        d_prev_inv,
                        d_inv
                      )
    variable var_d        : gf_element;
    variable var_cx_new   : gf_element;
  begin
    -- Set inputs for discrepancy multipliers input a (C(x) coefficients)
    d_multiplicand_a_inputs <= (OTHERS => GF_ZERO);
    for i in d_multiplicand_a_inputs'range(1) loop
      if L >= i then
        d_multiplicand_a_inputs(i) <= cx(i);
      end if;
    end loop;

    -- Set inputs for discrepancy multipliers input b (syndromes)
    d_multiplicand_b_inputs <= (OTHERS => GF_ZERO);
    for i in d_multiplicand_b_inputs'range(1) loop
      if L >= i then
        d_multiplicand_b_inputs(i) <= syndromes(i);
      end if;
    end loop;

    -- Set inputs for C(x) adjustment multipliers
    cx_adj_inputs <= (OTHERS => GF_ZERO);
    for i in cx_prev'range(1) loop
      if i < cx_prev'high(1)-k then
        cx_adj_inputs(k+i) <= cx_prev(i);
      end if;
    end loop;

    -- add discrepancy multiplication products together
    var_d := GF_ZERO;
    for i in d_multiplicand_outputs'range(1) loop
      var_d := var_d XOR d_multiplicand_outputs(i);
    end loop;
    d <= var_d;

    -- add C(x) adjustment multiplication products together with old C(x)
    for i in cx_adj_outputs'range(1) loop
      cx_new(i) <= cx(i) XOR cx_adj_outputs(i);
    end loop;

    if use_d_prev_inv = '1' then
      inv_mux <= d_prev_inv;
    else
      inv_mux <= d_inv;
    end if;

  end process comb_process;

end rtl;
