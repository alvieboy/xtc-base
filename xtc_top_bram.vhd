library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.xtcpkg.all;
use work.xtccomppkg.all;
use work.wishbonepkg.all;

entity xtc_top_bram is
  port (
    wb_syscon:      in wb_syscon_type;
    -- IO wishbone interface
    iowbo:           out wb_mosi_type;
    iowbi:           in wb_miso_type
  );
end entity;

architecture behave of xtc_top_bram is

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
    ram_wb_tag_i:       in std_logic_vector(31 downto 0);
    ram_wb_tag_o:       out std_logic_vector(31 downto 0);
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
    rom_wb_tag_i:       in std_logic_vector(31 downto 0);
    rom_wb_tag_o:       out std_logic_vector(31 downto 0);
    rom_wb_adr_i:       in std_logic_vector(BITS-1 downto 2);
    rom_wb_cyc_i:       in std_logic;
    rom_wb_stb_i:       in std_logic;
    rom_wb_stall_o:     out std_logic
  );
  end component;

  signal wbo,romwbo,ramwbo,piowbo: wb_mosi_type;
  signal wbi,romwbi,ramwbi,piowbi: wb_miso_type;

begin

  cpu: xtc
  port map (
    wb_syscon       => wb_syscon,
    -- Master wishbone interface
    wbo             => wbo,
    wbi             => wbi,
    -- ROM wb interface
    romwbo          => romwbo,
    romwbi          => romwbi,
    isnmi           => '0'
  );

  myram: romram
  generic map (
    BITS  => 15
  )
  port map (
    ram_wb_clk_i    => wb_syscon.clk,
    ram_wb_rst_i    => wb_syscon.rst,
    ram_wb_ack_o    => ramwbi.ack,
    ram_wb_dat_i    => ramwbo.dat,
    ram_wb_dat_o    => ramwbi.dat,
    ram_wb_adr_i    => ramwbo.adr(14 downto 2),
    ram_wb_cyc_i    => ramwbo.cyc,
    ram_wb_stb_i    => ramwbo.stb,
    ram_wb_sel_i    => ramwbo.sel,
    ram_wb_we_i     => ramwbo.we,
    ram_wb_stall_o  => ramwbi.stall,
    ram_wb_tag_i    => ramwbo.tag,
    ram_wb_tag_o    => ramwbi.tag,

    rom_wb_clk_i    => wb_syscon.clk,
    rom_wb_rst_i    => wb_syscon.rst,
    rom_wb_ack_o    => romwbi.ack,
    rom_wb_dat_o    => romwbi.dat,
    rom_wb_adr_i    => romwbo.adr(14 downto 2),
    rom_wb_cyc_i    => romwbo.cyc,
    rom_wb_stb_i    => romwbo.stb,
    rom_wb_tag_i    => romwbo.tag,
    rom_wb_tag_o    => romwbi.tag,
    rom_wb_stall_o  => romwbi.stall
  );

  muxer: xtc_wbmux2
  generic map (
    select_line   => 31,
    address_high  => 31,
    address_low   => 2
  )
  port map (
    wb_syscon     => wb_syscon,
    -- Master 
    m_wbi         => wbo,
    m_wbo         => wbi,

    -- Slave 0 signals
    s0_wbi        => ramwbi,
    s0_wbo        => ramwbo,

    -- Slave 1 signals
    s1_wbi        => piowbi,
    s1_wbo        => piowbo
  );

  

  ioadaptor: wb_master_p_to_slave_np
  port map (
    syscon      => wb_syscon,
    mwbo        => piowbi,
    mwbi        => piowbo,
    swbi        => iowbi,
    swbo        => iowbo
  );


end behave;
