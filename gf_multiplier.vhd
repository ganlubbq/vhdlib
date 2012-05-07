------------------------
-- GF(2^M) multiplier --
------------------------

library ieee;
use ieee.std_logic_1164.all;

entity gf_multiplier is

  generic (
    POLYNOMIAL : std_logic_vector := "10000001001" -- irreducible polynomial, default: P(x) = x^10 + x^3 + 1";
  );

  port (
    mul_a     : in std_logic_vector(POLYNOMIAL'length-2 downto 0);
    mul_b     : in std_logic_vector(POLYNOMIAL'length-2 downto 0);
    product   : out std_logic_vector(POLYNOMIAL'length-2 downto 0)
  );

end entity;

architecture rtl of gf_multiplier is
  constant M  : integer := POLYNOMIAL'length-1;
  constant PX : std_logic_vector(M downto 0) := POLYNOMIAL; -- make sure polynomial range is descending

  type m_vector_array is array(M-1 downto 0) of std_logic_vector(M-1 downto 0);
  signal ofmat : m_vector_array; -- overflow signals matrix

begin
  gen_cell_matrix_rows : for i in mul_a'range generate
  begin

    gen_cell_matrix_cols : for j in mul_b'range generate
    begin

      gen_top_row : if i = M-1 generate
        ofmat(i)(j) <= mul_a(j) AND mul_b(i);
      end generate gen_top_row;

      gen_right_col : if i < M-1 and j = 0 generate
        ofmat(i)(j) <= (mul_a(j) AND mul_b(i)) XOR (PX(j) AND ofmat(i+1)(M-1));
      end generate gen_right_col;

      gen_rest_of_cells : if i < M-1 and j > 0 generate
        ofmat(i)(j) <= (mul_a(j) AND mul_b(i)) XOR (PX(j) AND ofmat(i+1)(M-1)) XOR ofmat(i+1)(j-1);
      end generate gen_rest_of_cells;

    end generate gen_cell_matrix_cols;

  end generate gen_cell_matrix_rows;

  -- output product of multiplication
  product <= ofmat(0)(M-1 downto 0);

end rtl;
