library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.newcpupkg.all;
use work.newcpucomppkg.all;

entity newcpu is
  port (
    wb_clk_i:       in std_logic;
    wb_rst_i:       in std_logic;

    -- Master wishbone interface

    wb_ack_i:       in std_logic;
    wb_dat_i:       in std_logic_vector(31 downto 0);
    wb_dat_o:       out std_logic_vector(31 downto 0);
    wb_adr_o:       out std_logic_vector(31 downto 0);
    wb_cyc_o:       out std_logic;
    wb_stb_o:       out std_logic;
    wb_sel_o:       out std_logic_vector(3 downto 0);
    wb_we_o:        out std_logic;
    -- ROM wb interface

    rom_wb_ack_i:       in std_logic;
    rom_wb_dat_i:       in std_logic_vector(31 downto 0);
    rom_wb_adr_o:       out std_logic_vector(31 downto 0);
    rom_wb_cyc_o:       out std_logic;
    rom_wb_stb_o:       out std_logic;
    rom_wb_cti_o:       out std_logic_vector(2 downto 0);
    rom_wb_stall_i:     in std_logic;

    wb_inta_i:      in std_logic;
    isnmi:          in std_logic;
    poppc_inst:     out std_logic;
    break:          out std_logic;
    intack:         out std_logic
  );
end newcpu;

architecture behave of newcpu is

  signal fuo:  fetch_output_type;
  signal duo:  decode_output_type;
  signal fduo: fetchdata_output_type;
  signal euo:  execute_output_type;
  signal muo:  memory_output_type;

  signal rb1_addr: std_logic_vector(2 downto 0);
  signal rb2_addr: std_logic_vector(2 downto 0);
  signal rb1_wr:   std_logic_vector(31 downto 0);
  signal rb2_wr:   std_logic_vector(31 downto 0);
  signal rb1_we:   std_logic;
  signal rb2_we:   std_logic;
  signal rb1_en:   std_logic;
  signal rb2_en:   std_logic;
  signal rb1_rd:   std_logic_vector(31 downto 0);
  signal rb2_rd:   std_logic_vector(31 downto 0);

  signal cache_valid:          std_logic;
  signal cache_flush:          std_logic;
  signal cache_data:           std_logic_vector(31 downto 0);
  signal cache_address:        std_logic_vector(31 downto 0);
  signal cache_strobe:         std_logic;
  signal cache_enable:         std_logic;
  signal cache_stall:          std_logic;


begin

  -- Register bank.

  rb: regbank_2p
  port map (
    clk     => wb_clk_i,
    rb1_en  => rb1_en,
    rb1_addr=> rb1_addr,
    rb1_rd  => rb1_rd,
    rb2_en  => rb2_en,
    rb2_we  => rb2_we,
    rb2_addr=> rb2_addr,
    rb2_wr  => rb2_wr
  );

  cache: icache
  generic map (
    ADDRESS_HIGH => 31
  )
  port map (
    wb_clk_i    => wb_clk_i,
    wb_rst_i    => wb_rst_i,

    valid       => cache_valid,
    data        => cache_data,
    address     => cache_address,
    strobe      => cache_strobe,
    stall       => cache_stall,
    enable      => cache_enable,
    flush       => cache_flush,

    m_wb_ack_i  => rom_wb_ack_i,
    m_wb_dat_i  => rom_wb_dat_i,
    m_wb_adr_o  => rom_wb_adr_o,
    m_wb_cyc_o  => rom_wb_cyc_o,
    m_wb_stb_o  => rom_wb_stb_o,
    m_wb_stall_i => rom_wb_stall_i
  );

  fetch_unit: fetch
    port map (
      clk       => wb_clk_i,
      rst       => wb_rst_i,
      -- Connection to ROM
      stall     => cache_stall,
      valid     => cache_valid,
      address   => cache_address,
      read      => cache_data,
      enable    => cache_enable,
      strobe    => cache_strobe,
      -- Outputs for next stages
      fuo       => fuo
    );

  decode_unit: decode
    port map (
      clk       => wb_clk_i,
      rst       => wb_rst_i,
      -- Input from fetch unit
      fui       => fuo,
      -- Outputs for next stages
      duo       => duo
    );

  fetchdata_unit: fetchdata
    port map (
      clk       => wb_clk_i,
      rst       => wb_rst_i,
      r_en      => rb1_en,
      --r_we      => rb1_we,
      r_addr    => rb1_addr,
      --r_write   => rb1_wr,
      r_read    => rb1_rd,
      -- Input from decode unit
      dui       => duo,
      -- Outputs for next stages
      fduo       => fduo
    );

  execute_unit: execute
    port map (
      clk       => wb_clk_i,
      rst       => wb_rst_i,
      -- Input from fetchdata unit
      fdui      => fduo,
      -- Outputs for next stages
      euo       => euo
    );

  memory_unit: memory
    port map (
    clk             => wb_clk_i,
    rst             => wb_rst_i,
    -- Memory interface
    wb_ack_i        => wb_ack_i,
    wb_dat_i        => wb_dat_i,
    wb_dat_o        => wb_dat_o,
    wb_adr_o        => wb_adr_o,
    wb_cyc_o        => wb_cyc_o,
    wb_stb_o        => wb_stb_o,
    wb_sel_o        => wb_sel_o,
    wb_we_o         => wb_we_o,
    -- Input for previous stages
    eui             => euo,
    -- Output for next stages
    muo             => muo
    );

  writeback_unit: writeback
    port map (
      clk       => wb_clk_i,
      rst       => wb_rst_i,
      r_en      => rb2_en,
      r_we      => rb2_we,
      r_addr    => rb2_addr,
      r_write   => rb2_wr,
      r_read    => rb2_rd,
      -- Input from previous stage
      mui       => muo,
      eui       => euo -- for fast register write
    );


  cache_flush<='0';
end behave;

