library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.xtcpkg.all;
use work.xtccomppkg.all;
-- synthesis translate_off
use work.txt_util.all;
-- synthesis translate_on


entity execute is
  port (
    clk:  in std_logic;
    rst:  in std_logic;
    mem_busy: in std_logic;
    busy: out std_logic;
    refetch: in std_logic;
    wb_busy: in std_logic;

    -- Input for previous stages
    fdui:  in fetchdata_output_type;

    -- Output for next stages
    euo:  out execute_output_type
  );
end entity execute;

architecture behave of execute is

  signal alu_a_a, alu_a_b: std_logic_vector(31 downto 0);
  signal alu_a_r: unsigned(31 downto 0);
  signal alu_b_a, alu_b_b: std_logic_vector(31 downto 0);
  signal alu_b_r: unsigned(31 downto 0);
  signal alu1_ci, alu1_co, alu1_busy, alu1_bo, alu1_sign, alu1_zero: std_logic;
  signal alu2_ci, alu2_co, alu2_busy, alu2_bo, alu2_sign, alu2_zero: std_logic;
  signal er: execute_regs_type;

begin

  euo.r <= er;
  alu_a_a <= fdui.rr1;
  alu_a_b <= fdui.rr2;
  alu_b_a <= fdui.rr1;


  myaluA: alu_A
    port map (
      clk   => clk,
      rst   => rst,
  
      a     => unsigned(alu_a_a),
      b     => unsigned(alu_a_b),
      o     => alu_a_r,
      op    => fdui.r.drq.alu1_op,
      ci    => er.flag_carry,
      busy  => alu1_busy,
      co    => alu1_co,
      zero  => alu1_zero,
      bo    => alu1_bo,
      sign  => alu1_sign
    );

  myaluB: alu_B
    port map (
      clk   => clk,
      rst   => rst,
  
      a     => unsigned(alu_b_a),
      b     => unsigned(alu_b_b),
      o     => alu_b_r,
      op    => fdui.r.drq.alu2_op,
      co    => alu2_co,
      zero  => alu2_zero
    );

  process(clk,fdui,er,rst,alu_a_r,alu_b_r,
          alu1_co, alu1_sign,alu1_zero,alu1_bo,
          alu2_co, alu2_zero,
          mem_busy,wb_busy)
    variable ew: execute_regs_type;
    variable busy_int: std_logic;
    constant reg_zero: unsigned(31 downto 0) := (others => '0');
    variable im8_fill: unsigned(31 downto 0);
    variable invalid_instr: boolean;
  begin
    ew := er;

    ew.valid := fdui.r.drq.valid;
    ew.jump := '0';
    ew.jumpaddr := (others => 'X');
    ew.regwe := '0';
    invalid_instr := false;

    -- ALUB selector
    case fdui.r.drq.op is
      when O_ADDI | O_BRR | O_CALLR | O_CALLI | O_CMPI =>
        --alu_b_b <= std_logic_vector(im8_fill);
        alu_b_b <= std_logic_vector(fdui.r.drq.imreg);
      when others =>
        alu_b_b <= (others => 'X');
        -- See below for memory alub usage
    end case;


    if ( mem_busy='1' and fdui.r.drq.memory_access='1' ) or
      -- Load must stall pipeline for now
      ( mem_busy='1' and er.data_access='1' and er.data_writeenable='0' )
      then
      busy_int := '1';
    else
      busy_int := wb_busy;
    end if;

    if mem_busy='0' then
      ew.data_access := '0';
    end if;

    if fdui.r.drq.valid='1' and busy_int='0' then
      -- synthesis translate_off
      if rising_edge(clk) then
        -- report hstr(std_logic_vector(fdui.r.drq.pc)) & " " & fdui.r.drq.strasm;
      end if;
      -- synthesis translate_on

      ew.alur1 := alu_a_r(31 downto 0);
      ew.alur2 := alu_b_r(31 downto 0);

      ew.reg_source := fdui.r.drq.reg_source;

      ew.wb_is_data_address := fdui.r.drq.wb_is_data_address;

      if fdui.r.drq.modify_flags then
        if fdui.r.drq.reg_source=reg_source_alu1 then
          ew.flag_carry   := alu1_co;
          ew.flag_sign    := alu1_sign;
          ew.flag_borrow  := alu1_bo;
          ew.flag_zero    := alu1_zero;
        else
          ew.flag_carry   := alu2_co;
          --ew.flag_sign    := alu2_sign;
          --ew.flag_borrow  := alu2_bo;
          ew.flag_zero    := alu2_zero;
        end if;
      end if;

      ew.dreg := fdui.r.drq.dreg;
      ew.mwreg := fdui.r.drq.sra2;
      ew.regwe := fdui.r.drq.regwe;
      ew.sr := fdui.r.drq.sr;

      if mem_busy='0' or refetch='1' then
        ew.macc := fdui.r.drq.macc;
        ew.data_write := fdui.rr2;

        case fdui.r.drq.macc is
          when M_WORD  |
               M_HWORD |
               M_BYTE |
               M_WORD_POSTINC |
               M_WORD_POSTDEC |
               M_HWORD_POSTINC |
               M_BYTE_POSTINC =>
            ew.data_address := fdui.rr1;

          when M_WORD_PREINC  |
               M_WORD_PREDEC  |
               M_HWORD_PREINC |
               M_BYTE_PREINC =>
            ew.data_address := std_logic_vector(alu_b_r);

          when M_WORD_IND |
               M_HWORD_IND |
               M_BYTE_IND =>
            ew.data_address := std_logic_vector(alu_b_r);

          when others =>
            invalid_instr := true;
        end case;
        if fdui.r.drq.memory_access='1' then
          case fdui.r.drq.macc is
            when M_WORD_PREINC | M_WORD_POSTINC =>
              alu_b_b <= x"00000004";
            when M_WORD_PREDEC | M_WORD_POSTDEC =>
              alu_b_b <= x"FFFFFFFC";
            when M_HWORD_POSTINC | M_HWORD_PREINC =>
              alu_b_b <= x"00000002";
            when M_BYTE_POSTINC | M_BYTE_PREINC =>
              alu_b_b <= x"00000001";
            when M_WORD_IND |
                 M_HWORD_IND |
                 M_BYTE_IND =>
                alu_b_b <= std_logic_vector(fdui.r.drq.imreg);
            when others =>
          end case;
        end if;

        ew.data_access := fdui.r.drq.memory_access;
        ew.data_writeenable := fdui.r.drq.memory_write;

      end if;

      -- Branching

      case fdui.r.drq.op is
        when O_BRR | O_CALLR =>
        when O_CALLI  =>
          ew.jump := '1'; ew.jumpaddr := alu_b_r(31 downto 0) + fdui.r.drq.npc(31 downto 0);
        when O_BRI =>
          -- NOTE: if we use sync output here, we can use imreg.
          ew.jump := '1';
          --ew.jumpaddr := im8_fill(31 downto 0) + fdui.r.drq.npc(31 downto 0);
          ew.jumpaddr := fdui.r.drq.imreg + fdui.r.drq.npc(31 downto 0);
        when O_BRINE =>
          ew.jump := not er.flag_zero;
          --ew.jumpaddr := im8_fill(31 downto 0) + fdui.r.drq.npc(31 downto 0);
          ew.jumpaddr := fdui.r.drq.imreg + fdui.r.drq.npc(31 downto 0);
        when O_BRIE =>
          --ew.jump := er.flag_zero; ew.jumpaddr := im8_fill(31 downto 0) + fdui.r.drq.npc(31 downto 0);
          ew.jump := er.flag_zero; ew.jumpaddr := fdui.r.drq.imreg + fdui.r.drq.npc(31 downto 0);
        when O_BRIG =>
          ew.jump := er.flag_sign; ew.jumpaddr := fdui.r.drq.imreg + fdui.r.drq.npc(31 downto 0);
        when O_RET =>
          ew.jump := '1'; ew.jumpaddr := er.br;
        when others =>

      end case;
      -- Never jump if busy
      if busy_int='1' then
        ew.jump := '0';
      end if;

      -- Link register
      case fdui.r.drq.op is
        when O_CALLR | O_CALLI =>
          ew.br := fdui.r.drq.fpc;  -- This is PC+2. We have to skip delay slot
        when O_SSR =>

          case fdui.r.drq.sr is
            when SR_BR =>
              ew.br := unsigned(fdui.rr1);
            when others =>
              invalid_instr := true;

          end case;

        when others =>
      end case;
    end if;

    busy <= busy_int;

    -- Fast writeback
    euo.alur1 <= alu_a_r(31 downto 0);
    euo.alur2 <= alu_b_r(31 downto 0);
    euo.reg_source <= ew.reg_source;
    euo.dreg <= ew.dreg;
    euo.regwe <= ew.regwe;
    euo.imreg <= fdui.r.drq.imreg;
    euo.sr <= ew.sr;

    if rising_edge(clk) then
      if invalid_instr then
        report "Invalid instruction" severity failure;
      end if;
      er <= ew;
    end if;

  end process;

end behave;
