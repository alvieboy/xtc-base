library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.xtcpkg.all;
use work.wishbonepkg.all;

package xtccomppkg is

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
    dob:              out std_logic_vector(31 downto 0);

    -- RTL Debug access
    dbg_addr:         in std_logic_vector(address_bits-1 downto 0);
    dbg_do:           out std_logic_vector(32-1 downto 0)

  );
  end component;

  component xtc is
  port (
    wb_syscon:      in wb_syscon_type;
    -- Master wishbone interface
    wbo:            out wb_mosi_type;
    wbi:            in  wb_miso_type;
    -- ROM wb interface
    romwbo:         out wb_mosi_type;
    romwbi:         in  wb_miso_type;

    nmi:            in std_logic;
    nmiack:         out std_logic;
    rstreq:         out std_logic;
    break:          out std_logic;
    intack:         out std_logic;
    edbg:           in memory_debug_type
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
    abort:          in std_logic;

    tag:            in std_logic_vector(31 downto 0);
    tagen:          in std_logic;

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

  component alu is
  port (
    clk: in std_logic;
    rst: in std_logic;

    a:  in unsigned(31 downto 0);
    b:  in unsigned(31 downto 0);
    o: out unsigned(31 downto 0);
    y: out unsigned(31 downto 0);
    op: in alu_op_type;
    en: in std_logic;

    ci: in std_logic;
    cen:in std_logic;
    busy: out std_logic;
    valid: out std_logic;
    co: out std_logic;
    zero: out std_logic;
    ovf:   out std_logic;
    sign: out std_logic

  );
  end component;

  component fetch is  port (
    clk:  in std_logic;
    rst:  in std_logic;

    -- Connection to ROM
    stall: in std_logic;
    valid: in std_logic;
    address: out std_logic_vector(31 downto 0);
    read: in     std_logic_vector(31 downto 0);
    enable: out std_logic;
    strobe: out std_logic;
    abort: out std_logic;
    nseq: out std_logic;

    -- Control
    freeze:   in std_logic;
    jump:     in std_logic;
    jumpaddr: in word_type;
    dual: in std_logic;

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
    jumpmsb: in std_logic;
    dual: out std_logic
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
    dui:          in decode_output_type;
    freeze:       in std_logic;
    flush:        in std_logic;
    refetch:      in std_logic;
    executed:     in boolean;

    clrhold:      in std_logic;

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
    refetch: in std_logic;
    wb_busy: in std_logic;
    int:  in std_logic;
    intline: in std_logic_vector(7 downto 0);
    nmi:  in std_logic;
    nmiack:  out std_logic;
    -- Input for previous stages
    fdui:  in fetchdata_output_type;
    -- Output for next stages
    euo:  out execute_output_type;
    -- Input from memory unit, for SPR update
    mui:  in memory_output_type;
    -- Coprocessor interface
    co:   out copifo;
    ci:   in  copifi;

    dbgo: out execute_debug_type

  );
  end component execute;

  component memory is
  port (
    clk:  in std_logic;
    rst:  in std_logic;
    -- Memory interface
    wb_ack_i:       in std_logic;
    wb_err_i:       in std_logic;
    wb_dat_i:       in std_logic_vector(31 downto 0);
    wb_dat_o:       out std_logic_vector(31 downto 0);
    wb_adr_o:       out std_logic_vector(31 downto 0);
    wb_tag_o:       out std_logic_vector(31 downto 0);
    wb_tag_i:       in std_logic_vector(31 downto 0);
    wb_cyc_o:       out std_logic;
    wb_stb_o:       out std_logic;
    wb_sel_o:       out std_logic_vector(3 downto 0);
    wb_we_o:        out std_logic;
    wb_stall_i:     in  std_logic;

    protw:          in std_logic_vector(31 downto 0);
    proten:         in std_logic;

    busy:           out std_logic;
    refetch:        out std_logic;
    dbgo:           out memory_debug_type;
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

    -- Register 0 access writeback
    r0_en:       out std_logic;
    r0_we:       out std_logic;
    r0_addr:     out regaddress_type;
    r0_write:    out word_type_std;
    -- Register 1 access writeback
    r1_en:       out std_logic;
    r1_we:       out std_logic;
    r1_addr:     out regaddress_type;
    r1_write:    out word_type_std;
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
    rb2_en:   in std_logic;
        -- RTL Debug access
    dbg_addr:         in std_logic_vector(address_bits-1 downto 0) := (others => '0');
    dbg_do:           out std_logic_vector(32-1 downto 0)

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
        -- RTL Debug access
    --dbg_addr:         in std_logic_vector(address_bits-1 downto 0) := (others => '0');
    --dbg_do:           out std_logic_vector(32-1 downto 0)

  );
  end component;


  component opdec is
  port (
    opcode_low:   in std_logic_vector(15 downto 0);
    opcode_high:   in std_logic_vector(15 downto 0);
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

  component wbmux2 is
  generic (
    select_line: integer;
    address_high: integer:=31;
    address_low: integer:=2
  );
  port (
    wb_syscon:  in wb_syscon_type;
    -- Master 
    m_wbi:       in wb_mosi_type;
    m_wbo:       out wb_miso_type;
    -- Slave signals
    s0_wbo:       out wb_mosi_type;
    s0_wbi:       in wb_miso_type;
    s1_wbo:       out wb_mosi_type;
    s1_wbi:       in wb_miso_type
  );
  end component;

  component xtc_wbmux2 is
  generic (
    select_line: integer;
    address_high: integer:=31;
    address_low: integer:=2
  );
  port (
    wb_syscon:  in wb_syscon_type;
    -- Master 
    m_wbi:       in wb_mosi_type;
    m_wbo:       out wb_miso_type;
    -- Slave signals
    s0_wbo:       out wb_mosi_type;
    s0_wbi:       in wb_miso_type;
    s1_wbo:       out wb_mosi_type;
    s1_wbi:       in wb_miso_type
  );
  end component;

  component wbarb2_1 is
  generic (
    ADDRESS_HIGH: integer := 31;
    ADDRESS_LOW: integer := 0
  );
  port (
    wb_syscon:   in wb_syscon_type;
    -- Master 0 signals
    m0_wbi:       in wb_mosi_type;
    m0_wbo:       out wb_miso_type;
    -- Master 1 signals
    m1_wbi:       in wb_mosi_type;
    m1_wbo:       out wb_miso_type;
    -- Slave signals
    s0_wbi:       in wb_miso_type;
    s0_wbo:       out wb_mosi_type
  );
  end component;

  component wb_master_p_to_slave_np is
  port (
    syscon:   in wb_syscon_type;

    -- Master signals
    mwbi:     in wb_mosi_type;
    mwbo:     out wb_miso_type;
    -- Slave signals
    swbi:     in wb_miso_type;
    swbo:     out wb_mosi_type
  );
  end component;

  component xtc_top_bram is
  port (
    wb_syscon:      in wb_syscon_type;
    -- IO wishbone interface
    iowbo:           out wb_mosi_type;
    iowbi:           in wb_miso_type
  );
  end component;

  component xtc_top_sdram is
  port (
    wb_syscon:      in wb_syscon_type;
    -- IO wishbone interface
    iowbo:           out wb_mosi_type;
    iowbi:           in wb_miso_type;
       -- DMA
    dmawbi:         in wb_mosi_type;
    dmawbo:         out wb_miso_type;
    nmi:              in std_logic;
    nmiack:           out std_logic;
    rstreq:           out std_logic;
    -- extra clocking
    clk_off_3ns: in std_logic;

    -- SDRAM signals
    DRAM_ADDR   : OUT   STD_LOGIC_VECTOR (11 downto 0);
    DRAM_BA      : OUT   STD_LOGIC_VECTOR (1 downto 0);
    DRAM_CAS_N   : OUT   STD_LOGIC;
    DRAM_CKE      : OUT   STD_LOGIC;
    DRAM_CLK      : OUT   STD_LOGIC;
    DRAM_CS_N   : OUT   STD_LOGIC;
    DRAM_DQ      : INOUT STD_LOGIC_VECTOR(15 downto 0);
    DRAM_DQM      : OUT   STD_LOGIC_VECTOR(1 downto 0);
    DRAM_RAS_N   : OUT   STD_LOGIC;
    DRAM_WE_N    : OUT   STD_LOGIC

  );
  end component;

  component regbank_5p is
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
    rb3_en:   in std_logic;
    rb3_rd:   out std_logic_vector(31 downto 0);

    rb4_addr: in std_logic_vector(ADDRESS_BITS-1 downto 0);
    rb4_en:   in std_logic;
    rb4_rd:   out std_logic_vector(31 downto 0);

    rbw_addr: in std_logic_vector(ADDRESS_BITS-1 downto 0);
    rbw_wr:   in std_logic_vector(31 downto 0);
    rbw_we:   in std_logic;
    rbw_en:   in std_logic;
        -- RTL Debug access
    dbg_addr:         in std_logic_vector(address_bits-1 downto 0) := (others => '0');
    dbg_do:           out std_logic_vector(32-1 downto 0)

  );
  end component regbank_5p;


  component regbank_4r_2w is
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
    rb3_en:   in std_logic;
    rb3_rd:   out std_logic_vector(31 downto 0);

    rb4_addr: in std_logic_vector(ADDRESS_BITS-1 downto 0);
    rb4_en:   in std_logic;
    rb4_rd:   out std_logic_vector(31 downto 0);

    rbw1_addr: in std_logic_vector(ADDRESS_BITS-1 downto 0);
    rbw1_wr:   in std_logic_vector(31 downto 0);
    rbw1_we:   in std_logic;
    rbw1_en:   in std_logic;

    rbw2_addr: in std_logic_vector(ADDRESS_BITS-1 downto 0);
    rbw2_wr:   in std_logic_vector(31 downto 0);
    rbw2_we:   in std_logic;
    rbw2_en:   in std_logic;
        -- RTL Debug access
    dbg_addr:         in std_logic_vector(address_bits-1 downto 0) := (others => '0');
    dbg_do:           out std_logic_vector(32-1 downto 0)

  );
  end component;

  component insnqueue is
  port (
    rst:      in std_logic;

    clkw:     in std_logic;
    din:      in std_logic_vector(15 downto 0);
    en:       in std_logic;
    clr:      in std_logic;
    full:     out std_logic;

    clkr:     in std_logic;
    pop:      in std_logic;
    dualpop:  in std_logic;
    dout0:    out std_logic_vector(15 downto 0);
    dout1:    out std_logic_vector(15 downto 0);
    empty:    out std_logic;
    dvalid:   out std_logic
  );
  end component;

  component xtc_ioctrl is
  port (
    syscon:     in wb_syscon_type;
    wbi:        in wb_mosi_type;
    wbo:        out wb_miso_type;
    -- Slaves
    swbi:       in slot_wbi;
    swbo:       out slot_wbo;
    sids:       in slot_ids
  );
  end component xtc_ioctrl;

  component mmu is
  generic (
    TLB_ENTRY_BITS: natural := 3;
    CONTEXT_SIZE_BITS: natural := 6;
    SIMPLIFIED: boolean := true
  );
  port (
    clk:    in std_logic;
    rst:    in std_logic;

    addr:   in std_logic_vector(31 downto 0);
    ctx:    in std_logic_vector(CONTEXT_SIZE_BITS-1 downto 0);
    en:     in std_logic;

    tlbw:   in std_logic;
    tlba:   in std_logic_vector(TLB_ENTRY_BITS-1 downto 0);
    tlbv:   in tlb_entry_type;
    
    paddr:  out std_logic_vector(31 downto 0);
    valid:  out std_logic;
    pw:     out std_logic; -- Write permission
    pr:     out std_logic; -- Read permission
    px:     out std_logic; -- eXecute permission
    ps:     out std_logic  -- Supervisor/User
  );
  end component;

  component dcache is
  generic (
      ADDRESS_HIGH: integer := 31;
      CACHE_MAX_BITS: integer := 13; -- 8 Kb
      CACHE_LINE_SIZE_BITS: integer := 6 -- 64 bytes
  );
  port (
    syscon:     in wb_syscon_type;
    ci:         in dcache_in_type;
    co:         out dcache_out_type;
    mwbi:       in wb_miso_type;
    mwbo:       out wb_mosi_type
  );
  end component;

  component generic_dp_ram_rf is
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


  component nodev is
  port (
    syscon:     in wb_syscon_type;
    wbi:        in wb_mosi_type;
    wbo:        out wb_miso_type
  );
  end component;

  component sinkdev is
  port (
    syscon:     in wb_syscon_type;
    wbi:        in wb_mosi_type;
    wbo:        out wb_miso_type
  );
  end component;


end package;
