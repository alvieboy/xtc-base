library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.newcpupkg.all;
use work.newcpucomppkg.all;

entity tb is
end entity tb;

architecture sim of tb is

  constant period: time := 10 ns;
  signal w_clk: std_logic := '0';
  signal w_rst: std_logic := '0';

  signal wb_read:    std_logic_vector(31 downto 0);
  signal wb_write:   std_logic_vector(31 downto 0);
  signal wb_address: std_logic_vector(31 downto 0);
  signal wb_stb:     std_logic;
  signal wb_cyc:     std_logic;
  signal wb_sel:     std_logic_vector(3 downto 0);
  signal wb_we:      std_logic;
  signal wb_ack:     std_logic;

  signal rom_wb_ack:       std_logic;
  signal rom_wb_read:      std_logic_vector(31 downto 0);
  signal rom_wb_adr:       std_logic_vector(31 downto 0);
  signal rom_wb_cyc:       std_logic;
  signal rom_wb_stb:       std_logic;
  signal rom_wb_cti:       std_logic_vector(2 downto 0);
  signal rom_wb_stall:     std_logic;

begin

  w_clk <= not w_clk after period/2;

  cpu: newcpu
  port map (
    wb_clk_i        => w_clk,
    wb_rst_i        => w_rst,

    -- Master wishbone interface

    wb_ack_i        => wb_ack,
    wb_dat_i        => wb_read,
    wb_dat_o        => wb_write,
    wb_adr_o        => wb_address,
    wb_cyc_o        => wb_cyc,
    wb_stb_o        => wb_stb,
    wb_sel_o        => wb_sel,
    wb_we_o         => wb_we,
      -- ROM wb interface

    rom_wb_ack_i    => rom_wb_ack,
    rom_wb_dat_i    => rom_wb_read,
    rom_wb_adr_o    => rom_wb_adr,
    rom_wb_cyc_o    => rom_wb_cyc,
    rom_wb_stb_o    => rom_wb_stb,
    rom_wb_cti_o    => rom_wb_cti,
    rom_wb_stall_i  => rom_wb_stall,

    wb_inta_i       => '0',
    isnmi           => '0'
  );

  -- Reset procedure
  process
  begin
    w_rst<='0';
    wait for period;
    w_rst<='1';
    wait for period;
    w_rst<='0';
    wait;
  end process;


  -- Simple ROM
  rom_wb_stall <= '0';
  process(w_clk)
  begin
    if rising_edge(w_clk) then

      if rom_wb_cyc='1' and rom_wb_stb='1' then
        case rom_wb_adr(29 downto 2) is
          when x"0000000" => rom_wb_read <= x"00008000";
          when x"0000001" => rom_wb_read <= x"00009010";
          when x"0000002" => rom_wb_read <= x"0000F109"; -- 1sss0Xddd -- MOVE A, R1
          when x"0000003" => rom_wb_read <= x"00008010"; -- Load 1
          when x"0000004" => rom_wb_read <= x"00008010"; -- Load 1
          when x"0000005" => rom_wb_read <= x"0000112A"; -- Add A to R1, store to R2 -- 1sss01ddd
          when x"0000006" => rom_wb_read <= x"00001838"; -- Sub R1 to A, store in Zero   -- GPR, AZ, AZ 0sss110__
          when x"0000007" => rom_wb_read <= x"00001938"; -- Sub A to R1, store in Zero   -- AZ, GPR, AZ 1sss110__
          when x"0000008" => rom_wb_read <= x"00004024"; -- LA, Load R1 address + 1
          when x"0000009" => rom_wb_read <= x"0000" & "1110"&"0"&"11"&"1"&"001"&"000"&"11"; -- SA, Store R2 address + 1  -- 1	1	1	0	o	M	M		S	S	S				o	o
          when x"000000a" => rom_wb_read <= x"00008001";
          when x"000000b" => rom_wb_read <= x"0000" & "1110"&"0"&"11"&"1"&"001"&"000"&"11"; -- SA, Store R2 address + 1  -- 1	1	1	0	o	M	M		S	S	S				o	o
          

          when others => rom_wb_read <= (others => '0');
        end case;
        rom_wb_ack<='1';
      else
        rom_wb_ack<='0';
      end if;
    end if;
  end process;

end sim;
