library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.xtcpkg.all;


entity cop_mmu is
  port (
    clk:    in std_logic;
    rst:    in std_logic;

    tlbw:   out std_logic;
    tlba:   out std_logic_vector(2 downto 0);
    tlbv:   out tlb_entry_type;

    mmuen:  out std_logic;
    icache_flush: out std_logic;
    dcache_flush: out std_logic;
    dcache_inflush: in std_logic;

    dbgi:    in execute_debug_type;
    mdbgi:    in memory_debug_type;


    proten: out std_logic;
    protw: out std_logic_vector(31 downto 0);
    fflags: in std_logic_vector(31 downto 0);
    ci:     in copo;
    co:     out copi
  );
end entity cop_mmu;


architecture behave of cop_mmu is

  signal addr_q: unsigned(2 downto 0);
  signal req: std_logic;

  signal wrq: std_logic_vector(31 downto 0);

  signal ack: std_logic;


  -- TODO: move this to other place
  --type logtype is record
  --  pc: word_type;
  --  lhs: word_type;
  --  rhs: word_type;
  --  opc: word_type;
  --end record;

  subtype logtype is std_logic_vector(127 downto 0);
  constant LOGSIZE: integer := 1;
  type logbuffertype is array (0 to LOGSIZE-1) of logtype;
  shared variable logbuffer: logbuffertype;
  signal loghigh,logread: integer range 0 to LOGSIZE-1;
  signal logenabled: std_logic;
  signal rlog: logtype;

  -- memory debugging.
  subtype mlogtype is std_logic_vector(95 downto 0);
  constant MLOGSIZE: integer := 1;
  type mlogbuffertype is array (0 to MLOGSIZE-1) of mlogtype;
  shared variable mlogbuffer: mlogbuffertype;
  signal mloghigh,mlogread: integer range 0 to MLOGSIZE-1;
  signal mlogenabled: std_logic;
  signal mrlog: mlogtype;

  signal mmatch: word_type;
  signal mmatchen: std_logic;
  signal msetup: boolean;
  signal enablelog: std_logic;

begin

  tlba<=std_logic_vector(addr_q);

  req<='1' when ci.id="00" and ci.en='1' else '0';

  process(clk)
  begin
    if rising_edge(clk) then
      co.fault<='0';
      if ci.en='1' and ci.id/="00" then
        co.fault<='1';
      end if;
    end if;
  end process;

  tlbv.pagesize <= wrq(31 downto 30);
  tlbv.ctx      <= wrq(24 downto 24);
  tlbv.flags    <= wrq(23 downto 20);
  tlbv.paddr    <= wrq(19 downto 0);
  tlbv.vaddr    <= ci.data(19 downto 0);

  process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        mmuen<='0';
        tlbw<='0';
        ack<='0';
        icache_flush<='0';
        dcache_flush<='0';
        mmatchen<='0';
        msetup<=false;
        enablelog<='0';
        proten<='0';
      else
        tlbw<='0';
        ack<='0';
        msetup<=false;
        icache_flush<='0';
        dcache_flush<='0';
        if req='1' and ack='0' then
          co.data<=(others => '0');
          case ci.reg is
            when "0000" =>
              if ci.wr='1' then
                addr_q <= unsigned(ci.data(2 downto 0));
              end if;
            when "0001" =>
              if ci.wr='1' then
                wrq <= ci.data;
              end if;
            when "0010" =>
              if ci.wr='1' then
                tlbw<='1';
              end if;
            when "0011" =>
              if ci.wr='1' and MMU_ENABLED then
                mmuen<=ci.data(0);
              end if;
            when "0100" =>
              if ci.wr='1' then
                icache_flush<=ci.data(0);
                dcache_flush<=ci.data(1);
              end if;
              co.data(1) <= dcache_inflush;
              if MMU_ENABLED then
                co.data(0) <= '1';
              end if;

            when "0110" =>
              if ci.wr='1' then
                enablelog<= ci.data(0);
                proten<=ci.data(1);
              end if;
              co.data <= std_logic_vector(fflags);

            when "0111" =>
              if ci.wr='1' then
                protw<=ci.data;
              end if;
              co.data <= std_logic_vector(mdbgi.faddr);

            -- TODO: move this to another COP
            when "1000" =>
              if ci.wr='1' then
                logread<=to_integer(unsigned(ci.data));
              end if;
              co.data(15 downto 0) <= std_logic_vector(to_unsigned(loghigh,16));
              co.data(31 downto 16) <= std_logic_vector(to_unsigned(LOGSIZE,16));
            when "1001" =>
              co.data <= rlog(127 downto 96);
            when "1010" =>
              co.data <= rlog(95 downto 64);
            when "1011" =>
              co.data <= rlog(63 downto 32);
            when "1100" =>
              co.data <= rlog(31 downto 0);


            when "0101" =>
              if ci.wr='1' then
                mlogread<=to_integer(unsigned(ci.data));
              end if;
              co.data(15 downto 0) <= std_logic_vector(to_unsigned(mloghigh,16));
              co.data(31 downto 16) <= std_logic_vector(to_unsigned(MLOGSIZE,16));
            when "1101" =>
              co.data <= mrlog(95 downto 64);
            when "1110" =>
              if ci.wr='1' then
                msetup<=true;
                mmatch<=unsigned(ci.data);
                if (ci.data/=x"FFFFFFFF") then
                  mmatchen<='1';
                else
                  mmatchen<='0';
                end if;
              end if;
              co.data <= mrlog(63 downto 32);
            when "1111" =>
              co.data <= mrlog(31 downto 0);

            when others =>
          end case;
          ack<='1';
        else
        end if;
      end if;
    end if;
  end process;

  co.valid<=ack;

  --logenabled <= '1';--dbgi.dbgen;
  --mlogenabled <= '1';--dbgi.dbgen;

  -- TODO: trace
  process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        logenabled<='0';
        --loghigh<=0;
      else
        if dbgi.trap='1' then
          logenabled<='0';
        end if;
        if logenabled='1' then
          if dbgi.valid and dbgi.executed then
            loghigh<=loghigh+1;
            -- synthesis translate_off
            if loghigh=LOGSIZE-1 then
              loghigh<=0;
            end if;
            -- synthesis translate_on
            logbuffer(loghigh) := std_logic_vector(dbgi.pc) &
              std_logic_vector(dbgi.lhs) &
              std_logic_vector(dbgi.rhs) &
              std_logic_vector(dbgi.opcode1) &
              std_logic_vector(dbgi.opcode2);
          end if;
        end if;
        if enablelog='1' then
          logenabled<='1';
        end if;
        rlog <=  logbuffer(logread);

      end if;

    end if;
  end process;



  -- TODO: trace
  process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        mlogenabled<='0';
        mloghigh<=0;
      else
        if msetup then
          mlogenabled<='1';
        end if;
        if dbgi.trap='1' then
          mlogenabled<='0';
        end if;
        if mlogenabled='1' then
          if mdbgi.strobe='1' and (mmatchen='0' or mdbgi.data=mmatch) and mdbgi.write='1' then
            mloghigh<=mloghigh+1;
            -- synthesis translate_off
            if mloghigh=MLOGSIZE-1 then
              mloghigh<=0;
            end if;
            -- synthesis translate_on
            mlogbuffer(mloghigh) :=
              std_logic_vector(mdbgi.pc(31 downto 1)) &
              mdbgi.write &
              std_logic_vector(mdbgi.address) &
              std_logic_vector(mdbgi.data);

          end if;
        end if;

        mrlog <=  mlogbuffer(mlogread);

      end if;

    end if;
  end process;


end behave;
