library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.newcpupkg.all;
use work.newcpucomppkg.all;

entity execute is
  port (
    clk:  in std_logic;
    rst:  in std_logic;
    -- Input for previous stages
    fdui:  in fetchdata_output_type;
    -- Output for next stages
    euo:  out execute_output_type
  );
end entity execute;

architecture behave of execute is

      signal alu_a, alu_b: std_logic_vector(31 downto 0);
      signal alu_r: unsigned(31 downto 0);
      signal alu_ci, alu_co, alu_busy, alu_bo, alu_sign, alu_zero: std_logic;
      signal modify_flags: boolean := true;
      signal select_a_or_register: std_logic;
      signal alu_a_or_z_reg: std_logic_vector(31 downto 0);

      signal er: execute_regs_type;

  begin

  euo.r <= er;

    myaly: alu
    port map (
      clk   => clk,
      rst   => rst,
  
      a     => unsigned(alu_a),
      b     => unsigned(alu_b),
      o     => alu_r,
      op    => fdui.r.drq.alu_op,
      ci    => er.flag_carry,
      busy  => alu_busy,
      co    => alu_co,
      zero  => alu_zero,
      bo    => alu_bo,
      sign  => alu_sign
    );

    alu_a_or_z: mux32_2
      port map  (
        i0  => x"00000000",
        i1  => std_logic_vector(er.a),
        sel => fdui.r.drq.source.a_or_z,
        o   => alu_a_or_z_reg
      );

    alua_a_or_reg: mux32_2 
      port map  (
        i0  => std_logic_vector(fdui.rr),
        i1  => alu_a_or_z_reg,
        sel => fdui.r.drq.source.a_or_gpr,
        o   => alu_a
      );

    alub_a_or_reg: mux32_2
      port map  (
        i0  => alu_a_or_z_reg,
        i1  =>  std_logic_vector(fdui.rr),
        sel => fdui.r.drq.source.a_or_gpr,
        o   => alu_b
      );

    process(clk,fdui,er,rst,alu_r,modify_flags,
            alu_co, alu_sign,alu_zero,alu_bo)
      variable ew: execute_regs_type;
      constant reg_zero: unsigned(31 downto 0) := (others => '0');
    begin
      ew := er;
      --ew.fdrq := fdui.r;

      -- For pre-increment and post-increment, we need to swap
      -- the target GPR.
      if fdui.r.drq.swap_target_reg='1' then
        ew.reg2_addr := fdui.r.drq.ra1;
      else
        ew.reg2_addr := fdui.r.drq.ra2;
      end if;

      ew.rb2_we :='0';
      ew.valid := fdui.r.drq.valid;

      if fdui.r.drq.valid='1' then
        ew.alur := alu_r(31 downto 0);
        ew.wb_is_data_address := fdui.r.drq.wb_is_data_address;
        case fdui.r.drq.a_source is
          when a_source_immed =>
            ew.a(31 downto 11) := (others => fdui.r.drq.opcode(10));
            ew.a(10 downto 0) := unsigned(fdui.r.drq.opcode(10 downto 0));
          when a_source_immednext =>
            ew.a(31 downto 11) := ew.a(20 downto 0);
            ew.a(10 downto 0):= unsigned(fdui.r.drq.opcode(10 downto 0));
          when a_source_alu =>
            ew.a := alu_r;
            ew.rb2_we := not fdui.r.drq.dest.a_or_gpr;
          when a_source_none_but_wrreg =>
            ew.rb2_we := not fdui.r.drq.dest.a_or_gpr;
          when others =>
        end case;

        if modify_flags then
          ew.flag_carry := alu_co;
          ew.flag_sign  := alu_sign;
          ew.flag_borrow := alu_bo;
          ew.flag_zero := alu_zero;
        end if;

        -- Data access.
        ew.data_write := std_logic_vector(ew.a);
        -- This offset below can be used to "predecrement" a pointer.
        ew.data_address := std_logic_vector(unsigned(fdui.rr) + fdui.r.drq.la_offset);  -- Address is always a GPR
        ew.data_access := fdui.r.drq.memory_access;
        ew.data_writeenable := fdui.r.drq.memory_write;
      end if;

      if rst='1' then
        ew.a := (others => '0');
      end if;

      if rising_edge(clk) then
        er <= ew;
      end if;

    end process;
    
  end behave;
