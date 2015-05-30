library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.xtcpkg.all;
use work.xtccomppkg.all;
use work.wishbonepkg.all;
-- synthesis translate_off
use work.txt_util.all;
-- synthesis translate_on

entity xtc is
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
    break:          out std_logic;
    intack:         out std_logic;
    rstreq:         out std_logic;

    edbg:           in memory_debug_type
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
  signal cache_seq:            std_logic;
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
  signal e_busy:  std_logic;
  --signal refetch_registers:   std_logic;
  signal freeze_decoder:      std_logic;
  signal executed:            boolean;

  component tracer is
  port (
    clk:              in std_logic;
    dbgi:             in execute_debug_type
  );
  end component tracer;

  signal dbg:   execute_debug_type;
  signal mdbg:  memory_debug_type;
  signal cifo:    copifo;
  signal cifi:    copifi;

  signal co:    copo_a;
  signal ci:    copi_a;

  signal mwbi:  wb_miso_type;
  signal mwbo:  wb_mosi_type;

  signal immu_tlbw: std_logic:='0';
  signal immu_tlbv: tlb_entry_type;
  signal immu_tlba: std_logic_vector(2 downto 0):="000";
  signal immu_context: std_logic_vector(5 downto 0):=(others => '0');
  signal immu_paddr: std_logic_vector(31 downto 0);
  signal immu_valid: std_logic;
  signal immu_enabled: std_logic:='1';

  signal cache_tag: std_logic_vector(31 downto 0);
  signal dcache_accesstype: std_logic_vector(1 downto 0);
  signal flushfd: std_logic;
  signal clrhold: std_logic;

  signal internalfault: std_logic;
  signal pipeline_internalfault: std_logic;
  signal busycnt: unsigned (31 downto 0);

  signal proten:  std_logic;
  signal protw:   std_logic_vector(31 downto 0);
  signal rstreq_i: std_logic;
  signal fflags:  std_logic_vector(31 downto 0);
  signal intin:   std_logic_vector(31 downto 0);

  signal trappc:    std_logic_vector(31 downto 0);
  signal trapaddr:  std_logic_vector(31 downto 0);
  signal trapbase:  std_logic_vector(31 downto 0);
  signal istrap:    std_logic;

begin

    process(wb_syscon.clk)
  begin
    if rising_edge(wb_syscon.clk) then
      if pipeline_internalfault='1' then
        fflags(0) <= execute_busy;
        fflags(1) <= notallvalid;
        fflags(2) <= freeze_decoder;
        fflags(3) <= wb_busy;
        fflags(4) <= memory_busy;
        fflags(5) <= dbg.hold;
        fflags(6) <= dbg.multvalid;
        fflags(7) <= dbg.trap;
      end if;
    end if;
  end process;

  rstreq_i<= pipeline_internalfault ;
  rstreq <= rstreq_i;

  -- synthesis translate_off
  trc: tracer
    port map (
      clk => wb_syscon.clk,
      dbgi  => dbg
    );
  -- synthesis translate_on

  -- Register bank.

  rbe: entity work.regbank_3p
  generic map (
    ADDRESS_BITS => 5,
    ZEROSIZE => 4
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
  );

  cache: if INSTRUCTION_CACHE generate

  cache: entity work.icache
  generic map (
    ADDRESS_HIGH => 31
  )
  port map (
    syscon      => wb_syscon,

    valid       => cache_valid,
    data        => cache_data,
    address     => cache_address,
    strobe      => cache_strobe,
    stall       => cache_stall,
    enable      => cache_enable,
    flush       => icache_flush,
    abort       => icache_abort,
    seq         => cache_seq,
    tag         => cache_tag,
    tagen       => immu_enabled,
    mwbi        => romwbi,
    mwbo        => romwbo
  );

    mmub: if MMU_ENABLED generate
    cache_tag <= immu_paddr;
    immuinst: entity work.mmu
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

  --romwbo.we<='0';

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



  fetch_unit: entity work.fetch
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
      seq       => cache_seq,
      nseq      => cache_nseq,

      freeze    => decode_freeze,
      jump      => euo.jump,
      jumppriv  => euo.jumppriv,
      jumpaddr  => euo.r.jumpaddr,
      dual      => dual,

      -- Outputs for next stages
      fuo       => fuo
    );

  decode_unit: entity work.decode
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
      flush   => euo.jump, -- DELAY SLOT when fetchdata is passthrough
      jump    => euo.jump,
      jumpmsb => euo.r.jumpaddr(1)
    );

  freeze_decoder <= execute_busy or notallvalid;
  flushfd <= euo.jump or euo.trap;

  fetchdata_unit: entity work.fetchdata
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
      flush      => flushfd,-- euo.jump, -- DELAY SLOT
      refetch    => notallvalid, --refetch_registers,--execute_busy,-- TEST TEST: was refetch,
      w_addr     => w_addr,
      w_en       => w_en,
      executed  => executed,
      clrhold   => euo.clrhold,
      -- Input from decode unit
      dui       => duo,
      -- Outputs for next stages
      fduo       => fduo
    );

  busycheck: block

    signal dirtyReg:    regaddress_type;
    signal dirty:       std_logic;
    signal v1,v2,v3:    std_logic;
    signal isBlocking:  std_logic;
    signal canProceed:  std_logic;
  begin

    v1 <= '0' when dirty='1' and rb1_en='1' and rb1_addr=dirtyReg else '1';
    v2 <= '0' when dirty='1' and rb2_en='1' and rb2_addr=dirtyReg else '1';
    v3 <= '0' when dirty='1' and w_en='1' and w_addr=dirtyReg else '1';

    isBlocking <= '1' when duo.r.valid='1' and ( duo.r.blocks='1' )
              and execute_busy='0' and euo.jump='0'
              and allvalid='1' and euo.trap='0'
        else '0';

    process(wb_syscon.clk)
    begin
    if rising_edge(wb_syscon.clk) then
      if wb_syscon.rst='1' then
        dirty <= '0';
        dirtyReg <= (others => '0'); -- X
      else
        if isBlocking='1' and dirty='0' then -- and duo.r.sra2/="0000"
          dirty <= '1';
          dirtyReg <= duo.r.sra2;
        end if;
        -- Memory reads clear flags.
        if muo.mregwe='1' and dirty='1' then
          -- TODO here: why not use only the memory wb, rather than all wb ?
          if (dirtyReg=muo.mreg) then
            dirty <= '0';
            dirtyReg <= (others => 'X');
          --if (dirtyReg /= muo.mreg) then
          --  report "Omg.. clearing reg " &hstr(muo.mreg) & ", but dirty register is "&hstr(dirtyReg) severity failure;
          end if;
        end if;

        if muo.fault='1' then
          dirty <= '0';
        end if;
        
      end if;

    end if;
  end process;

    canProceed <= '0' when (dirty='1' and duo.r.valid='1' and duo.r.blocks='1') else '1';
    allvalid <= v1 and v2 and v3 and canProceed;

    notallvalid <= not allvalid;

  end block;

  execute_busy <= e_busy;
  executed <= euo.executed;

  execute_unit: entity work.execute
    port map (
      clk       => wb_syscon.clk,
      rst       => wb_syscon.rst,
      busy      => e_busy,
      mem_busy  => memory_busy,
      wb_busy   => wb_busy,
      refetch   => refetch,
      int       => wbi.int,
      nmi       => nmi,
      nmiack    => nmiack,
      intline   => x"00",
      -- Input from fetchdata unit
      fdui      => fduo,
      -- Outputs for next stages
      euo       => euo,
      -- Input from memory unit (spr update)
      mui       => muo,
      -- COP
      co        => cifo,
      ci        => cifi,
      -- Trap
      trappc    => trappc,
      istrap    => istrap,
      trapbase  => trapbase,
      -- Debug
      dbgo      => dbg
    );


  --  MMU cop
  copmmuinst: entity work.cop_mmu
    port map (
      clk   => wb_syscon.clk,
      rst   => wb_syscon.rst,

      tlbw  => immu_tlbw,
      tlba  => immu_tlba,
      tlbv  => immu_tlbv,
      mmuen => immu_enabled,
      proten => proten,
      protw  => protw,
      dbgi  => dbg,
      mdbgi  => mdbg,--edbg,
      fflags => fflags,
      ci    => ci(1),
      co    => co(1)
  );

  coparbinst: entity work.cop_arb
    port map (
      clk   => wb_syscon.clk,
      rst   => wb_syscon.rst,
      cfi   => cifo,
      cfo   => cifi,
      ci    => co,
      co    => ci
    );

  --  MMU cop
  copsysinst: entity work.cop_sys
    port map (
      clk   => wb_syscon.clk,
      rst   => wb_syscon.rst,
      icache_flush    => icache_flush,
      dcache_flush    => dcache_flush,
      dcache_inflush  => dcache_inflush,
      int_in => x"00000000",

      trappc    => trappc,
      trapaddr  => trapaddr,
      istrap    => istrap,
      trapbase  => trapbase,

      --intacken => '0',
      ci    => ci(0),
      co    => co(0)
  );



  dcachegen: if DATA_CACHE generate
     dcache_accesstype <= ACCESS_NOCACHE when mwbo.adr(31)='1' else
      ACCESS_WB_WA;

     dcacheinst: entity work.dcache
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
         co.err      => mwbi.err,
         mwbi   => wbi,
         mwbo   => wbo
       );
  end generate;

  nodcache: if not DATA_CACHE generate

    wbo<=mwbo;
    mwbi<=wbi;

  end generate;


  memory_unit: entity work.memory
    port map (
    clk             => wb_syscon.clk,
    rst             => wb_syscon.rst,
    -- Memory interface
    wb_ack_i        => mwbi.ack,
    wb_err_i        => mwbi.err,
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
    dbgo            => mdbg,
    refetch         => refetch,
    busy            => memory_busy,
    proten          => proten,
    protw           => protw,
    -- Input for previous stages
    eui             => euo,
    -- Output for next stages
    muo             => muo
    );

  writeback_unit: entity work.writeback
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

  faultcheck: if FAULTCHECKS generate

    -- Internal pipeline fault...
    process(wb_syscon.clk)
    begin
      if rising_edge(wb_syscon.clk) then
        if wb_syscon.rst='1' then
          busycnt<=(others =>'0');
        else
          if execute_busy='1' or notallvalid='1' or freeze_decoder='1' then
            busycnt<=busycnt+1;
          else
            busycnt<=(others =>'0');
          end if;
  
        end if;
      end if;
    end process;
  
    pipeline_internalfault<='1' when busycnt > 65535 else '0';
  end generate;

  nofaultchecks: if not FAULTCHECKS generate
    pipeline_internalfault<='0';
  end generate;

  -- synthesis translate_off
  process
  begin
    wait on muo.internalfault;
    if muo.internalfault'event and muo.internalfault='1' then
      wait until rising_edge(wb_syscon.clk);
      wait until rising_edge(wb_syscon.clk);
      report "Internal memory fault" severity failure;
    end if;
  end process;
  -- synthesis translate_on

end behave;

