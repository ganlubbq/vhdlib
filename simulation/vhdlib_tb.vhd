library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

library work;
use work.vhdlib_package.all;

entity vhdlib_tb is
  
  constant BINARY_POLYNOMIAL_DECIMAL_19 : std_logic_vector  := "10011";

end vhdlib_tb;

---------------------
-- rs_lfsr_encoder --
---------------------
architecture rs_lfsr_encoder_tb of vhdlib_tb is
  constant GEN_POLYNOMIAL   : gf2m_poly_t       := GF2M_POLYNOMIAL_G709_GENERATOR;
  constant GF_POLYNOMIAL    : std_logic_vector  := BINARY_POLYNOMIAL_G709_GF;

  signal clock, reset, start_of_message, start_of_codeword, end_of_codeword : std_logic := '0';
  signal message, codeword : std_logic_vector(7 downto 0);

begin

  dut : entity work.rs_lfsr_encoder(rtl)
  generic map (
                GEN_POLYNOMIAL  => GEN_POLYNOMIAL,
                GF_POLYNOMIAL   => GF_POLYNOMIAL
              )
  port map (
             clock              => clock,
             reset              => reset,
             start_of_message   => start_of_message,
             message            => message,
             start_of_codeword  => start_of_codeword,
             end_of_codeword    => end_of_codeword,
             codeword           => codeword
           );

  clock_process : process
  begin
    clock <= '0';
    wait for 5 ns;
    clock <= '1';
    wait for 5 ns;
  end process clock_process;

  stm_process : process
    variable read_line : line;
    variable message_stm : std_logic_vector(7 downto 0);
    variable start_of_message_stm  : std_logic;
    file vector_file : text open read_mode is "t_rs_lfsr_encoder.txt";
  begin

    reset <= '1';
    wait for 6 ns;
    reset <= '0';

    while not endfile(vector_file) loop
      readline(vector_file, read_line);
      read(read_line, start_of_message_stm);
      read(read_line, message_stm);

      start_of_message <= start_of_message_stm;
      message <= message_stm;

      wait for 3 ns;

      wait for 7 ns;
    end loop;

    start_of_message <= '0';
    message <= (OTHERS => '0');

    wait;
  end process stm_process;

  assert_process : process
    variable read_line : line;
    variable message_stm : std_logic_vector(7 downto 0);
    variable start_of_message_stm  : std_logic;
    variable message_int, codeword_int : integer;
    file vector_file : text open read_mode is "t_rs_lfsr_encoder.txt";
  begin

    wait until start_of_codeword = '1';

    while not endfile(vector_file) loop

      wait for 2 ns;

      readline(vector_file, read_line);
      read(read_line, start_of_message_stm);
      read(read_line, message_stm);

      message_int := to_integer(unsigned(message_stm));
      codeword_int := to_integer(unsigned(codeword));

      assert message_int = codeword_int
      report "Incorrect output. Expected " & integer'image(message_int) & " not " & integer'image(codeword_int) severity error;

      assert message_int /= codeword_int
      report "Correct output" severity note;

      wait until rising_edge(clock);

    end loop;

    report "HAS ENDED!";
    wait;
  end process assert_process;

end rs_lfsr_encoder_tb;

-------------------------
-- gf_horner_evaluator --
-------------------------

architecture gf_horner_evaluator_tb of vhdlib_tb is
  constant GF_POLYNOMIAL    : std_logic_vector := BINARY_POLYNOMIAL_DECIMAL_19; -- irreducible, binary polynomial
  constant NO_OF_PAR_EVALS  : natural := 6;
  constant NO_OF_COEFS      : natural := 3;
  constant SYMBOL_WIDTH     : natural := 4;
  constant M                : natural := GF_POLYNOMIAL'length-1;

  signal clock            : std_logic;
  signal reset            : std_logic;
  signal clock_enable     : std_logic;
  signal new_calculation  : std_logic;
  signal coefficients     : std_logic_vector(NO_OF_COEFS*SYMBOL_WIDTH-1 downto 0);
  signal eval_values      : std_logic_vector(NO_OF_PAR_EVALS*M-1 downto 0);
  signal start_values     : std_logic_vector(NO_OF_PAR_EVALS*M-1 downto 0);
  signal result_values    : std_logic_vector(NO_OF_PAR_EVALS*M-1 downto 0);

begin

  dut : entity work.gf_horner_evaluator(rtl)
  generic map (
                GF_POLYNOMIAL   => GF_POLYNOMIAL,
                NO_OF_PAR_EVALS => NO_OF_PAR_EVALS,
                NO_OF_COEFS     => NO_OF_COEFS,
                SYMBOL_WIDTH    => SYMBOL_WIDTH
              )
  port map (
             clock           => clock,
             reset           => reset,
             clock_enable    => clock_enable,
             new_calculation => new_calculation,
             coefficients    => coefficients,
             eval_values     => eval_values,
             start_values    => start_values,
             result_values   => result_values
           );

  clock_process : process
  begin
    clock <= '0';
    wait for 5 ns;
    clock <= '1';
    wait for 5 ns;
  end process clock_process;

  stm_process : process
    variable read_line            : line;
    variable new_calculation_stm  : std_logic;
    variable coefficient_stm      : integer;
    variable value_stm            : integer;
    file vector_file              : text open read_mode is "t_gf_horner_evaluator.txt";
  begin

    new_calculation <= '0';
    clock_enable <= '0';
    coefficients <= (OTHERS => '0');
    eval_values <= (OTHERS => '0');
    start_values <= (OTHERS => '0');

    reset <= '1';
    wait for 6 ns;
    reset <= '0';
    clock_enable  <= '1';

    while not endfile(vector_file) loop
      readline(vector_file, read_line);
      read(read_line, new_calculation_stm);
      new_calculation <= new_calculation_stm;

      for i in 0 to NO_OF_COEFS-1 loop
        read(read_line, coefficient_stm);
        coefficients(coefficients'high-i*SYMBOL_WIDTH downto coefficients'length-(i+1)*SYMBOL_WIDTH) <= std_logic_vector(to_unsigned(coefficient_stm,SYMBOL_WIDTH));
      end loop;

      for i in 0 to NO_OF_PAR_EVALS-1 loop
        read(read_line, value_stm);
        eval_values(eval_values'high-i*M downto eval_values'length-(i+1)*M) <= std_logic_vector(to_unsigned(value_stm,M));
      end loop;

      for i in 0 to NO_OF_PAR_EVALS-1 loop
        read(read_line, value_stm);
        start_values(start_values'high-i*M downto start_values'length-(i+1)*M) <= std_logic_vector(to_unsigned(value_stm,M));
      end loop;

      wait for 10 ns;

      for i in 0 to NO_OF_PAR_EVALS-1 loop
        read(read_line, value_stm);
        assert result_values(result_values'high-i*M downto result_values'length-(i+1)*M) = std_logic_vector(to_unsigned(value_stm,M))
          report "ERROR!" severity error;
      end loop;

    end loop;

    new_calculation <= '0';
    clock_enable <= '0';
    coefficients <= (OTHERS => '0');
    eval_values <= (OTHERS => '0');
    start_values <= (OTHERS => '0');
    report "HAS ENDED!";
    wait;
  end process stm_process;

end gf_horner_evaluator_tb;

-------------------------
-- syndrome_calculator --
-------------------------

architecture syndrome_calculator_tb of vhdlib_tb is
  constant GF_POLYNOMIAL    : std_logic_vector := BINARY_POLYNOMIAL_DECIMAL_19; -- irreducible, binary polynomial
  constant NO_OF_COEFS      : natural := 3;
  constant NO_OF_SYNDROMES  : natural := 6;
  constant M                : natural := GF_POLYNOMIAL'length-1;

  signal clock            : std_logic;
  signal reset            : std_logic;
  signal clock_enable     : std_logic;
  signal new_calculation  : std_logic;
  signal coefficients     : std_logic_vector(NO_OF_COEFS*M-1 downto 0);
  signal syndromes        : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0);

begin

  dut : entity work.syndrome_calculator(rtl)
  generic map (
    GF_POLYNOMIAL   => GF_POLYNOMIAL,
    NO_OF_COEFS     => NO_OF_COEFS,
    NO_OF_SYNDROMES => NO_OF_SYNDROMES
  )
  port map (
    clock           => clock,
    reset           => reset,
    clock_enable    => clock_enable,
    new_calculation => new_calculation,
    coefficients    => coefficients,
    syndromes       => syndromes
  );

  clock_process : process
  begin
    clock <= '0';
    wait for 5 ns;
    clock <= '1';
    wait for 5 ns;
  end process clock_process;

  stm_process : process
    variable read_line           : line;
    variable new_calculation_stm     : std_logic;
    variable coefficient_stm  : integer;
    variable syndrome_stm     : integer;
    file vector_file          : text open read_mode is "t_syndrome_calculator.txt";
  begin

    new_calculation      <= '0';
    clock_enable    <= '0';
    coefficients  <= (OTHERS => '0');

    reset         <= '1';
    wait for 6 ns;
    reset         <= '0';
    clock_enable  <= '1';

    while not endfile(vector_file) loop
      readline(vector_file, read_line);
      read(read_line, new_calculation_stm);
      new_calculation <= new_calculation_stm;

      for i in 0 to NO_OF_COEFS-1 loop
        read(read_line, coefficient_stm);
        coefficients(coefficients'high-i*M downto coefficients'length-(i+1)*M) <= std_logic_vector(to_unsigned(coefficient_stm,M));
      end loop;

      wait for 10 ns;

      for i in 0 to NO_OF_SYNDROMES-1 loop
        read(read_line, syndrome_stm);
        assert syndromes(syndromes'high-i*M downto syndromes'length-(i+1)*M) = std_logic_vector(to_unsigned(syndrome_stm,M))
          report "ERROR!" severity error;
      end loop;

    end loop;

    new_calculation      <= '0';
    clock_enable    <= '0';
    coefficients  <= (OTHERS => '0');
    report "HAS ENDED!";
    wait;
  end process stm_process;

end syndrome_calculator_tb;

----------------------
-- gf_lookup_table --
----------------------

architecture gf_lookup_table_tb of vhdlib_tb is

  constant GF_POLYNOMIAL : std_logic_vector := BINARY_POLYNOMIAL_DECIMAL_19;
  constant M             : integer          := GF_POLYNOMIAL'length-1;
  constant TABLE_TYPE    : gf_table_type    := gf_table_type_zech_logarithm;

  signal clock        : std_logic;
  signal element_in    : std_logic_vector(M-1 downto 0);
  signal element_out   : std_logic_vector(M-1 downto 0);

begin

  dut : entity work.gf_lookup_table(rtl)
  generic map (
    GF_POLYNOMIAL => GF_POLYNOMIAL,
    TABLE_TYPE    => TABLE_TYPE
  )
  port map (
    clock      => clock,
    element_in  => element_in,
    element_out => element_out
  );

  clock_process : process
  begin
    clock <= '0';
    wait for 5 ns;
    clock <= '1';
    wait for 5 ns;
  end process clock_process;

  stm_process : process
    variable read_line       : line;
    variable element_stm     : integer;
    file vector_file      : text open read_mode is "t_gf_lookup_table.txt";
  begin
    element_in       <= (OTHERS => '0');
    wait for 6 ns;

    while not endfile(vector_file) loop

      readline(vector_file, read_line);
      read(read_line, element_stm);
      element_in       <= std_logic_vector(to_unsigned(element_stm,M));

      wait for 10 ns;

      read(read_line, element_stm);
      assert element_out = std_logic_vector(to_unsigned(element_stm,M)) report "ERROR!" severity error;
    end loop;
    report "HAS ENDED!";
    wait;
  end process stm_process;

end gf_lookup_table_tb;

--------------------------
-- gf_horner_multiplier --
--------------------------

architecture gf_horner_multiplier_tb of vhdlib_tb is

  constant GF_POLYNOMIAL : std_logic_vector := BINARY_POLYNOMIAL_DECIMAL_19;
  constant SYMBOL_WIDTH  : integer          := 4;
  constant M             : integer          := GF_POLYNOMIAL'length-1;

  signal coefficient   : std_logic_vector(SYMBOL_WIDTH-1 downto 0);
  signal eval_value    : std_logic_vector(M-1 downto 0);
  signal product_in    : std_logic_vector(M-1 downto 0);
  signal product_out   : std_logic_vector(M-1 downto 0);

begin

  dut : entity work.gf_horner_multiplier(rtl)
  generic map (
    GF_POLYNOMIAL => GF_POLYNOMIAL,
    SYMBOL_WIDTH  => SYMBOL_WIDTH
  )
  port map (
    coefficient => coefficient,
    eval_value  => eval_value,
    product_in  => product_in,
    product_out => product_out
  );

  stm_process : process
    variable read_line : line;
    variable coefficient_stm  : integer;
    variable eval_value_stm   : integer;
    variable product_in_stm   : integer;
    variable product_out_stm  : integer;
    file vector_file : text open read_mode is "t_gf_horner_multiplier.txt";
  begin
    while not endfile(vector_file) loop
      readline(vector_file, read_line);
      read(read_line, coefficient_stm);
      read(read_line, product_in_stm);
      read(read_line, eval_value_stm);
      read(read_line, product_out_stm);
      coefficient   <= std_logic_vector(to_unsigned(coefficient_stm,SYMBOL_WIDTH));
      eval_value    <= std_logic_vector(to_unsigned(eval_value_stm,M));
      product_in    <= std_logic_vector(to_unsigned(product_in_stm,M));
      wait for 1 ns;
      assert product_out = std_logic_vector(to_unsigned(product_out_stm,M)) report "ERROR!" severity error;
      wait for 1 ns;
    end loop;
    report "HAS ENDED!";
    wait;
  end process stm_process;

end gf_horner_multiplier_tb;

----------------------------
-- crc_generator_parallel --
----------------------------
architecture crc_generator_parallel_tb of vhdlib_tb is
  constant POLYNOMIAL  : std_logic_vector := BINARY_POLYNOMIAL_CRC32;
  constant DATA_WIDTH  : integer := 8;

  signal crc_in, crc_out : std_logic_vector(POLYNOMIAL'length-2 downto 0);
  signal data_in : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

  dut : entity work.crc_generator_parallel(rtl)
    generic map (
      POLYNOMIAL  => POLYNOMIAL,
      DATA_WIDTH  => DATA_WIDTH
    )
    port map (
      crc_in  => crc_in,
      data_in  => data_in,
      crc_out => crc_out
    );

  stm_process : process
    variable read_line : line;
    variable data_in_stm  : std_logic_vector(DATA_WIDTH-1 downto 0);
    variable crc_out_check  : std_logic_vector(POLYNOMIAL'length-2 downto 0);
    file vector_file : text open read_mode is "t_crc_generator_parallel.txt";
  begin

    crc_in <= (OTHERS => '0');

    while not endfile(vector_file) loop
      readline(vector_file, read_line);
      read(read_line, data_in_stm);
      read(read_line, crc_out_check);

      data_in <= data_in_stm;

      wait for 5 ns;

      assert crc_out = crc_out_check
        report "ERROR" severity error;

      assert crc_out /= crc_out_check
        report "Correct output" severity note;

      crc_in <= crc_out;

      wait for 5 ns;
    end loop;

    report "HAS ENDED!";
    wait;
  end process stm_process;

end crc_generator_parallel_tb;

-----------------------------
-- prbs_generator_parallel --
-----------------------------
architecture prbs_generator_parallel_tb of vhdlib_tb is
  constant POLYNOMIAL  : std_logic_vector := "101001";--PRBS_3_POLY;
  constant DATA_WIDTH  : integer := 7;--POLYNOMIAL'length-1;

  signal prbs_in  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal prbs_out : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

  dut : entity work.prbs_generator_parallel(rtl)
    generic map (
      POLYNOMIAL  => POLYNOMIAL,
      DATA_WIDTH  => DATA_WIDTH
    )
    port map (
      prbs_in   => prbs_in,
      prbs_out  => prbs_out
    );

  stm_process : process
    variable read_line : line;
    variable prbs_in_stm  : std_logic_vector(DATA_WIDTH-1 downto 0);
    variable prbs_out_check : std_logic_vector(DATA_WIDTH-1 downto 0);
    file vector_file : text open read_mode is "t_prbs_generator_parallel.txt";
  begin

    while not endfile(vector_file) loop
      readline(vector_file, read_line);
      read(read_line, prbs_in_stm);
      read(read_line, prbs_out_check);

      prbs_in <= prbs_in_stm;

      wait for 5 ns;

      assert prbs_out = prbs_out_check
        report "ERROR" severity error;

      assert prbs_out /= prbs_out_check
        report "Correct output" severity note;

      wait for 5 ns;
    end loop;

    report "HAS ENDED!";
    wait;
  end process stm_process;

end prbs_generator_parallel_tb;

---------------------------------
-- berlekamp_massey_calculator --
---------------------------------

architecture berlekamp_massey_calculator_tb of vhdlib_tb is
  constant GF_POLYNOMIAL    : std_logic_vector := BINARY_POLYNOMIAL_DECIMAL_19; -- irreducible, binary polynomial
  constant SYMBOL_WIDTH     : integer := 4;
  constant NO_OF_CORR_ERRS  : integer := 3;
  constant NO_OF_SYNDROMES  : integer := 2*NO_OF_CORR_ERRS;
  constant M                : integer := GF_POLYNOMIAL'length-1;

  signal clock              : std_logic;
  signal reset              : std_logic;
  signal new_calculation         : std_logic;
  signal syndromes_in     : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0);
  signal ready            : std_logic;
  signal error_locator_out  : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0);

begin

  dut : entity work.berlekamp_massey_calculator(rtl)
  generic map (
    GF_POLYNOMIAL   => GF_POLYNOMIAL,
    NO_OF_SYNDROMES => NO_OF_SYNDROMES
  )
  port map (
    clock             => clock,
    reset             => reset,
    new_calculation        => new_calculation,
    syndromes_in    => syndromes_in,
    ready           => ready,
    error_locator_out => error_locator_out
  );

  clock_process : process
  begin
    clock <= '0';
    wait for 5 ns;
    clock <= '1';
    wait for 5 ns;
  end process clock_process;

  stm_process : process
    variable read_line       : line;
    variable gf_element_stm  : integer;
    file vector_file      : text open read_mode is "t_berlekamp_massey_calculator.txt";
  begin

    new_calculation      <= '0';
    syndromes_in  <= (OTHERS => '0');

    reset <= '1';
    wait for 6 ns;
    reset <= '0';

    while not endfile(vector_file) loop
      readline(vector_file, read_line);
      new_calculation <= '1';

      for i in 0 to NO_OF_SYNDROMES-1 loop
        read(read_line, gf_element_stm);
        syndromes_in(syndromes_in'high-i*M downto syndromes_in'length-(i+1)*M) <= std_logic_vector(to_unsigned(gf_element_stm,M));
      end loop;

      wait for 10 ns;

      new_calculation  <= '0';

      wait until ready = '1';

      wait for 10 ns;

      for i in 0 to NO_OF_SYNDROMES-1 loop
        read(read_line, gf_element_stm);
        assert error_locator_out(error_locator_out'high-i*M downto error_locator_out'length-(i+1)*M) = std_logic_vector(to_unsigned(gf_element_stm,M))
          report "ERROR!" severity error;
      end loop;

    end loop;

    syndromes_in  <= (OTHERS => '0');
    report "HAS ENDED!";
    wait;
  end process stm_process;

end berlekamp_massey_calculator_tb;

---------------------------
-- error_value_evaluator --
---------------------------

architecture error_value_evaluator_tb of vhdlib_tb is
  constant GF_POLYNOMIAL    : std_logic_vector := BINARY_POLYNOMIAL_DECIMAL_19; -- irreducible, binary polynomial
  constant SYMBOL_WIDTH     : integer := 4;
  constant NO_OF_CORR_ERRS  : integer := 3;
  constant NO_OF_SYNDROMES  : integer := 2*NO_OF_CORR_ERRS;
  constant M                : integer := GF_POLYNOMIAL'length-1;

  signal clock              : std_logic;
  signal reset              : std_logic;
  signal new_calculation         : std_logic;
  signal syndromes_in     : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0);
  signal error_locator_in   : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0);
  signal ready            : std_logic;
  signal error_eval_out     : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0);

begin

  dut : entity work.error_value_evaluator(rtl)
  generic map (
    GF_POLYNOMIAL   => GF_POLYNOMIAL,
    NO_OF_SYNDROMES => NO_OF_SYNDROMES
  )
  port map (
    clock             => clock,
    reset             => reset,
    new_calculation        => new_calculation,
    syndromes_in    => syndromes_in,
    error_locator_in  => error_locator_in,
    error_eval_out    => error_eval_out,
    ready           => ready
  );

  clock_process : process
  begin
    clock <= '0';
    wait for 5 ns;
    clock <= '1';
    wait for 5 ns;
  end process clock_process;

  stm_process : process
    variable read_line       : line;
    variable gf_element_stm  : integer;
    file vector_file      : text open read_mode is "t_error_value_evaluator.txt";
  begin

    new_calculation        <= '0';
    syndromes_in    <= (OTHERS => '0');
    error_locator_in  <= (OTHERS => '0');

    reset <= '1';
    wait for 6 ns;
    reset <= '0';

    while not endfile(vector_file) loop
      readline(vector_file, read_line);
      new_calculation <= '1';

      for i in 0 to NO_OF_SYNDROMES-1 loop
        read(read_line, gf_element_stm);
        syndromes_in(syndromes_in'high-i*M downto syndromes_in'length-(i+1)*M) <= std_logic_vector(to_unsigned(gf_element_stm,M));
      end loop;

      for i in 0 to NO_OF_SYNDROMES-1 loop
        read(read_line, gf_element_stm);
        error_locator_in(error_locator_in'high-i*M downto error_locator_in'length-(i+1)*M) <= std_logic_vector(to_unsigned(gf_element_stm,M));
      end loop;

      wait for 10 ns;

      new_calculation  <= '0';

      wait until ready = '1';

      wait for 10 ns;

      for i in 0 to NO_OF_SYNDROMES-1 loop
        read(read_line, gf_element_stm);
        assert error_eval_out(error_eval_out'high-i*M downto error_eval_out'length-(i+1)*M) = std_logic_vector(to_unsigned(gf_element_stm,M))
          report "ERROR!" severity error;
      end loop;

    end loop;

    syndromes_in    <= (OTHERS => '0');
    error_locator_in  <= (OTHERS => '0');
    report "HAS ENDED!";
    wait;
  end process stm_process;

end error_value_evaluator_tb;

-----------------------
-- forney_calculator --
-----------------------

-- architecture forney_calculator_tb of vhdlib_tb is
--   constant GF_POLYNOMIAL    : std_logic_vector := BINARY_POLYNOMIAL_DECIMAL_19; -- irreducible, binary polynomial
--   constant NO_OF_CORR_ERRS  : integer := 3;
--   constant NO_OF_SYNDROMES  : integer := 2*NO_OF_CORR_ERRS;
--   constant M                : integer := GF_POLYNOMIAL'length-1;
-- 
--   signal clock              : std_logic;
--   signal reset              : std_logic;
--   signal new_calculation         : std_logic;
--   signal error_roots_in     : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
--   signal error_eval_in      : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0);
--   signal error_values_out   : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
--   signal ready            : std_logic;
-- 
-- begin
-- 
--   dut : entity work.forney_calculator(rtl)
--   generic map (
--     GF_POLYNOMIAL   => GF_POLYNOMIAL,
--     NO_OF_CORR_ERRS => NO_OF_CORR_ERRS
--   )
--   port map (
--     clock             => clock,
--     reset             => reset,
--     new_calculation        => new_calculation,
--     error_roots_in    => error_roots_in,
--     error_eval_in     => error_eval_in,
--     error_values_out  => error_values_out,
--     ready           => ready
--   );
-- 
--   clock_process : process
--   begin
--     clock <= '0';
--     wait for 5 ns;
--     clock <= '1';
--     wait for 5 ns;
--   end process clock_process;
-- 
--   stm_process : process
--     variable read_line       : line;
--     variable gf_element_stm  : integer;
--     file vector_file      : text open read_mode is "t_forney_calculator.txt";
--   begin
-- 
--     new_calculation      <= '0';
--     error_roots_in  <= (OTHERS => '0');
--     error_eval_in   <= (OTHERS => '0');
-- 
--     reset <= '1';
--     wait for 6 ns;
--     reset <= '0';
-- 
--     while not endfile(vector_file) loop
--       readline(vector_file, read_line);
--       new_calculation <= '1';
-- 
--       for i in 0 to NO_OF_CORR_ERRS-1 loop
--         read(read_line, gf_element_stm);
--         error_roots_in(error_roots_in'high-i*M downto error_roots_in'length-(i+1)*M) <= std_logic_vector(to_unsigned(gf_element_stm,M));
--       end loop;
-- 
--       for i in 0 to NO_OF_SYNDROMES-1 loop
--         read(read_line, gf_element_stm);
--         error_eval_in(error_eval_in'high-i*M downto error_eval_in'length-(i+1)*M) <= std_logic_vector(to_unsigned(gf_element_stm,M));
--       end loop;
-- 
--       wait for 10 ns;
-- 
--       new_calculation  <= '0';
-- 
--       wait until ready = '1';
-- 
--       wait for 10 ns;
-- 
-- --       for i in 0 to NO_OF_SYNDROMES-1 loop
-- --         read(read_line, gf_element_stm);
-- --         assert error_values_out(error_values_out'high-i*M downto error_values_out'length-(i+1)*M) = std_logic_vector(to_unsigned(gf_element_stm,M))
-- --           report "ERROR!" severity error;
-- --       end loop;
-- 
--     end loop;
-- 
--     error_roots_in  <= (OTHERS => '0');
--     error_eval_in   <= (OTHERS => '0');
--     report "HAS ENDED!";
--     wait;
--   end process stm_process;
-- 
-- end forney_calculator_tb;

------------------
-- chien_search --
------------------

architecture chien_search_tb of vhdlib_tb is
  constant GF_POLYNOMIAL    : std_logic_vector := BINARY_POLYNOMIAL_DECIMAL_19; -- irreducible, binary polynomial
  constant SYMBOL_WIDTH     : integer := 4;
  constant NO_OF_CORR_ERRS  : integer := 3;
  constant NO_OF_SYNDROMES  : integer := 2*NO_OF_CORR_ERRS;
  constant M                : integer := GF_POLYNOMIAL'length-1;

  signal clock                : std_logic;
  signal reset                : std_logic;
  signal new_calculation           : std_logic;
  signal error_locator_in     : std_logic_vector(NO_OF_SYNDROMES*M-1 downto 0);
  signal ready              : std_logic;
  signal error_roots_out      : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
  signal error_locations_out  : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);
  signal sym_locations_out  : std_logic_vector(NO_OF_CORR_ERRS*M-1 downto 0);

begin

  dut : entity work.chien_search(rtl)
  generic map (
                GF_POLYNOMIAL   => GF_POLYNOMIAL,
                NO_OF_CORR_ERRS => NO_OF_CORR_ERRS,
                NO_OF_SYNDROMES => NO_OF_SYNDROMES
              )
  port map (
             clock                 => clock,
             reset                 => reset,
             new_calculation            => new_calculation,
             error_locator_in      => error_locator_in,
             ready               => ready,
             error_roots_out       => error_roots_out,
             error_locations_out   => error_locations_out,
             sym_locations_out   => sym_locations_out
           );

  clock_process : process
  begin
    clock <= '0';
    wait for 5 ns;
    clock <= '1';
    wait for 5 ns;
  end process clock_process;

  stm_process : process
    variable read_line       : line;
    variable gf_element_stm  : integer;
    file vector_file      : text open read_mode is "t_chien_search.txt";
  begin

    new_calculation        <= '0';
    error_locator_in  <= (OTHERS => '0');

    reset <= '1';
    wait for 6 ns;
    reset <= '0';

    while not endfile(vector_file) loop
      readline(vector_file, read_line);
      new_calculation <= '1';

      for i in 0 to NO_OF_SYNDROMES-1 loop
        read(read_line, gf_element_stm);
        error_locator_in(error_locator_in'high-i*M downto error_locator_in'length-(i+1)*M) <= std_logic_vector(to_unsigned(gf_element_stm,M));
      end loop;

      wait for 10 ns;

      new_calculation  <= '0';

      wait until ready = '1';

      wait for 10 ns;

--       for i in 0 to NO_OF_SYNDROMES-1 loop
--         read(read_line, gf_element_stm);
--         assert error_eval_out(error_eval_out'high-i*M downto error_eval_out'length-(i+1)*M) = std_logic_vector(to_unsigned(gf_element_stm,M))
--           report "ERROR!" severity error;
--       end loop;

    end loop;

    error_locator_in  <= (OTHERS => '0');
    report "HAS ENDED!";
    wait;
  end process stm_process;

end chien_search_tb;
