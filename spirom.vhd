library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.wishbonepkg.all;

entity spirom is
  port (
    syscon:     in wb_syscon_type;
    wbi:        in wb_mosi_type;
    wbo:        out wb_miso_type;

    mosi:     out std_logic;
    miso:     in  std_logic;
    sck:      out std_logic;
    ncs:      out std_logic
  );
end entity spirom;

architecture behave of spirom is

  type state_type is (
    idle,
    chipsel,
    reselect,
    clock,
    transfer,
    read,
    chipdesel
  );

  constant CSDLYMAX: integer := 8;
  constant BASEADDR: unsigned(23 downto 0) := x"000000";
  constant PRESCALEVAL: unsigned(3 downto 0) := "0001";


  type regs_type is record
    state: state_type;
    ack: std_logic;
    sel: std_logic;
    nextaddr: unsigned(21 downto 0);
    csdly: integer range 0 to CSDLYMAX;
  end record;

  signal r: regs_type;


  signal shreg: std_logic_vector(31 downto 0);
  signal shbusy: std_logic;

  signal size: std_logic_vector(1 downto 0);
  signal loaden: std_logic;
  signal load: std_logic_vector(31 downto 0);

begin

  ncs<=r.sel;
  wbo.ack<=r.ack;
  wbo.dat<=shreg;

  process(r,wbi,syscon)
    variable w: regs_type;
    variable laddr: unsigned(21 downto 0);
  begin
    w:=r;

    w.ack:='0';
    loaden<='0';
    load<=(others => 'X');
    size<=(others => 'X');

    case r.state is
      when idle =>
        if wbi.cyc='1' and wbi.stb='1' and r.ack='0' then
          if wbi.we='1' then
            -- Ignore writes;
            w.ack:='1';
          else
            if r.sel='0' then
              if r.nextaddr=unsigned(wbi.adr(23 downto 2)) then
                -- dly must be zero
                w.state := transfer;
                w.sel:='0'; -- already
              else
                -- Need deselect.
                w.sel:='1';
                w.state := reselect;
                w.csdly := CSDLYMAX;
              end if;
            else
              w.state := chipsel;
              w.sel :='0';
              w.csdly := CSDLYMAX;
            end if;
          end if;
        end if;

      when reselect =>
        if r.csdly=0 then
          w.state := chipsel;
          w.csdly := CSDLYMAX;
          w.sel:='0';
        else
          w.csdly:=w.csdly-1;
        end if;

      when chipsel =>
        if r.csdly=0 then

          if shbusy='0' then
            w.state := clock;
          end if;

          loaden <='1';
          load(31 downto 24) <= x"0b"; -- READ_FAST
          load(23 downto 2) <= wbi.adr(23 downto 2);
          load(1 downto 0)<="00";
          size <="11";

        else
          w.csdly:=w.csdly-1;
        end if;

      when clock =>
        if shbusy='0' then
          w.state := transfer;
        end if;

        loaden<='1';
        size<="00";

      when transfer =>
        if shbusy='0' then
          w.state := read;
        end if;
        laddr:=unsigned(wbi.adr(23 downto 2));
        w.nextaddr := laddr+1;

        loaden<='1';
        size<="11";

      when read =>
        if shbusy='0' then
          -- We got data.
          w.ack:='1';
          w.state:=idle;
        end if;
      when others =>
    end case;


    if syscon.rst='1' then
      w.ack := '0';
      w.sel := '1';
      w.state:=idle;
    end if;

    if rising_edge(syscon.clk) then
      r<=w;
    end if;

  end process;

  shifter: block

    signal cnt: integer range 0 to 31;
    signal prescale: unsigned(3 downto 0);
    type shstate_type is (idle, clock0, clock1);
    signal state: shstate_type;
  begin

    process(syscon.clk)
    begin
      if rising_edge(syscon.clk) then
        if syscon.rst='1' then
          state <= idle;
          sck <= '1';
          shbusy<='0';
        else
          case state is
            when idle =>

              if loaden='1' then
                shreg<=load;
                shbusy<='1';
                prescale <= PRESCALEVAL;
                state <= clock0;
                case size is
                  when "00" => cnt<=7;
                  when "01" => cnt<=15;
                  when "10" => cnt<=23;
                  when "11" => cnt<=31;
                  when others =>
                end case;
                sck <= '1';
              end if;

            when clock0 =>
              if prescale=0 then
                prescale <= PRESCALEVAL;
                sck<='0';
                state <=clock1;
                mosi<=shreg(31);
                -- Sample ?
              else
                prescale<=prescale-1;
              end if;

            when clock1 =>
              if prescale=0 then
                prescale <= PRESCALEVAL;
                sck<='1';
                shreg(31 downto 0)<=shreg(30 downto 0) & miso;

                if cnt=0 then
                  -- If load is present, do it.
                  shbusy<='0';
                  state <=idle;
                else
                  cnt<=cnt-1;
                  state <= clock0;
                end if;

              else
                prescale<=prescale-1;
              end if;
          end case;
        end if;
      end if;
    end process;
  end block;

end behave;
