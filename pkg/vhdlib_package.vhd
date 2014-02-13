library ieee;
use ieee.std_logic_1164.all;

package vhdlib_package is

  -----------
  -- TYPES --
  -----------

  -- Type for GF(2^M) polynomials as natural integer arrays
  type gf2m_poly_t is array(natural range <>) of natural;
  type bin_matrix_t is array(natural range <>, natural range <>) of std_logic;

  ---------------
  -- CONSTANTS --
  ---------------

  -- binary polynomials
  constant CRC32_POLY         : std_logic_vector  := "100000100110000010001110110110111";
  constant PRBS_32_POLY       : std_logic_vector  := "100000000010000000000000000000111";
  constant PRBS_3_POLY        : std_logic_vector  := "1101";
  constant G709_GF_POLY       : std_logic_vector  := "100011101";
  constant G975_I10_GF_POLY   : std_logic_vector  := "10000001001";

  -- lookup table types
  constant INV_TABLE_TYPE       : string            := "INVERSE";
  constant LOG_TABLE_TYPE       : string            := "LOGARITHM";
  constant EXP_TABLE_TYPE       : string            := "EXPONENT";
  constant ZECH_LOG_TABLE_TYPE  : string            := "ZECH_LOGARITHM";

  -- G709 RS(255,239) generator polynomial
  constant G709_GEN_POLY      : gf2m_poly_t       := (1, 59, 13, 104, 189, 68, 209, 30, 8, 163, 65, 41, 229, 98, 50, 36, 59);

  ---------------------------
  -- FUNCTION DECLARATIONS --
  ---------------------------

  -- XOR reduction of bit vector
  pure function xor_reduce  (slv : std_logic_vector)
    return std_logic;

  -- return remainder of binary polynomial division
  pure function bin_poly_div (dividend  : std_logic_vector;
                              divisor   : std_logic_vector)
    return std_logic_vector;

  -- binary polynomial division of monomial polynomial
  pure function single_bit_poly_div ( div_len  : natural;
                                      divisor  : std_logic_vector)
    return std_logic_vector;

  -- exponentiation of primitive GF(2^M) element
  pure function prim_elem_exp (n        : natural;
                               gf_poly  : std_logic_vector)
    return std_logic_vector;

  -- multiplication of binary matrix
  pure function bin_mat_multiply  (bin_mat_a  : bin_matrix_t;
                                   bin_mat_b  : bin_matrix_t)
    return bin_matrix_t;

  -- exponentiation of binary matrix
  -- TODO: not in use currently; remove?
  pure function bin_mat_exp (n        : natural;
                             bin_mat  : bin_matrix_t)
    return bin_matrix_t;

end package vhdlib_package;

package body vhdlib_package is

  --------------------------
  -- FUNCTION DEFINITIONS --
  --------------------------

  --
  -- Function     : xor_reduce
  --
  -- Description  : XOR reduction of a logic vector.
  --                Becomes superfluous in VHDL-2008.
  --
  -- Input        :
  --  slv         : Vector to be reduced.
  --
  -- Output       : Reduction of vector as single logic value.
  --
  pure function xor_reduce(slv : std_logic_vector)
    return std_logic is

    variable r : std_logic;
  begin
    r := '0';
    for i in slv'range loop
      r := slv(i) XOR r;
    end loop;
    return r;
  end;

  --
  -- Function     : bin_poly_div
  --
  -- Description  : Binary polynomial division.
  --
  -- Input        :
  --  dividend    : Polynomial to be divided.
  --  divisor     : Divisor used for dividing the dividend.
  --
  -- Output       : Remainder polynomial from division.
  --
  pure function bin_poly_div (dividend  : std_logic_vector;
                              divisor   : std_logic_vector)
    return std_logic_vector is

    constant M    : natural := divisor'length-1;
    variable v    : std_logic_vector(dividend'length-1 downto 0);
    variable ret  : std_logic_vector(M-1 downto 0);
  begin
    v   := dividend;
    ret := (OTHERS => '0');

    for i in v'high downto M loop
      if v(i) = '1' then
        v(i downto i-M) := v(i downto i-M) XOR divisor;
      end if;
    end loop;

    -- returned vector/remainder is always of length M
    if v'length > M then
      ret := v(ret'range);
    else
      ret(v'range) := v;
    end if;

    return ret;
  end function bin_poly_div;


  --
  -- Function     : single_bit_poly_div
  --
  -- Description  : Binary polynomial division of dividend
  --                with only one non-zero term.
  --
  -- Input        :
  --  div_len     : Degree of dividend plus 1.
  --  divisor     : Divisor used for dividing the dividend.
  --
  -- Output       : Remainder polynomial from division.
  --
  pure function single_bit_poly_div ( div_len  : natural;
                                      divisor  : std_logic_vector)
    return std_logic_vector is

    variable v : std_logic_vector(div_len-1 downto 0);
  begin
    v         := (OTHERS => '0');
    v(v'high) := '1';

    return bin_poly_div(v, divisor);
  end function single_bit_poly_div;

  --
  -- Function     : prim_elem_exp
  --
  -- Description  : Calculates the nth power of a primitive
  --                element from GF(2^M).
  --
  -- Input        :
  --  n           : The power of the primitive element.
  --  gf_poly     : Irreducible polynomial used to construct GF(2^M).
  --
  -- Output       : An element from GF(2^M) that is the nth power of
  --                the primitive element.
  --
  pure function prim_elem_exp (n        : natural;
                               gf_poly  : std_logic_vector)
    return std_logic_vector is
  begin
    return single_bit_poly_div(n+1, gf_poly);
  end function prim_elem_exp;

  --
  -- Function     : bin_mat_multiply
  --
  -- Description  : Multiplies two binary matrices.
  --
  -- Input        :
  --  bin_mat_a   : A binary matrix.
  --  bin_mat_b   : A binary matrix.
  --
  -- Output       : A binary matrix of size equal to first dimension of
  --                bin_mat_a and second dimension of bin_mat_b.
  --
  pure function bin_mat_multiply  (bin_mat_a  : bin_matrix_t;
                                   bin_mat_b  : bin_matrix_t)
    return bin_matrix_t is
    variable ret_mat  : bin_matrix_t(bin_mat_a'range(1), bin_mat_b'range(2));
  begin
    assert bin_mat_a'length(2) = bin_mat_b'length(1)
      report "Dimensions of matrices to multiply do not match!"
      severity failure;

    ret_mat := (OTHERS => (OTHERS => '0'));

    for k in bin_mat_a'range(1) loop
      for i in bin_mat_a'range(2) loop
        for j in bin_mat_b'range(2) loop
          ret_mat(k,i)  := ret_mat(k,i) XOR (bin_mat_a(k,j) AND bin_mat_b(j,i));
        end loop;
      end loop;
    end loop;

    return ret_mat;
  end function bin_mat_multiply;

  --
  -- Function     : bin_mat_exp
  --
  -- Description  : Calculates the nth power of a quadratic,
  --                binary matrix.
  --
  -- Input        :
  --  n           : The power of the exponentiation.
  --  bin_mat     : The quadratic, binary matrix.
  --
  -- Output       : A binary matrix of size equal to bin_mat.
  --
  pure function bin_mat_exp (n        : natural;
                             bin_mat  : bin_matrix_t)
    return bin_matrix_t is
    variable ret_mat  : bin_matrix_t(bin_mat'range, bin_mat'range);
  begin
    ret_mat := bin_mat;

    -- if n < 2 just return input matrix
    for e in 2 to n loop
      ret_mat := bin_mat_multiply(ret_mat, bin_mat);
    end loop;

    return ret_mat;
  end function bin_mat_exp;

end package body vhdlib_package;
