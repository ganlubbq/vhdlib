--------------------------------------------------------------
-- An LFSR-based encoder for Reed-Solomon code over GF(2^M) --
--------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.vhdlib_package.all;

entity rs_lfsr_encoder is
  generic (
    GEN_POLYNOMIAL  : gf2m_poly_t       := G709_GEN_POLY;         -- a generator polynomial given as an array of integers
    GF_POLYNOMIAL   : std_logic_vector  := G709_GF_POLY           -- irreducible, binary polynomial
  );
  port (
    clk : in  std_logic;                                          -- clock
    rst : in  std_logic;                                          -- asynchronous reset
    som : in  std_logic;                                          -- start of message to be encoded; encoding is restarted when asserted
    msg : in  std_logic_vector(GF_POLYNOMIAL'length-2 downto 0);  -- GF(2^M) element of input message to be encoded
    soc : out std_logic;                                          -- start of codeword
    eoc : out std_logic;                                          -- end of codeword
    cw  : out std_logic_vector(GF_POLYNOMIAL'length-2 downto 0)   -- GF(2^M) element of output codeword
  );
end entity;

architecture rtl of rs_lfsr_encoder is
  constant M  : integer := GF_POLYNOMIAL'length-1;                                -- order of GF irreducible, binary polynomial
  constant N  : integer := 2**M-1;                                                -- total number of symbols in codeword
  constant DT : integer := GEN_POLYNOMIAL'length-1;                               -- number of parity symbols in codeword; twice the number of correctable errors
  constant K  : integer := N-DT;                                                  -- number of information symbols in codeword
  constant GX : gf2m_poly_t(GEN_POLYNOMIAL'length-1 downto 0) := GEN_POLYNOMIAL;  -- done to make sure polynomial range is descending

  subtype gf_elem is std_logic_vector(M-1 downto 0);
  type gf_elem_array_t is array(DT-1 downto 0) of gf_elem;

  signal mul_out      : gf_elem_array_t;        -- output from GF multipliers
  signal gf_regs      : gf_elem_array_t;        -- LFSR registers
  signal gf_regs_fb   : gf_elem_array_t;        -- output from LFSR registers
  signal msg_xor      : gf_elem;                -- feedback from last register added to input data
  signal codeword_cnt : unsigned(M-1 downto 0); -- counter for codeword generation

begin

  gen_multipliers : for i in DT-1 downto 0 generate
    cons_multiplier : entity work.gf_multiplier(rtl)
      generic map (
        GF_POLYNOMIAL => GF_POLYNOMIAL
      )
      port map (
        mul_a         => std_logic_vector(to_unsigned(GX(i),M)),  -- ith coefficient of GEN_POLYNOMIAL
        mul_b         => msg_xor,
        product       => mul_out(i)
      );
  end generate gen_multipliers;

  shift_proc : process(clk, rst)
  begin
    if rst = '1' then
      gf_regs         <= (OTHERS => (OTHERS => '0'));
      codeword_cnt    <= (OTHERS => '1');
      cw              <= (OTHERS => '0');
      soc             <= '0';
      eoc             <= '0';

    elsif rising_edge(clk) then
      for i in DT-1 downto 1 loop
        -- add register values to multiplicator outputs and shift them to next register
        gf_regs(i)    <= gf_regs_fb(i-1) XOR mul_out(i);
      end loop;

      gf_regs(0)      <= mul_out(0);

      -- codeword counter
      if codeword_cnt /= N then
        codeword_cnt  <= codeword_cnt + 1;
      end if;

      if codeword_cnt = N-2 then
        -- last symbol of codeword on output signal cw
        eoc           <= '1';
      else
        eoc           <= '0';
      end if;

      if (codeword_cnt < K or som = '1') then
        -- bypass information symbols to codeword output
        cw            <= msg;
      else
        -- output redundancy symbols
        cw            <= gf_regs(gf_regs'high);
      end if;

      if som = '1' then
        -- start of new message to encode
        codeword_cnt  <= (OTHERS => '0');
        eoc           <= '0';
        soc           <= '1';
      else
        soc           <= '0';
      end if;

    end if;
  end process shift_proc;

  gf_regs_fb  <= gf_regs when som = '0' else (OTHERS => (OTHERS => '0'));
  msg_xor     <= msg XOR gf_regs_fb(gf_regs_fb'high) when (codeword_cnt < K-1 or som = '1') else (OTHERS => '0');

end rtl;
