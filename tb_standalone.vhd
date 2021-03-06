library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.xtcpkg.all;
use work.xtccomppkg.all;
use work.wishbonepkg.all;

entity tbs is
end entity tbs;

architecture sim of tbs is

  constant period: time := 10 ns;
  signal w_clk: std_logic := '0';
  signal w_rst: std_logic := '0';

  signal wb_read:    std_logic_vector(31 downto 0);
  signal wb_write:   std_logic_vector(31 downto 0);
  signal wb_address: std_logic_vector(31 downto 0);
  signal wb_stb:     std_logic;
  signal wb_cyc:     std_logic;
  signal wb_sel:     std_logic_vector(3 downto 0);
  signal wb_we:      std_logic;
  signal wb_ack:     std_logic;
  signal wb_stall:     std_logic;

  signal rom_wb_ack:       std_logic;
  signal rom_wb_read:      std_logic_vector(31 downto 0);
  signal rom_wb_adr:       std_logic_vector(31 downto 0);
  signal rom_wb_cyc:       std_logic;
  signal rom_wb_stb:       std_logic;
  signal rom_wb_cti:       std_logic_vector(2 downto 0);
  signal rom_wb_stall:     std_logic;

  component wbarb2_1 is
  generic (
    ADDRESS_HIGH: integer := 31;
    ADDRESS_LOW: integer := 0
  );
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;

    -- Master 0 signals

    m0_wb_dat_o: out std_logic_vector(31 downto 0);
    m0_wb_dat_i: in std_logic_vector(31 downto 0);
    m0_wb_adr_i: in std_logic_vector(ADDRESS_HIGH downto ADDRESS_LOW);
    m0_wb_sel_i: in std_logic_vector(3 downto 0);
    m0_wb_cti_i: in std_logic_vector(2 downto 0);
    m0_wb_we_i:  in std_logic;
    m0_wb_cyc_i: in std_logic;
    m0_wb_stb_i: in std_logic;
    m0_wb_stall_o: out std_logic;
    m0_wb_ack_o: out std_logic;

    -- Master 1 signals

    m1_wb_dat_o: out std_logic_vector(31 downto 0);
    m1_wb_dat_i: in std_logic_vector(31 downto 0);
    m1_wb_adr_i: in std_logic_vector(ADDRESS_HIGH downto ADDRESS_LOW);
    m1_wb_sel_i: in std_logic_vector(3 downto 0);
    m1_wb_cti_i: in std_logic_vector(2 downto 0);
    m1_wb_we_i:  in std_logic;
    m1_wb_cyc_i: in std_logic;
    m1_wb_stb_i: in std_logic;
    m1_wb_ack_o: out std_logic;
    m1_wb_stall_o: out std_logic;

    -- Slave signals

    s0_wb_dat_i: in std_logic_vector(31 downto 0);
    s0_wb_dat_o: out std_logic_vector(31 downto 0);
    s0_wb_adr_o: out std_logic_vector(ADDRESS_HIGH downto ADDRESS_LOW);
    s0_wb_sel_o: out std_logic_vector(3 downto 0);
    s0_wb_cti_o: out std_logic_vector(2 downto 0);
    s0_wb_we_o:  out std_logic;
    s0_wb_cyc_o: out std_logic;
    s0_wb_stb_o: out std_logic;
    s0_wb_ack_i: in std_logic;
    s0_wb_stall_i: in std_logic
  );
  end component;

  component wb_singleport_ram is
  generic (
    bits: natural := 8
  );
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;
    wb_dat_o: out std_logic_vector(31 downto 0);
    wb_dat_i: in std_logic_vector(31 downto 0);
    wb_adr_i: in std_logic_vector(31 downto 0);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;
    wb_inta_o:out std_logic
  );
  end component;

  component wb_master_np_to_slave_p is
  generic (
    ADDRESS_HIGH: integer := 31;
    ADDRESS_LOW: integer := 0
  );
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;

    -- Master signals

    m_wb_dat_o: out std_logic_vector(31 downto 0);
    m_wb_dat_i: in std_logic_vector(31 downto 0);
    m_wb_adr_i: in std_logic_vector(ADDRESS_HIGH downto ADDRESS_LOW);
    m_wb_sel_i: in std_logic_vector(3 downto 0);
    m_wb_cti_i: in std_logic_vector(2 downto 0);
    m_wb_we_i:  in std_logic;
    m_wb_cyc_i: in std_logic;
    m_wb_stb_i: in std_logic;
    m_wb_ack_o: out std_logic;

    -- Slave signals

    s_wb_dat_i: in std_logic_vector(31 downto 0);
    s_wb_dat_o: out std_logic_vector(31 downto 0);
    s_wb_adr_o: out std_logic_vector(ADDRESS_HIGH downto ADDRESS_LOW);
    s_wb_sel_o: out std_logic_vector(3 downto 0);
    s_wb_cti_o: out std_logic_vector(2 downto 0);
    s_wb_we_o:  out std_logic;
    s_wb_cyc_o: out std_logic;
    s_wb_stb_o: out std_logic;
    s_wb_ack_i: in std_logic;
    s_wb_stall_i: in std_logic
  );
  end component;

  component romram is
  generic (
    BITS: integer := 32
  );
  port (
    ram_wb_clk_i:       in std_logic;
    ram_wb_rst_i:       in std_logic;
    ram_wb_ack_o:       out std_logic;
    ram_wb_dat_i:       in std_logic_vector(31 downto 0);
    ram_wb_dat_o:       out std_logic_vector(31 downto 0);
    ram_wb_adr_i:       in std_logic_vector(BITS-1 downto 2);
    ram_wb_sel_i:       in std_logic_vector(3 downto 0);
    ram_wb_cyc_i:       in std_logic;
    ram_wb_stb_i:       in std_logic;
    ram_wb_we_i:        in std_logic;
    ram_wb_stall_o:     out std_logic;

    rom_wb_clk_i:       in std_logic;
    rom_wb_rst_i:       in std_logic;
    rom_wb_ack_o:       out std_logic;
    rom_wb_dat_o:       out std_logic_vector(31 downto 0);
    rom_wb_adr_i:       in std_logic_vector(BITS-1 downto 2);
    rom_wb_cyc_i:       in std_logic;
    rom_wb_stb_i:       in std_logic;
    rom_wb_stall_o:     out std_logic
  );
  end component;

begin

  w_clk <= not w_clk after period/2;

  cpu: xtc
  port map (
    wb_clk_i        => w_clk,
    wb_rst_i        => w_rst,

    -- Master wishbone interface

    wb_ack_i        => wb_ack,
    wb_dat_i        => wb_read,
    wb_dat_o        => wb_write,
    wb_adr_o        => wb_address,
    wb_cyc_o        => wb_cyc,
    wb_stb_o        => wb_stb,
    wb_sel_o        => wb_sel,
    wb_we_o         => wb_we,
    wb_stall_i      => wb_stall,
      -- ROM wb interface

    rom_wb_ack_i    => rom_wb_ack,
    rom_wb_dat_i    => rom_wb_read,
    rom_wb_adr_o    => rom_wb_adr,
    rom_wb_cyc_o    => rom_wb_cyc,
    rom_wb_stb_o    => rom_wb_stb,
    rom_wb_stall_i  => rom_wb_stall,

    wb_inta_i       => '0',
    isnmi           => '0'
  );

  myram: romram
  generic map (
    BITS  => 15
  )
  port map (
    ram_wb_clk_i    => w_clk,
    ram_wb_rst_i    => w_rst,
    ram_wb_ack_o    => wb_ack,
    ram_wb_dat_i    => wb_write,
    ram_wb_dat_o    => wb_read,
    ram_wb_adr_i    => wb_address(14 downto 2),
    ram_wb_cyc_i    => wb_cyc,
    ram_wb_stb_i    => wb_stb,
    ram_wb_sel_i    => wb_sel,
    ram_wb_we_i     => wb_we,
    ram_wb_stall_o  => wb_stall,

    rom_wb_clk_i    => w_clk,
    rom_wb_rst_i    => w_rst,
    rom_wb_ack_o    => rom_wb_ack,
    rom_wb_dat_o    => rom_wb_read,
    rom_wb_adr_i    => rom_wb_adr(14 downto 2),
    rom_wb_cyc_i    => rom_wb_cyc,
    rom_wb_stb_i    => rom_wb_stb,
    rom_wb_stall_o  => rom_wb_stall
  );


  -- Reset procedure
  process
  begin
    w_rst<='0';
    wait for period;
    w_rst<='1';
    wait for period;
    w_rst<='0';
    wait;
  end process;

end sim;
