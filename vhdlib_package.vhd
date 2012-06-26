library ieee;
use ieee.std_logic_1164.all;

package vhdlib_package is

  -----------
  -- TYPES --
  -----------

  -- Type for GF(2^M) polynomials as integer arrays
  type gf2m_poly_t is array(natural range <>) of natural;

  ---------------
  -- CONSTANTS --
  ---------------

  -- binary polynomials
  constant CRC32_POLY         : std_logic_vector := "100000100110000010001110110110111";
  constant G709_GF_POLY       : std_logic_vector := "100011101";
  constant G975_I10_GF_POLY   : std_logic_vector := "10000001001";

  -- G709 RS(255,239) generator polynomial
  constant G709_GEN_POLY : gf2m_poly_t := (1, 59, 13, 104, 189, 68, 209, 30, 8, 163, 65, 41, 229, 98, 50, 36, 59);

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

  -- binary polynomial divisoin of monomial polynomial
  pure function single_bit_poly_div ( div_len  : integer;
                                      divisor  : std_logic_vector)
    return std_logic_vector;

  -- exponentiation of primitive GF(2^M) element
  pure function prim_elem_exp (exp      : integer;
                               gf_poly  : std_logic_vector)
    return std_logic_vector;

end package vhdlib_package;

package body vhdlib_package is

  --------------------------
  -- FUNCTION DEFINITIONS --
  --------------------------

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

  pure function bin_poly_div (dividend  : std_logic_vector;
                              divisor   : std_logic_vector)
    return std_logic_vector is

    constant M    : integer := divisor'length-1;
    variable v    : std_logic_vector(dividend'length-1 downto 0);
    variable ret  : std_logic_vector(M-1 downto 0);
  begin
    v := dividend;
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

  pure function single_bit_poly_div ( div_len  : integer;
                                      divisor  : std_logic_vector)
    return std_logic_vector is

    variable v : std_logic_vector(div_len-1 downto 0);
  begin
    v := (v'high => '1', OTHERS => '0');

    return bin_poly_div(v, divisor);
  end function single_bit_poly_div;

  pure function prim_elem_exp (exp      : integer;
                               gf_poly  : std_logic_vector)
    return std_logic_vector is
  begin
    return single_bit_poly_div(exp+1, gf_poly);
  end function prim_elem_exp;

end package body vhdlib_package;
