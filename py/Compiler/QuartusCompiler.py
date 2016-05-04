# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Authors:					Patrick Lehmann
# 
# Python Class:			This PoCXCOCompiler compiles xco IPCores to netlists
# 
# Description:
# ------------------------------------
#		TODO:
#		- 
#		- 
#
# License:
# ==============================================================================
# Copyright 2007-2016 Technische Universitaet Dresden - Germany
#											Chair for VLSI-Design, Diagnostics and Architecture
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#		http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================
#
# entry point
from pathlib import Path

from PoC.Entity import WildCard

if __name__ != "__main__":
	# place library initialization code here
	pass
else:
	from lib.Functions import Exit

	Exit.printThisIsNoExecutableFile("The PoC-Library - Python Module Compiler.XSTCompiler")


# load dependencies
from lib.Functions						import Init
from Base.Project							import ToolChain, Tool
from Base.Compiler						import Compiler as BaseCompiler, CompilerException
from ToolChains.Altera.Quartus	import Quartus, QuartusSettingsFile, QuartusProjectFile


class Compiler(BaseCompiler):
	_TOOL_CHAIN =	ToolChain.Altera_Quartus
	_TOOL =				Tool.Altera_Quartus_Map

	def __init__(self, host, showLogs, showReport, dryRun, noCleanUp):
		super().__init__(host, showLogs, showReport, dryRun, noCleanUp)

		self._quartus =			None

		configSection = host.PoCConfig['CONFIG.DirectoryNames']
		self.Directories.Working = host.Directories.Temp / configSection['QuartusSynthesisFiles']
		self.Directories.Netlist = host.Directories.Root / configSection['NetlistFiles']

		self._PrepareCompiler()

	def _PrepareCompiler(self):
		self._LogVerbose("Preparing Quartus-II Map (quartus_map).")
		quartusSection = self.Host.PoCConfig['INSTALL.Altera.Quartus']
		binaryPath = Path(quartusSection['BinaryDirectory'])
		version =	quartusSection['Version']
		self._quartus =		Quartus(self.Host.Platform, binaryPath, version, logger=self.Logger)

	def RunAll(self, fqnList, *args, **kwargs):
		for fqn in fqnList:
			entity = fqn.Entity
			if (isinstance(entity, WildCard)):
				for testbench in entity.GetQuartusNetlist():
					try:
						self.Run(testbench, *args, **kwargs)
					except CompilerException:
						pass
			else:
				testbench = entity.QuartusNetlist
				try:
					self.Run(testbench, *args, **kwargs)
				except CompilerException:
					pass

	def Run(self, netlist, board, **_):
		self._LogQuiet("IP core: {0!s}".format(netlist.Parent, **Init.Foreground))

		# setup all needed paths to execute fuse
		self._PrepareCompilerEnvironment(board.Device)
		self._WriteSpecialSectionIntoConfig(board.Device)

		self._CreatePoCProject(netlist, board)
		self._AddFileListFile(netlist.FilesFile)
		if (netlist.RulesFile is not None):
			self._AddRulesFiles(netlist.RulesFile)

		# netlist.XstFile = self.Directories.Working / (netlist.ModuleName + ".xst")
		netlist.QsfFile = self.Directories.Working / (netlist.ModuleName + ".qsf")

		self._WriteQuartusProjectFile(netlist, board.Device)

		self._LogNormal("Executing pre-processing tasks...")
		self._RunPreCopy(netlist)
		self._RunPreReplace(netlist)

		self._LogNormal("Running Altera Quartus Map...")
		self._RunCompile(netlist, board.Device)

		self._LogNormal("Executing post-processing tasks...")
		self._RunPostCopy(netlist)
		self._RunPostReplace(netlist)
		self._RunPostDelete(netlist)

	def _PrepareCompilerEnvironment(self, device):
		self._LogNormal("preparing synthesis environment...")
		self.Directories.Destination = self.Directories.Netlist / str(device)
		super()._PrepareCompilerEnvironment()

	def _WriteSpecialSectionIntoConfig(self, device):
		# add the key Device to section SPECIAL at runtime to change interpolation results
		self.Host.PoCConfig['SPECIAL'] = {}
		self.Host.PoCConfig['SPECIAL']['Device'] =				device.ShortName
		self.Host.PoCConfig['SPECIAL']['DeviceSeries'] =	device.Series
		self.Host.PoCConfig['SPECIAL']['OutputDir']	=			self.Directories.Working.as_posix()


	def _WriteQuartusProjectFile(self, netlist, device):
		quartusProjectFile = QuartusProjectFile(netlist.QsfFile)

		quartusProject = QuartusSettingsFile(netlist.ModuleName, quartusProjectFile)
		quartusProject.GlobalAssignments['FAMILY'] =							"\"{0}\"".format(device.Series)
		quartusProject.GlobalAssignments['DEVICE'] =							device.ShortName
		quartusProject.GlobalAssignments['TOP_LEVEL_ENTITY'] =		netlist.ModuleName
		quartusProject.GlobalAssignments['VHDL_INPUT_VERSION'] =	"VHDL_2008"

		quartusProject.CopySourceFilesFromProject(self.PoCProject)

		quartusProject.Write()

	def _RunPrepareCompile(self, netlist):
		pass

	def _RunCompile(self, netlist, device):
		q2map = self._quartus.GetMap()
		q2map.Parameters[q2map.ArgProjectName] =	str(netlist.QsfFile)
		q2map.Compile()