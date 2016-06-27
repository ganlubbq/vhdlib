library ieee;
use ieee.std_logic_1164.all;

package vhdlib_package is

  -----------
  -- TYPES --
  -----------

  -- Type for GF(2^M) polynomials as natural integer arrays
  type gf2m_poly_t is array(natural range <>) of natural;
  type binary_matrix_t is array(natural range <>, natural range <>) of std_logic;

  ---------------
  -- CONSTANTS --
  ---------------

  -- binary polynomials
  constant CRC32_POLY         : std_logic_vector  := "100000100110000010001110110110111";
  constant PRBS_32_POLY       : std_logic_vector  := "100000000010000000000000000000111";
  constant PRBS_3_POLY        : std_logic_vector  := "1101";
  constant G709_GF_POLY       : std_logic_vector  := "100011101";
  constant G975_I10_GF_POLY   : std_logic_vector  := "10000001001";

  -- look-up table types
  constant INV_TABLE_TYPE       : string  := "INVERSE";
  constant LOG_TABLE_TYPE       : string  := "LOGARITHM";
  constant EXP_TABLE_TYPE       : string  := "EXPONENT";
  constant ZECH_LOG_TABLE_TYPE  : string  := "ZECH_LOGARITHM";

  -- G709 RS(255,239) generator polynomial
  constant G709_GEN_POLY      : gf2m_poly_t       := (1, 59, 13, 104, 189, 68, 209, 30, 8, 163, 65, 41, 229, 98, 50, 36, 59);

  ---------------------------
  -- FUNCTION DECLARATIONS --
  ---------------------------

  -- XOR reduction of bit vector
  pure function xor_reduce  (vector_to_reduce : std_logic_vector)
    return std_logic;

  -- return remainder of binary polynomial division
  pure function binary_polynomial_division (dividend  : std_logic_vector;
                              divisor   : std_logic_vector)
    return std_logic_vector;

  -- binary polynomial division of monomial polynomial
  pure function single_bit_polynomial_division ( dividend_length  : natural;
                                      divisor  : std_logic_vector)
    return std_logic_vector;

  -- exponentiation of primitive GF(2^M) element
  pure function primitive_element_exponentiation (n        : natural;
                               gf_polynomial  : std_logic_vector)
    return std_logic_vector;

  -- multiplication of binary matrix
  pure function binary_matrix_multiply  (binary_matrix_a  : binary_matrix_t;
                                   binary_matrix_b  : binary_matrix_t)
    return binary_matrix_t;

  -- exponentiation of binary matrix
  -- TODO: not in use currently; remove?
  pure function binary_matrix_exponentiation (n        : natural;
                             binary_matrix  : binary_matrix_t)
    return binary_matrix_t;

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
  --  vector_to_reduce         : Vector to be reduced.
  --
  -- Output       : Reduction of vector as single logic value.
  --
  pure function xor_reduce(vector_to_reduce : std_logic_vector)
    return std_logic is

    variable r : std_logic;
  begin
    r := '0';
    for i in vector_to_reduce'range loop
      r := vector_to_reduce(i) XOR r;
    end loop;
    return r;
  end;

  --
  -- Function     : binary_polynomial_division
  --
  -- Description  : Binary polynomial division.
  --
  -- Input        :
  --  dividend    : Polynomial to be divided.
  --  divisor     : Divisor used for dividing the dividend.
  --
  -- Output       : Remainder polynomial from division.
  --
  pure function binary_polynomial_division (dividend  : std_logic_vector;
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
  end function binary_polynomial_division;


  --
  -- Function     : single_bit_polynomial_division
  --
  -- Description  : Binary polynomial division of dividend
  --                with only one non-zero term.
  --
  -- Input        :
  --  dividend_length     : Degree of dividend plus 1.
  --  divisor     : Divisor used for dividing the dividend.
  --
  -- Output       : Remainder polynomial from division.
  --
  pure function single_bit_polynomial_division ( dividend_length  : natural;
                                      divisor  : std_logic_vector)
    return std_logic_vector is

    variable v : std_logic_vector(dividend_length-1 downto 0);
  begin
    v         := (OTHERS => '0');
    v(v'high) := '1';

    return binary_polynomial_division(v, divisor);
  end function single_bit_polynomial_division;

  --
  -- Function     : primitive_element_exponentiation
  --
  -- Description  : Calculates the nth power of a primitive
  --                element from GF(2^M).
  --
  -- Input        :
  --  n           : The power of the primitive element.
  --  gf_polynomial     : Irreducible polynomial used to construct GF(2^M).
  --
  -- Output       : An element from GF(2^M) that is the nth power of
  --                the primitive element.
  --
  pure function primitive_element_exponentiation (n        : natural;
                               gf_polynomial  : std_logic_vector)
    return std_logic_vector is
  begin
    return single_bit_polynomial_division(n+1, gf_polynomial);
  end function primitive_element_exponentiation;

  --
  -- Function     : binary_matrix_multiply
  --
  -- Description  : Multiplies two binary matrices.
  --
  -- Input        :
  --  binary_matrix_a   : A binary matrix.
  --  binary_matrix_b   : A binary matrix.
  --
  -- Output       : A binary matrix of size equal to first dimension of
  --                binary_matrix_a and second dimension of binary_matrix_b.
  --
  pure function binary_matrix_multiply  (binary_matrix_a  : binary_matrix_t;
                                   binary_matrix_b  : binary_matrix_t)
    return binary_matrix_t is
    variable return_matrix  : binary_matrix_t(binary_matrix_a'range(1), binary_matrix_b'range(2));
  begin
    -- number of columns in binary_matrix_a must equal number of rows in binary_matrix_b
    assert binary_matrix_a'length(2) = binary_matrix_b'length(1)
      report "Dimensions of matrices to multiply do not match!"
      severity failure;

    return_matrix := (OTHERS => (OTHERS => '0'));

    -- k iterates over rows of binary_matrix_a
    for k in binary_matrix_a'range(1) loop
      -- i iterates over columns of binary_matrix_a
      for i in binary_matrix_a'range(2) loop
        -- j iterates over columns of binary_matrix_b
        for j in binary_matrix_b'range(2) loop
          return_matrix(k,i)  := return_matrix(k,i) XOR (binary_matrix_a(k,j) AND binary_matrix_b(j,i));
        end loop;
      end loop;
    end loop;

    return return_matrix;
  end function binary_matrix_multiply;

  --
  -- Function     : binary_matrix_exponentiation
  --
  -- Description  : Calculates the nth power of a quadratic,
  --                binary matrix.
  --
  -- Input        :
  --  n           : The power of the exponentiation.
  --  binary_matrix     : The quadratic, binary matrix.
  --
  -- Output       : A binary matrix of size equal to binary_matrix.
  --
  pure function binary_matrix_exponentiation (n        : natural;
                             binary_matrix  : binary_matrix_t)
    return binary_matrix_t is
    variable return_matrix  : binary_matrix_t(binary_matrix'range, binary_matrix'range);
  begin
    return_matrix := binary_matrix;

    -- if n < 2 just return input matrix
    for e in 2 to n loop
      return_matrix := binary_matrix_multiply(return_matrix, binary_matrix);
    end loop;

    return return_matrix;
  end function binary_matrix_exponentiation;

end package body vhdlib_package;
