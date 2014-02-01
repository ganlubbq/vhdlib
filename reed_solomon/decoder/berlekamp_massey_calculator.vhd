----------------------------------------------------------------------
-- Berlekamp-Massey calculator for finding error-locator polynomial --
----------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity berlekamp_massey_calculator is
  generic (
    GF_POLYNOMIAL   : std_logic_vector := G709_GF_POLY; -- irreducible, binary polynomial
    CORRECTABLE_ERR : integer := 3
  );
  port (
    clk             : in  std_logic;
    rst             : in  std_logic;
    new_calc        : in  std_logic;                                                                -- when '1' a new calculation is started with the given syndromes
    syndromes_in    : in  std_logic_vector(2*CORRECTABLE_ERR*(GF_POLYNOMIAL'length-1)-1 downto 0);  -- lowest order syndrome at MSBs, ascending
    ready           : out std_logic;                                                                -- when '1' the calculated error locator is ready
    err_locator_out : out std_logic_vector(2*CORRECTABLE_ERR*(GF_POLYNOMIAL'length-1)-1 downto 0)   -- highest order coefficient at MSBs, descending
  );
end entity;

architecture rtl of berlekamp_massey_calculator is
  constant M              : integer := GF_POLYNOMIAL'length-1;

  subtype gf_elem         is std_logic_vector(M-1 downto 0);
  type gf_array_desc_t    is array(2*CORRECTABLE_ERR-1 downto 0) of gf_elem;
  type calculator_state_t is (IDLE, CALCULATING);

  constant GF_ZERO        : gf_elem := (OTHERS => '0');
  constant GF_ONE         : gf_elem := (0 => '1', OTHERS => '0');

  -- TODO: give reasonable names to signals
  signal L                : integer range 0 to 2*CORRECTABLE_ERR; -- current number of assumed errors
  signal n                : integer range 0 to 2*CORRECTABLE_ERR;
  signal k                : integer range 1 to 2*CORRECTABLE_ERR;
  signal d                : gf_elem;          -- discrepancy
  signal d_mul_a_inputs   : gf_array_desc_t;
  signal d_mul_b_inputs   : gf_array_desc_t;
  signal d_mul_outputs    : gf_array_desc_t;
  signal d_prev           : gf_elem;          -- previous value of discrepancy
  signal d_prev_inv       : gf_elem;          -- inverse of d_prev
  signal inv_mux          : gf_elem;
  signal use_d_prev_inv   : std_logic;        -- when '1' use d_prev_inv for next calculation step, else use d_inv
  signal d_inv            : gf_elem;          -- inverse of d
  signal d_d_prev_inv     : gf_elem;
  signal cx               : gf_array_desc_t;
  signal cx_new           : gf_array_desc_t;  -- cx_new = cx - d_d_prev_inv * cx_prev
  signal cx_adj_inputs    : gf_array_desc_t;
  signal cx_adj_outputs   : gf_array_desc_t;
  signal cx_prev          : gf_array_desc_t;
  signal syndromes        : gf_array_desc_t;
  signal calculator_state : calculator_state_t;

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
        mul_a   => d_mul_a_inputs(i),
        mul_b   => d_mul_b_inputs(i),
        product => d_mul_outputs(i)
      );
  end generate discrepancy_multipliers;

  cx_adjustment_multipliers : for i in cx'range(1) generate -- TODO: could range be decreased?
  begin
    cx_adjustment_multiplier : entity work.gf_multiplier(rtl)
      generic map (
        GF_POLYNOMIAL => GF_POLYNOMIAL
      )
      port map (
        mul_a   => cx_adj_inputs(i),
        mul_b   => d_d_prev_inv,
        product => cx_adj_outputs(i)
      );
  end generate cx_adjustment_multipliers;

  d_b_inv_multiplier : entity work.gf_multiplier(rtl)
    generic map (
      GF_POLYNOMIAL => GF_POLYNOMIAL
    )
    port map (
      mul_a   => d,
      mul_b   => inv_mux,
      product => d_d_prev_inv
    );

  inverse_d_prev_table : entity work.gf_lookup_table(rtl)
    generic map (
      GF_POLYNOMIAL => GF_POLYNOMIAL,
      TABLE_TYPE    => INV_TABLE_TYPE
    )
    port map (
      clk       => clk,
      elem_in   => d_prev,
      elem_out  => d_prev_inv
    );

  inverse_d_table : entity work.gf_lookup_table(rtl)
    generic map (
      GF_POLYNOMIAL => GF_POLYNOMIAL,
      TABLE_TYPE    => INV_TABLE_TYPE
    )
    port map (
      clk       => clk,
      elem_in   => d,
      elem_out  => d_inv
    );

  ---------------
  -- Processes --
  ---------------

  clk_proc : process(clk, rst)
  begin
    if rst = '1' then
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
      err_locator_out   <= (OTHERS => '0');
    elsif rising_edge(clk) then

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
        if n = 2*CORRECTABLE_ERR-1 then
          calculator_state  <= IDLE;
        end if;
      end if;

      -- if new input is given then reset algorithm
      if new_calc = '1' then
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
          err_locator_out((i+1)*M-1 downto i*M)  <= cx(i);
        end loop;
      else
        err_locator_out <= (OTHERS => '0');
      end if;
    end if;
  end process clk_proc;

  comb_proc : process(  d_mul_a_inputs,
                        d_mul_b_inputs,
                        d_mul_outputs,
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
    variable var_d        : gf_elem;
    variable var_cx_new   : gf_elem;
  begin
    -- set inputs for discrepancy multipliers input a (C(x) coefficients)
    d_mul_a_inputs <= (OTHERS => GF_ZERO);
    for i in d_mul_a_inputs'range(1) loop
      if L >= i then
        d_mul_a_inputs(i) <= cx(i);
      end if;
    end loop;

    -- set inputs for discrepancy multipliers input b (syndromes)
    d_mul_b_inputs <= (OTHERS => GF_ZERO);
    for i in d_mul_b_inputs'range(1) loop
      if L >= i then
        d_mul_b_inputs(i) <= syndromes(i);
      end if;
    end loop;

    -- set inputs for C(x) adjustment multipliers
    cx_adj_inputs <= (OTHERS => GF_ZERO);
    for i in cx_prev'range(1) loop
      if i < cx_prev'high(1)-k then
        cx_adj_inputs(k+i) <= cx_prev(i);
      end if;
    end loop;

    -- add discrepancy multiplication products together
    var_d := GF_ZERO;
    for i in d_mul_outputs'range(1) loop
      var_d := var_d XOR d_mul_outputs(i);
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

  end process comb_proc;

end rtl;
