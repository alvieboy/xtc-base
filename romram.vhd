library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.xtcpkg.all;

entity romram is
  generic (
    BITS: integer := 32
  );
  port (
    ram_wb_clk_i:       in std_logic;
    ram_wb_rst_i:       in std_logic;
    ram_wb_ack_o:       out std_logic;
    ram_wb_dat_i:       in std_logic_vector(31 downto 0);
    ram_wb_dat_o:       out std_logic_vector(31 downto 0);
    ram_wb_adr_i:       in std_logic_vector(BITS-1 downto 2);
    ram_wb_cyc_i:       in std_logic;
    ram_wb_stb_i:       in std_logic;
    ram_wb_we_i:        in std_logic;
    ram_wb_stall_o:     out std_logic;
    ram_wb_sel_i:       in std_logic_vector(3 downto 0);

    rom_wb_clk_i:       in std_logic;
    rom_wb_rst_i:       in std_logic;
    rom_wb_ack_o:       out std_logic;
    rom_wb_dat_o:       out std_logic_vector(31 downto 0);
    rom_wb_adr_i:       in std_logic_vector(BITS-1 downto 2);
    rom_wb_cyc_i:       in std_logic;
    rom_wb_stb_i:       in std_logic;
    rom_wb_stall_o:     out std_logic
  );
end entity romram;

architecture behave of romram is

component internalram is
  port (
    CLK:              in std_logic;
    WEA:  in std_logic;
    ENA:  in std_logic;
    MASKA:    in std_logic_vector(3 downto 0);
    ADDRA:         in std_logic_vector(BITS-1 downto 2);
    DIA:        in std_logic_vector(31 downto 0);
    DOA:         out std_logic_vector(31 downto 0);
    WEB:  in std_logic;
    ENB:  in std_logic;
    ADDRB:         in std_logic_vector(BITS-1 downto 2);
    DIB:        in std_logic_vector(31 downto 0);
    MASKB:    in std_logic_vector(3 downto 0);
    DOB:         out std_logic_vector(31 downto 0)
  );
end component;

  signal rom_enable: std_logic;
  signal ram_enable: std_logic;
  signal romack, ramack: std_logic;

  constant nothing: std_logic_vector(31 downto 0) := (others => '0');
begin

  rom_enable <= rom_wb_stb_i and rom_wb_cyc_i;
  ram_enable <= ram_wb_stb_i and ram_wb_cyc_i;

  rom_wb_stall_o <= '0';
  ram_wb_stall_o <= '0';

  rom_wb_ack_o <= romack;
  ram_wb_ack_o <= ramack;

  -- ACK processing (pipelined)

  cache: if INSTRUCTION_CACHE generate

  process(rom_wb_clk_i)
  begin
    if rising_edge(rom_wb_clk_i) then
      if rom_wb_rst_i='1' then
        romack <= '0';
      else
        --if rom_enable='1' then
          romack <= rom_enable;
        --end if;
      end if;
    end if;
  end process;

  end generate;

  nocache: if not INSTRUCTION_CACHE generate

  process(rom_wb_clk_i)
  begin
    if rising_edge(rom_wb_clk_i) then
      if rom_wb_rst_i='1' then
        romack <= '0';
      else
        romack <= '1';
      end if;
    end if;
  end process;

  end generate;


  -- ACK processing (pipelined)
  process(ram_wb_clk_i)
  begin
    if rising_edge(ram_wb_clk_i) then
      if ram_wb_rst_i='1' then
        ramack <= '0';
      else
        ramack <= ram_enable;
      end if;
    end if;
  end process;

ram: internalram
  port map (
    CLK   => rom_wb_clk_i,
    WEA   => '0',
    ENA   => rom_enable,
    MASKA => "1111",
    ADDRA => rom_wb_adr_i(BITS-1 downto 2),
    DIA   => nothing,
    DOA   => rom_wb_dat_o,

    WEB   => ram_wb_we_i,
    ENB   => ram_enable,
    ADDRB => ram_wb_adr_i(BITS-1 downto 2),
    DIB   => ram_wb_dat_i,
    MASKB => ram_wb_sel_i,
    DOB   => ram_wb_dat_o
  );

end behave;
