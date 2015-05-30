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

    dbgi:    in execute_debug_type;
    mdbgi:    in memory_debug_type;

    proten: out std_logic;
    protw: out std_logic_vector(31 downto 0);
    fflags: in std_logic_vector(31 downto 0);
    ci:     in copi;
    co:     out copo
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
  constant LOGSIZE: integer := 16;
  type logbuffertype is array (0 to LOGSIZE-1) of logtype;
  shared variable logbuffer: logbuffertype;
  signal loghigh,logread: integer range 0 to LOGSIZE-1;
  signal logenabled: std_logic;
  signal rlog: logtype;

  -- memory debugging.
  subtype mlogtype is std_logic_vector(95 downto 0);
  constant MLOGSIZE: integer := 32;
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

  req<='1' when ci.en='1' else '0';

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
        mmatchen<='1';
        mmatch<=x"001640E4";
        msetup<=false;
        enablelog<='0';
        proten<='0';
        addr_q <= (others => 'X');
        wrq    <= (others => 'X');
        protw  <= (others => 'X');
        co.data<= (others => 'X');
      else
        tlbw<='0';
        ack<='0';
        msetup<=false;
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

            when "0110" =>
              if ci.wr='1' then
                if TRACER_ENABLED then
                  enablelog<= ci.data(0);
                end if;
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
              if TRACER_ENABLED then
                if ci.wr='1' then
                  logread<=to_integer(unsigned(ci.data));
                end if;
                co.data(15 downto 0) <= std_logic_vector(to_unsigned(loghigh,16));
                co.data(31 downto 16) <= std_logic_vector(to_unsigned(LOGSIZE,16));
              end if;
            when "1001" =>
              if TRACER_ENABLED then
                co.data <= rlog(127 downto 96);
              end if;
            when "1010" =>
              if TRACER_ENABLED then
                co.data <= rlog(95 downto 64);
              end if;
            when "1011" =>
              if TRACER_ENABLED then
                co.data <= rlog(63 downto 32);
              end if;
            when "1100" =>
              if TRACER_ENABLED then
                co.data <= rlog(31 downto 0);
              end if;

            when "0101" =>
              if TRACER_ENABLED then
                if ci.wr='1' then
                  mlogread<=to_integer(unsigned(ci.data));
                end if;
                co.data(15 downto 0) <= std_logic_vector(to_unsigned(mloghigh,16));
                co.data(31 downto 16) <= std_logic_vector(to_unsigned(MLOGSIZE,16));
              end if;
            when "1101" =>
              if TRACER_ENABLED then
                co.data <= mrlog(95 downto 64);
              end if;
            when "1110" =>
              if TRACER_ENABLED then
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
              end if;
            when "1111" =>
              if TRACER_ENABLED then
                co.data <= mrlog(31 downto 0);
              end if;
            when others =>
          end case;
          ack<='1';
        else
        end if;
      end if;
    end if;
  end process;

  co.valid<=ack;

  tracer: if TRACER_ENABLED generate

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
            if loghigh=LOGSIZE-1 then
              loghigh<=0;
            else
              loghigh<=loghigh+1;
            end if;
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
        mlogenabled<='1';
        mloghigh<=0;
      else
        if msetup then
          mlogenabled<='1';
        end if;
        if dbgi.trap='1' then
          mlogenabled<='0';
        end if;
        if mlogenabled='1' then
          if mdbgi.strobe='1' and (mmatchen='0' or mdbgi.address=mmatch) and mdbgi.write='1' then
            if mloghigh=MLOGSIZE-1 then
              mloghigh<=0;
            else
              mloghigh<=mloghigh+1;
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

  end generate;

end behave;
