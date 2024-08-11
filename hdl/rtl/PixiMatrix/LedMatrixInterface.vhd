library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library universal;
    use universal.CommonFunctions.all;
    use universal.CommonTypes.all;

entity LedMatrixInterface is
    generic (
        -- System clock frequency
        cClockFrequency_Hz : natural;
        -- Shift clock frequency
        cSclkFrequency_Hz : natural;
        -- Indicates the number of leds in a single row of the matrix
        cPanelLength_pix : natural range 1 to 64;
        -- Indicates the total number of rows in the matrix
        cPanelWidth_pix  : natural range 1 to 64;
        -- Indicates the number of bits resolution of a single color in a single pixel.
        cColorWidth_bits : natural range 1 to 8
    );
    port (
        -- system clock input
        i_clk : in std_logic;
        -- active low reset synchronous to system clock
        i_resetn : in std_logic;
        
        -- pixel fetch address
        o_addr : out std_logic_vector(clog2(cPanelLength_pix * cPanelWidth_pix / 2) - 1 downto 0);
        -- pixel index mux select
        o_select : out std_logic_vector(clog2(cColorWidth_bits) - 1 downto 0);
        -- pixel fetch read enable
        o_ren : out std_logic;

        -- pixel data valid
        i_dvalid : in std_logic;
        -- pixel data for top half of matrix
        i_rgb0 : in std_logic_vector(0 to 2);
        -- pixel data for bottom half of matrix
        i_rgb1 : in std_logic_vector(0 to 2);

        -- output clock for driving connected d-flops
        o_sclk : out std_logic;
        -- latch signal for latching in current data on d-flops
        o_latch : out std_logic;
        -- blanking signal for turning the display off
        o_blank : out std_logic;
        -- address signal for indexing specific rows of LEDs in the matrix
        o_a : out std_logic_vector(clog2(cPanelWidth_pix / 2) - 1 downto 0);
        -- rgb bus for providing the value of each bit to the top half of matrix
        o_rgb0 : out std_logic_vector(0 to 2);
        -- rgb bus for providing the value of each bit to the top half of matrix
        o_rgb1 : out std_logic_vector(0 to 2)
    );
end entity LedMatrixInterface;

architecture rtl of LedMatrixInterface is
    constant cSclkPeriod_cc : natural := cClockFrequency_Hz / cSclkFrequency_Hz;
    type state_t is (RESET, FETCH, FETCH_LAST, SHIFT, BLANK, SET_ADDRESS, LATCH, UNBLANK);
    type matrix_engine_t is record
        state    : state_t;
        pix_col  : natural range 0 to cPanelLength_pix;
        pix_row  : natural range 0 to cPanelWidth_pix/2;
        pix_idx  : natural range 0 to cColorWidth_bits;
        red0     : std_logic_vector(cPanelLength_pix - 1 downto 0);
        green0   : std_logic_vector(cPanelLength_pix - 1 downto 0);
        blue0    : std_logic_vector(cPanelLength_pix - 1 downto 0);
        red1     : std_logic_vector(cPanelLength_pix - 1 downto 0);
        green1   : std_logic_vector(cPanelLength_pix - 1 downto 0);
        blue1    : std_logic_vector(cPanelLength_pix - 1 downto 0);
        counter  : natural range 0 to 65535;
    end record matrix_engine_t;
    signal matrix_engine : matrix_engine_t := (
        state    => RESET,
        pix_col  => 0,
        pix_row  => 0,
        pix_idx  => 0,
        red0     => (others => '0'),
        green0   => (others => '0'),
        blue0    => (others => '0'),
        red1     => (others => '0'),
        green1   => (others => '0'),
        blue1    => (others => '0'),
        counter  => 0
    );
begin
    
    StateMachine: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                matrix_engine <= (
                    state    => RESET,
                    pix_col  => 0,
                    pix_row  => 0,
                    pix_idx  => 0,
                    red0     => (others => '0'),
                    green0   => (others => '0'),
                    blue0    => (others => '0'),
                    red1     => (others => '0'),
                    green1   => (others => '0'),
                    blue1    => (others => '0'),
                    counter  => 0
                );

                o_addr   <= (others => '0');
                o_select <= (others => '0');
                o_ren    <= '0';
                o_a      <= (others => '0');
                o_blank  <= '1';
                o_latch  <= '0';
                o_sclk   <= '0';
                o_rgb0   <= "000";
                o_rgb1   <= "000";
            else
                case matrix_engine.state is
                    when RESET =>
                        matrix_engine.state <= FETCH;
                        o_addr   <= (others => '0');
                        o_select <= (others => '0');
                        o_ren    <= '0';
                        o_a      <= (others => '0');
                        o_blank  <= '1';
                        o_latch  <= '0';
                        o_sclk   <= '0';
                        o_rgb0   <= "000";
                        o_rgb1   <= "000";

                    when FETCH =>
                        o_ren    <= '1';
                        o_select <= to_slv(matrix_engine.pix_idx, clog2(cColorWidth_bits));
                        if (matrix_engine.pix_col < cPanelLength_pix) then
                            matrix_engine.pix_col <= matrix_engine.pix_col + 1;
                            o_addr   <= to_slv(matrix_engine.pix_col + matrix_engine.pix_row * cPanelLength_pix, 
                                clog2(cPanelLength_pix * cPanelWidth_pix / 2)); 
                        else
                            o_ren <= '0';
                            matrix_engine.pix_col <= 0;
                            matrix_engine.state <= FETCH_LAST;
                        end if;

                        if (i_dvalid = '1') then
                            matrix_engine.red0(0)   <= i_rgb0(0);
                            matrix_engine.green0(0) <= i_rgb0(1);
                            matrix_engine.blue0(0)  <= i_rgb0(2);

                            matrix_engine.red1(0)   <= i_rgb1(0);
                            matrix_engine.green1(0) <= i_rgb1(1);
                            matrix_engine.blue1(0)  <= i_rgb1(2);
                            for ii in 1 to cPanelLength_pix - 1 loop
                                matrix_engine.red0(ii)   <= matrix_engine.red0(ii - 1);
                                matrix_engine.green0(ii) <= matrix_engine.green0(ii - 1);
                                matrix_engine.blue0(ii)  <= matrix_engine.blue0(ii - 1);

                                matrix_engine.red1(ii)   <= matrix_engine.red1(ii - 1);
                                matrix_engine.green1(ii) <= matrix_engine.green1(ii - 1);
                                matrix_engine.blue1(ii)  <= matrix_engine.blue1(ii - 1);
                            end loop;
                        end if;
                    
                    when FETCH_LAST => 
                        matrix_engine.state <= SHIFT;
                        if (i_dvalid = '1') then
                            matrix_engine.red0(0)   <= i_rgb0(0);
                            matrix_engine.green0(0) <= i_rgb0(1);
                            matrix_engine.blue0(0)  <= i_rgb0(2);

                            matrix_engine.red1(0)   <= i_rgb1(0);
                            matrix_engine.green1(0) <= i_rgb1(1);
                            matrix_engine.blue1(0)  <= i_rgb1(2);
                            for ii in 1 to cPanelLength_pix - 1 loop
                                matrix_engine.red0(ii)   <= matrix_engine.red0(ii - 1);
                                matrix_engine.green0(ii) <= matrix_engine.green0(ii - 1);
                                matrix_engine.blue0(ii)  <= matrix_engine.blue0(ii - 1);

                                matrix_engine.red1(ii)   <= matrix_engine.red1(ii - 1);
                                matrix_engine.green1(ii) <= matrix_engine.green1(ii - 1);
                                matrix_engine.blue1(ii)  <= matrix_engine.blue1(ii - 1);
                            end loop;
                        end if;

                    when SHIFT =>
                        if (matrix_engine.counter < cSclkPeriod_cc) then
                            matrix_engine.counter <= matrix_engine.counter + 1;
                            if (matrix_engine.counter = cSclkPeriod_cc / 2) then
                                o_sclk <= '1';
                            elsif (matrix_engine.counter = cSclkPeriod_cc / 4) then
                                matrix_engine.red0(0)   <= '0';
                                matrix_engine.green0(0) <= '0';
                                matrix_engine.blue0(0)  <= '0';

                                matrix_engine.red1(0)   <= '0';
                                matrix_engine.green1(0) <= '0';
                                matrix_engine.blue1(0)  <= '0';
                                for ii in 1 to cPanelLength_pix - 1 loop
                                    matrix_engine.red0(ii)   <= matrix_engine.red0(ii - 1);
                                    matrix_engine.green0(ii) <= matrix_engine.green0(ii - 1);
                                    matrix_engine.blue0(ii)  <= matrix_engine.blue0(ii - 1);

                                    matrix_engine.red1(ii)   <= matrix_engine.red1(ii - 1);
                                    matrix_engine.green1(ii) <= matrix_engine.green1(ii - 1);
                                    matrix_engine.blue1(ii)  <= matrix_engine.blue1(ii - 1);
                                end loop;

                                o_rgb0 <= matrix_engine.red0(cPanelLength_pix - 1) 
                                    & matrix_engine.green0(cPanelLength_pix - 1) 
                                    & matrix_engine.blue0(cPanelLength_pix - 1);
                                o_rgb1 <= matrix_engine.red1(cPanelLength_pix - 1) 
                                    & matrix_engine.green1(cPanelLength_pix - 1) 
                                    & matrix_engine.blue1(cPanelLength_pix - 1);
                            end if;
                        else
                            o_sclk <= '0';
                            matrix_engine.counter <= 0;
                            if (matrix_engine.pix_col < cPanelLength_pix - 1) then
                                matrix_engine.pix_col <= matrix_engine.pix_col + 1;
                            else
                                matrix_engine.pix_col <= 0;
                                matrix_engine.state   <= BLANK;
                            end if;
                        end if;

                    when BLANK => 
                        o_blank <= '1';
                        if (matrix_engine.counter < cSclkPeriod_cc) then
                            matrix_engine.counter <= matrix_engine.counter + 1;
                        else
                            matrix_engine.counter <= 0;
                            matrix_engine.state <= SET_ADDRESS;
                        end if;

                    when SET_ADDRESS =>
                        o_a <= to_slv(matrix_engine.pix_row, clog2(cPanelWidth_pix/2));
                        if (matrix_engine.counter < cSclkPeriod_cc) then
                            matrix_engine.counter <= matrix_engine.counter + 1;
                        else
                            matrix_engine.counter <= 0;
                            matrix_engine.state <= LATCH;
                        end if;

                    when LATCH =>
                        o_latch <= '1';
                        if (matrix_engine.counter < cSclkPeriod_cc) then
                            matrix_engine.counter <= matrix_engine.counter + 1;
                        else
                            matrix_engine.counter <= 0;
                            matrix_engine.state <= UNBLANK;
                        end if;

                    when UNBLANK =>
                        o_blank             <= '0';
                        o_latch             <= '0';
                        if (matrix_engine.counter < cSclkPeriod_cc * (2 ** (matrix_engine.pix_idx))) then
                            matrix_engine.counter <= matrix_engine.counter + 1;
                        else
                            matrix_engine.counter <= 0;
                            matrix_engine.state <= FETCH;

                            if (matrix_engine.pix_idx < cColorWidth_bits - 1) then
                                matrix_engine.pix_idx <= matrix_engine.pix_idx + 1;
                            else
                                matrix_engine.pix_idx <= 0;
                                if (matrix_engine.pix_row < cPanelWidth_pix/2 - 1) then
                                    matrix_engine.pix_row <= matrix_engine.pix_row + 1; 
                                else
                                    matrix_engine.pix_row <= 0;
                                end if;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process StateMachine;
    
end architecture rtl;