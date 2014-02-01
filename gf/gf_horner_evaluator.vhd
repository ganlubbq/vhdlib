-----------------------------------------------------
-- Polynomial evaluation by use of Horner's scheme --
-----------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity gf_horner_evaluator is
  generic (
    GF_POLYNOMIAL   : std_logic_vector  := G709_GF_POLY; -- irreducible, binary polynomial
    CORRECTABLE_ERR : integer           := 3
  );
  port (
    clk             : in  std_logic;
    rst             : in  std_logic;
    new_calc        : in  std_logic;
    err_eval_in     : in  std_logic_vector(2*CORRECTABLE_ERR*(GF_POLYNOMIAL'length-1)-1 downto 0);  -- highest order coefficient at MSBs, descending
    err_roots_in    : in  std_logic_vector(CORRECTABLE_ERR*(GF_POLYNOMIAL'length-1)-1 downto 0);
    ready           : out std_logic;
    eval_values_out : out std_logic_vector(CORRECTABLE_ERR*(GF_POLYNOMIAL'length-1)-1 downto 0)
  );
end entity;

architecture rtl of gf_horner_evaluator is
  constant M              : integer := GF_POLYNOMIAL'length-1;

  subtype gf_elem         is std_logic_vector(M-1 downto 0);
  type gf_values_t        is array(CORRECTABLE_ERR-1 downto 0) of gf_elem;
  type err_eval_t         is array(2*CORRECTABLE_ERR-1 downto 0) of gf_elem;
  type calculator_state_t is (IDLE, CALCULATING);

  constant GF_ZERO        : gf_elem := (OTHERS => '0');

  signal err_roots        : gf_values_t;
  signal eval_values      : gf_values_t;
  signal muls_out         : gf_values_t;
  signal err_eval         : err_eval_t;
  signal n                : integer range 0 to 2*CORRECTABLE_ERR-1;
  signal calculator_state : calculator_state_t;

begin

  -- Horner scheme multipliers
  gen_multipliers : for i in 0 to CORRECTABLE_ERR-1 generate
  begin
    multiplier : entity work.gf_multiplier(rtl)
      generic map (
        GF_POLYNOMIAL => GF_POLYNOMIAL
      )
      port map (
        mul_a         => err_roots(i),
        mul_b         => eval_values(i),
        product       => muls_out(i)
      );
  end generate gen_multipliers;

  clk_proc : process (clk, rst)
  begin
    if rst = '1' then
      err_roots         <= (OTHERS => GF_ZERO);
      err_eval          <= (OTHERS => GF_ZERO);
      eval_values       <= (OTHERS => GF_ZERO);
      n                 <= 0;
      ready             <= '0';
      calculator_state  <= IDLE;
    elsif rising_edge(clk) then

      if n /= 0 then
        n     <= n - 1;
        ready <= '0';
        for i in 0 to CORRECTABLE_ERR-1 loop
          eval_values(i) <= muls_out(i) XOR err_eval(n);
        end loop;
      else
        ready <= '1';
        for i in 0 to CORRECTABLE_ERR-1 loop
          eval_values_out((i+1)*M-1 downto i*M) <= eval_values(i);
        end loop;
      end if;

      if new_calc = '1' then
        n     <= 2*CORRECTABLE_ERR-1;
        ready <= '0';

        for i in 0 to 2*CORRECTABLE_ERR-1 loop
          err_eval(i) <= err_eval_in((i+1)*M-1 downto i*M);
        end loop;

        for i in 0 to CORRECTABLE_ERR-1 loop
          err_roots(i) <= err_roots_in((i+1)*M-1 downto i*M);
        end loop;
      end if;
    end if;
  end process clk_proc;

end rtl;
