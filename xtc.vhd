library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.xtcpkg.all;
use work.xtccomppkg.all;
use work.wishbonepkg.all;

entity xtc is
  port (
    wb_syscon:      in wb_syscon_type;

    -- Master wishbone interface
    wbo:            out wb_mosi_type;
    wbi:            in  wb_miso_type;
    -- ROM wb interface
    romwbo:         out wb_mosi_type;
    romwbi:         in  wb_miso_type;

    isnmi:          in std_logic;
    break:          out std_logic;
    intack:         out std_logic
  );
end xtc;

architecture behave of xtc is

  signal fuo:  fetch_output_type;
  signal duo:  decode_output_type;
  signal fduo: fetchdata_output_type;
  signal euo:  execute_output_type;
  signal muo:  memory_output_type;

  signal rbw1_addr: regaddress_type;
  signal rbw1_wr:   std_logic_vector(31 downto 0);
  signal rbw1_we:   std_logic;
  signal rbw1_en:   std_logic;

  signal rbw2_addr: regaddress_type;
  signal rbw2_wr:   std_logic_vector(31 downto 0);
  signal rbw2_we:   std_logic := '0';
  signal rbw2_en:   std_logic := '0';

  signal rb1_addr: regaddress_type;
  signal rb1_en:   std_logic;
  signal rb1_rd:   std_logic_vector(31 downto 0);
  signal rb2_addr: regaddress_type;
  signal rb2_en:   std_logic;
  signal rb2_rd:   std_logic_vector(31 downto 0);
  signal rb3_addr: regaddress_type;
  signal rb3_en:   std_logic;
  signal rb3_rd:   std_logic_vector(31 downto 0);
  signal rb4_addr: regaddress_type;
  signal rb4_en:   std_logic;
  signal rb4_rd:   std_logic_vector(31 downto 0);

  signal jumpaddr:   word_type;
  signal cache_valid:          std_logic;
  signal dcache_flush:          std_logic;
  signal dcache_inflush:          std_logic;
  signal icache_flush:          std_logic;
  signal icache_abort:          std_logic;
  signal cache_data:           std_logic_vector(31 downto 0);
  signal cache_address:        std_logic_vector(31 downto 0);
  signal cache_strobe:         std_logic;
  signal cache_enable:         std_logic;
  signal cache_stall:          std_logic;
  signal cache_nseq:           std_logic;
  
  signal decode_freeze:       std_logic;

  signal w_en:                std_logic;
  signal w_addr:              regaddress_type;

  signal memory_busy:         std_logic;
  signal execute_busy:        std_logic;
  signal wb_busy:             std_logic;

  signal refetch:             std_logic;
  signal dual:                std_logic;

  signal allvalid:            std_logic;
  signal notallvalid:         std_logic;
  signal retryfetch:          std_logic;
  signal e_busy:  std_logic;
  signal refetch_registers:   std_logic;
  signal freeze_decoder:      std_logic;
  signal executed:            boolean;

  component tracer is
  port (
    clk:              in std_logic;
    dbgi:             in execute_debug_type
  );
  end component tracer;

  signal dbg:   execute_debug_type;
  signal co: copo;
  signal ci: copi;

  signal mwbi:  wb_miso_type;
  signal mwbo:  wb_mosi_type;


  signal immu_tlbw: std_logic:='0';
  signal immu_tlbv: tlb_entry_type;
  signal immu_tlba: std_logic_vector(3 downto 0):="0000";

  signal immu_context: std_logic_vector(5 downto 0):=(others => '0');
  signal immu_paddr: std_logic_vector(31 downto 0);
  signal immu_valid: std_logic;
  signal immu_enabled: std_logic:='1';

  signal cache_tag: std_logic_vector(31 downto 0);
  signal dcache_accesstype: std_logic_vector(1 downto 0);

begin

  -- synthesis translate_off
  trc: tracer
    port map (
      clk => wb_syscon.clk,
      dbgi  => dbg
    );
  -- synthesis translate_on

  -- Register bank.

  rbe: regbank_3p
  generic map (
    ADDRESS_BITS => 4
  )
  port map (
    clk     => wb_syscon.clk,
    rb1_en  => rb1_en,
    rb1_addr=> rb1_addr,
    rb1_rd  => rb1_rd,
    rb2_en  => rb2_en,
    rb2_addr=> rb2_addr,
    rb2_rd  => rb2_rd,

    rb3_en  => rbw1_en,
    rb3_we  => rbw1_we,
    rb3_addr=> rbw1_addr,
    rb3_wr  => rbw1_wr
    --dbg_addr => "0000"
  );

  cache: if INSTRUCTION_CACHE generate

  cache: icache
  generic map (
    ADDRESS_HIGH => 31
  )
  port map (
    wb_clk_i    => wb_syscon.clk,
    wb_rst_i    => wb_syscon.rst,

    valid       => cache_valid,
    data        => cache_data,
    address     => cache_address,
    strobe      => cache_strobe,
    stall       => cache_stall,
    enable      => cache_enable,
    flush       => icache_flush,
    abort       => icache_abort,
    tag         => cache_tag,
    tagen       => immu_enabled,

    m_wb_ack_i  => romwbi.ack,
    m_wb_dat_i  => romwbi.dat,
    m_wb_adr_o  => romwbo.adr,
    m_wb_cyc_o  => romwbo.cyc,
    m_wb_stb_o  => romwbo.stb,
    m_wb_stall_i => romwbi.stall
  );

    mmub: if MMU_ENABLED generate
    cache_tag <= immu_paddr;
    immuinst: mmu
      port map (
        clk   => wb_syscon.clk,
        rst   => wb_syscon.rst,

        addr  => cache_address,
        ctx   => immu_context,
        en    => cache_strobe,

        tlbw  => immu_tlbw,
        tlba  => immu_tlba,
        tlbv  => immu_tlbv,
    
        paddr => immu_paddr,
        valid => immu_valid,
        pw    => open,
        pr    => open,
        px    => open,
        ps    => open
     );
   end generate;





  end generate;

  romwbo.we<='0';

  nocache: if not INSTRUCTION_CACHE generate

    -- Hack... we need to provide a solution for ACK being held low
    -- when no pipelined transaction exists

    -- For now, the romram is hacked to do it.
    --nopipe: if not EXTRA_PIPELINE generate
      cache_valid       <= romwbi.ack;
      cache_data        <= romwbi.dat;
      romwbo.adr      <= cache_address;
      romwbo.stb      <= cache_strobe;
      romwbo.cyc      <= cache_enable;
      cache_stall       <= romwbi.stall;
    --end generate;
  
    
  end generate;



  fetch_unit: fetch
    port map (
      clk       => wb_syscon.clk,
      rst       => wb_syscon.rst,
      -- Connection to ROM
      stall     => cache_stall,
      valid     => cache_valid,
      address   => cache_address,
      read      => cache_data,
      enable    => cache_enable,
      strobe    => cache_strobe,
      abort     => icache_abort,
      nseq      => cache_nseq,

      freeze    => decode_freeze,
      jump      => euo.r.jump,
      jumpaddr  => euo.r.jumpaddr,
      dual      => dual,

      -- Outputs for next stages
      fuo       => fuo
    );

  decode_unit: decode
    port map (
      clk       => wb_syscon.clk,
      rst       => wb_syscon.rst,
      -- Input from fetch unit
      fui       => fuo,
      -- Outputs for next stages
      duo       => duo,
      busy    => decode_freeze,
      freeze  => freeze_decoder,
      dual    => dual,
      flush   => euo.r.jump, -- DELAY SLOT when fetchdata is passthrough
      jump    => euo.r.jump,
      jumpmsb => euo.r.jumpaddr(1)
    );

  freeze_decoder <= execute_busy or notallvalid;

  fetchdata_unit: fetchdata
    port map (
      clk       => wb_syscon.clk,
      rst       => wb_syscon.rst,
      r1_en      => rb1_en,
      r1_addr    => rb1_addr,
      r1_read    => rb1_rd,
      r2_en      => rb2_en,
      r2_addr    => rb2_addr,
      r2_read    => rb2_rd,


      freeze     => execute_busy,
      flush      => euo.r.jump,-- euo.jump, -- DELAY SLOT
      refetch    => notallvalid, --refetch_registers,--execute_busy,-- TEST TEST: was refetch,
      w_addr     => w_addr,
      w_en       => w_en,
      executed  => executed,
      -- Input from decode unit
      dui       => duo,
      -- Outputs for next stages
      fduo       => fduo
    );

  busycheck: block

    constant COUNT: integer :=16;
    signal tq: std_logic_vector(COUNT-1 downto 0);
  
    signal i1,i2:       integer range 0 to COUNT-1;
    signal s1:          integer range 0 to COUNT-1;
    signal c1:          integer range 0 to COUNT-1;
    signal v1,v2,v3:    std_logic;
  begin
  
    i1 <= to_integer(unsigned(rb1_addr));
    i2 <= to_integer(unsigned(rb2_addr));
  
    s1 <= to_integer(unsigned(muo.mreg));
    c1 <= to_integer(unsigned(duo.r.sra2));
  
  
    v1<='1' when rb1_en='0' else tq(i1);
    v2<='1' when rb2_en='0' else tq(i2);
    v3<='1';-- when w_en='0' else tq(s1);


    process(wb_syscon.clk)
    begin
    if rising_edge(wb_syscon.clk) then
      if wb_syscon.rst='1' then
        tq <= (others => '1');
      else
        if duo.r.valid='1' and ( duo.r.blocks='1' ) and execute_busy='0' and euo.r.jump='0' and allvalid='1' then
          tq(c1) <= '0';
        end if;
        -- Memory reads clear flags.
        if muo.mregwe='1' then
          tq(s1) <= '1';
        end if;
      end if;

      retryfetch <= not (v1 and v2);

    end if;
  end process;

    allvalid <= v1 and v2;-- and v3;
    notallvalid <= not allvalid;

  end block;


  process(e_busy,retryfetch)
  begin
    ----refetch_registers<='0';
    --if allvalid='1' then
      execute_busy<=e_busy;
    --else
      --if e_busy='1' or retryfetch='1' then
      --  execute_busy<='1';
      --  refetch_registers<=retryfetch;
      --else
      --  execute_busy<='0';
      --end if;
   -- end if;
  end process;
  --execute_busy <= retryfetch or e_busy;-- or (not allvalid);
  executed <= euo.executed;

  execute_unit: execute
    port map (
      clk       => wb_syscon.clk,
      rst       => wb_syscon.rst,
      busy      => e_busy,
      mem_busy  => memory_busy,
      wb_busy   => wb_busy,
      refetch   => refetch,
      int       => '0',--wb_inta_i,
      intline   => x"00",
      -- Input from fetchdata unit
      fdui      => fduo,
      -- Outputs for next stages
      euo       => euo,
      -- Input from memory unit (spr update)
      mui       => muo,
      -- COP
      co        => co,
      ci        => ci,
      -- Debug
      dbgo      => dbg
    );


  -- Dummy MMU cop
  mmucop: block
     component cop_mmu is
     port (
       clk:    in std_logic;
       rst:    in std_logic;
   
       tlbw:   out std_logic;
       tlba:   out std_logic_vector(3 downto 0);
       tlbv:   out tlb_entry_type;
       mmuen: out std_logic;
       icache_flush: out std_logic;
       dcache_flush: out std_logic;
       dcache_inflush: in std_logic;
       ci:     in copo;
       co:     out copi
     );
     end component;

  begin

    copmmuinst: cop_mmu
      port map (
        clk   => wb_syscon.clk,
        rst   => wb_syscon.rst,
    
        tlbw  => immu_tlbw,
        tlba  => immu_tlba,
        tlbv  => immu_tlbv,
        mmuen => immu_enabled,
        icache_flush => icache_flush,
        dcache_flush => dcache_flush,
        dcache_inflush => dcache_inflush,
        ci    => co,
        co    => ci
    );


  end block;

  dcachegen: if DATA_CACHE generate
     dcache_accesstype <= ACCESS_NOCACHE when mwbo.adr(31)='1' else
      ACCESS_WT;

     dcacheinst: dcache
       generic map (
           ADDRESS_HIGH => 31,
           CACHE_MAX_BITS =>  13, -- 8 Kb
           CACHE_LINE_SIZE_BITS => 6 -- 64 bytes
       )
       port map (
         syscon     => wb_syscon,
         ci.data    => mwbo.dat,
         ci.address => mwbo.adr,
         ci.strobe  => mwbo.stb,
         ci.we      => mwbo.we,
         ci.wmask   => mwbo.sel,
         ci.enable  => mwbo.cyc,
         ci.tag     => mwbo.tag,
         ci.flush   => dcache_flush,
         ci.accesstype => dcache_accesstype,
         co.in_flush   => dcache_inflush,
         co.data     => mwbi.dat,
         co.stall    => mwbi.stall,
         co.valid    => mwbi.ack,
         co.tag      => mwbi.tag,
         mwbi   => wbi,
         mwbo   => wbo
       );
  end generate;

  nodcache: if not DATA_CACHE generate

    wbo<=mwbo;
    mwbi<=wbi;

  end generate;


  memory_unit: memory
    port map (
    clk             => wb_syscon.clk,
    rst             => wb_syscon.rst,
    -- Memory interface
    wb_ack_i        => mwbi.ack,
    wb_dat_i        => mwbi.dat,
    wb_dat_o        => mwbo.dat,
    wb_adr_o        => mwbo.adr,
    wb_cyc_o        => mwbo.cyc,
    wb_stb_o        => mwbo.stb,
    wb_sel_o        => mwbo.sel,
    wb_tag_o        => mwbo.tag,
    wb_tag_i        => mwbi.tag,
    wb_we_o         => mwbo.we,
    wb_stall_i      => mwbi.stall,

    refetch         => refetch,
    busy            => memory_busy,
    -- Input for previous stages
    eui             => euo,
    -- Output for next stages
    muo             => muo
    );

  writeback_unit: writeback
    port map (
      clk       => wb_syscon.clk,
      rst       => wb_syscon.rst,
      busy      => wb_busy,
      r0_en      => rbw1_en,
      r0_we      => rbw1_we,
      r0_addr    => rbw1_addr,
      r0_write   => rbw1_wr,
      r1_en      => rbw2_en,
      r1_we      => rbw2_we,
      r1_addr    => rbw2_addr,
      r1_write   => rbw2_wr,
      --r_read    => rbw_rd,
      -- Input from previous stage
      mui       => muo,
      eui       => euo -- for fast register write
    );


end behave;

