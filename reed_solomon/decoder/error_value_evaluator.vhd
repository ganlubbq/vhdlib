---------------------------
-- Error value evaluator --
---------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity error_value_evaluator is
  generic (
    GF_POLYNOMIAL   : std_logic_vector  := BINARY_POLYNOMIAL_G709_GF; -- irreducible, binary polynomial
    NO_OF_SYNDROMES : natural           := 6
  );
  port (
    clock           : in  std_logic;
    reset           : in  std_logic;
    new_calculation : in  std_logic;
    syndromes       : in  std_logic_vector(NO_OF_SYNDROMES*(GF_POLYNOMIAL'length-1)-1 downto 0);  -- Syndrom values. Lowest order syndrome at MSBs, ascending.
    error_locator   : in  std_logic_vector(NO_OF_SYNDROMES*(GF_POLYNOMIAL'length-1)-1 downto 0);  -- Error locator polynomial. Highest order coefficient at MSBs, descending.
    error_evaluator : out std_logic_vector(NO_OF_SYNDROMES*(GF_POLYNOMIAL'length-1)-1 downto 0);  -- Error evaluator polynomial. Highest order coefficient at MSBs, descending.
    ready           : out std_logic
  );
end entity;

architecture rtl of error_value_evaluator is
  constant M : natural := GF_POLYNOMIAL'length-1;

  subtype gf_element is std_logic_vector(M-1 downto 0);
  type gf_array_desc_t is array(NO_OF_SYNDROMES-1 downto 0) of gf_element;
  type calculator_state is (IDLE, CALCULATING);

  constant GF_ZERO  : gf_element := (OTHERS => '0');
  constant GF_ONE   : gf_element := (0 => '1', OTHERS => '0');

  signal n                            : natural range 1 to NO_OF_SYNDROMES; -- Error evaluator polynomial coefficient iteration counter.
  signal error_evaluator_coefficient  : gf_element;                         -- Error evaluator polynomial coefficient.
  signal multiplier_outputs           : gf_array_desc_t;                    -- Outputs from multipliers.
  signal error_evaluator_registers    : gf_array_desc_t;                    -- Rrror evaluator polynomial registers.
  signal error_locator_registers      : gf_array_desc_t;                    -- Error locator polynomial registers.
  signal syndromes_registers          : gf_array_desc_t;                    -- Syndrome values.
  signal state                        : calculator_state;                   -- State of calculator module.

begin

  ------------------------------
  -- Component instantiations --
  ------------------------------

  multipliers : for i in error_evaluator_registers'range(1) generate
  begin
    multiplier : entity work.gf_multiplier(rtl)
      generic map (
        GF_POLYNOMIAL => GF_POLYNOMIAL
      )
      port map (
        multiplicand_a  => syndromes_registers(i),
        multiplicand_b  => error_locator_registers(i),
        product         => multiplier_outputs(i)
      );
  end generate multipliers;

  ---------------
  -- Processes --
  ---------------

  clock_process : process(clock, reset)
  begin
    if reset = '1' then
      n                         <= 1;
      syndromes_registers       <= (OTHERS => GF_ZERO);
      error_locator_registers   <= (OTHERS => GF_ZERO);
      error_evaluator_registers <= (OTHERS => GF_ZERO);
      state                     <= IDLE;
      ready                     <= '0';
      error_evaluator           <= (OTHERS => '0');

    elsif rising_edge(clock) then

      ready <= '0'; -- preassignment

      if state = CALCULATING then
        syndromes_registers(syndromes_registers'high(1))            <= GF_ZERO;
        syndromes_registers(syndromes_registers'high(1)-1 downto 0) <= syndromes_registers(syndromes_registers'high(1) downto 1);

        -- store newly calculated coefficient of error-value evaluator
        error_evaluator_registers(NO_OF_SYNDROMES-n) <= error_evaluator_coefficient;

        -- check whether iteration should continue
        if n = NO_OF_SYNDROMES then
          state  <= IDLE;
        else
          n <= n + 1;
        end if;
      end if;

      -- if new input is given then reset calculation
      if new_calculation = '1' then
        -- read in syndromes
        for i in syndromes_registers'high(1) downto 0 loop
          syndromes_registers(i) <= syndromes((i+1)*M-1 downto i*M);
        end loop;

        -- read in error locator
        for i in error_locator_registers'high(1) downto 0 loop
          error_locator_registers(i) <= error_locator((i+1)*M-1 downto i*M);
        end loop;

        n     <= 1;
        state <= CALCULATING;
      end if;

      -- set output and ready when calculation is over
      if state = IDLE then
        ready <= '1';

        for i in error_evaluator_registers'range(1) loop
          error_evaluator((i+1)*M-1 downto i*M)  <= error_evaluator_registers(i);
        end loop;
      end if;
    end if;
  end process clock_process;

  combinatorial_process : process( multiplier_outputs )
    variable var_error_evaluator_coefficient : gf_element;
  begin
    -- add multiplication products together
    var_error_evaluator_coefficient   := GF_ZERO;
    for i in multiplier_outputs'range(1) loop
      var_error_evaluator_coefficient := multiplier_outputs(i) XOR var_error_evaluator_coefficient;
    end loop;
    error_evaluator_coefficient <= var_error_evaluator_coefficient;

  end process combinatorial_process;

end rtl;
