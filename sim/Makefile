CFLAGS=-O2 -g

WORKSOURCES=../tx_unit_sim.vhd        \
../xtcpkg.vhd                     \
../xtc.vhd                        \
../pty.vhd                        \
../fifo.vhd                       \
../uart_mv_filter.vhd             \
../uart_rx.vhd                    \
../uart.vhd                       \
../wishbonepkg.vhd                \
../regbank_4r_2w.vhd              \
../taint.vhd                      \
../txt_util.vhd                   \
../generic_dp_ram_r.vhd           \
../alu_b.vhd                      \
../regbank_3p.vhd                 \
../regbank_2p.vhd                 \
../writeback.vhd                  \
../tb.vhd                         \
../mux32_4.vhd                    \
../mux32_2.vhd                    \
../memory.vhd                     \
../icache.vhd                     \
../generic_dp_ram.vhd             \
../fetch.vhd                      \
../fetchdata.vhd                  \
../execute.vhd                    \
../decode.vhd                     \
../alu_a.vhd                      \
../opdec.vhd                      \
../wb_singleport_ram.vhd          \
../regbank_5p.vhd                 \
../wb_master_np_to_slave_p.vhd    \
../wbarb2_1.vhd                   \
../romram.vhd                     \
../internalram.vhd                \
../wbmux2.vhd                     \
../wb_master_p_to_slave_np.vhd    \
../tb_standalone.vhd              \
../uart_brgen.vhd                 \
../uart_pty_tx.vhd                \
../xtccomppkg.vhd                 \
../xtc_top_bram.vhd

all: tb

tb: ../tb.vhd $(WORKSOURCES) work-obj93.cf pty-impl.o
	@ghdl -m --ieee=synopsys -fexplicit -Wl,pty-impl.o tb
	@echo "Now run as ./tb --ieee-asserts=disable --wave=out.ghw"
	
work-obj93.cf: 
	@for i in $(WORKSOURCES); do \
		echo Importing $$i; \
		ghdl -i $$i; \
	done

clean:
	rm -f work-obj93.cf