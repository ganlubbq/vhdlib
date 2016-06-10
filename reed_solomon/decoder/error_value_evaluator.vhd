---------------------------
-- Error value evaluator --
---------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity error_value_evaluator is
  generic (
    GF_POLYNOMIAL   : std_logic_vector  := G709_GF_POLY; -- irreducible, binary polynomial
    NO_OF_SYNDROMES : natural           := 6
  );
  port (
    clk             : in  std_logic;
    rst             : in  std_logic;
    new_calc        : in  std_logic;
    syndromes_in    : in  std_logic_vector(NO_OF_SYNDROMES*(GF_POLYNOMIAL'length-1)-1 downto 0);  -- lowest order syndrome at MSBs, ascending
    err_locator_in  : in  std_logic_vector(NO_OF_SYNDROMES*(GF_POLYNOMIAL'length-1)-1 downto 0);  -- highest order coefficient at MSBs, descending
    err_eval_out    : out std_logic_vector(NO_OF_SYNDROMES*(GF_POLYNOMIAL'length-1)-1 downto 0);  -- highest order coefficient at MSBs, descending
    ready           : out std_logic
  );
end entity;

architecture rtl of error_value_evaluator is
  constant M                : natural := GF_POLYNOMIAL'length-1;

  subtype gf_elem is std_logic_vector(M-1 downto 0);
  type gf_array_desc_t is array(NO_OF_SYNDROMES-1 downto 0) of gf_elem;
  type calculator_state_t is (IDLE, CALCULATING);

  constant GF_ZERO  : gf_elem := (OTHERS => '0');
  constant GF_ONE   : gf_elem := (0 => '1', OTHERS => '0');

  signal n                : natural range 1 to NO_OF_SYNDROMES; -- polynomial coefficient iterator
  signal err_eval_coef    : gf_elem;                            -- polynomial coefficient
  signal mul_outputs      : gf_array_desc_t;                    -- outputs from multipliers
  signal err_eval         : gf_array_desc_t;                    -- error evaluator polynomial
  signal err_locator      : gf_array_desc_t;                    -- error locator polynomial
  signal syndromes        : gf_array_desc_t;                    -- syndrome values
  signal calculator_state : calculator_state_t;                 -- state of module

begin

  ------------------------------
  -- Component instantiations --
  ------------------------------

  multipliers : for i in err_eval'range(1) generate
  begin
    multiplier : entity work.gf_multiplier(rtl)
      generic map (
        GF_POLYNOMIAL => GF_POLYNOMIAL
      )
      port map (
        mul_a   => syndromes(i),
        mul_b   => err_locator(i),
        product => mul_outputs(i)
      );
  end generate multipliers;

  ---------------
  -- Processes --
  ---------------

  clk_proc : process(clk, rst)
  begin
    if rst = '1' then
      n                 <= 1;
      syndromes         <= (OTHERS => GF_ZERO);
      err_locator       <= (OTHERS => GF_ZERO);
      err_eval          <= (OTHERS => GF_ZERO);
      calculator_state  <= IDLE;
      ready             <= '0';
      err_eval_out      <= (OTHERS => '0');

    elsif rising_edge(clk) then

      ready <= '0'; -- preassignment

      if calculator_state = CALCULATING then
        syndromes(syndromes'high(1))            <= GF_ZERO;
        syndromes(syndromes'high(1)-1 downto 0) <= syndromes(syndromes'high(1) downto 1);

        -- store newly calculated coefficient of error-value evaluator
        err_eval(NO_OF_SYNDROMES-n) <= err_eval_coef;

        -- check whether iteration should continue
        if n = NO_OF_SYNDROMES then
          calculator_state  <= IDLE;
        else
          n <= n + 1;
        end if;
      end if;

      -- if new input is given then reset calculation
      if new_calc = '1' then
        -- read in syndromes
        for i in syndromes'high(1) downto 0 loop
          syndromes(i) <= syndromes_in((i+1)*M-1 downto i*M);
        end loop;

        -- read in error locator
        for i in err_locator'high(1) downto 0 loop
          err_locator(i) <= err_locator_in((i+1)*M-1 downto i*M);
        end loop;

        n                 <= 1;
        calculator_state  <= CALCULATING;
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

  comb_proc : process( mul_outputs )
    variable var_err_eval_coef  : gf_elem;
  begin
    -- add multiplication products together
    var_err_eval_coef   := GF_ZERO;
    for i in mul_outputs'range(1) loop
      var_err_eval_coef := mul_outputs(i) XOR var_err_eval_coef;
    end loop;
    err_eval_coef <= var_err_eval_coef;

  end process comb_proc;

end rtl;
