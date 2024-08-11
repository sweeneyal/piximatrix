library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library universal;
    use universal.CommonFunctions.all;
    use universal.CommonTypes.all;

use std.textio.all;

entity ImageRom is
    generic (
        cInputPath       : string;
        cPanelWidth_pix  : natural range 1 to 64;
        cPanelLength_pix : natural range 1 to 64;
        cColorWidth_bits : natural range 1 to 8
    );
    port (
        -- system clock input
        i_clk : in std_logic;
        -- active low reset synchronous to system clock
        i_resetn : in std_logic;
        
        -- pixel fetch address
        i_addr : in std_logic_vector(clog2(cPanelLength_pix * cPanelWidth_pix / 2) - 1 downto 0);
        -- pixel index mux select
        i_select : in std_logic_vector(clog2(cColorWidth_bits) - 1 downto 0);
        -- pixel fetch read enable
        i_ren : in std_logic;

        -- pixel data valid
        o_dvalid : out std_logic;
        -- pixel data for top half of matrix
        o_rgb0 : out std_logic_vector(0 to 2);
        -- pixel data for bottom half of matrix
        o_rgb1 : out std_logic_vector(0 to 2)
    );
end entity ImageRom;

architecture rtl of ImageRom is
    type pixel_t is record
        red   : std_logic_vector(cColorWidth_bits - 1 downto 0);
        green : std_logic_vector(cColorWidth_bits - 1 downto 0);
        blue  : std_logic_vector(cColorWidth_bits - 1 downto 0);
    end record pixel_t;
    type pixel_array_t is array (0 to cPanelWidth_pix * cPanelLength_pix - 1) of pixel_t;

    file f_input : text;
begin
    
    StateMachine: process(i_clk)
        variable line_color : line;
        variable matrix     : pixel_array_t;
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                file_open(f_input, cInputPath, read_mode);
                for ii in 0 to cPanelLength_pix * cPanelWidth_pix - 1 loop
                    readline(f_input, line_color);
                    read(line_color, matrix(ii).red);
                    readline(f_input, line_color);
                    read(line_color, matrix(ii).green);
                    readline(f_input, line_color);
                    read(line_color, matrix(ii).blue);
                end loop;
                file_close(f_input);
            else
                o_dvalid <= i_ren;
                if (i_ren = '1') then
                    o_rgb0(0) <= matrix(to_natural(i_addr)).red(to_natural(i_select));
                    o_rgb0(1) <= matrix(to_natural(i_addr)).green(to_natural(i_select));
                    o_rgb0(2) <= matrix(to_natural(i_addr)).blue(to_natural(i_select));

                    o_rgb1(0) <= matrix(to_natural(i_addr) + (cPanelWidth_pix / 2) * cPanelLength_pix).red(to_natural(i_select));
                    o_rgb1(1) <= matrix(to_natural(i_addr) + (cPanelWidth_pix / 2) * cPanelLength_pix).green(to_natural(i_select));
                    o_rgb1(2) <= matrix(to_natural(i_addr) + (cPanelWidth_pix / 2) * cPanelLength_pix).blue(to_natural(i_select));
                end if;
            end if;
        end if;
    end process StateMachine;
    
end architecture rtl;