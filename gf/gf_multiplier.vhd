------------------------
-- GF(2^M) multiplier --
------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity gf_multiplier is
  generic (
    GF_POLYNOMIAL : std_logic_vector := BINARY_POLYNOMIAL_G709_GF -- irreducible, binary polynomial
  );
  port (
    mul_a   : in  std_logic_vector(GF_POLYNOMIAL'length-2 downto 0);  -- first multiplicand
    mul_b   : in  std_logic_vector(GF_POLYNOMIAL'length-2 downto 0);  -- second multiplicand
    product : out std_logic_vector(GF_POLYNOMIAL'length-2 downto 0)   -- multiplication product
  );
end entity;

architecture rtl of gf_multiplier is
  constant M  : natural := GF_POLYNOMIAL'length-1;
  constant PX : std_logic_vector(M downto 0) := GF_POLYNOMIAL; -- make sure polynomial range is descending

  type m_vector_array is array(M-1 downto 0) of std_logic_vector(M-1 downto 0);
  signal ofmat : m_vector_array; -- overflow signals matrix

begin
  -- generate a matrix of cell that contain two AND gates whose outputs are XORed together with the output of
  -- a neighboring cell
  gen_cell_matrix_rows : for i in mul_a'range generate
  begin
    gen_cell_matrix_cols : for j in mul_b'range generate
    begin

      -- for the cells in the top row there's no input for one of the AND gates
      gen_top_row : if i = M-1 generate
        ofmat(i)(j) <= mul_a(j) AND mul_b(i);
      end generate gen_top_row;

      -- for the cells in the rightmost column there's no carry-in from a neighbor cell
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
