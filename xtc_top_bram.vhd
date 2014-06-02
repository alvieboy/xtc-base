library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.xtcpkg.all;
use work.xtccomppkg.all;

entity xtc_top_bram is
  port (
    wb_clk_i:       in std_logic;
    wb_clk_i_2x:    in std_logic;
    wb_rst_i:       in std_logic;

    -- IO wishbone interface

    wb_ack_i:       in std_logic;
    wb_dat_i:       in std_logic_vector(31 downto 0);
    wb_dat_o:       out std_logic_vector(31 downto 0);
    wb_adr_o:       out std_logic_vector(31 downto 0);
    wb_tag_o:       out std_logic_vector(31 downto 0);
    wb_tag_i:       in std_logic_vector(31 downto 0);
    wb_cyc_o:       out std_logic;
    wb_stb_o:       out std_logic;
    wb_sel_o:       out std_logic_vector(3 downto 0);
    wb_we_o:        out std_logic;
    wb_inta_i:      in std_logic
  );
end entity;

architecture behave of xtc_top_bram is


  signal wb_read:       std_logic_vector(31 downto 0);
  signal wb_write:      std_logic_vector(31 downto 0);
  signal wb_address:    std_logic_vector(31 downto 0);
  signal wb_tago:       std_logic_vector(31 downto 0);
  signal wb_tagi:       std_logic_vector(31 downto 0);
  signal wb_stb:        std_logic;
  signal wb_cyc:        std_logic;
  signal wb_sel:        std_logic_vector(3 downto 0);
  signal wb_we:         std_logic;
  signal wb_ack:        std_logic;
  signal wb_stall:      std_logic;

  signal ram_wb_read:       std_logic_vector(31 downto 0);
  signal ram_wb_write:      std_logic_vector(31 downto 0);
  signal ram_wb_address:    std_logic_vector(31 downto 0);
  signal ram_wb_tag_i:      std_logic_vector(31 downto 0);
  signal ram_wb_tag_o:      std_logic_vector(31 downto 0);
  signal ram_wb_stb:        std_logic;
  signal ram_wb_cyc:        std_logic;
  signal ram_wb_sel:        std_logic_vector(3 downto 0);
  signal ram_wb_we:         std_logic;
  signal ram_wb_ack:        std_logic;
  signal ram_wb_stall:      std_logic;

  signal pio_wb_read:       std_logic_vector(31 downto 0);
  signal pio_wb_write:      std_logic_vector(31 downto 0);
  signal pio_wb_address:    std_logic_vector(31 downto 0);
  signal pio_wb_tag_i:      std_logic_vector(31 downto 0);
  signal pio_wb_tag_o:      std_logic_vector(31 downto 0);
  signal pio_wb_stb:        std_logic;
  signal pio_wb_cyc:        std_logic;
  signal pio_wb_sel:        std_logic_vector(3 downto 0);
  signal pio_wb_we:         std_logic;
  signal pio_wb_ack:        std_logic;
  signal pio_wb_stall:      std_logic;
  signal pio_wb_int:        std_logic;

  signal rom_wb_ack:       std_logic;
  signal rom_wb_read:      std_logic_vector(31 downto 0);
  signal rom_wb_adr:       std_logic_vector(31 downto 0);
  signal rom_wb_tag_i:     std_logic_vector(31 downto 0);
  signal rom_wb_tag_o:     std_logic_vector(31 downto 0);
  signal rom_wb_cyc:       std_logic;
  signal rom_wb_stb:       std_logic;
  signal rom_wb_cti:       std_logic_vector(2 downto 0);
  signal rom_wb_stall:     std_logic;





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

begin

  cpu: xtc
  port map (
    wb_clk_i        => wb_clk_i,
    wb_clk_i_2x     => wb_clk_i_2x,
    wb_rst_i        => wb_rst_i,

    -- Master wishbone interface

    wb_ack_i        => wb_ack,
    wb_dat_i        => wb_read,
    wb_dat_o        => wb_write,
    wb_adr_o        => wb_address,
    wb_cyc_o        => wb_cyc,
    wb_stb_o        => wb_stb,
    wb_sel_o        => wb_sel,
    wb_tag_o        => wb_tago,
    wb_tag_i        => wb_tagi,
    wb_we_o         => wb_we,
    wb_stall_i      => wb_stall,
      -- ROM wb interface

    rom_wb_ack_i    => rom_wb_ack,
    rom_wb_dat_i    => rom_wb_read,
    rom_wb_adr_o    => rom_wb_adr,
    rom_wb_cyc_o    => rom_wb_cyc,
    rom_wb_stb_o    => rom_wb_stb,
    rom_wb_stall_i  => rom_wb_stall,

    wb_inta_i       => wb_inta_i,
    isnmi           => '0'
  );

  myram: romram
  generic map (
    BITS  => 15
  )
  port map (
    ram_wb_clk_i    => wb_clk_i,
    ram_wb_rst_i    => wb_rst_i,
    ram_wb_ack_o    => ram_wb_ack,
    ram_wb_dat_i    => ram_wb_write,
    ram_wb_dat_o    => ram_wb_read,
    ram_wb_adr_i    => ram_wb_address(14 downto 2),
    ram_wb_cyc_i    => ram_wb_cyc,
    ram_wb_stb_i    => ram_wb_stb,
    ram_wb_sel_i    => ram_wb_sel,
    ram_wb_we_i     => ram_wb_we,
    ram_wb_stall_o  => ram_wb_stall,
    ram_wb_tag_i    => ram_wb_tag_i,
    ram_wb_tag_o    => ram_wb_tag_o,

    rom_wb_clk_i    => wb_clk_i,
    rom_wb_rst_i    => wb_rst_i,
    rom_wb_ack_o    => rom_wb_ack,
    rom_wb_dat_o    => rom_wb_read,
    rom_wb_adr_i    => rom_wb_adr(14 downto 2),
    rom_wb_cyc_i    => rom_wb_cyc,
    rom_wb_stb_i    => rom_wb_stb,
    rom_wb_tag_i    => rom_wb_tag_i,
    rom_wb_tag_o    => rom_wb_tag_o,
    rom_wb_stall_o  => rom_wb_stall
  );

  muxer: wbmux2
  generic map (
    select_line   => 31,
    address_high  => 31,
    address_low   => 2
  )
  port map (
    wb_clk_i      => wb_clk_i,
	 	wb_rst_i      => wb_rst_i,

    -- Master 

    m_wb_dat_o    => wb_read,
    m_wb_dat_i    => wb_write,
    m_wb_adr_i    => wb_address(31 downto 2),
    m_wb_sel_i    => wb_sel,
    m_wb_we_i     => wb_we,
    m_wb_cyc_i    => wb_cyc,
    m_wb_stb_i    => wb_stb,
    m_wb_tag_i    => wb_tago,
    m_wb_tag_o    => wb_tagi,
    m_wb_ack_o    => wb_ack,
    m_wb_stall_o  => wb_stall,

    -- Slave 0 signals

    s0_wb_dat_i   => ram_wb_read,
    s0_wb_dat_o   => ram_wb_write,
    s0_wb_tag_i   => ram_wb_tag_o,
    s0_wb_tag_o   => ram_wb_tag_i,
    s0_wb_adr_o   => ram_wb_address(31 downto 2),
    s0_wb_sel_o   => ram_wb_sel,
    s0_wb_we_o    => ram_wb_we,
    s0_wb_cyc_o   => ram_wb_cyc,
    s0_wb_stb_o   => ram_wb_stb,
    s0_wb_ack_i   => ram_wb_ack,
    s0_wb_stall_i => ram_wb_stall,

    -- Slave 1 signals

    s1_wb_dat_i   => pio_wb_read,
    s1_wb_dat_o   => pio_wb_write,
    s1_wb_tag_i   => pio_wb_tag_o,
    s1_wb_tag_o   => pio_wb_tag_i,
    s1_wb_adr_o   => pio_wb_address(31 downto 2),
    s1_wb_sel_o   => pio_wb_sel,
    s1_wb_we_o    => pio_wb_we,
    s1_wb_cyc_o   => pio_wb_cyc,
    s1_wb_stb_o   => pio_wb_stb,
    s1_wb_ack_i   => pio_wb_ack,
    s1_wb_stall_i => pio_wb_stall
  );



  ioadaptor: wb_master_p_to_slave_np
  port map (
    syscon.clk  => wb_clk_i,
    syscon.rst  => wb_rst_i,
    -- Master signals
    mwbo.dat    => pio_wb_read,
    mwbo.ack    => pio_wb_ack,
    mwbo.stall  => pio_wb_stall,
    mwbo.int    => pio_wb_int,
    mwbo.tag    => pio_wb_tag_i,

    mwbi.dat    => pio_wb_write,
    mwbi.adr    => pio_wb_address,
    mwbi.cyc    => pio_wb_cyc,
    mwbi.tag    => pio_wb_tag_o,
    mwbi.stb    => pio_wb_stb,
    mwbi.we     => pio_wb_we,
    mwbi.sel    => pio_wb_sel,

    -- Slave signals
    swbi.dat    => wb_dat_i,
    swbi.ack    => wb_ack_i,
    swbi.stall  => '0',
    swbi.int    => '0',
    swbi.tag    => wb_tag_i,
    
    swbo.adr    => wb_adr_o,
    swbo.dat    => wb_dat_o,
    swbo.sel    => wb_sel_o,
    swbo.stb    => wb_stb_o,
    swbo.cyc    => wb_cyc_o,
    swbo.tag    => wb_tag_o,
    swbo.we     => wb_we_o
  );


end behave;
