-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
--
-- Entity:					Converter binary numbers to BCD encoded numbers.
--
-- Description:
-- ------------------------------------
--		TODO
-- 
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
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
use			IEEE.STD_LOGIC_1164.ALL;
use			IEEE.NUMERIC_STD.ALL;

library	PoC;
use			PoC.utils.all;
use			PoC.components.all;


entity arith_convert_bin2bcd is
	generic (
		BITS					: POSITIVE		:= 8;
		DIGITS				: POSITIVE		:= 3;
		RADIX					: POSITIVE		:= 2
	);
	port (
		Clock					: in	STD_LOGIC;
		Reset					: in	STD_LOGIC;
		
		Start					: in	STD_LOGIC;
		Busy					: out	STD_LOGIC;
		
		Binary				:	in	STD_LOGIC_VECTOR(BITS - 1 downto 0);
		IsSigned			: in	STD_LOGIC															:= '0';
		BCDDigits			: out	T_BCD_VECTOR(DIGITS - 1 downto 0);
		Sign					: out STD_LOGIC
	);
end;


architecture rtl of arith_convert_bin2bcd is
	constant RADIX_BITS			: POSITIVE	:= log2ceil(RADIX);
	constant BINARY_SHIFTS	: POSITIVE	:= div_ceil(BITS, RADIX_BITS);
	constant BINARY_BITS		: POSITIVE	:= BINARY_SHIFTS * RADIX_BITS;
	
	subtype T_CARRY					is UNSIGNED(RADIX_BITS - 1 downto 0);
	type T_CARRY_VECTOR			is array(NATURAL range <>) of T_CARRY;
	
	signal Digit_Shift_rst	: STD_LOGIC;
	signal Digit_Shift_en		: STD_LOGIC;
	signal Digit_Shift_in		: T_CARRY_VECTOR(DIGITS downto 0);
	
	signal Binary_en				: STD_LOGIC;
	signal Binary_rl				: STD_LOGIC;
	signal Binary_d					: STD_LOGIC_VECTOR(BINARY_BITS - 1 downto 0)	:= (others => '0');
	
	signal Sign_d						: STD_LOGIC																		:= '0';
	signal DelayShifter			: STD_LOGIC_VECTOR(BINARY_SHIFTS downto 0)		:= '1' & (BINARY_SHIFTS - 1 downto 0 => '0');
	
	function nextBCD(Value : UNSIGNED(4 downto 0)) return UNSIGNED is
		constant Temp : UNSIGNED(4 downto 0)	:= Value - 10;
	begin
		if (Value > 9) then
			return '1' & Temp(3 downto 0);
		else
			return Value;
		end if;
	end function;
	
begin
	Busy							<= not DelayShifter(DelayShifter'high);
		
	Binary_en					<= Start;
	Binary_rl					<= Start nor DelayShifter(DelayShifter'high);
	Digit_Shift_rst		<= Start;
	Digit_Shift_en		<= Start nor DelayShifter(DelayShifter'high);
		
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				Binary_d	<= (others => '0');
			elsif (Binary_en = '1') then
				Binary_d(Binary_d'high downto Binary'high)	<= (others => '0');
				if ((IsSigned and Binary(Binary'high)) = '1') then
					Binary_d(Binary'high downto 0)						<= inc(not(Binary));
					Sign_d																		<= '1';
				else
					Binary_d(Binary'high downto 0)						<= Binary;
					Sign_d																		<= '0';
				end if;
				DelayShifter																<= (BINARY_SHIFTS downto 1 => '0') & '1';
			elsif (Binary_rl = '1') then
				DelayShifter	<= DelayShifter(DelayShifter'high - 1 downto 0) & DelayShifter(DelayShifter'high);
				Binary_d			<= Binary_d(Binary_d'high - RADIX_BITS downto 0) & Binary_d(Binary_d'high downto Binary_d'high - RADIX_BITS + 1);
			end if;
		end if;
	end process;
	
	Sign								<= Sign_d;
	Digit_Shift_in(0)		<= unsigned(Binary_d(Binary_d'high downto Binary_d'high - RADIX_BITS + 1));
	
	-- generate DIGITS many systolic elements
	genDigits : for i in 0 to DIGITS - 1 generate
		signal Digit_nxt	: UNSIGNED(3 + RADIX_BITS downto 0);
		signal Digit_d		: UNSIGNED(3 downto 0)							:= (others => '0');
	begin
		process(Digit_d, Digit_Shift_in)
			variable Temp : UNSIGNED(4 downto 0);
		begin
			Temp := '0' & Digit_d;
			for j in RADIX_BITS - 1 downto 0 loop
				Temp												:= nextBCD(Temp(3 downto 0) & Digit_Shift_in(i)(j));
				Digit_nxt(j + 4 downto j) 	<= Temp;
			end loop;
		end process;
		
		Digit_Shift_in(i + 1)	<= Digit_nxt(Digit_nxt'high downto Digit_nxt'high - RADIX_BITS + 1);

		process(Clock)
		begin
			if rising_edge(Clock) then
				if (Digit_Shift_rst = '1') then
					Digit_d		<= "0000";
				elsif (Digit_Shift_en = '1') then
					Digit_d	<= Digit_nxt(Digit_d'range);
				end if;
			end if;
		end process;
		
		BCDDigits(i)	<= t_bcd(std_logic_vector(Digit_d));
	end generate;
end;
