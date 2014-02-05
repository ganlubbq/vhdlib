library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

library work;
use work.vhdlib_package.all;

entity vhdlib_tb is

end vhdlib_tb;

---------------------
-- rs_lfsr_encoder --
---------------------
architecture rs_lfsr_encoder_tb of vhdlib_tb is
  constant GEN_POLYNOMIAL   : gf2m_poly_t       := G709_GEN_POLY;
  constant GF_POLYNOMIAL    : std_logic_vector  := G709_GF_POLY;

  signal clk, rst, som, soc, eoc : std_logic := '0';
  signal msg, cw : std_logic_vector(7 downto 0);

begin

  dut : entity work.rs_lfsr_encoder(rtl)
    generic map (
      GEN_POLYNOMIAL  => GEN_POLYNOMIAL,
      GF_POLYNOMIAL   => GF_POLYNOMIAL
    )
    port map (
      clk => clk,
      rst => rst,
      som => som,
      msg => msg,
      soc => soc,
      eoc => eoc,
      cw  => cw
    );

  clk_proc : process
  begin
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
  end process clk_proc;

  stm_proc : process
    variable rdline : line;
    variable msg_stm : std_logic_vector(7 downto 0);
    variable som_stm  : std_logic;
    file vector_file : text open read_mode is "t_rs_lfsr_encoder.txt";
  begin

    rst <= '1';
    wait for 6 ns;
    rst <= '0';

    while not endfile(vector_file) loop
      readline(vector_file, rdline);
      read(rdline, som_stm);
      read(rdline, msg_stm);

      som <= som_stm;
      msg <= msg_stm;

      wait for 3 ns;

      wait for 7 ns;
    end loop;

    som <= '0';
    msg <= (OTHERS => '0');

    wait;
  end process stm_proc;

  assert_proc : process
    variable rdline : line;
    variable msg_stm : std_logic_vector(7 downto 0);
    variable som_stm  : std_logic;
    variable x,y : integer;
    file vector_file : text open read_mode is "t_rs_lfsr_encoder.txt";
  begin

    wait until soc = '1';

    while not endfile(vector_file) loop

      wait for 2 ns;

      readline(vector_file, rdline);
      read(rdline, som_stm);
      read(rdline, msg_stm);

      x := to_integer(unsigned(msg_stm));
      y := to_integer(unsigned(cw));

      assert x = y
        report "Incorrect output. Expected " & integer'image(x) & " not " & integer'image(y) severity error;

      assert x /= y
        report "Correct output" severity note;

      wait until rising_edge(clk);

    end loop;

    report "HAS ENDED!";
    wait;
  end process assert_proc;

end rs_lfsr_encoder_tb;

-------------------------
-- syndrome_calculator --
-------------------------

architecture syndrome_calculator_tb of vhdlib_tb is
  constant GF_POLYNOMIAL    : std_logic_vector := "10011"; -- irreducible, binary polynomial
  constant SYMBOL_WIDTH     : integer := 4;
  constant NO_OF_SYMBOLS    : integer := 3;
  constant NO_OF_SYNDROMES  : integer := 6;
  constant M                : integer := GF_POLYNOMIAL'length-1;

  signal clk            : std_logic;
  signal rst            : std_logic;
  signal en             : std_logic;
  signal new_calc       : std_logic;
  signal symbols        : std_logic_vector(SYMBOL_WIDTH*NO_OF_SYMBOLS-1 downto 0);
  signal syndromes_in   : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0);
  signal syndromes_out  : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0);

begin

  dut : entity work.syndrome_calculator(rtl)
  generic map (
    GF_POLYNOMIAL   => GF_POLYNOMIAL,
    SYMBOL_WIDTH    => SYMBOL_WIDTH,
    NO_OF_SYMBOLS   => NO_OF_SYMBOLS,
    NO_OF_SYNDROMES => NO_OF_SYNDROMES
  )
  port map (
    clk             => clk,
    rst             => rst,
    en              => en,
    new_calc        => new_calc,
    symbols         => symbols,
    syndromes_in    => syndromes_in,
    syndromes_out   => syndromes_out
  );

  clk_proc : process
  begin
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
  end process clk_proc;

  stm_proc : process
    variable rdline       : line;
    variable new_calc_stm : std_logic;
    variable symbol_stm   : integer;
    variable syndrome_stm : integer;
    file vector_file      : text open read_mode is "t_syndrome_calculator.txt";
  begin

    new_calc      <= '0';
    en            <= '0';
    symbols       <= (OTHERS => '0');
    syndromes_in  <= (OTHERS => '0');

    rst <= '1';
    wait for 6 ns;
    rst <= '0';
    en    <= '1';

    while not endfile(vector_file) loop
      readline(vector_file, rdline);
      read(rdline, new_calc_stm);
      new_calc <= new_calc_stm;

      for i in 0 to NO_OF_SYMBOLS-1 loop
        read(rdline, symbol_stm);
        symbols(symbols'high-i*SYMBOL_WIDTH downto symbols'length-(i+1)*SYMBOL_WIDTH) <= std_logic_vector(to_unsigned(symbol_stm,SYMBOL_WIDTH));
      end loop;

      for i in 0 to NO_OF_SYNDROMES-1 loop
        read(rdline, syndrome_stm);
        syndromes_in(syndromes_in'high-i*M downto syndromes_in'length-(i+1)*M) <= std_logic_vector(to_unsigned(syndrome_stm,M));
      end loop;

      wait for 10 ns;

      for i in 0 to NO_OF_SYNDROMES-1 loop
        read(rdline, syndrome_stm);
        assert syndromes_out(syndromes_out'high-i*M downto syndromes_out'length-(i+1)*M) = std_logic_vector(to_unsigned(syndrome_stm,M))
          report "ERROR!" severity error;
      end loop;

    end loop;

    new_calc      <= '0';
    en            <= '0';
    symbols       <= (OTHERS => '0');
    syndromes_in  <= (OTHERS => '0');
    report "HAS ENDED!";
    wait;
  end process stm_proc;

end syndrome_calculator_tb;

----------------------
-- gf_lookup_table --
----------------------

architecture gf_lookup_table_tb of vhdlib_tb is

  constant GF_POLYNOMIAL : std_logic_vector := "10011";
  constant M             : integer          := GF_POLYNOMIAL'length-1;
  constant TABLE_TYPE    : string           := EXP_TABLE_TYPE;

  signal clk        : std_logic;
  signal elem_in    : std_logic_vector(M-1 downto 0);
  signal elem_out   : std_logic_vector(M-1 downto 0);

begin

  dut : entity work.gf_lookup_table(rtl)
  generic map (
    GF_POLYNOMIAL => GF_POLYNOMIAL,
    TABLE_TYPE    => TABLE_TYPE
  )
  port map (
    clk      => clk,
    elem_in  => elem_in,
    elem_out => elem_out
  );

  clk_proc : process
  begin
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
  end process clk_proc;

  stm_proc : process
    variable rdline       : line;
    variable elem_stm     : integer;
    file vector_file      : text open read_mode is "t_gf_lookup_table.txt";
  begin
    elem_in       <= (OTHERS => '0');
    wait for 6 ns;

    while not endfile(vector_file) loop

      readline(vector_file, rdline);
      read(rdline, elem_stm);
      elem_in       <= std_logic_vector(to_unsigned(elem_stm,M));

      wait for 10 ns;

      read(rdline, elem_stm);
      assert elem_out = std_logic_vector(to_unsigned(elem_stm,M)) report "ERROR!" severity error;
    end loop;
    report "HAS ENDED!";
    wait;
  end process stm_proc;

end gf_lookup_table_tb;

--------------------------
-- gf_horner_multiplier --
--------------------------

architecture gf_horner_multiplier_tb of vhdlib_tb is

  constant GF_POLYNOMIAL : std_logic_vector := "10011";
  constant PRIM_ELEM_POW : integer          := 1;
  constant SYMBOL_WIDTH  : integer          := 4;
  constant M             : integer          := GF_POLYNOMIAL'length-1;

  signal symbol        : std_logic_vector(SYMBOL_WIDTH-1 downto 0);
  signal product_in    : std_logic_vector(M-1 downto 0);
  signal product_out   : std_logic_vector(M-1 downto 0);

begin

  dut : entity work.gf_horner_multiplier(rtl)
  generic map (
    GF_POLYNOMIAL => GF_POLYNOMIAL,
    PRIM_ELEM_POW => PRIM_ELEM_POW,
    SYMBOL_WIDTH  => SYMBOL_WIDTH
  )
  port map (
    symbol      => symbol,
    product_in  => product_in,
    product_out => product_out
  );

  stm_proc : process
    variable rdline : line;
    variable symbol_stm       : integer;
    variable product_in_stm   : integer;
    variable product_out_stm  : integer;
    file vector_file : text open read_mode is "t_gf_horner_multiplier.txt";
  begin
    while not endfile(vector_file) loop
      readline(vector_file, rdline);
      read(rdline, symbol_stm);
      read(rdline, product_in_stm);
      read(rdline, product_out_stm);
      symbol        <= std_logic_vector(to_unsigned(symbol_stm,SYMBOL_WIDTH));
      product_in    <= std_logic_vector(to_unsigned(product_in_stm,M));
      wait for 1 ns;
      assert product_out = std_logic_vector(to_unsigned(product_out_stm,M)) report "ERROR!" severity error;
      assert product_out /= std_logic_vector(to_unsigned(product_out_stm,M)) report "Correct output" severity note;
      wait for 1 ns;
    end loop;
    report "HAS ENDED!";
    wait;
  end process stm_proc;

end gf_horner_multiplier_tb;

-----------------
-- crc_gen_par --
-----------------
architecture crc_gen_par_tb of vhdlib_tb is
  constant POLYNOMIAL  : std_logic_vector := CRC32_POLY;
  constant DATA_WIDTH  : integer := 8;

  signal crc_in, crc_out : std_logic_vector(POLYNOMIAL'length-2 downto 0);
  signal dat_in : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

  dut : entity work.crc_gen_par(rtl)
    generic map (
      POLYNOMIAL  => POLYNOMIAL,
      DATA_WIDTH  => DATA_WIDTH
    )
    port map (
      crc_in  => crc_in,
      dat_in  => dat_in,
      crc_out => crc_out
    );

  stm_proc : process
    variable rdline : line;
    variable dat_in_stm  : std_logic_vector(DATA_WIDTH-1 downto 0);
    variable crc_out_chk  : std_logic_vector(POLYNOMIAL'length-2 downto 0);
    file vector_file : text open read_mode is "t_crc_gen_par.txt";
  begin

    crc_in <= (OTHERS => '0');

    while not endfile(vector_file) loop
      readline(vector_file, rdline);
      read(rdline, dat_in_stm);
      read(rdline, crc_out_chk);

      dat_in <= dat_in_stm;

      wait for 5 ns;

      assert crc_out = crc_out_chk
        report "ERROR" severity error;

      assert crc_out /= crc_out_chk
        report "Correct output" severity note;

      crc_in <= crc_out;

      wait for 5 ns;
    end loop;

    report "HAS ENDED!";
    wait;
  end process stm_proc;

end crc_gen_par_tb;

------------------
-- prbs_gen_par --
------------------
architecture prbs_gen_par_tb of vhdlib_tb is
  constant POLYNOMIAL  : std_logic_vector := "101001";--PRBS_3_POLY;
  constant DATA_WIDTH  : integer := 7;--POLYNOMIAL'length-1;

  signal prbs_in  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal prbs_out : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

  dut : entity work.prbs_gen_par(rtl)
    generic map (
      POLYNOMIAL  => POLYNOMIAL,
      DATA_WIDTH  => DATA_WIDTH
    )
    port map (
      prbs_in   => prbs_in,
      prbs_out  => prbs_out
    );

  stm_proc : process
    variable rdline : line;
    variable prbs_in_stm  : std_logic_vector(DATA_WIDTH-1 downto 0);
    variable prbs_out_chk : std_logic_vector(DATA_WIDTH-1 downto 0);
    file vector_file : text open read_mode is "t_prbs_gen_par.txt";
  begin

    while not endfile(vector_file) loop
      readline(vector_file, rdline);
      read(rdline, prbs_in_stm);
      read(rdline, prbs_out_chk);

      prbs_in <= prbs_in_stm;

      wait for 5 ns;

      assert prbs_out = prbs_out_chk
        report "ERROR" severity error;

      assert prbs_out /= prbs_out_chk
        report "Correct output" severity note;

      wait for 5 ns;
    end loop;

    report "HAS ENDED!";
    wait;
  end process stm_proc;

end prbs_gen_par_tb;

---------------------------------
-- berlekamp_massey_calculator --
---------------------------------

architecture berlekamp_massey_calculator_tb of vhdlib_tb is
  constant GF_POLYNOMIAL    : std_logic_vector := "10011"; -- irreducible, binary polynomial
  constant SYMBOL_WIDTH     : integer := 4;
  constant CORRECTABLE_ERR  : integer := 3;
  constant NO_OF_SYNDROMES  : integer := 2*CORRECTABLE_ERR;
  constant M                : integer := GF_POLYNOMIAL'length-1;

  signal clk              : std_logic;
  signal rst              : std_logic;
  signal new_calc         : std_logic;
  signal syndromes_in     : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0);
  signal ready            : std_logic;
  signal err_locator_out  : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0);

begin

  dut : entity work.berlekamp_massey_calculator(rtl)
  generic map (
    GF_POLYNOMIAL   => GF_POLYNOMIAL,
    NO_OF_SYNDROMES => NO_OF_SYNDROMES
  )
  port map (
    clk             => clk,
    rst             => rst,
    new_calc        => new_calc,
    syndromes_in    => syndromes_in,
    ready           => ready,
    err_locator_out => err_locator_out
  );

  clk_proc : process
  begin
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
  end process clk_proc;

  stm_proc : process
    variable rdline       : line;
    variable gf_elem_stm  : integer;
    file vector_file      : text open read_mode is "t_berlekamp_massey_calculator.txt";
  begin

    new_calc      <= '0';
    syndromes_in  <= (OTHERS => '0');

    rst <= '1';
    wait for 6 ns;
    rst <= '0';

    while not endfile(vector_file) loop
      readline(vector_file, rdline);
      new_calc <= '1';

      for i in 0 to NO_OF_SYNDROMES-1 loop
        read(rdline, gf_elem_stm);
        syndromes_in(syndromes_in'high-i*M downto syndromes_in'length-(i+1)*M) <= std_logic_vector(to_unsigned(gf_elem_stm,M));
      end loop;

      wait for 10 ns;

      new_calc  <= '0';

      wait until ready = '1';

      wait for 10 ns;

      for i in 0 to NO_OF_SYNDROMES-1 loop
        read(rdline, gf_elem_stm);
        assert err_locator_out(err_locator_out'high-i*M downto err_locator_out'length-(i+1)*M) = std_logic_vector(to_unsigned(gf_elem_stm,M))
          report "ERROR!" severity error;
      end loop;

    end loop;

    syndromes_in  <= (OTHERS => '0');
    report "HAS ENDED!";
    wait;
  end process stm_proc;

end berlekamp_massey_calculator_tb;

---------------------------
-- error_value_evaluator --
---------------------------

architecture error_value_evaluator_tb of vhdlib_tb is
  constant GF_POLYNOMIAL    : std_logic_vector := "10011"; -- irreducible, binary polynomial
  constant SYMBOL_WIDTH     : integer := 4;
  constant CORRECTABLE_ERR  : integer := 3;
  constant NO_OF_SYNDROMES  : integer := 2*CORRECTABLE_ERR;
  constant M                : integer := GF_POLYNOMIAL'length-1;

  signal clk              : std_logic;
  signal rst              : std_logic;
  signal new_calc         : std_logic;
  signal syndromes_in     : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0);
  signal err_locator_in   : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0);
  signal ready            : std_logic;
  signal err_eval_out     : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0);

begin

  dut : entity work.error_value_evaluator(rtl)
  generic map (
    GF_POLYNOMIAL   => GF_POLYNOMIAL,
    NO_OF_SYNDROMES => NO_OF_SYNDROMES
  )
  port map (
    clk             => clk,
    rst             => rst,
    new_calc        => new_calc,
    syndromes_in    => syndromes_in,
    err_locator_in  => err_locator_in,
    ready           => ready,
    err_eval_out    => err_eval_out
  );

  clk_proc : process
  begin
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
  end process clk_proc;

  stm_proc : process
    variable rdline       : line;
    variable gf_elem_stm  : integer;
    file vector_file      : text open read_mode is "t_error_value_evaluator.txt";
  begin

    new_calc        <= '0';
    syndromes_in    <= (OTHERS => '0');
    err_locator_in  <= (OTHERS => '0');

    rst <= '1';
    wait for 6 ns;
    rst <= '0';

    while not endfile(vector_file) loop
      readline(vector_file, rdline);
      new_calc <= '1';

      for i in 0 to NO_OF_SYNDROMES-1 loop
        read(rdline, gf_elem_stm);
        syndromes_in(syndromes_in'high-i*M downto syndromes_in'length-(i+1)*M) <= std_logic_vector(to_unsigned(gf_elem_stm,M));
      end loop;

      for i in 0 to NO_OF_SYNDROMES-1 loop
        read(rdline, gf_elem_stm);
        err_locator_in(err_locator_in'high-i*M downto err_locator_in'length-(i+1)*M) <= std_logic_vector(to_unsigned(gf_elem_stm,M));
      end loop;

      wait for 10 ns;

      new_calc  <= '0';

      wait until ready = '1';

      wait for 10 ns;

      for i in 0 to NO_OF_SYNDROMES-1 loop
        read(rdline, gf_elem_stm);
        assert err_eval_out(err_eval_out'high-i*M downto err_eval_out'length-(i+1)*M) = std_logic_vector(to_unsigned(gf_elem_stm,M))
          report "ERROR!" severity error;
      end loop;

    end loop;

    syndromes_in    <= (OTHERS => '0');
    err_locator_in  <= (OTHERS => '0');
    report "HAS ENDED!";
    wait;
  end process stm_proc;

end error_value_evaluator_tb;

------------------
-- chien_search --
------------------

architecture chien_search_tb of vhdlib_tb is
  constant GF_POLYNOMIAL    : std_logic_vector := "10011"; -- irreducible, binary polynomial
  constant SYMBOL_WIDTH     : integer := 4;
  constant CORRECTABLE_ERR  : integer := 3;
  constant NO_OF_SYNDROMES  : integer := 2*CORRECTABLE_ERR;
  constant M                : integer := GF_POLYNOMIAL'length-1;

  signal clk                : std_logic;
  signal rst                : std_logic;
  signal new_calc           : std_logic;
  signal err_locator_in     : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0);
  signal ready              : std_logic;
  signal err_roots_out      : std_logic_vector(CORRECTABLE_ERR*M-1 downto 0);
  signal err_locations_out  : std_logic_vector(CORRECTABLE_ERR*M-1 downto 0);
  signal bit_locations_out  : std_logic_vector(CORRECTABLE_ERR*M-1 downto 0);

begin

  dut : entity work.chien_search(rtl)
  generic map (
    GF_POLYNOMIAL   => GF_POLYNOMIAL,
    CORRECTABLE_ERR => CORRECTABLE_ERR,
    NO_OF_SYNDROMES => NO_OF_SYNDROMES
  )
  port map (
    clk                 => clk,
    rst                 => rst,
    new_calc            => new_calc,
    err_locator_in      => err_locator_in,
    ready               => ready,
    err_roots_out       => err_roots_out,
    err_locations_out   => err_locations_out,
    bit_locations_out   => bit_locations_out
  );

  clk_proc : process
  begin
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
  end process clk_proc;

  stm_proc : process
    variable rdline       : line;
    variable gf_elem_stm  : integer;
    file vector_file      : text open read_mode is "t_chien_search.txt";
  begin

    new_calc        <= '0';
    err_locator_in  <= (OTHERS => '0');

    rst <= '1';
    wait for 6 ns;
    rst <= '0';

    while not endfile(vector_file) loop
      readline(vector_file, rdline);
      new_calc <= '1';

      for i in 0 to NO_OF_SYNDROMES-1 loop
        read(rdline, gf_elem_stm);
        err_locator_in(err_locator_in'high-i*M downto err_locator_in'length-(i+1)*M) <= std_logic_vector(to_unsigned(gf_elem_stm,M));
      end loop;

      wait for 10 ns;

      new_calc  <= '0';

      wait until ready = '1';

      wait for 10 ns;

--       for i in 0 to NO_OF_SYNDROMES-1 loop
--         read(rdline, gf_elem_stm);
--         assert err_eval_out(err_eval_out'high-i*M downto err_eval_out'length-(i+1)*M) = std_logic_vector(to_unsigned(gf_elem_stm,M))
--           report "ERROR!" severity error;
--       end loop;

    end loop;

    err_locator_in  <= (OTHERS => '0');
    report "HAS ENDED!";
    wait;
  end process stm_proc;

end chien_search_tb;
