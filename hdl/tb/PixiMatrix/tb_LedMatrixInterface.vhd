library vunit_lib;
    context vunit_lib.vunit_context;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library osvvm;
    use osvvm.TbUtilPkg.all;
    use osvvm.RandomPkg.all;

library universal;
    use universal.CommonFunctions.all;
    use universal.CommonTypes.all;

library piximatrix;

entity tb_LedMatrixInterface is
    generic (
        runner_cfg : string
    );
end entity tb_LedMatrixInterface;

architecture tb of tb_LedMatrixInterface is
    constant cClockFrequency_Hz : natural := 100e6;
    constant cSclkFrequency_Hz  : natural := 10e6;
    constant cPanelLength_pix   : natural := 64;
    constant cPanelWidth_pix    : natural := 64;
    constant cColorWidth_bits   : natural := 4;

    signal i_clk    : std_logic := '0';
    signal i_resetn : std_logic := '0';
    signal o_addr   : std_logic_vector(clog2(cPanelLength_pix * cPanelWidth_pix / 2) - 1 downto 0) := (others => '0');
    signal o_select : std_logic_vector(clog2(cColorWidth_bits) - 1 downto 0) := (others => '0');
    signal o_ren    : std_logic := '0';
    signal i_dvalid : std_logic := '0';
    signal i_rgb0   : std_logic_vector(0 to 2) := "000";
    signal i_rgb1   : std_logic_vector(0 to 2) := "000";
    signal o_sclk   : std_logic := '0';
    signal o_latch  : std_logic := '0';
    signal o_blank  : std_logic := '0';
    signal o_a      : std_logic_vector(clog2(cPanelWidth_pix / 2) - 1 downto 0) := (others => '0');
    signal o_rgb0   : std_logic_vector(0 to 2) := "000";
    signal o_rgb1   : std_logic_vector(0 to 2) := "000";
begin
    
    CreateClock(clk=>i_clk, period=>10 ns);

    eDut : entity piximatrix.LedMatrixInterface
    generic map (
        cClockFrequency_Hz => cClockFrequency_Hz,
        cSclkFrequency_Hz => cSclkFrequency_Hz,
        cPanelLength_pix => cPanelLength_pix,
        cPanelWidth_pix  => cPanelWidth_pix,
        cColorWidth_bits => cColorWidth_bits
    ) port map (
        i_clk    => i_clk,
        i_resetn => i_resetn,

        o_addr   => o_addr,
        o_select => o_select,
        o_ren    => o_ren,

        i_dvalid => i_dvalid,
        i_rgb0   => i_rgb0,
        i_rgb1   => i_rgb1,

        o_sclk   => o_sclk,
        o_latch  => o_latch,
        o_blank  => o_blank,
        o_a      => o_a,
        o_rgb0   => o_rgb0,
        o_rgb1   => o_rgb1
    );

    Stimuli: process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("t_simple") then
                i_resetn <= '0';
                wait until rising_edge(i_clk);
                wait for 100 ps;
                i_resetn <= '1';
            end if;
        end loop;
        test_runner_cleanup(runner);
    end process Stimuli;
    
end architecture tb;