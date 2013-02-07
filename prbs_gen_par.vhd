---------------------------------------
-- Generic, parallel PRBS calculator --
---------------------------------------


-- TODO: NOT DONE

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.vhdlib_package.all;

entity prbs_gen_par is
  generic (
    POLYNOMIAL : std_logic_vector := PRBS_3_POLY; -- binary CRC polynomial
    DATA_WIDTH : integer          := 4
  );
  port (
    prbs_in   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    prbs_out  : out std_logic_vector(DATA_WIDTH-1 downto 0)
  );

end entity;

architecture rtl of prbs_gen_par is

  function gen_prbs_matrix return bin_matrix_t is
    constant M        : integer := POLYNOMIAL'length-1;
    variable ret_mat  : bin_matrix_t(0 to M-1, 0 to M-1);
  begin
    ret_mat := (OTHERS => (OTHERS => '0'));
    -- make first row equal to transposed PRBS polynomial (except for lowest order coefficient)
    for i in POLYNOMIAL'left downto POLYNOMIAL'right+1 loop
      ret_mat(0,M-1)
    end loop;

    return ret_mat;
  end function gen_prbs_matrix;

begin


end rtl;
