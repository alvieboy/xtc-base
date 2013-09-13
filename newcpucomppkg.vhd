library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.newcpupkg.all;

package newcpucomppkg is

  component generic_dp_ram is
  generic (
    address_bits: integer := 8;
    data_bits: integer := 32
  );
  port (
    clka:             in std_logic;
    ena:              in std_logic;
    wea:              in std_logic;
    addra:            in std_logic_vector(address_bits-1 downto 0);
    dia:              in std_logic_vector(data_bits-1 downto 0);
    doa:              out std_logic_vector(data_bits-1 downto 0);
    clkb:             in std_logic;
    enb:              in std_logic;
    web:              in std_logic;
    addrb:            in std_logic_vector(address_bits-1 downto 0);
    dib:              in std_logic_vector(data_bits-1 downto 0);
    dob:              out std_logic_vector(data_bits-1 downto 0)
  );

  end component;

  component generic_dp_ram_r is
  generic (
    address_bits: integer := 8;
    srval_1: std_logic_vector(31 downto 0);
    srval_2: std_logic_vector(31 downto 0)
  );
  port (
    clka:             in std_logic;
    ena:              in std_logic;
    wea:              in std_logic;
    addra:            in std_logic_vector(address_bits-1 downto 0);
    ssra:             in std_logic;
    dia:              in std_logic_vector(31 downto 0);
    doa:              out std_logic_vector(31 downto 0);
    clkb:             in std_logic;
    enb:              in std_logic;
    ssrb:             in std_logic;
    web:              in std_logic;
    addrb:            in std_logic_vector(address_bits-1 downto 0);
    dib:              in std_logic_vector(31 downto 0);
    dob:              out std_logic_vector(31 downto 0)
  );
  end component;

  component newcpu is
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

    wb_inta_i:      in std_logic;

    -- ROM wb interface

    rom_wb_ack_i:       in std_logic;
    rom_wb_dat_i:       in std_logic_vector(31 downto 0);
    rom_wb_adr_o:       out std_logic_vector(31 downto 0);
    rom_wb_cyc_o:       out std_logic;
    rom_wb_stb_o:       out std_logic;
    rom_wb_cti_o:       out std_logic_vector(2 downto 0);
    rom_wb_stall_i:     in std_logic;

    isnmi:          in std_logic;
    poppc_inst:     out std_logic;
    break:          out std_logic;
    intack:         out std_logic
  );
  end component;

  component icache is
  generic (
      ADDRESS_HIGH: integer := 26
  );
  port (
    wb_clk_i:       in std_logic;
    wb_rst_i:       in std_logic;

    valid:          out std_logic;
    data:           out std_logic_vector(31 downto 0);
    address:        in std_logic_vector(31 downto 0);
    strobe:         in std_logic;
    enable:         in std_logic;
    stall:          out std_logic;
    flush:          in std_logic;
    -- Master wishbone interface

    m_wb_ack_i:       in std_logic;
    m_wb_dat_i:       in std_logic_vector(31 downto 0);
    m_wb_dat_o:       out std_logic_vector(31 downto 0);
    m_wb_adr_o:       out std_logic_vector(31 downto 0);
    m_wb_cyc_o:       out std_logic;
    m_wb_stb_o:       out std_logic;
    m_wb_stall_i:     in std_logic;
    m_wb_we_o:        out std_logic
  );
  end component;

  component mux32_4 is
  port (
    i0: in std_logic_vector(31 downto 0);
    i1: in std_logic_vector(31 downto 0);
    i2: in std_logic_vector(31 downto 0);
    i3: in std_logic_vector(31 downto 0);
    sel: in std_logic_vector(1 downto 0);
    o: out std_logic_vector(31 downto 0)
  );
  end component;

  component mux32_2 is
  port (
    i0: in std_logic_vector(31 downto 0);
    i1: in std_logic_vector(31 downto 0);
    sel: in std_logic;
    o: out std_logic_vector(31 downto 0)
  );
  end component mux32_2;

  component alu_A is
  port (
    clk: in std_logic;
    rst: in std_logic;

    a:  in unsigned(31 downto 0);
    b:  in unsigned(31 downto 0);
    o: out unsigned(31 downto 0);

    op: in alu1_op_type;

    ci: in std_logic;
    busy: out std_logic;
    co: out std_logic;
    zero: out std_logic;
    bo:   out std_logic;
    sign: out std_logic

  );
  end component;

  component fetch is
  port (
    clk:  in std_logic;
    rst:  in std_logic;

    -- Connection to ROM
    stall: in std_logic;
    valid: in std_logic;
    address: out std_logic_vector(31 downto 0);
    read: in     std_logic_vector(31 downto 0);
    enable: out std_logic;
    strobe: out std_logic;

    -- Control
    freeze:   in std_logic;
    jump:     in std_logic;
    jumpaddr: in word_type;
    
    -- Outputs for next stages
    fuo:  out fetch_output_type
  );
  end component;

  component decode is
  port (
    clk:  in std_logic;
    rst:  in std_logic;

    -- Input for previous stages
    fui:  in fetch_output_type;

    -- Output for next stages
    duo:  out decode_output_type;
    busy: out std_logic;
    freeze: in std_logic;
    flush:  in std_logic;
    jump:   in std_logic;
    jumpmsb: in std_logic
  );
  end component;

  component fetchdata is
  port (
    clk:  in std_logic;
    rst:  in std_logic;
    -- Register access
    r1_en:   out std_logic;
    r1_addr:   out regaddress_type;
    r1_read:   in word_type_std;

    r2_en:   out std_logic;
    r2_addr:   out regaddress_type;
    r2_read:   in word_type_std;

    w_addr: out regaddress_type;
    w_en:     out std_logic;
    -- Input for previous stages
    dui:  in decode_output_type;
    freeze: in std_logic;
    flush: in std_logic;
    refetch: in std_logic;
    -- Output for next stages
    fduo:  out fetchdata_output_type
  );
  end component;

  component execute is
  port (
    clk:  in std_logic;
    rst:  in std_logic;
    mem_busy: in std_logic;
    busy: out std_logic;
    wb_busy: in std_logic;
    -- Input for previous stages
    fdui:  in fetchdata_output_type;
    -- Output for next stages
    euo:  out execute_output_type
  );
  end component execute;

  component memory is
  port (
    clk:  in std_logic;
    rst:  in std_logic;
    -- Memory interface
    wb_ack_i:       in std_logic;
    wb_dat_i:       in std_logic_vector(31 downto 0);
    wb_dat_o:       out std_logic_vector(31 downto 0);
    wb_adr_o:       out std_logic_vector(31 downto 0);
    wb_cyc_o:       out std_logic;
    wb_stb_o:       out std_logic;
    wb_sel_o:       out std_logic_vector(3 downto 0);
    wb_we_o:        out std_logic;

    busy:           out std_logic;
    refetch:        out std_logic;

    -- Input for previous stages
    eui:  in execute_output_type;
    -- Output for next stages
    muo:  out memory_output_type
  );
  end component memory;

  component writeback is
  port (
    clk:  in std_logic;
    rst:  in std_logic;
    busy: out std_logic;
    -- Register access
    r_en:   out std_logic;
    r_we:   out std_logic;
    r_addr:   out regaddress_type;
    r_write:   out word_type_std;
    -- Input for previous stages
    mui:  in memory_output_type;
    eui:  in execute_output_type
  );
  end component;

  component regbank_2p is
  generic (
    ADDRESS_BITS: integer := 4
  );
  port (
    clk:      in std_logic;

    rb1_addr: in std_logic_vector(ADDRESS_BITS-1 downto 0);
    rb1_en:   in std_logic;
    rb1_rd:   out std_logic_vector(31 downto 0);

    rb2_addr: in std_logic_vector(ADDRESS_BITS-1 downto 0);
    rb2_wr:   in std_logic_vector(31 downto 0);
    rb2_we:   in std_logic;
    rb2_en:   in std_logic
  );
  end component;

  component regbank_3p is
  generic (
    ADDRESS_BITS: integer := 4
  );
  port (
    clk:      in std_logic;

    rb1_addr: in std_logic_vector(ADDRESS_BITS-1 downto 0);
    rb1_en:   in std_logic;
    rb1_rd:   out std_logic_vector(31 downto 0);

    rb2_addr: in std_logic_vector(ADDRESS_BITS-1 downto 0);
    rb2_en:   in std_logic;
    rb2_rd:   out std_logic_vector(31 downto 0);

    rb3_addr: in std_logic_vector(ADDRESS_BITS-1 downto 0);
    rb3_wr:   in std_logic_vector(31 downto 0);
    rb3_we:   in std_logic;
    rb3_en:   in std_logic
  );
  end component;

  component alu_B is
  port (
    clk: in std_logic;
    rst: in std_logic;

    a:  in unsigned(31 downto 0);
    b:  in unsigned(31 downto 0);
    o: out unsigned(31 downto 0);

    op: in alu2_op_type;

    co: out std_logic;
    zero: out std_logic;
    bo:   out std_logic;
    sign: out std_logic
  );
  end component;

  component opdec is
  port (
    opcode:   in std_logic_vector(15 downto 0);
    dec:      out opdec_type
  );
  end component;

  component taint is
  generic (
    COUNT: integer := 16
  );
  port (
    clk: in std_logic;
    rst: in std_logic;

    req1_en: in std_logic;
    req1_r: in regaddress_type;

    req2_en: in std_logic;
    req2_r: in regaddress_type;

    ready:  out std_logic;

    set_en:  in std_logic;
    set_r:   in regaddress_type;
    clr_en:  in std_logic;
    clr_r:   in regaddress_type;

    taint:  out std_logic_vector(COUNT-1 downto 0)
  );
  end component;

end package;