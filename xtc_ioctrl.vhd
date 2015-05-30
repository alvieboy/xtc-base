library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbonepkg.all;
use work.xtcpkg.all;

entity xtc_ioctrl is
  port (
    syscon:     in wb_syscon_type;
    wbi:        in wb_mosi_type;
    wbo:        out wb_miso_type;
    -- Slaves
    swbi:       in slot_wbi;
    swbo:       out slot_wbo;
    sids:       in slot_ids
  );
end entity xtc_ioctrl;


architecture behave of xtc_ioctrl is

  signal selector: std_logic_vector(15 downto 0);
  signal selnum: integer range 0 to 15;
  signal ackint: std_logic := '0';
  signal trans_valid: std_logic := '1';
  signal tagi: std_logic_vector(31 downto 0);

begin

  process(wbi.adr)
    variable num: integer range 0 to 15;
  begin
    num := to_integer(unsigned(wbi.adr(30 downto 28)));
    selector<=(others => '0');
    selector(num)<='1';
    selnum<=num;
  end process;

  direct: if not IO_REGISTER_INPUTS generate

    wbo.dat <= swbi(selnum).dat;
    ackint  <= swbi(selnum).ack;
    wbo.err <= swbi(selnum).err;
    wbo.tag <= tagi;

  end generate;

  indirect: if IO_REGISTER_INPUTS generate
    trans_valid<='1' when ackint='0' else '0';
    process(syscon.clk)
    begin
      if rising_edge(syscon.clk) then
        if syscon.rst='1' then
          wbo.dat <= (others => 'X');
          ackint <= '0';
          wbo.err <= '0';
          wbo.tag <= (others => 'X');
        else
          wbo.dat <= swbi(selnum).dat;
          ackint <= swbi(selnum).ack;
          wbo.err <= swbi(selnum).err;
          wbo.tag <= tagi;
        end if;
      end if;
    end process;
  end generate;

  wbo.stall <= '0';
  wbo.ack <= ackint;

  -- Simple tag generator. Also resynchronizer
  process(syscon.clk)
  begin
    if rising_edge(syscon.clk) then
      --if syscon.rst='1' then
      --  wbo.tag <=  (others => '0');
      --else
        tagi <= wbi.tag;
      --end if;
    end if;
  end process;


  slavegen: for i in 0 to 15 generate
    swbo(i).adr <= wbi.adr;
    swbo(i).dat <= wbi.dat;
    swbo(i).we  <= wbi.we;
    --swbo(i).tag <= wbi.tag;
    swbo(i).cyc <= wbi.cyc and selector(i) and trans_valid;
    swbo(i).stb <= wbi.stb and selector(i) and trans_valid;
  end generate;


end behave;
