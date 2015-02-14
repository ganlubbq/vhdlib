library ieee;
use ieee.std_logic_1164.all;

package vhdlib_package is

  -----------
  -- TYPES --
  -----------

  -- Type for GF(2^M) polynomials as natural integer arrays
  type gf2m_polynomial is array(natural range <>) of natural;
  type binary_matrix_t is array(natural range <>, natural range <>) of std_logic;

  -- look-up table type
  type gf_table_type is (
    gf_table_type_inverse,
    gf_table_type_logarithm,
    gf_table_type_exponent,
    gf_table_type_zech_logarithm
  );

  ---------------
  -- CONSTANTS --
  ---------------

  -- binary polynomials
  constant BINARY_POLYNOMIAL_CRC32        : std_logic_vector  := "100000100110000010001110110110111";
  constant BINARY_POLYNOMIAL_PRBS_32      : std_logic_vector  := "100000000010000000000000000000111";
  constant BINARY_POLYNOMIAL_PRBS_3       : std_logic_vector  := "1101";
  constant BINARY_POLYNOMIAL_G709_GF      : std_logic_vector  := "100011101";
  constant BINARY_POLYNOMIAL_G975_I10_GF  : std_logic_vector  := "10000001001";

  -- G709 RS(255,239) generator polynomial
  constant GF2M_POLYNOMIAL_G709_GENERATOR : gf2m_polynomial := (1, 59, 13, 104, 189, 68, 209, 30, 8, 163, 65, 41, 229, 98, 50, 36, 59);

  ---------------------------
  -- FUNCTION DECLARATIONS --
  ---------------------------

  -- Galois Field multiplication
  pure function gf_multiply (multiplicand_a : std_logic_vector;
                             multiplicand_b : std_logic_vector;
                             gf_polynomial : std_logic_vector)
    return std_logic_vector;

  -- XOR reduction of bit vector
  pure function xor_reduce (vector_to_reduce : std_logic_vector)
    return std_logic;

  -- return remainder of binary polynomial division
  pure function binary_polynomial_division (dividend : std_logic_vector;
                                            divisor : std_logic_vector)
    return std_logic_vector;

  -- binary polynomial division of monomial polynomial
  pure function single_bit_polynomial_division (dividend_length : natural;
                                                divisor : std_logic_vector)
    return std_logic_vector;

  -- exponentiation of primitive GF(2^M) element
  pure function primitive_element_exponentiation (n : natural;
                                                  gf_polynomial : std_logic_vector)
    return std_logic_vector;

  -- multiplication of binary matrix
  pure function binary_matrix_multiply (binary_matrix_a : binary_matrix_t;
                                        binary_matrix_b : binary_matrix_t)
    return binary_matrix_t;

  -- exponentiation of binary matrix
  -- TODO: not in use currently; remove?
  pure function binary_matrix_exponentiation (n : natural;
                                              binary_matrix : binary_matrix_t)
    return binary_matrix_t;

end package vhdlib_package;

package body vhdlib_package is

  --------------------------
  -- FUNCTION DEFINITIONS --
  --------------------------

  --
  -- Function:
  -- gf_multiply
  --
  -- Description:
  -- Multiplication of Galois Field elements.
  --
  -- Input:
  -- multiplicand_a : First Galois field multiplicand
  -- multiplicand_b : Second Galois field multiplicand
  -- gf_polynomial  : Irreducible, binary polynomial defining the Galois field
  --
  -- Output:
  -- The product of the two Galois field multiplicands
  --
  pure function gf_multiply (multiplicand_a : std_logic_vector;
                             multiplicand_b : std_logic_vector;
                             gf_polynomial : std_logic_vector)
    return std_logic_vector is

    constant M  : natural := gf_polynomial'length-1;
    constant PX : std_logic_vector(M downto 0) := gf_polynomial; -- Make sure polynomial range is descending

    type m_times_m_matrix is array(M-1 downto 0) of std_logic_vector(M-1 downto 0);
    variable result_matrix : m_times_m_matrix;
  begin
    for i in multiplicand_a'range loop
      for j in multiplicand_b'range loop

        if i = M-1 then
          result_matrix(i)(j) := multiplicand_a(j) AND multiplicand_b(i);
        end if;

        if i < M-1 and j = 0 then
          result_matrix(i)(j) := (multiplicand_a(j) AND multiplicand_b(i)) XOR (PX(j) AND result_matrix(i+1)(M-1));
        end if;

        if i < M-1 and j > 0 then
          result_matrix(i)(j) := (multiplicand_a(j) AND multiplicand_b(i)) XOR (PX(j) AND result_matrix(i+1)(M-1)) XOR result_matrix(i+1)(j-1);
        end if;

      end loop;
    end loop;

    return result_matrix(0)(M-1 downto 0);
  end;

  --
  -- Function:
  -- xor_reduce
  --
  -- Description:
  -- XOR reduction of a logic vector.
  -- Is superfluous in VHDL-2008.
  --
  -- Input:
  -- vector_to_reduce : Vector to be reduced.
  --
  -- Output:
  -- Reduction of vector as single logic value.
  --
  pure function xor_reduce(vector_to_reduce : std_logic_vector)
    return std_logic is

    variable result : std_logic;
  begin
    result := '0';
    for i in vector_to_reduce'range loop
      result := vector_to_reduce(i) XOR result;
    end loop;
    return result;
  end;

  --
  -- Function:
  -- binary_polynomial_division
  --
  -- Description:
  -- Binary polynomial division.
  --
  -- Input:
  -- dividend : Polynomial to be divided.
  -- divisor  : Divisor used for dividing the dividend.
  --
  -- Output:
  -- Remainder polynomial from division.
  --
  pure function binary_polynomial_division (dividend : std_logic_vector;
                                            divisor : std_logic_vector)
    return std_logic_vector is

    constant M : natural := divisor'length-1;
    variable vector : std_logic_vector(dividend'length-1 downto 0);
    variable result : std_logic_vector(M-1 downto 0);
  begin
    vector := dividend;
    result := (OTHERS => '0');

    for i in vector'high downto M loop
      if vector(i) = '1' then
        vector(i downto i-M) := vector(i downto i-M) XOR divisor;
      end if;
    end loop;

    -- returned vector/remainder is always of length M
    if vector'length > M then
      result := vector(result'range);
    else
      result(vector'range) := vector;
    end if;

    return result;
  end function binary_polynomial_division;

  --
  -- Function:
  -- single_bit_polynomial_division
  --
  -- Description:
  -- Binary polynomial division of dividend
  -- with only one non-zero term.
  --
  -- Input:
  -- dividend_length  : Degree of dividend plus 1.
  -- divisor          : Divisor used for dividing the dividend.
  --
  -- Output:
  -- Remainder polynomial from division.
  --
  pure function single_bit_polynomial_division (dividend_length : natural;
                                                divisor : std_logic_vector)
    return std_logic_vector is

    variable vector : std_logic_vector(dividend_length-1 downto 0);
  begin
    vector := (OTHERS => '0');
    vector(vector'high) := '1';

    return binary_polynomial_division(vector, divisor);
  end function single_bit_polynomial_division;

  --
  -- Function:
  -- primitive_element_exponentiation
  --
  -- Description:
  -- Calculates the nth power of a primitive
  -- element from GF(2^M).
  --
  -- Input:
  -- n              : The power of the primitive element.
  -- gf_polynomial  : Irreducible polynomial used to construct GF(2^M).
  --
  -- Output:
  -- An element from GF(2^M) that is the nth power of
  -- the primitive element.
  --
  pure function primitive_element_exponentiation (n : natural;
                                                  gf_polynomial : std_logic_vector)
    return std_logic_vector is
  begin
    return single_bit_polynomial_division(n+1, gf_polynomial);
  end function primitive_element_exponentiation;

  --
  -- Function:
  -- binary_matrix_multiply
  --
  -- Description:
  -- Multiplies two binary matrices.
  --
  -- Input:
  -- binary_matrix_a  : First multiplicand binary matrix.
  -- binary_matrix_b  : Second multiplicand binary matrix.
  --
  -- Output:
  -- A binary matrix of size equal to first dimension of
  -- binary_matrix_a and second dimension of binary_matrix_b.
  --
  pure function binary_matrix_multiply (binary_matrix_a : binary_matrix_t;
                                        binary_matrix_b : binary_matrix_t)
    return binary_matrix_t is
    variable result : binary_matrix_t(binary_matrix_a'range(1), binary_matrix_b'range(2));
  begin
    -- number of columns in binary_matrix_a must equal number of rows in binary_matrix_b
    assert binary_matrix_a'length(2) = binary_matrix_b'length(1)
      report "Dimensions of matrices to multiply do not match!"
      severity failure;

    result := (OTHERS => (OTHERS => '0'));

    -- k iterates over rows of binary_matrix_a
    for k in binary_matrix_a'range(1) loop
      -- i iterates over columns of binary_matrix_a
      for i in binary_matrix_a'range(2) loop
        -- j iterates over columns of binary_matrix_b
        for j in binary_matrix_b'range(2) loop
          result(k,i)  := result(k,i) XOR (binary_matrix_a(k,j) AND binary_matrix_b(j,i));
        end loop;
      end loop;
    end loop;

    return result;
  end function binary_matrix_multiply;

  --
  -- Function:
  -- binary_matrix_exponentiation
  --
  -- Description:
  -- Calculates the nth power of a quadratic, binary matrix.
  --
  -- Input:
  -- n              : The power of the exponentiation.
  -- binary_matrix  : The quadratic, binary matrix.
  --
  -- Output:
  -- A binary matrix of size equal to binary_matrix.
  --
  pure function binary_matrix_exponentiation (n : natural;
                                              binary_matrix : binary_matrix_t)
    return binary_matrix_t is
    variable result : binary_matrix_t(binary_matrix'range, binary_matrix'range);
  begin
    result := binary_matrix;

    -- if n < 2 just return input matrix
    for e in 2 to n loop
      result := binary_matrix_multiply(result, binary_matrix);
    end loop;

    return result;
  end function binary_matrix_exponentiation;

end package body vhdlib_package;
