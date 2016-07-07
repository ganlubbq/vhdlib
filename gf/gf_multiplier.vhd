------------------------
-- GF(2^M) multiplier --
------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity gf_multiplier is
  generic (
    GF_POLYNOMIAL : std_logic_vector := BINARY_POLYNOMIAL_G709_GF -- Irreducible, binary polynomial
  );
  port (
    multiplicand_a  : in  std_logic_vector(GF_POLYNOMIAL'length-2 downto 0);  -- First multiplicand
    multiplicand_b  : in  std_logic_vector(GF_POLYNOMIAL'length-2 downto 0);  -- Second multiplicand
    product         : out std_logic_vector(GF_POLYNOMIAL'length-2 downto 0)   -- Multiplication product
  );
end entity;

architecture rtl of gf_multiplier is
  constant M  : natural := GF_POLYNOMIAL'length-1;
  constant PX : std_logic_vector(M downto 0) := GF_POLYNOMIAL; -- Make sure polynomial range is descending

  type m_times_m_matrix is array(M-1 downto 0) of std_logic_vector(M-1 downto 0);
  signal overflow_matrix : m_times_m_matrix; -- overflow signals matrix

begin
  -- Generate a matrix of cells that contain two AND gates whose outputs are XORed together with the output of a neighboring cell
  generate_cell_matrix_rows : for i in multiplicand_a'range generate
  begin
    generate_cell_matrix_columns : for j in multiplicand_b'range generate
    begin

      -- For the cells in the top row there's no input for one of the AND gates
      generate_top_row : if i = M-1 generate
        overflow_matrix(i)(j) <= multiplicand_a(j) AND multiplicand_b(i);
      end generate generate_top_row;

      -- For the cells in the rightmost column there's no carry-in from a neighbor cell
      generate_right_column : if i < M-1 and j = 0 generate
        overflow_matrix(i)(j) <= (multiplicand_a(j) AND multiplicand_b(i)) XOR (PX(j) AND overflow_matrix(i+1)(M-1));
      end generate generate_right_column;

      generate_rest_of_cells : if i < M-1 and j > 0 generate
        overflow_matrix(i)(j) <= (multiplicand_a(j) AND multiplicand_b(i)) XOR (PX(j) AND overflow_matrix(i+1)(M-1)) XOR overflow_matrix(i+1)(j-1);
      end generate generate_rest_of_cells;

    end generate generate_cell_matrix_columns;
  end generate generate_cell_matrix_rows;

  -- Output product of multiplication
  product <= overflow_matrix(0)(M-1 downto 0);

end rtl;
