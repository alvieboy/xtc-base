library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library std;
use std.textio.all;

library work;
use work.xtcpkg.all;
use work.xtccomppkg.all;
use work.txt_util.all;

entity tracer is
  generic (
    trace_file: string := "trace.txt"
  );
  port (
    clk:              in std_logic;
    dbgi:             in execute_debug_type
  );
end entity tracer;

architecture sim of tracer is

  file 		t_file		: TEXT open write_mode is trace_file;
  signal  clock: unsigned(31 downto 0) := (others => '0');

begin

  logger: process(clk)
    variable executed: string(1 to 1);
    variable op: string(1 to 8);
  begin

    if rising_edge(clk) then
      clock <= clock + 1;
      if dbgi.valid then
        if dbgi.executed then
          executed := "E";
        else
          executed := " ";
        end if;
        if dbgi.dual then
          op := hstr(dbgi.opcode2) & hstr(dbgi.opcode1);
        else
          op := hstr(dbgi.opcode2) & "    ";

        end if;
        if TRACECLOCK then
        print( t_file, executed & " 0x" & hstr(std_logic_vector(clock)) & " 0x" &
          hstr(std_logic_vector(dbgi.pc)) & " 0x" & op & " 0x"
          & hstr(std_logic_vector(dbgi.lhs))
          & " 0x" & hstr(std_logic_vector(dbgi.rhs))
          );
        else
        print( t_file, executed & " 0x" &
          hstr(std_logic_vector(dbgi.pc)) & " 0x" & op & " 0x"
          & hstr(std_logic_vector(dbgi.lhs))
          & " 0x" & hstr(std_logic_vector(dbgi.rhs))
          );
        end if;
      end if;
    end if;

  end process;

end sim;
