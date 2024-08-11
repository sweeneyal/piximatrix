library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library universal;
    use universal.CommonFunctions.all;
    use universal.CommonTypes.all;

use std.textio.all;

entity LedMatrixModel is
    generic (
        cOutputPath      : string;
        cPanelWidth_pix  : natural range 1 to 64;
        cPanelLength_pix : natural range 1 to 64;
        cColorWidth_bits : natural range 1 to 8
    );
    port (
        i_sclk    : in std_logic;
        i_a       : in std_logic_vector(clog2(cPanelWidth_pix / 2) - 1 downto 0);
        i_rgb0    : in std_logic_vector(0 to 2);
        i_rgb1    : in std_logic_vector(0 to 2);
        i_blank   : in std_logic;
        i_latch   : in std_logic;
        o_imgdone : out std_logic
    );
end entity LedMatrixModel;

architecture mdl of LedMatrixModel is
    type pixel_t is record
        red   : std_logic_vector(cColorWidth_bits - 1 downto 0);
        green : std_logic_vector(cColorWidth_bits - 1 downto 0);
        blue  : std_logic_vector(cColorWidth_bits - 1 downto 0);
    end record pixel_t;
    type pixel_row_t is array (0 to cPanelLength_pix - 1) of pixel_t;
    type pixel_matrix_t is array (0 to cPanelWidth_pix / 2 - 1) of pixel_row_t;
    

    file rgblog : text;
begin
    
    RgbLogger: process(i_sclk, i_blank, i_latch)
        variable idx          : natural := 0;
        variable lastaddr     : std_logic_vector(clog2(cPanelWidth_pix / 2) - 1 downto 0) := (others => '0');
        variable dirty0 : std_logic_matrix_t
            (0 to cPanelWidth_pix / 2 - 1)(0 to cPanelLength_pix - 1) := (others => (others => '0'));
        variable dirty1 : std_logic_matrix_t
            (0 to cPanelWidth_pix / 2 - 1)(0 to cPanelLength_pix - 1) := (others => (others => '0'));
        variable readyToPrint : boolean := true;
        variable outputline   : line;

        variable sreg_red0   : std_logic_vector(cPanelLength_pix - 1 downto 0) := (others => '0');
        variable sreg_green0 : std_logic_vector(cPanelLength_pix - 1 downto 0) := (others => '0');
        variable sreg_blue0  : std_logic_vector(cPanelLength_pix - 1 downto 0) := (others => '0');
        variable sreg_red1   : std_logic_vector(cPanelLength_pix - 1 downto 0) := (others => '0');
        variable sreg_green1 : std_logic_vector(cPanelLength_pix - 1 downto 0) := (others => '0');
        variable sreg_blue1  : std_logic_vector(cPanelLength_pix - 1 downto 0) := (others => '0');
        variable matrix0     : pixel_matrix_t;
        variable matrix1     : pixel_matrix_t;
    begin
        if rising_edge(i_sclk) then
            o_imgdone      <= '0';
            for ii in cPanelLength_pix - 1 downto 1 loop
                sreg_red0(ii)   := sreg_red0(ii - 1);
                sreg_green0(ii) := sreg_green0(ii - 1);
                sreg_blue0(ii)  := sreg_blue0(ii - 1);

                sreg_red1(ii)   := sreg_red1(ii - 1);
                sreg_green1(ii) := sreg_green1(ii - 1);
                sreg_blue1(ii)  := sreg_blue1(ii - 1);
            end loop;
            sreg_red0(0)   := i_rgb0(0);
            sreg_green0(0) := i_rgb0(1);
            sreg_blue0(0)  := i_rgb0(2);

            sreg_red1(0)   := i_rgb1(0);
            sreg_green1(0) := i_rgb1(1);
            sreg_blue1(0)  := i_rgb1(2);
        end if;

        if rising_edge(i_latch) then
            if (lastaddr /= i_a) then
                lastaddr := i_a;
                idx      := 0;
            end if;
            for ii in 0 to cPanelLength_pix - 1 loop
                matrix0(to_natural(i_a))(ii).red(idx)   := sreg_red0(cPanelLength_pix - 1 - ii);
                matrix0(to_natural(i_a))(ii).green(idx) := sreg_green0(cPanelLength_pix - 1 - ii);
                matrix0(to_natural(i_a))(ii).blue(idx)  := sreg_blue0(cPanelLength_pix - 1 - ii);

                matrix1(to_natural(i_a))(ii).red(idx)   := sreg_red1(cPanelLength_pix - 1 - ii);
                matrix1(to_natural(i_a))(ii).green(idx) := sreg_green1(cPanelLength_pix - 1 - ii);
                matrix1(to_natural(i_a))(ii).blue(idx)  := sreg_blue1(cPanelLength_pix - 1 - ii);

                if (idx = cColorWidth_bits - 1) then
                    dirty0(to_natural(i_a))(ii) := bool2bit(idx = cColorWidth_bits - 1);
                    dirty1(to_natural(i_a))(ii) := bool2bit(idx = cColorWidth_bits - 1);
                end if;
            end loop;
            idx := idx + 1;
            if idx > cColorWidth_bits - 1 then
                idx := 0;
            end if;

            readyToPrint := true;
            for ii in 0 to cPanelWidth_pix / 2 - 1 loop
                for jj in 0 to cPanelLength_pix - 1 loop
                    readyToPrint := readyToPrint 
                        and (dirty0(ii)(jj) = '1') and (dirty1(ii)(jj) = '1');
                end loop;
            end loop;
            if readyToPrint then
                report "Ready to print!";
                file_open(rgblog, cOutputPath, write_mode);
                for ii in 0 to cPanelWidth_pix / 2 - 1 loop
                    for jj in 0 to cPanelLength_pix - 1 loop
                        write(outputline, matrix0(ii)(jj).red, right, cColorWidth_bits);
                        writeline(rgblog, outputline);
                        write(outputline, matrix0(ii)(jj).green, right, cColorWidth_bits);
                        writeline(rgblog, outputline);
                        write(outputline, matrix0(ii)(jj).blue, right, cColorWidth_bits);
                        writeline(rgblog, outputline);
                    end loop;
                end loop;
                for ii in 0 to cPanelWidth_pix / 2 - 1 loop
                    for jj in 0 to cPanelLength_pix - 1 loop
                        write(outputline, matrix1(ii)(jj).red, right, cColorWidth_bits);
                        writeline(rgblog, outputline);
                        write(outputline, matrix1(ii)(jj).green, right, cColorWidth_bits);
                        writeline(rgblog, outputline);
                        write(outputline, matrix1(ii)(jj).blue, right, cColorWidth_bits);
                        writeline(rgblog, outputline);
                    end loop;
                end loop;
                file_close(rgblog);
                o_imgdone <= '1';
                dirty0 := (others => (others => '0'));
                dirty1 := (others => (others => '0'));
            end if;
        end if;
    end process RgbLogger;
    
end architecture mdl;