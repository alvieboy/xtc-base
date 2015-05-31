library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.xtcpkg.all;

entity fetch is
  port (
    clk:   in std_logic;
    rst:   in std_logic;

    -- Connection to ROM
    stall:    in std_logic;
    valid:    in std_logic;
    address:  out std_logic_vector(31 downto 0);
    read:     in std_logic_vector(31 downto 0);
    enable:   out std_logic;
    strobe:   out std_logic;
    seq:      out std_logic;
    abort:    out std_logic;
    nseq:     out std_logic;
    -- Control
    freeze:    in std_logic;
    jump:     in std_logic;
    jumppriv: in std_logic;
    jumpaddr: in word_type;
    dual:     in std_logic;

    -- Outputs for next stages
    fuo:  out fetch_output_type
  );
end entity fetch;

architecture behave of fetch is

  signal fr: fetch_regs_type;

  signal opcode0, opcode1: std_logic_vector(15 downto 0);

  signal strobe_i: std_logic;

  -- debug only
  signal busycnt: unsigned(31 downto 0);

begin

  fault1: if FAULTCHECKS generate

    process(clk)
    begin
      if rising_edge(clk) then
        if rst='1' then
          busycnt<=(others =>'0');
        else
          if strobe_i='1' and stall='1' then
            busycnt<=busycnt+1;
          else
            busycnt<=(others =>'0');
          end if;
  
        end if;
      end if;
    end process;
  
    fuo.internalfault<='1' when busycnt > 65535 else '0';

  end generate;

  strobe<=strobe_i;

  fuo.r <= fr;

  fuo.opcode <= opcode0 & opcode1;

  address <= std_logic_vector(fr.fpc);

  nseq <= '1' when fr.state=jumping else '0';
  seq <= fr.seq;

  process(fr, rst, clk, stall, valid, freeze, dual, jump, jumpaddr,read)
    variable fw: fetch_regs_type;
    variable npc: word_type;
    variable realnpc: word_type;
  begin
    fw := fr;
    npc := fr.fpc + 4;
    if dual='1' then
      realnpc := fr.pc + 4;
    else
      realnpc := fr.pc + 2;
    end if;

    fuo.npc <= realnpc;
    fuo.valid <= valid;

    abort <= '0';

    enable <= not freeze;
    --strobe_i <= not freeze;
    strobe_i<='1';
    if fr.unaligned_jump='1' and read(15)='1' then -- Extended opcode.
      fuo.valid <= '0';
    end if;

    opcode0 <= read(31 downto 16);

    if fr.invert_readout='1' then
      opcode1 <= fr.qopc;
    else
      opcode1 <= read(15 downto 0);
    end if;

    fuo.inverted <= fr.unaligned;

    case fr.state is
      when running =>
        if jump='0' then
          if stall='0' and freeze='0' then
            fw.fpc := npc;
          end if;
      
          if valid='1' then
            if freeze='0' then
              if not (fr.unaligned_jump='1' and dual='1') then
                fw.pc := realnpc;
                fw.seq := '1';
              end if;
              fw.qopc := read(15 downto 0);
              fw.unaligned_jump := '0';
            end if;

            -- simple check
            --if dual='1' and fr.unaligned_jump='1' then
            --  report "DUAL" severity note;
            --end if;
          end if;

          if dual='0' and valid='1' and freeze='0' then
            -- Will go unaligned
            if fr.unaligned='0' then
              fw.unaligned := '1';
              fw.invert_readout:='1';
              --enable <= '0';
              --strobe_i <= '0';
            else
              if fr.invert_readout='1' then
                strobe_i<='0';
                if fr.unaligned_jump='1' then
                  --strobe_i<='1';
                end if;
                fw.fpc := fr.fpc;
              else
                strobe_i <='1';
              end if;
              
              -- If we had an unaligned jump, we have to trick
              -- the system into outputting directly from the RAM, since this
              -- is the value usually queued.
              fw.unaligned := '0';
              fw.invert_readout := '0';
            end if;
          else
            if dual='1' and freeze='0' and fr.unaligned_jump='1' then
              fw.invert_readout:='1';
            else
              --fw.invert_readout:='0';
            end if;
          end if;
        else
          -- Jump request
          fw.fpc := jumpaddr;
          fw.priv:= jumppriv;
          fw.unaligned := jumpaddr(1);
          fw.fpc(1 downto 0) := "00";
          fw.seq := '0';
          fw.pc := jumpaddr;
          fw.pc(0) := '0';
          fw.unaligned_jump := jumpaddr(1);
          fw.state := jumping;
          strobe_i <= '0';
          enable <= '0';
          abort <= '1';
          --fuo.valid <= '0';

        end if;

      when jumping =>
        if true then

          strobe_i <= '1';
          enable <= '1';
        if stall='0' then
          fw.fpc := npc;
          fw.seq := '1';
          --fw.unaligned := fr.unaligned_jump;
          if fr.unaligned_jump='1' then
            fw.invert_readout := '1';
            fw.state := aligning;
            fw.unaligned_jump:='0';
          else
            fw.invert_readout := '0';
            fw.state := running;
          end if;
        end if;
        else
          fw.fpc := jumpaddr;
          fw.unaligned := jumpaddr(1);
          fw.fpc(1 downto 0) := "00";

          fw.pc := jumpaddr;
          fw.pc(0) := '0';
          fw.unaligned_jump := jumpaddr(1);
          --fw.state := jumping;
          strobe_i <= '0';
          enable <= '0';
          abort <= '1';
        end if;
        fuo.valid<='0';

      when aligning =>
        fuo.valid<='0';
        if valid='1' then
          fw.qopc :=  read(15 downto 0);
          --fw.unaligned := '0';
          fw.fpc := npc;
          fw.seq := '1';
          fw.state := running;
        end if;
      when others =>
    end case;

    if rst='1' then
      fw.pc :=  RESETADDRESS;
      fw.fpc := RESETADDRESS;
      fw.seq := '0';
      fw.priv:='1';
      --strobe_i <= '0';
      --enable <= '0';
      fw.unaligned := '0';
      fw.unaligned_jump := '0';
      fw.invert_readout := '0';
      fw.state := jumping;
      fw.qopc := (others => '0');
      --fuo.valid<='0';
    end if;

    if rising_edge(clk) then
      fr <= fw;
    end if;

  end process;

end behave;
