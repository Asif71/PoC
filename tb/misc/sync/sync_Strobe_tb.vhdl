-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- =============================================================================
-- Authors:					Patrick Lehmann
--
-- Testbench:				testbench for a strobe signal synchronizer
--
-- Description:
-- ------------------------------------
--		TODO
--
-- License:
-- =============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--		http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.physical.all;
-- simulation only packages
use			PoC.sim_types.all;
use			PoC.simulation.all;
use			PoC.waveform.all;


entity sync_Strobe_tb is
end entity;


architecture tb of sync_Strobe_tb is
	constant CLOCK_1_FREQ			: FREQ								:= 100 MHz;
	constant CLOCK_2_FREQ			: FREQ								:= 60 MHz;

	signal Clock1							: std_logic;
	signal Clock2							: std_logic;

	signal Sync_in						: std_logic_vector(0 downto 0)	:= "0";
	signal Sync_out						: std_logic_vector(0 downto 0);
	signal Sync_Busy					: std_logic_vector(0 downto 0);

begin
	-- initialize global simulation status
	simInitialize;
	-- generate global testbench clock and reset
	simGenerateClock(Clock1, Frequency => CLOCK_1_FREQ);
	simGenerateClock(Clock2, Frequency => CLOCK_2_FREQ, Phase => 90 deg, Wander => 1 permil);


	procStimuli : process
		constant simProcessID	: T_SIM_PROCESS_ID := simRegisterProcess("Stimuli process");
	begin
		simWaitUntilRisingEdge(Clock1, 4);

		Sync_in			<=	"1";
		wait until rising_edge(Clock1);

		Sync_in			<=	"0";
		wait until rising_edge(Clock1);

		Sync_in			<=	"X";
		wait until rising_edge(Clock1);

		Sync_in			<=	"0";
		simWaitUntilRisingEdge(Clock1, 2);

		Sync_in			<=	"1";
		wait until rising_edge(Clock1);

		Sync_in			<=	"0";
		simWaitUntilRisingEdge(Clock1, 6);

		Sync_in			<=	"1";
		simWaitUntilRisingEdge(Clock1, 16);

		Sync_in			<=	"0";
		wait until rising_edge(Clock1);

		Sync_in			<=	"1";
		wait until rising_edge(Clock1);

		Sync_in			<=	"0";
		simWaitUntilRisingEdge(Clock1, 6);

		-- This process is finished
		simDeactivateProcess(simProcessID);
		wait;  -- forever
	end process;

	UUT : entity PoC.sync_Strobe
		generic map (
			BITS								=> 1,				-- number of bit to be synchronized
			GATED_INPUT_BY_BUSY	=> TRUE			-- use gated input (by busy signal)
		)
		port map (
			Clock1		=> Clock1,						-- input clock domain
			Clock2		=> Clock2,						-- output clock domain
			Input			=> Sync_in,						-- input bits
			Output		=> Sync_out,					-- output bits
			Busy			=> Sync_Busy					-- busy bits
		);
end architecture;
