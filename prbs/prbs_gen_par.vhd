---------------------------------------
-- Generic, parallel PRBS calculator --
---------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity prbs_gen_par is
  generic (
    POLYNOMIAL : std_logic_vector := PRBS_3_POLY; -- binary PRBS polynomial
    DATA_WIDTH : natural          := 4
  );
  port (
    prbs_in   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    prbs_out  : out std_logic_vector(DATA_WIDTH-1 downto 0)
  );

end entity;

architecture rtl of prbs_gen_par is

  constant M        : natural := POLYNOMIAL'length-1;

  function gen_prbs_matrix return bin_matrix_t is
    constant P        : std_logic_vector(M downto 0) := POLYNOMIAL;
    variable ret_mat  : bin_matrix_t(0 to M-1, 0 to M-1);
  begin
    ret_mat := (OTHERS => (OTHERS => '0'));

    -- make first row equal to transposed PRBS polynomial vector (except for lowest order coefficient)
    for i in M-1 downto 0 loop
      ret_mat(i,0) := P(i+1);
    end loop;

    -- make eye matrix from (0,1) to (M-2,M-1)
    for i in 0 to M-2 loop
      ret_mat(i,i+1)  := '1';
    end loop;

    return ret_mat;
  end function gen_prbs_matrix;

  function gen_evolved_prbs_matrix return bin_matrix_t is
    variable ret_mat  : bin_matrix_t(0 to M-1, DATA_WIDTH-1 downto 0);
    variable prbs_mat : bin_matrix_t(0 to M-1, 0 to M-1);
    variable tmp_mat  : bin_matrix_t(0 to M-1, 0 to M-1);
  begin
    ret_mat   := (OTHERS => (OTHERS => '0'));
    prbs_mat  := gen_prbs_matrix;
    tmp_mat   := prbs_mat;

    for i in 0 to DATA_WIDTH-1 loop
      -- copy leftmost column from tmp_mat to the rightmost, _EMPTY_ column in ret_mat
      for j in 0 to M-1 loop
        ret_mat(j,i)  := tmp_mat(j,0);
      end loop;

      -- incremental exponentiation of PRBS output matrix
      tmp_mat := bin_mat_multiply(tmp_mat,prbs_mat);
    end loop;

    return ret_mat;
  end function gen_evolved_prbs_matrix;

  constant PRBS_IN_MATRIX : bin_matrix_t := gen_evolved_prbs_matrix;

begin

  assert POLYNOMIAL'length-1 <= DATA_WIDTH
    report "Input data width is too small to determine PRBS generator state!"
    severity failure;

  -- PRBS output from gating PRBS input XOR matrix and input signal
  prbs_out_proc : process(prbs_in)
    variable tmp_prbs_out : std_logic_vector(DATA_WIDTH-1 downto 0);
  begin
    tmp_prbs_out  := (OTHERS => '0');

    for i in 0 to M-1 loop
      if prbs_in(DATA_WIDTH-1-i) = '1' then
        for j in DATA_WIDTH-1 downto 0 loop
          tmp_prbs_out(j) := tmp_prbs_out(j) XOR PRBS_IN_MATRIX(i,j);
        end loop;
      end if;
    end loop;

    prbs_out  <= tmp_prbs_out;

  end process prbs_out_proc;

end rtl;
