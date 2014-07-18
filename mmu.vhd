library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.xtcpkg.all;

entity mmu is
  port (
    clk:    in std_logic;
    rst:    in std_logic;

    addr:   in std_logic_vector(31 downto 0);
    ctx:    in std_logic_vector(5 downto 0);
    en:     in std_logic;

    tlbw:   in std_logic;
    tlba:   in std_logic_vector(3 downto 0);
    tlbv:   in tlb_entry_type;
    
    paddr:  out std_logic_vector(31 downto 0);
    valid:  out std_logic;
    pw:     out std_logic; -- Write permission
    pr:     out std_logic; -- Read permission
    px:     out std_logic; -- eXecute permission
    ps:     out std_logic  -- Supervisor/User
  );
end entity mmu;


architecture behave of mmu is


  constant TLB_ENTRIES: integer := 8;

  constant PAGE_4K:       std_logic_vector(1 downto 0) := "00";
  constant PAGE_256K:     std_logic_vector(1 downto 0) := "01";
  constant PAGE_1M:       std_logic_vector(1 downto 0) := "10";
  constant PAGE_16M:      std_logic_vector(1 downto 0) := "11";

  signal  tlbmatch: std_logic_vector(TLB_ENTRIES-1 downto 0);

  type tlb_array_type is array(TLB_ENTRIES-1 downto 0) of tlb_entry_type;

  signal tlb: tlb_array_type;

  subtype physaddr_t is std_logic_vector(31 downto 0);
  type physaddr_a is array(TLB_ENTRIES-1 downto 0) of physaddr_t;
  signal physaddr: physaddr_a;

begin

  -- Match signals
  tlbe: for n in 0 to TLB_ENTRIES-1 generate
    process(tlb(n), addr, ctx)
      variable match_4k, match_256k, match_1m, match_16m, match_ctx: std_logic;
      variable e: tlb_entry_type;
    begin
      e:=tlb(n);
      match_4k    :='0';
      match_256k  :='0';
      match_16m   :='0';
      match_1m    :='0';
      match_ctx   :='0';


      physaddr(n) <= (others => 'X');

      if (e.ctx=ctx) then
        match_ctx:='1';
      end if;

      if (e.vaddr(17 downto 12) = addr(17 downto 12)) then
        match_4k  := '1';
      end if;
      if (e.vaddr(19 downto 18) = addr(19 downto 18)) then
        match_256k  := '1';
      end if;
      if (e.vaddr(23 downto 20) = addr(23 downto 20)) then
        match_1m    := '1';
      end if;
      if (e.vaddr(31 downto 24) = addr(31 downto 24)) then
        match_16m   := '1';
      end if;


      case (e.pagesize) is
        when PAGE_4K =>
          tlbmatch(n) <= match_ctx and match_16m and match_1m and match_256k and match_4k;
          physaddr(n) <= e.paddr(31 downto 12) & addr(11 downto 0);
        when PAGE_256K =>
          tlbmatch(n) <= match_ctx and match_16m and match_1m and match_256k;
          physaddr(n) <= e.paddr(31 downto 18) & addr(17 downto 0);
        when PAGE_1M =>
          tlbmatch(n) <= match_ctx and match_16m and match_1m;
          physaddr(n) <= e.paddr(31 downto 20) & addr(19 downto 0);
        when PAGE_16M =>
          tlbmatch(n) <= match_ctx and match_16m;
          physaddr(n) <= e.paddr(31 downto 24) & addr(23 downto 0);
        when others =>
          tlbmatch(n) <= '0';

      end case;

    end process;
  end generate;

  process(clk)
    variable valid_i: std_logic;
  begin
    if rising_edge(clk) then
      valid_i:='0';
      if en='1' then
        for i in 0 to TLB_ENTRIES-1 loop
          if tlbmatch(i)='1' then
            paddr <= physaddr(i);
            valid_i:='1';
          end if;
        end loop;
        valid<=valid_i;
      end if;

      if tlbw='1' then
        tlb(to_integer(unsigned(tlba)))<=tlbv;
      end if;

    end if;
  end process;





end behave;

