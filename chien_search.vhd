-----------------------------------------
-- Chien search for codes over GF(2^M) --
-----------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity chien_search is
  generic (
    GF_POLYNOMIAL   : std_logic_vector := G709_GF_POLY; -- irreducible, binary polynomial
    CORRECTABLE_ERR : integer := 3
  );
  port (
    clk                 : in  std_logic;
    rst                 : in  std_logic;
    new_calc            : in  std_logic;
    err_locator_in      : in  std_logic_vector(2*CORRECTABLE_ERR*(GF_POLYNOMIAL'length-1)-1 downto 0);   -- highest order coefficient at MSBs, descending
    ready               : out std_logic;
    err_roots_out       : out std_logic_vector(CORRECTABLE_ERR*(GF_POLYNOMIAL'length-1)-1 downto 0);
    err_locations_out   : out std_logic_vector(CORRECTABLE_ERR*(GF_POLYNOMIAL'length-1)-1 downto 0)
  );
end entity;

architecture rtl of chien_search is
  constant M  : integer := GF_POLYNOMIAL'length-1;

  subtype gf_elem is std_logic_vector(M-1 downto 0);
  type gf_array_desc_t is array(CORRECTABLE_ERR downto 0) of gf_elem;
  type calculator_state_t is (IDLE, CALCULATING);

  constant GF_ZERO        : gf_elem := (OTHERS => '0');

  signal gammas           : gf_array_desc_t;
  signal gammas_new       : gf_array_desc_t;
  signal gammas_sum       : gf_elem;
  signal n                : integer range 0 to 2**M-2;
  signal calculator_state : calculator_state_t;
  signal debug_root_found : std_logic;

begin

  -- One GF multiplier per term in the error locator
  gen_coef_multipliers : for i in 0 to CORRECTABLE_ERR generate
  begin
    coef_multiplier : entity work.gf_multiplier(rtl)
      generic map (
        GF_POLYNOMIAL => GF_POLYNOMIAL
      )
      port map (
        mul_a     => prim_elem_exp(i,GF_POLYNOMIAL),
        mul_b     => gammas(i),
        product   => gammas_new(i)
      );
  end generate gen_coef_multipliers;

  clk_proc : process (clk, rst)
  begin
    if rst = '1' then
      gammas            <= (OTHERS => GF_ZERO);
      n                 <= 0;
      calculator_state  <= IDLE;
      ready             <= '0';
      debug_root_found  <= '0';
    elsif rising_edge(clk) then
      ready             <= '0'; -- preassignment
      debug_root_found  <= '0';

      if new_calc = '1' then
        n                 <= 0;
        calculator_state  <= CALCULATING;
        for i in CORRECTABLE_ERR downto 0 loop
          gammas(i) <= err_locator_in((i+1)*M-1 downto i*M);
        end loop;
      end if;

      if calculator_state = CALCULATING then
        if n = 2**M-2 then
          calculator_state  <= IDLE;
        else
          n <= n + 1;
        end if;

        if gammas_sum = GF_ZERO then
          -- alpha^n is a root of the error locator
          debug_root_found  <= '1';
        end if;

        -- set new gamma values
        gammas  <= gammas_new;

        if calculator_state = IDLE then
          ready <= '1';
          -- output calculated values
        end if;
      end if;
    end if;
  end process clk_proc;

  comb_proc : process( gammas )
    variable var_gammas_sum   : gf_elem;
  begin
    -- add multiplication products together
    var_gammas_sum    := GF_ZERO;
    for i in gammas'range(1) loop
      var_gammas_sum := gammas(i) XOR var_gammas_sum;
    end loop;
    gammas_sum        <= var_gammas_sum;
  end process comb_proc;

end rtl;
