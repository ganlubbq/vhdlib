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
    clk             : in  std_logic;
    rst             : in  std_logic;
    new_calc        : in  std_logic;
    err_roots_in    : in  std_logic_vector(NO_OF_CORR_ERRS*(GF_POLYNOMIAL'length-1)-1 downto 0);  -- highest order coefficient at MSBs, descending
    err_eval_in     : in  std_logic_vector(2*NO_OF_CORR_ERRS*(GF_POLYNOMIAL'length-1)-1 downto 0);  -- highest order coefficient at MSBs, descending
    err_values_out  : out std_logic_vector(NO_OF_CORR_ERRS*(GF_POLYNOMIAL'length-1)-1 downto 0);  -- highest order coefficient at MSBs, descending
    ready           : out std_logic
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

  signal calculator_state   : calculator_state_t;
  signal err_eval           : gf_array_desc_t(2*NO_OF_CORR_ERRS-1 downto 0);
  signal err_roots          : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
  signal err_values         : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
  signal err_eval_coefs     : std_logic_vector(NO_OF_COEFS*M-1 downto 0);
  signal coef_offset        : natural range 2*NO_OF_CORR_ERRS-1 downto 0;
  signal new_numerator_calc : std_logic;

begin

  ------------------------------
  -- Component instantiations --
  ------------------------------

  gf_horner_evaluator : entity work.gf_horner_evaluator(rtl)
    generic map (
      GF_POLYNOMIAL   => GF_POLYNOMIAL,
      NO_OF_PAR_EVALS => NO_OF_CORR_ERRS,
      SYNDROME_CALC   => FALSE,
      NO_OF_COEFS     => NO_OF_COEFS,
      SYMBOL_WIDTH    => M
    )
    port map (
      clk           => clk,
      rst           => rst,
      clk_enable    => clk_enable,
      new_calc      => new_numerator_calc,
      coeficients   => err_eval_coefs,
      eval_values   => err_roots,
      start_values  => (OTHERS => '0'),
      result_values => numerator_values
    );

  ---------------
  -- Processes --
  ---------------

  clk_proc : process(clk, rst)
  begin
    if rst = '1' then
      calculator_state    <= IDLE;
      ready               <= '0';
      clk_enable          <= '0';
      new_numerator_calc  <= '0';
      coef_offset         <= 2*NO_OF_CORR_ERRS-1;

    elsif rising_edge(clk) then
      -- preassignments
      ready               <= '0';
      new_numerator_calc  <= '0';

      if calculator_state = CALCULATING then
        -- decrement error evaluator polynomial coefficient offset
        coef_offset <= coef_offset-NO_OF_COEFS;

        -- check if numerator calculation is over
        if coef_offset <= NO_OF_COEFS then
          -- TODO
          calculator_state  <= IDLE;
        end if;
      end if;

      -- if new input is given then reset calculation
      if new_calc = '1' then
        -- read in error evaluator polynomial
        for i in err_eval'high(1) downto 0 loop
          err_eval(i) <= err_eval_in((i+1)*M-1 downto i*M);
        end loop;

        err_roots           <= err_roots_in;
        err_values          <= err_values_in;
        ready               <= '0';
        clk_enable          <= '1';
        new_numerator_calc  <= '1';
        coef_offset         <= 2*NO_OF_CORR_ERRS-1;
        calculator_state    <= CALCULATING;
      end if;

      -- set output and ready when calculation is over
      if calculator_state = IDLE then
        ready   <= '1';

        for i in err_eval'range(1) loop
          err_eval_out((i+1)*M-1 downto i*M)  <= err_eval(i);
        end loop;
      end if;
    end if;
  end process clk_proc;

  comb_proc : process( err_eval )
  begin
    -- input correct coefficients to Horner scheme evaluator
    err_eval_coefs  <= (OTHERS => '0');
    for i in 0 to NO_OF_COEFS-1 loop
      err_eval_coefs((NO_OF_COEFS-i)*SYMBOL_WIDTH-1 downto (NO_OF_COEFS-i-1)*SYMBOL_WIDTH) <= err_eval(coef_offset-i);
    end loop;

  end process comb_proc;

end rtl;
