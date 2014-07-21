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
    tlba:   out std_logic_vector(3 downto 0);
    tlbv:   out tlb_entry_type;

    mmuen:  out std_logic;
    icache_flush: out std_logic;
    dcache_flush: out std_logic;
    dcache_inflush: in std_logic;

    ci:     in copo;
    co:     out copi
  );
end entity cop_mmu;


architecture behave of cop_mmu is

  signal addr_q: unsigned(3 downto 0);
  signal req: std_logic;

  signal wrq: std_logic_vector(31 downto 0);

  signal ack: std_logic;


begin

  tlba<=std_logic_vector(addr_q);

  req<='1' when ci.id="00" and ci.en='1' else '0';

  tlbv.pagesize <= wrq(31 downto 30);
  tlbv.ctx      <= wrq(29 downto 24);
  tlbv.flags    <= wrq(23 downto 20);
  tlbv.paddr    <= wrq(19 downto 0);
  tlbv.vaddr    <= ci.data(19 downto 0);

  process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        mmuen<='0';
      else
      tlbw<='0';
      ack<='0';
      icache_flush<='0';
      dcache_flush<='0';
      if req='1' and ack='0' then
        co.data<=(others => '0');
        case ci.reg is
          when "0000" =>
            if ci.wr='1' then
              addr_q <= unsigned(ci.data(3 downto 0));
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
            if ci.wr='1' then
              mmuen<=ci.data(0);
            end if;
          when "0100" =>
            if ci.wr='1' then
              icache_flush<=ci.data(0);
              dcache_flush<=ci.data(1);
            end if;
            co.data(1) <= dcache_inflush;
          when others =>
        end case;
        ack<='1';
      else
      end if;
      end if;
    end if;
  end process;

  co.valid<=ack;

end behave;
