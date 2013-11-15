library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity insnqueue is
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
end entity;


architecture behave of insnqueue is

  constant QUEUESIZE: integer := 8;

  signal rdptr, wrptr, rdptrplus: integer range 0 to QUEUESIZE-1;

  subtype insntype is std_logic_vector(15 downto 0);
  type queuetype is array(0 to QUEUESIZE-1) of insntype;
  
  signal qq: queuetype;
  signal dvalid_int: std_logic;

begin


--  process(clkr)
--  begin
--    if rising_edge(clkr) then
  process(rdptr,rdptrplus,qq)
  begin
      dout0 <= qq(rdptr);
      dout1 <= qq(rdptrplus);
  end process;
--    end if;
--  end process;

  empty <= '1' when rdptr=wrptr else '0';

  process(rdptr,wrptr)
  begin
    full <= '0';
    if wrptr=QUEUESIZE-1 then
      if rdptr=0 then
        full <= '1';
      end if;
    else
      if rdptr-wrptr=1 then
        full<='1';
      end if;
    end if;

    dvalid_int <= '0';

    -- Now, how many items ?
    if rdptr>wrptr then
      dvalid_int <= '1';
    elsif rdptr<wrptr then
      if wrptr-rdptr>1 then
          dvalid_int<='1';
      end if;
    end if;

  end process;

  process(rdptr)
  begin
    if rdptr=QUEUESIZE-1 then
      rdptrplus <= 0;
    else
      rdptrplus <= rdptr+1;
    end if;
  end process;

  process(clkw)
  begin
    if rising_edge(clkw) then
      if rst='1' then
        wrptr <= 0;
      else
        if clr='1' then
          wrptr<=rdptr;
        else
          if en='1' then
            qq(wrptr)<=din;
              if wrptr=QUEUESIZE-1 then
                wrptr<=0;
              else
                wrptr<=wrptr+1;
              end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  process(clkr)
  begin
    if rising_edge(clkr) then
      if rst='1' then
        rdptr<=0;
        dvalid<='0';
      else
        if pop='1' then
          if dualpop='0' then
            if rdptr=QUEUESIZE-1 then
              rdptr<=0;
            else
              rdptr<=rdptr+1;
            end if;
          else
            if rdptr=QUEUESIZE-1 then
              rdptr<=1;
            elsif rdptr=QUEUESIZE-2 then
              rdptr<=0;
            else
              rdptr<=rdptr+2;
            end if;
          end if;
        end if;

        dvalid <= dvalid_int;

      end if;
    end if;
  end process;

end behave;
