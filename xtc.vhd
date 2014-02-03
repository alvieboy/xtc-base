library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.xtcpkg.all;
use work.xtccomppkg.all;

entity xtc is
  port (
    wb_clk_i:       in std_logic;
    wb_clk_i_2x:    in std_logic;
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
    wb_stall_i:     in  std_logic;
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
  signal cache_flush:          std_logic;
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
  signal retryfetch:          std_logic;
  signal e_busy:  std_logic;
  signal refetch_registers:   std_logic;

begin

  -- Register bank.

  rbe: regbank_4r_2w
  generic map (
    ADDRESS_BITS => 4
  )
  port map (
    clk     => wb_clk_i,
    rb1_en  => rb1_en,
    rb1_addr=> rb1_addr,
    rb1_rd  => rb1_rd,
    rb2_en  => rb2_en,
    rb2_addr=> rb2_addr,
    rb2_rd  => rb2_rd,
    rb3_en  => rb3_en,
    rb3_addr=> rb3_addr,
    rb3_rd  => rb3_rd,
    rb4_en  => rb4_en,
    rb4_addr=> rb4_addr,
    rb4_rd  => rb4_rd,

    rbw1_en  => rbw1_en,
    rbw1_we  => rbw1_we,
    rbw1_addr=> rbw1_addr,
    rbw1_wr  => rbw1_wr,
    rbw2_en  => rbw2_en,
    rbw2_we  => rbw2_we,
    rbw2_addr=> rbw2_addr,
    rbw2_wr  => rbw2_wr

  );

  cache: if INSTRUCTION_CACHE generate

--  cache: icache
--  generic map (
--    ADDRESS_HIGH => 31
--  )
--  port map (
--    wb_clk_i    => wb_clk_i,
--    wb_rst_i    => wb_rst_i,

--    valid       => cache_valid,
    --data        => cache_data,
--    address     => cache_address,
--    strobe      => cache_strobe,
--    stall       => cache_stall,
--    enable      => cache_enable,
--    flush       => cache_flush,

--    m_wb_ack_i  => rom_wb_ack_i,
--    m_wb_dat_i  => rom_wb_dat_i,
--    m_wb_adr_o  => rom_wb_adr_o,
 --   m_wb_cyc_o  => rom_wb_cyc_o,
--    m_wb_stb_o  => rom_wb_stb_o,
--    m_wb_stall_i => rom_wb_stall_i
--  );

  end generate;

  nocache: if not INSTRUCTION_CACHE generate

    -- Hack... we need to provide a solution for ACK being held low
    -- when no pipelined transaction exists

    -- For now, the romram is hacked to do it.
    nopipe: if not EXTRA_PIPELINE generate
      cache_valid       <= rom_wb_ack_i;
      cache_data        <= rom_wb_dat_i;
      rom_wb_adr_o      <= cache_address;
      rom_wb_stb_o      <= cache_strobe;
      rom_wb_cyc_o      <= cache_enable;
      cache_stall       <= rom_wb_stall_i;
    end generate;
  
    pipe: if EXTRA_PIPELINE generate
      pipeb: block
      begin
        process(wb_clk_i)
        begin
          if rising_edge(wb_clk_i) then
            if cache_nseq='1' then
              cache_valid<='0';
            else
              cache_valid <= rom_wb_ack_i;
            end if;
            if cache_strobe='1' and cache_enable='1' then
              cache_data <= rom_wb_dat_i;
            end if;
          end if;
        end process;
        --cache_valid       <= rom_wb_ack_i;
       -- cache_data        <= rom_wb_dat_i;
        rom_wb_adr_o      <= cache_address;
        rom_wb_stb_o      <= cache_strobe;
        rom_wb_cyc_o      <= cache_enable;
        cache_stall       <= rom_wb_stall_i;
      end block;

    end generate;

  end generate;



  fetch_unit: fetch
    port map (
      clk       => wb_clk_i,
      clk2x     => wb_clk_i_2x,
      rst       => wb_rst_i,
      -- Connection to ROM
      stall     => cache_stall,
      valid     => cache_valid,
      address   => cache_address,
      read      => cache_data,
      enable    => cache_enable,
      strobe    => cache_strobe,
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
      clk       => wb_clk_i,
      rst       => wb_rst_i,
      -- Input from fetch unit
      fui       => fuo,
      -- Outputs for next stages
      duo       => duo,
      busy    => decode_freeze,
      freeze  => execute_busy,
      dual    => dual,
      flush   => euo.r.jump, -- DELAY SLOT when fetchdata is passthrough
      jump    => euo.r.jump,
      jumpmsb => euo.r.jumpaddr(1)
    );

  fetchdata_unit: fetchdata
    port map (
      clk       => wb_clk_i,
      rst       => wb_rst_i,
      r1_en      => rb1_en,
      r1_addr    => rb1_addr,
      r1_read    => rb1_rd,
      r2_en      => rb2_en,
      r2_addr    => rb2_addr,
      r2_read    => rb2_rd,
      r3_en      => rb3_en,
      r3_addr    => rb3_addr,
      r3_read    => rb3_rd,
      r4_en      => rb4_en,
      r4_addr    => rb4_addr,
      r4_read    => rb4_rd,


      freeze     => execute_busy,
      flush      => euo.r.jump,-- euo.jump, -- DELAY SLOT
      refetch    => refetch_registers,--execute_busy,-- TEST TEST: was refetch,
      w_addr     => w_addr,
      w_en       => w_en,
      -- Input from decode unit
      dui       => duo,
      -- Outputs for next stages
      fduo       => fduo
    );

  busycheck: block

    constant COUNT: integer :=16;
    signal tq: std_logic_vector(COUNT-1 downto 0);
  
    signal i1,i2,i3,i4: integer range 0 to COUNT-1;
    signal s1:          integer range 0 to COUNT-1;
    signal c1:          integer range 0 to COUNT-1;
    signal v1,v2,v3,v4: std_logic;
  begin
  
    i1 <= to_integer(unsigned(rb1_addr));
    i2 <= to_integer(unsigned(rb2_addr));
    i3 <= to_integer(unsigned(rb3_addr));
    i4 <= to_integer(unsigned(rb4_addr));
  
    s1 <= to_integer(unsigned(muo.mreg));
    c1 <= to_integer(unsigned(duo.r.sra4));
  
  
    v1<='1' when rb1_en='0' else tq(i1);
    v2<='1' when rb2_en='0' else tq(i2);
    v3<='1' when rb3_en='0' else tq(i3);
    v4<='1' when rb4_en='0' else tq(i4);


    process(wb_clk_i)
    begin
    if rising_edge(wb_clk_i) then
      if wb_rst_i='1' then
        tq <= (others => '1');
      else
        if duo.r.valid='1' and ( duo.r.blocks='1' ) and execute_busy='0' and euo.r.jump='0' then
          tq(c1) <= '0';
        end if;
        --if set1_en='1' then
        --  t(s1) <= '1';
        --end if;
        if muo.mregwe='1' then
          tq(s1) <= '1';
        end if;
  
        --if clr1_en='1' then
        --  t(c1) <= '1';
        --end if;
        
      end if;

      retryfetch <= not (v1 and v2 and v3 and v4);

    end if;
  end process;

    allvalid <= v1 and v2 and v3 and v4;

  end block;


  process(e_busy,retryfetch)
  begin
    refetch_registers<='0';
    --if allvalid='1' then
      execute_busy<=e_busy;
    --else
      if e_busy='1' or retryfetch='1' then
        execute_busy<='1';
        refetch_registers<=retryfetch;
      else
        execute_busy<='0';
      end if;
   -- end if;
  end process;
  --execute_busy <= retryfetch or e_busy;-- or (not allvalid);


  execute_unit: execute
    port map (
      clk       => wb_clk_i,
      rst       => wb_rst_i,
      busy      => e_busy,
      mem_busy  => memory_busy,
      wb_busy   => wb_busy,
      refetch   => refetch,
      int       => wb_inta_i,
      intline   => x"00",
      -- Input from fetchdata unit
      fdui      => fduo,
      -- Outputs for next stages
      euo       => euo,
      -- Input from memory unit (spr update)
      mui       => muo
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
    wb_stall_i      => wb_stall_i,

    refetch         => refetch,
    busy            => memory_busy,
    -- Input for previous stages
    eui             => euo,
    -- Output for next stages
    muo             => muo
    );

  writeback_unit: writeback
    port map (
      clk       => wb_clk_i,
      rst       => wb_rst_i,
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


  cache_flush<='0';
end behave;

