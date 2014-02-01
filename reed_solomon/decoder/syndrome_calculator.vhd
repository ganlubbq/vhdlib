------------------------------------------------
-- Syndrome calculator for codes over GF(2^M) --
------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity syndrome_calculator is
  generic (
    GF_POLYNOMIAL   : std_logic_vector  := G709_GF_POLY; -- irreducible, binary polynomial
    SYMBOL_WIDTH    : integer           := 8;
    NO_OF_SYMBOLS   : integer           := 10;
    NO_OF_SYNDROMES : integer           := 6
  );
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;
    en            : in  std_logic;
    new_calc      : in  std_logic;
    symbols       : in  std_logic_vector(SYMBOL_WIDTH*NO_OF_SYMBOLS-1 downto 0);                -- highest order symbol on MSBs, descending
    syndromes_in  : in  std_logic_vector(NO_OF_SYNDROMES*(GF_POLYNOMIAL'length-1)-1 downto 0);  -- lowest order syndrome on MSBs, ascending
    syndromes_out : out std_logic_vector(NO_OF_SYNDROMES*(GF_POLYNOMIAL'length-1)-1 downto 0)   -- lowest order syndrome on MSBs, ascending
  );
end entity;

architecture rtl of syndrome_calculator is
  constant M  : integer := GF_POLYNOMIAL'length-1;

  subtype gf_elem     is std_logic_vector(M-1 downto 0);
  type connections_t  is array(1 to NO_OF_SYNDROMES, 1 to NO_OF_SYMBOLS) of gf_elem;
  type gf_elements_t  is array(1 to NO_OF_SYNDROMES) of gf_elem;

  constant GF_ZERO  : gf_elem := (OTHERS => '0');

  signal connections    : connections_t;
  signal syndrome_regs  : gf_elements_t;
  signal syndrome_wires : gf_elements_t;

begin

  -- Horner scheme multipliers
  gen_syndromes : for j in 1 to NO_OF_SYNDROMES generate
  begin
    gen_symbols : for i in 0 to NO_OF_SYMBOLS-1 generate
    begin
      gen_top_multipliers : if i = 0 generate
      begin
        horner_multiplier : entity work.gf_horner_multiplier(rtl)
          generic map (
            GF_POLYNOMIAL => GF_POLYNOMIAL,
            PRIM_ELEM_POW => j,
            SYMBOL_WIDTH  => SYMBOL_WIDTH
          )
          port map (
            symbol      => symbols(symbols'high downto symbols'length-SYMBOL_WIDTH),
            product_in  => syndrome_wires(j),
            product_out => connections(j,i+1)
          );
      end generate gen_top_multipliers;

      gen_rest_of_multipliers : if i > 0 generate
      begin
        horner_multiplier : entity work.gf_horner_multiplier(rtl)
          generic map (
            GF_POLYNOMIAL => GF_POLYNOMIAL,
            PRIM_ELEM_POW => j,
            SYMBOL_WIDTH  => SYMBOL_WIDTH
          )
          port map (
            symbol      => symbols(symbols'high-i*SYMBOL_WIDTH downto symbols'length-(i+1)*SYMBOL_WIDTH),
            product_in  => connections(j,i),
            product_out => connections(j,i+1)
          );
      end generate gen_rest_of_multipliers;
    end generate gen_symbols;
  end generate gen_syndromes;

  clk_proc : process (clk, rst)
  begin
    if rst = '1' then
      syndrome_regs <= (OTHERS => GF_ZERO);
    elsif rising_edge(clk) then
      if en = '1' then
        for i in 1 to NO_OF_SYNDROMES loop
          syndrome_regs(i) <= connections(i,NO_OF_SYMBOLS);
        end loop;
      end if;
    end if;
  end process clk_proc;

  comb_proc : process(syndrome_regs, new_calc, syndromes_in)
  begin
    for i in 1 to NO_OF_SYNDROMES loop
      if new_calc = '1' then
        syndrome_wires(i) <= syndromes_in(syndromes_in'high-(i-1)*M downto syndromes_in'length-i*M);
      else
        syndrome_wires(i) <= syndrome_regs(i);
      end if;

      -- output
      syndromes_out(syndromes_out'high-(i-1)*M downto syndromes_out'length-i*M) <= syndrome_regs(i);
    end loop;
  end process comb_proc;

end rtl;
