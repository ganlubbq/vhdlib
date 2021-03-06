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
    GEN_POLYNOMIAL  : gf2m_polynomial   := GF2M_POLYNOMIAL_G709_GENERATOR;  -- a generator polynomial given as an array of integers
    GF_POLYNOMIAL   : std_logic_vector  := BINARY_POLYNOMIAL_G709_GF        -- irreducible, binary polynomial
  );
  port (
    clock             : in  std_logic;                                          -- clock
    reset             : in  std_logic;                                          -- asynchronous reset
    start_of_message  : in  std_logic;                                          -- start of message to be encoded; encoding is restarted when asserted
    message           : in  std_logic_vector(GF_POLYNOMIAL'length-2 downto 0);  -- GF(2^M) element of input message to be encoded
    start_of_codeword : out std_logic;                                          -- start of codeword
    end_of_codeword   : out std_logic;                                          -- end of codeword
    codeword          : out std_logic_vector(GF_POLYNOMIAL'length-2 downto 0)   -- GF(2^M) element of output codeword
  );
end entity;

architecture rtl of rs_lfsr_encoder is
  constant M  : natural := GF_POLYNOMIAL'length-1;                                -- order of GF irreducible, binary polynomial
  constant N  : natural := 2**M-1;                                                -- total number of symbols in codeword
  constant DT : natural := GEN_POLYNOMIAL'length-1;                               -- number of parity symbols in codeword; twice the number of correctable errors
  constant K  : natural := N-DT;                                                  -- number of information symbols in codeword
  constant GX : gf2m_polynomial(GEN_POLYNOMIAL'length-1 downto 0) := GEN_POLYNOMIAL;  -- done to make sure polynomial range is descending

  subtype gf_element is std_logic_vector(M-1 downto 0);
  type gf_element_array is array(DT-1 downto 0) of gf_element;

  signal multiplier_outputs : gf_element_array;       -- output from GF multipliers
  signal gf_regs            : gf_element_array;       -- LFSR registers
  signal gf_regs_fb         : gf_element_array;       -- output from LFSR registers
  signal message_xor        : gf_element;             -- feedback from last register added to input data
  signal codeword_count     : unsigned(M-1 downto 0); -- counter for codeword generation

begin

  gen_multipliers : for i in DT-1 downto 0 generate
    cons_multiplier : entity work.gf_multiplier(rtl)
      generic map (
        GF_POLYNOMIAL => GF_POLYNOMIAL
      )
      port map (
        multiplicand_a  => std_logic_vector(to_unsigned(GX(i),M)),  -- ith coefficient of GEN_POLYNOMIAL
        multiplicand_b  => message_xor,
        product         => multiplier_outputs(i)
      );
  end generate gen_multipliers;

  shift_proc : process(clock, reset)
  begin
    if reset = '1' then
      gf_regs         <= (OTHERS => (OTHERS => '0'));
      codeword_count    <= (OTHERS => '1');
      codeword              <= (OTHERS => '0');
      start_of_codeword             <= '0';
      end_of_codeword             <= '0';

    elsif rising_edge(clock) then
      for i in DT-1 downto 1 loop
        -- add register values to multiplicator outputs and shift them to next register
        gf_regs(i)    <= gf_regs_fb(i-1) XOR multiplier_outputs(i);
      end loop;

      gf_regs(0)      <= multiplier_outputs(0);

      -- codeword counter
      if codeword_count /= N then
        codeword_count  <= codeword_count + 1;
      end if;

      if codeword_count = N-2 then
        -- last symbol of codeword on output signal codeword
        end_of_codeword           <= '1';
      else
        end_of_codeword           <= '0';
      end if;

      if (codeword_count < K or start_of_message = '1') then
        -- bypass information symbols to codeword output
        codeword            <= message;
      else
        -- output redundancy symbols
        codeword            <= gf_regs(gf_regs'high);
      end if;

      if start_of_message = '1' then
        -- start of new message to encode
        codeword_count  <= (OTHERS => '0');
        end_of_codeword           <= '0';
        start_of_codeword           <= '1';
      else
        start_of_codeword           <= '0';
      end if;

    end if;
  end process shift_proc;

  gf_regs_fb  <= gf_regs when start_of_message = '0' else (OTHERS => (OTHERS => '0'));
  message_xor     <= message XOR gf_regs_fb(gf_regs_fb'high) when (codeword_count < K-1 or start_of_message = '1') else (OTHERS => '0');

end rtl;
