-- EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Thomas B. Preusser
--
-- Entity:  Carry-chain control for a counter input slice of (0,6) bits.
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universität Dresden - Germany,
--										 Chair of VLSI-Design, Diagnostics and Architecture
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
use IEEE.std_logic_1164.all;

entity atom06 is
  port (
    -- Bit Inputs
    x0 : in  std_logic_vector(5 downto 0);

    -- Carry-Chain MUX Control Outputs
    d  : out std_logic_vector(1 downto 0);
    s  : out std_logic_vector(1 downto 0)
  );
end entity atom06;


library UNISIM;
use UNISIM.vcomponents.all;

architecture xil of atom06 is
begin

  lo : LUT6_2
    generic map (
      INIT => x"6996_9669_9669_6996"
    )
    port map (
      O6 => s(0),
      O5 => open,
      I5 => x0(5),
      I4 => x0(4),
      I3 => x0(3),
      I2 => x0(2),
      I1 => x0(1),
      I0 => x0(0)
    );
  d(0) <= x0(5);

  hi : LUT6_2
    generic map (
      INIT => x"177E_7EE8" & x"E8E8_E8E8"
    )
    port map (
      O6 => s(1),
      O5 => d(1),
      I5 => '1',
      I4 => x0(4),
      I3 => x0(3),
      I2 => x0(2),
      I1 => x0(1),
      I0 => x0(0)
    );

end xil;
